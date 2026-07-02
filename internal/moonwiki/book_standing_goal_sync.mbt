///|
async fn handle_book_sync_standing_goal(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = match read_json_body(body) {
    Some(json) => json
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  let book_id = json_string(payload, "book_id", default="").trim().to_owned()
  if book_id == "" {
    send_api_error(conn, method_, 400, "Bad Request", "book_id is required")
    return
  }
  let context = workspace_context(workspace_root)
  let book_root = context.book_root(book_id)
  let book_json_path = @pathx.join(book_root, "book.json")
  if !@fs.exists(book_json_path) {
    send_api_error(conn, method_, 404, "Not Found", "Book not found")
    return
  }
  let result = sync_book_standing_goal(context.suite_root, book_root, book_id) catch {
    error => {
      send_api_error(
        conn,
        method_,
        500,
        "Internal Server Error",
        "Could not sync standing goal: \{error}",
      )
      return
    }
  }
  let ok = json_bool(result, "ok", default=false)
  if !ok {
    send_api_error(
      conn,
      method_,
      400,
      "Bad Request",
      json_string(result, "message", default="Could not sync standing goal"),
    )
    return
  }
  send_json(conn, method_, result)
}

///|
async fn sync_book_standing_goal(
  root : String,
  book_root : String,
  book_id : String,
) -> Json {
  let book_json = read_json_file_or_object(@pathx.join(book_root, "book.json"))
  let pattern_id = pdf_watch_pattern_id_from_book_json(book_json)
  if !book_pattern_supports_standing_watch(pattern_id) {
    return {
      "ok": false,
      "status": "unsupported_pattern",
      "book_id": book_id,
      "pattern_id": pattern_id,
      "message": "Book pattern `\{pattern_id}` does not declare a standing-watch workflow.",
    }
  }
  let receipt_path = @pathx.join(
    book_root,
    pdf_watch_moontown_standing_goal_receipt_relative_path(),
  )
  let receipt = read_json_file_or_object(receipt_path)
  let receipt_ready = moontown_standing_goal_registration_ready(
    receipt_path, receipt, book_id,
  )
  if !receipt_ready {
    return {
      "ok": false,
      "status": "missing_registration_receipt",
      "book_id": book_id,
      "pattern_id": pattern_id,
      "message": "Book-local Moontown standing-goal registration receipt is missing or invalid.",
      "standing_goal_registration_path": pdf_watch_moontown_standing_goal_receipt_relative_path(),
    }
  }
  let goals_path = town_standing_goals_path(root)
  let before_global_ready = json_record_with_target_book_exists(
    read_json_array_file(goals_path),
    book_id,
  )
  let watch = json_object_field_or_empty(book_json, "watch")
  let title = json_string(book_json, "title", default="")
  let topic = topic_from_book_title(title, pattern_id, book_id)
  let purpose = trimmed_payload_text(
    json_string(book_json, "purpose", default=""),
    default=default_book_pattern_purpose(pattern_id, topic),
  )
  let cadence = positive_or_default(
    json_int(
      watch,
      "cadence_minutes",
      default=json_int(receipt, "cadence_ticks", default=30),
    ),
    30,
  )
  let source_policy = trimmed_payload_text(
    json_string(watch, "source_policy", default=""),
    default=trimmed_payload_text(
      json_string(receipt, "source_policy", default=""),
      default="web-first",
    ),
  )
  let daemon = read_json_file_or_object(town_daemon_path(root))
  let daemon_tick = json_int(
    receipt,
    "next_due_tick",
    default=json_int(daemon, "tick_sequence", default=0),
  )
  let goal = pdf_watch_standing_goal(
    book_id~,
    topic~,
    pattern_id~,
    purpose~,
    cadence~,
    source_policy~,
    daemon_tick~,
  )
  @fsx.make_directory(
    moontown_product_root(root),
    recursive=true,
    exists_ok=true,
  )
  let goals = upsert_record_by_id(read_json_array_file(goals_path), goal)
  @fsx.write_to_file(
    goals_path,
    Json::array(goals).stringify(indent=2) + "\n",
    create=0o644,
  )
  let after_global_ready = json_record_with_target_book_exists(
    read_json_array_file(goals_path),
    book_id,
  )
  let verification = book_contract_verification(
    root, book_root, book_id, pattern_id,
  )
  let run_health = Json::object({})
  {
    "ok": after_global_ready,
    "status": if before_global_ready {
      "already_synced"
    } else {
      "synced"
    },
    "book_id": book_id,
    "pattern_id": pattern_id,
    "standing_goal": goal,
    "standing_goal_id": json_string(goal, "id", default=""),
    "standing_goal_path": goals_path,
    "standing_goal_registration_path": pdf_watch_moontown_standing_goal_receipt_relative_path(),
    "standing_goal_registration_ready": receipt_ready,
    "global_standing_goal_ready_before": before_global_ready,
    "global_standing_goal_ready": after_global_ready,
    "verification": verification,
    "run_health": run_health,
  }
}

///|
async fn sync_all_book_pattern_standing_goals(root : String) -> Json {
  let context = workspace_context(root)
  let root = context.suite_root
  let books_root = context.books_root
  if !is_directory(books_root) {
    return {
      "ok": true,
      "status": "no_books_root",
      "synced_count": 0,
      "already_synced_count": 0,
      "failed_count": 0,
      "goals": Json::array([]),
      "failures": Json::array([]),
    }
  }
  let goals_path = town_standing_goals_path(root)
  let mut goals = read_json_array_file(goals_path)
  let synced : Array[Json] = []
  let skipped_books : Array[Json] = []
  let mut synced_count = 0
  let mut already_synced_count = 0
  for book_id in read_directory_names(books_root, include_hidden=false) {
    let book_root = context.book_root(book_id)
    let book_json_path = @pathx.join(book_root, "book.json")
    if !is_directory(book_root) || !@fs.exists(book_json_path) {
      continue
    }
    let book_json = read_json_file_or_object(book_json_path)
    let pattern_id = pdf_watch_pattern_id_from_book_json(book_json)
    if !book_pattern_supports_standing_watch(pattern_id) {
      continue
    }
    let receipt_path = @pathx.join(
      book_root,
      pdf_watch_moontown_standing_goal_receipt_relative_path(),
    )
    let receipt = read_json_file_or_object(receipt_path)
    let receipt_ready = moontown_standing_goal_registration_ready(
      receipt_path, receipt, book_id,
    )
    if !receipt_ready {
      skipped_books.push({
        "book_id": book_id,
        "pattern_id": pattern_id,
        "status": "missing_registration_receipt",
        "standing_goal_registration_path": pdf_watch_moontown_standing_goal_receipt_relative_path(),
      })
      continue
    }
    let before_ready = json_record_with_target_book_exists(goals, book_id)
    let goal = pdf_watch_standing_goal_from_book_state(
      root, book_root, book_id, pattern_id, book_json, receipt,
    )
    goals = upsert_record_by_id(goals, goal)
    if before_ready {
      already_synced_count += 1
    } else {
      synced_count += 1
    }
    synced.push({
      "book_id": book_id,
      "pattern_id": pattern_id,
      "standing_goal_id": json_string(goal, "id", default=""),
      "global_standing_goal_ready_before": before_ready,
    })
  }
  if synced_count > 0 || already_synced_count > 0 {
    @fsx.make_directory(
      moontown_product_root(root),
      recursive=true,
      exists_ok=true,
    )
    @fsx.write_to_file(
      goals_path,
      Json::array(goals).stringify(indent=2) + "\n",
      create=0o644,
    )
  }
  {
    "ok": true,
    "status": if synced_count > 0 {
      if skipped_books.length() > 0 {
        "synced_with_skips"
      } else {
        "synced"
      }
    } else if already_synced_count > 0 {
      if skipped_books.length() > 0 {
        "already_synced_with_skips"
      } else {
        "already_synced"
      }
    } else if skipped_books.length() > 0 {
      "no_repairable_registered_standing_watch_books"
    } else {
      "no_standing_watch_books"
    },
    "standing_goal_path": goals_path,
    "synced_count": synced_count,
    "already_synced_count": already_synced_count,
    "skipped_count": skipped_books.length(),
    "failed_count": 0,
    "goals": Json::array(synced),
    "skipped_books": Json::array(skipped_books),
    "failures": Json::array([]),
  }
}

///|
async fn pdf_watch_standing_goal_from_book_state(
  root : String,
  book_root : String,
  book_id : String,
  pattern_id : String,
  book_json : Json,
  receipt : Json,
) -> Json {
  ignore(book_root)
  let watch = json_object_field_or_empty(book_json, "watch")
  let title = json_string(book_json, "title", default="")
  let topic = topic_from_book_title(title, pattern_id, book_id)
  let purpose = trimmed_payload_text(
    json_string(book_json, "purpose", default=""),
    default=default_book_pattern_purpose(pattern_id, topic),
  )
  let cadence = positive_or_default(
    json_int(
      watch,
      "cadence_minutes",
      default=json_int(receipt, "cadence_ticks", default=30),
    ),
    30,
  )
  let source_policy = trimmed_payload_text(
    json_string(watch, "source_policy", default=""),
    default=trimmed_payload_text(
      json_string(receipt, "source_policy", default=""),
      default="web-first",
    ),
  )
  let daemon = read_json_file_or_object(town_daemon_path(root))
  let daemon_tick = json_int(
    receipt,
    "next_due_tick",
    default=json_int(daemon, "tick_sequence", default=0),
  )
  pdf_watch_standing_goal(
    book_id~,
    topic~,
    pattern_id~,
    purpose~,
    cadence~,
    source_policy~,
    daemon_tick~,
  )
}

///|
fn positive_or_default(value : Int, default : Int) -> Int {
  if value > 0 {
    value
  } else {
    default
  }
}
