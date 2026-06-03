///|
async fn handle_town_daemon(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let daemon = read_json_file_or_object(town_daemon_path(workspace_root))
  send_json(conn, method_, daemon)
}

///|
async fn handle_town_standing_goals(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let root = @pathx.normalize(workspace_root)
  ignore(
    sync_all_pdf_watch_standing_goals(root) catch {
      _ => Json::object({})
    },
  )
  send_json(
    conn,
    method_,
    Json::array(read_json_array_file(town_standing_goals_path(root))),
  )
}

///|
async fn handle_create_standing_goal(
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
  let root = @pathx.normalize(workspace_root)
  let town_root = @pathx.join(root, ".moontown")
  @fsx.make_directory(town_root, recursive=true, exists_ok=true) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not create town state directory",
      )
      return
    }
  }
  let path = town_standing_goals_path(root)
  let daemon = read_json_file_or_object(town_daemon_path(root))
  let record = standing_goal_record_from_payload(
    payload,
    daemon_tick=json_int(daemon, "tick_sequence", default=0),
  )
  let goals = upsert_record_by_id(read_json_array_file(path), record)
  @fsx.write_to_file(
    path,
    Json::array(goals).stringify(indent=2) + "\n",
    create=0o644,
  ) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not write standing goal",
      )
      return
    }
  }
  send_json(conn, method_, record)
}

///|
async fn handle_create_pdf_evidence_watch_book(
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
  let pattern_id = normalize_book_pattern_id(
    json_string(payload, "pattern_id", default="pdf-evidence-watch"),
  )
  let base_type = json_string(payload, "base_type", default="research-book")
    .trim()
    .to_owned()
  if base_type != book_pattern_base_type(pattern_id) {
    send_api_error(
      conn,
      method_,
      400,
      "Bad Request",
      "pattern `\{pattern_id}` requires base_type `\{book_pattern_base_type(pattern_id)}`",
    )
    return
  }
  let topic = json_string(payload, "topic", default="").trim().to_owned()
  let mut websites = pdf_watch_websites_from_payload(payload)
  if pattern_id == "exchangeable-bond-evidence-watch" && websites.length() == 0 {
    websites = eb_default_source_websites()
  }
  if topic == "" {
    send_api_error(conn, method_, 400, "Bad Request", "topic is required")
    return
  }
  if websites.length() == 0 {
    send_api_error(
      conn, method_, 400, "Bad Request", "At least one source website is required",
    )
    return
  }
  let root = @pathx.normalize(workspace_root)
  let book_id = normalize_pdf_watch_book_id(
    json_string(payload, "book_id", default=""),
    topic~,
    pattern_id~,
  )
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  let created_dirs = create_pdf_watch_book_dirs(book_root) catch { _ => false }
  if !created_dirs {
    send_api_error(
      conn, method_, 500, "Internal Server Error", "Could not create book layout",
    )
    return
  }
  let cadence = pdf_watch_cadence_from_payload(payload)
  let source_policy = pdf_watch_source_policy_from_payload(payload)
  let method_path = "wiki/methods/my-analysis-method.md"
  let purpose = trimmed_payload_text(
    json_string(payload, "purpose", default=""),
    default=default_book_pattern_purpose(pattern_id, topic),
  )
  let method_body = analysis_method_for_pattern(
    pattern_id,
    topic,
    json_string(payload, "analysis_method", default=""),
  )
  let notify_on = pdf_watch_notify_on_from_payload(payload)
  let skill_pack = pdf_watch_skill_pack_from_payload(payload, pattern_id)
  let eb_target_fields = if pattern_id == "exchangeable-bond-evidence-watch" {
    eb_target_fields_from_payload(payload)
  } else {
    Json::object({})
  }
  let eb_target_bonds = if pattern_id == "exchangeable-bond-evidence-watch" {
    eb_target_bonds_from_payload(payload)
  } else {
    []
  }
  let eb_target_scope = if pattern_id == "exchangeable-bond-evidence-watch" {
    eb_target_scope_from_payload(payload, eb_target_fields, eb_target_bonds)
  } else {
    ""
  }
  let eb_effective_target_bonds = if pattern_id ==
    "exchangeable-bond-evidence-watch" {
    eb_effective_target_bonds(
      eb_target_scope, eb_target_fields, eb_target_bonds,
    )
  } else {
    eb_target_bonds
  }
  let eb_effective_target_fields = if pattern_id ==
    "exchangeable-bond-evidence-watch" {
    effective_eb_target_fields(eb_target_fields, eb_effective_target_bonds)
  } else {
    eb_target_fields
  }
  let book_json = pdf_watch_book_json(
    book_id~,
    topic~,
    pattern_id~,
    purpose~,
    cadence~,
    websites~,
    source_policy~,
    method_path~,
    notify_on~,
    skill_pack~,
    eb_target_scope~,
    eb_target_bonds=eb_effective_target_bonds,
  )
  let writes_ok = write_pdf_watch_book_files(
    book_root~,
    book_id~,
    topic~,
    pattern_id~,
    purpose~,
    book_json~,
    method_body~,
    websites~,
    eb_target_scope~,
    eb_target_fields=eb_effective_target_fields,
    eb_target_bonds=eb_effective_target_bonds,
  ) catch {
    _ => false
  }
  if !writes_ok {
    send_api_error(
      conn, method_, 500, "Internal Server Error", "Could not write book files",
    )
    return
  }
  let daemon = read_json_file_or_object(town_daemon_path(root))
  let goal = pdf_watch_standing_goal(
    book_id~,
    topic~,
    pattern_id~,
    purpose~,
    cadence~,
    source_policy~,
    daemon_tick=json_int(daemon, "tick_sequence", default=0),
  )
  let goals_path = town_standing_goals_path(root)
  @fsx.make_directory(
    @pathx.join(root, ".moontown"),
    recursive=true,
    exists_ok=true,
  ) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not create town state",
      )
      return
    }
  }
  let goals = upsert_record_by_id(read_json_array_file(goals_path), goal)
  @fsx.write_to_file(
    goals_path,
    Json::array(goals).stringify(indent=2) + "\n",
    create=0o644,
  ) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not register standing watch",
      )
      return
    }
  }
  let moonbooks = upsert_record_by_id(
    read_json_array_file(town_moonbooks_path(root)),
    pdf_watch_catalog_entry(
      book_id~,
      topic~,
      pattern_id~,
      purpose~,
      book_root~,
      skill_pack~,
    ),
  )
  @fsx.write_to_file(
    town_moonbooks_path(root),
    Json::array(moonbooks).stringify(indent=2) + "\n",
    create=0o644,
  ) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not register book catalog entry",
      )
      return
    }
  }
  let standing_goal_registration = write_moontown_standing_goal_registration(
    root~,
    book_root~,
    book_id~,
    pattern_id~,
    goal~,
  ) catch {
    _ =>
      {
        "ok": false,
        "status": "failed",
        "message": "Could not write Moontown standing goal registration receipt",
      }
  }
  let handoff = pdf_watch_handoff_record(
    book_id~,
    topic~,
    pattern_id~,
    purpose~,
    book_root~,
    goal~,
  )
  @fsx.make_directory(
    town_moondesk_requests_root(root),
    recursive=true,
    exists_ok=true,
  ) catch {
    _ => ()
  }
  @fsx.write_to_file(
    @pathx.join(town_moondesk_requests_root(root), book_id + ".json"),
    handoff.stringify(indent=2) + "\n",
    create=0o644,
  ) catch {
    _ => ()
  }
  let template_publish = write_moontown_book_template_publish(
    root~,
    book_root~,
    book_id~,
    topic~,
    pattern_id~,
    purpose~,
    cadence~,
    websites~,
    method_body~,
    skill_pack~,
    goal~,
  ) catch {
    _ =>
      {
        "ok": false,
        "status": "failed",
        "message": "Could not write Moontown book template request",
      }
  }
  if pattern_id == "exchangeable-bond-evidence-watch" {
    @fsx.write_to_file(
      @pathx.join(book_root, "raw/analysis-runs/eb-contract-verification.json"),
      book_contract_verification(root, book_root, book_id, pattern_id).stringify(
        indent=2,
      ) +
      "\n",
      create=0o644,
    ) catch {
      _ => ()
    }
  }
  let readiness = pdf_watch_readiness(
    root, book_root, book_id, pattern_id, goal,
  )
  let response : Json = {
    "ok": true,
    "status": "published",
    "base_type": base_type,
    "pattern_id": pattern_id,
    "book_id": book_id,
    "workspace_id": @desk.stable_id("book", book_id),
    "book_root": book_root,
    "book_json_path": @pathx.join(book_root, "book.json"),
    "method_path": method_path,
    "standing_goal": goal,
    "moontown_standing_goal_registration": standing_goal_registration,
    "moontown_publish": template_publish,
    "catalog_entry": true,
    "readiness": readiness,
  }
  send_json(conn, method_, response)
}

///|
async fn handle_book_contract_verify(
  workspace_root : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let book_id = decode_query_value(
      query_value(request_path, "book_id").unwrap_or(""),
    )
    .trim()
    .to_owned()
  if book_id == "" {
    send_api_error(conn, method_, 400, "Bad Request", "book_id is required")
    return
  }
  let root = @pathx.normalize(workspace_root)
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  let book_json_path = @pathx.join(book_root, "book.json")
  if !@fs.exists(book_json_path) {
    send_api_error(conn, method_, 404, "Not Found", "Book not found")
    return
  }
  let book_json = read_json_file_or_object(book_json_path)
  let pattern_id = pdf_watch_pattern_id_from_book_json(book_json)
  send_json(
    conn,
    method_,
    book_contract_verification(root, book_root, book_id, pattern_id),
  )
}

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
  let root = @pathx.normalize(workspace_root)
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  let book_json_path = @pathx.join(book_root, "book.json")
  if !@fs.exists(book_json_path) {
    send_api_error(conn, method_, 404, "Not Found", "Book not found")
    return
  }
  let result = sync_book_standing_goal(root, book_root, book_id) catch {
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
async fn handle_eb_refresh_runtime(
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
  let root = @pathx.normalize(workspace_root)
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  let book_json_path = @pathx.join(book_root, "book.json")
  if !@fs.exists(book_json_path) {
    send_api_error(conn, method_, 404, "Not Found", "Unknown book")
    return
  }
  let book_json = read_json_file_or_object(book_json_path)
  if pdf_watch_pattern_id_from_book_json(book_json) !=
    "exchangeable-bond-evidence-watch" {
    send_api_error(
      conn, method_, 400, "Bad Request", "Book is not an EB evidence watch book",
    )
    return
  }
  let refresh = refresh_eb_runtime_artifacts(root, book_root, book_id) catch {
    error => {
      send_api_error(
        conn,
        method_,
        500,
        "Internal Server Error",
        "Could not refresh EB runtime artifacts: \{error}",
      )
      return
    }
  }
  let standing_goal_sync = sync_book_standing_goal(root, book_root, book_id) catch {
    _ => Json::object({})
  }
  send_json(conn, method_, {
    "ok": true,
    "status": if json_bool(refresh, "changed", default=false) {
      "refreshed"
    } else {
      "already_current"
    },
    "book_id": book_id,
    "refresh": refresh,
    "standing_goal_sync": standing_goal_sync,
    "verification": book_contract_verification(
      root, book_root, book_id, "exchangeable-bond-evidence-watch",
    ),
    "run_health": eb_durable_run_health(root, book_root, book_id),
  })
}

///|
async fn sync_book_standing_goal(
  root : String,
  book_root : String,
  book_id : String,
) -> Json {
  let book_json = read_json_file_or_object(@pathx.join(book_root, "book.json"))
  let pattern_id = pdf_watch_pattern_id_from_book_json(book_json)
  if pattern_id != "pdf-evidence-watch" &&
    pattern_id != "exchangeable-bond-evidence-watch" {
    return {
      "ok": false,
      "status": "unsupported_pattern",
      "book_id": book_id,
      "pattern_id": pattern_id,
      "message": "Only PDF Evidence Watch book patterns can sync a Moontown standing goal.",
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
    @pathx.join(root, ".moontown"),
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
  let run_health = if pattern_id == "exchangeable-bond-evidence-watch" {
    eb_durable_run_health(root, book_root, book_id)
  } else {
    Json::object({})
  }
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
async fn sync_all_pdf_watch_standing_goals(root : String) -> Json {
  let books_root = @pathx.join(root, ".moontown/books")
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
    let book_root = @pathx.join(books_root, book_id)
    let book_json_path = @pathx.join(book_root, "book.json")
    if !is_directory(book_root) || !@fs.exists(book_json_path) {
      continue
    }
    let book_json = read_json_file_or_object(book_json_path)
    let pattern_id = pdf_watch_pattern_id_from_book_json(book_json)
    if pattern_id != "pdf-evidence-watch" &&
      pattern_id != "exchangeable-bond-evidence-watch" {
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
      @pathx.join(root, ".moontown"),
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
      "no_repairable_registered_pdf_watch_books"
    } else {
      "no_pdf_watch_books"
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

///|
async fn handle_eb_run_health(
  workspace_root : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let book_id = decode_query_value(
      query_value(request_path, "book_id").unwrap_or(""),
    )
    .trim()
    .to_owned()
  if book_id == "" {
    send_api_error(conn, method_, 400, "Bad Request", "book_id is required")
    return
  }
  let root = @pathx.normalize(workspace_root)
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  let book_json_path = @pathx.join(book_root, "book.json")
  if !@fs.exists(book_json_path) {
    send_api_error(conn, method_, 404, "Not Found", "Book not found")
    return
  }
  let book_json = read_json_file_or_object(book_json_path)
  if pdf_watch_pattern_id_from_book_json(book_json) !=
    "exchangeable-bond-evidence-watch" {
    send_api_error(
      conn, method_, 400, "Bad Request", "Book is not an EB evidence watch book",
    )
    return
  }
  ignore(
    sync_book_standing_goal(root, book_root, book_id) catch {
      _ => Json::object({})
    },
  )
  send_json(conn, method_, eb_durable_run_health(root, book_root, book_id))
}

///|
async fn handle_eb_sample_run(
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
  let root = @pathx.normalize(workspace_root)
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  let book_json_path = @pathx.join(book_root, "book.json")
  if !@fs.exists(book_json_path) {
    send_api_error(conn, method_, 404, "Not Found", "Unknown book")
    return
  }
  let book_json = read_json_file_or_object(book_json_path)
  if pdf_watch_pattern_id_from_book_json(book_json) !=
    "exchangeable-bond-evidence-watch" {
    send_api_error(
      conn, method_, 400, "Bad Request", "Book is not an EB evidence watch book",
    )
    return
  }
  let bond_code = trimmed_payload_text(
    json_string(payload, "bond_code", default=""),
    default="132001",
  )
  let bond_short_name = trimmed_payload_text(
    json_string(payload, "bond_short_name", default=""),
    default="示例EB",
  )
  let as_of = trimmed_payload_text(
    json_string(payload, "as_of", default=""),
    default="20260601",
  )
  let run_id = @desk.stable_id(
    "run",
    book_id + "-" + bond_code + "-" + bond_short_name + "-" + as_of,
  )
  let result = write_eb_sample_execution_run(
    root~,
    book_root~,
    book_id~,
    run_id~,
    bond_code~,
    bond_short_name~,
    as_of~,
  ) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not write EB sample run",
      )
      return
    }
  }
  send_json(conn, method_, result)
}

///|
async fn handle_eb_moonclaw_import(
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
  let root = @pathx.normalize(workspace_root)
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  let book_json_path = @pathx.join(book_root, "book.json")
  if !@fs.exists(book_json_path) {
    send_api_error(conn, method_, 404, "Not Found", "Unknown book")
    return
  }
  let book_json = read_json_file_or_object(book_json_path)
  if pdf_watch_pattern_id_from_book_json(book_json) !=
    "exchangeable-bond-evidence-watch" {
    send_api_error(
      conn, method_, 400, "Bad Request", "Book is not an EB evidence watch book",
    )
    return
  }
  let runtime_refresh = refresh_eb_runtime_artifacts(root, book_root, book_id) catch {
    error => {
      send_api_error(
        conn,
        method_,
        500,
        "Internal Server Error",
        "Could not refresh EB runtime artifacts before import: \{error}",
      )
      return
    }
  }
  let target_gate = eb_moonclaw_target_gate(book_root, book_id)
  if !json_bool(target_gate, "ok", default=false) {
    send_api_json_error(conn, method_, 409, "Conflict", target_gate)
    return
  }
  let packet_relative = eb_moonclaw_proposal_packet_relative_path()
  let packet_path = @pathx.join(book_root, packet_relative)
  if !@fs.exists(packet_path) {
    send_api_error(
      conn, method_, 409, "Conflict", "MoonClaw proposal packet is missing",
    )
    return
  }
  let moonclaw_root = trimmed_payload_text(
    json_string(payload, "moonclaw_root", default=""),
    default=default_moonclaw_root(),
  )
  let home = trimmed_payload_text(
    json_string(payload, "home", default=""),
    default=@pathx.join(root, ".moonclaw"),
  )
  let confirm = json_bool(payload, "confirm", default=false)
  let inline = json_bool(payload, "inline", default=false)
  let timeout_ms = clamp_int(
    json_int(payload, "timeout_ms", default=120000),
    1000,
    900000,
  )
  let receipt = run_eb_moonclaw_proposal_import(
    root~,
    book_root~,
    book_id~,
    packet_relative~,
    packet_path~,
    moonclaw_root~,
    home~,
    confirm~,
    inline~,
    timeout_ms~,
  ) catch {
    error => {
      send_api_error(
        conn,
        method_,
        500,
        "Internal Server Error",
        "Could not import MoonClaw proposal packet: \{error}",
      )
      return
    }
  }
  let run_health = eb_durable_run_health(root, book_root, book_id)
  send_json(conn, method_, {
    "ok": json_bool(receipt, "ok", default=false),
    "status": json_string(receipt, "status", default="failed"),
    "book_id": book_id,
    "proposal_id": json_string(receipt, "proposal_id", default=""),
    "run_id": json_string(receipt, "run_id", default=""),
    "receipt_path": eb_moonclaw_import_receipt_relative_path(),
    "receipt": receipt,
    "runtime_refresh": runtime_refresh,
    "run_health": run_health,
  })
}

///|
async fn handle_eb_moonclaw_run(
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
  let root = @pathx.normalize(workspace_root)
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  let book_json_path = @pathx.join(book_root, "book.json")
  if !@fs.exists(book_json_path) {
    send_api_error(conn, method_, 404, "Not Found", "Unknown book")
    return
  }
  let book_json = read_json_file_or_object(book_json_path)
  if pdf_watch_pattern_id_from_book_json(book_json) !=
    "exchangeable-bond-evidence-watch" {
    send_api_error(
      conn, method_, 400, "Bad Request", "Book is not an EB evidence watch book",
    )
    return
  }
  let target_gate = eb_moonclaw_target_gate(book_root, book_id)
  if !json_bool(target_gate, "ok", default=false) {
    send_api_json_error(conn, method_, 409, "Conflict", target_gate)
    return
  }
  let receipt_path = @pathx.join(
    book_root,
    eb_moonclaw_import_receipt_relative_path(),
  )
  let import_receipt = read_json_file_or_object(receipt_path)
  let run_id = trimmed_payload_text(
    json_string(payload, "run_id", default=""),
    default=json_string(import_receipt, "run_id", default=""),
  )
  if run_id == "" {
    send_api_error(
      conn, method_, 409, "Conflict", "No confirmed MoonClaw run id is available",
    )
    return
  }
  let moonclaw_root = trimmed_payload_text(
    json_string(payload, "moonclaw_root", default=""),
    default=json_string(
      import_receipt,
      "moonclaw_root",
      default=default_moonclaw_root(),
    ),
  )
  let home = trimmed_payload_text(
    json_string(payload, "home", default=""),
    default=json_string(
      import_receipt,
      "home",
      default=@pathx.join(root, ".moonclaw"),
    ),
  )
  let timeout_ms = clamp_int(
    json_int(payload, "timeout_ms", default=120000),
    1000,
    900000,
  )
  let receipt = run_eb_moonclaw_confirmed_run(
    root~,
    book_root~,
    book_id~,
    run_id~,
    moonclaw_root~,
    home~,
    timeout_ms~,
  ) catch {
    error => {
      send_api_error(
        conn,
        method_,
        500,
        "Internal Server Error",
        "Could not run confirmed MoonClaw job: \{error}",
      )
      return
    }
  }
  let run_health = eb_durable_run_health(root, book_root, book_id)
  send_json(conn, method_, {
    "ok": json_bool(receipt, "ok", default=false),
    "status": json_string(receipt, "status", default="failed"),
    "book_id": book_id,
    "run_id": run_id,
    "receipt_path": eb_moonclaw_run_receipt_relative_path(run_id),
    "receipt": receipt,
    "run_health": run_health,
  })
}

///|
async fn handle_eb_moonclaw_reconcile(
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
  let root = @pathx.normalize(workspace_root)
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  let book_json_path = @pathx.join(book_root, "book.json")
  if !@fs.exists(book_json_path) {
    send_api_error(conn, method_, 404, "Not Found", "Unknown book")
    return
  }
  let book_json = read_json_file_or_object(book_json_path)
  if pdf_watch_pattern_id_from_book_json(book_json) !=
    "exchangeable-bond-evidence-watch" {
    send_api_error(
      conn, method_, 400, "Bad Request", "Book is not an EB evidence watch book",
    )
    return
  }
  let requested_run_id = json_string(payload, "run_id", default="")
    .trim()
    .to_owned()
  let result = reconcile_eb_moonclaw_run(
    root~,
    book_root~,
    book_id~,
    requested_run_id~,
  ) catch {
    error => {
      send_api_error(
        conn,
        method_,
        500,
        "Internal Server Error",
        "Could not reconcile MoonClaw run: \{error}",
      )
      return
    }
  }
  send_json(conn, method_, result)
}

///|
async fn handle_eb_accept_recovered_output(
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
  let root = @pathx.normalize(workspace_root)
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  let book_json_path = @pathx.join(book_root, "book.json")
  if !@fs.exists(book_json_path) {
    send_api_error(conn, method_, 404, "Not Found", "Unknown book")
    return
  }
  let book_json = read_json_file_or_object(book_json_path)
  if pdf_watch_pattern_id_from_book_json(book_json) !=
    "exchangeable-bond-evidence-watch" {
    send_api_error(
      conn, method_, 400, "Bad Request", "Book is not an EB evidence watch book",
    )
    return
  }
  let reason = trimmed_payload_text(
    json_string(payload, "reason", default=""),
    default="Operator accepted an already validated EB workbook/source-screen package as recovered durable output.",
  )
  let result = accept_recovered_eb_output(root~, book_root~, book_id~, reason~) catch {
    error => {
      send_api_error(
        conn,
        method_,
        500,
        "Internal Server Error",
        "Could not accept recovered EB output: \{error}",
      )
      return
    }
  }
  send_json(conn, method_, result)
}

///|
async fn handle_eb_production_proof(
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
  let root = @pathx.normalize(workspace_root)
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  let book_json_path = @pathx.join(book_root, "book.json")
  if !@fs.exists(book_json_path) {
    send_api_error(conn, method_, 404, "Not Found", "Unknown book")
    return
  }
  let book_json = read_json_file_or_object(book_json_path)
  if pdf_watch_pattern_id_from_book_json(book_json) !=
    "exchangeable-bond-evidence-watch" {
    send_api_error(
      conn, method_, 400, "Bad Request", "Book is not an EB evidence watch book",
    )
    return
  }
  let moonclaw_root = trimmed_payload_text(
    json_string(payload, "moonclaw_root", default=""),
    default=default_moonclaw_root(),
  )
  let home = trimmed_payload_text(
    json_string(payload, "home", default=""),
    default=@pathx.join(root, ".moonclaw"),
  )
  let launch_if_missing = json_bool(payload, "launch_if_missing", default=true)
  let execute_moonclaw = json_bool(payload, "execute_moonclaw", default=true)
  let force_execute = json_bool(payload, "force_execute", default=false)
  let requested_timeout_ms = clamp_int(
    json_int(payload, "timeout_ms", default=300000),
    1000,
    900000,
  )
  let timeout_ms = eb_production_proof_effective_timeout_ms(
    requested_timeout_ms,
    execute_moonclaw~,
    force_execute~,
  )
  let result = run_eb_production_proof(
    root~,
    book_root~,
    book_id~,
    moonclaw_root~,
    home~,
    launch_if_missing~,
    execute_moonclaw~,
    force_execute~,
    timeout_ms~,
  ) catch {
    error => {
      send_api_error(
        conn,
        method_,
        500,
        "Internal Server Error",
        "Could not prove EB production run: \{error}",
      )
      return
    }
  }
  send_json(conn, method_, result)
}

///|
fn eb_production_proof_effective_timeout_ms(
  requested_timeout_ms : Int,
  execute_moonclaw~ : Bool,
  force_execute~ : Bool,
) -> Int {
  if (execute_moonclaw || force_execute) &&
    requested_timeout_ms < eb_production_proof_min_execution_timeout_ms() {
    eb_production_proof_min_execution_timeout_ms()
  } else {
    requested_timeout_ms
  }
}

///|
fn eb_production_proof_min_execution_timeout_ms() -> Int {
  900000
}

///|
async fn handle_town_dispatch(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  ignore(body)
  let root = @pathx.normalize(workspace_root)
  let dispatch_root = @pathx.join(root, ".moontown/moondesk-dispatches")
  @fsx.make_directory(dispatch_root, recursive=true, exists_ok=true) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not create dispatch ledger",
      )
      return
    }
  }
  let id = @desk.stable_id("dispatch", @async.now().to_string())
  let path = ".moontown/moondesk-dispatches/" + id + ".json"
  let absolute = @pathx.join(root, path)
  let preflight_repair = sync_all_pdf_watch_standing_goals(root) catch {
    _ => Json::object({ "ok": false, "status": "repair_failed" })
  }
  let can_run = @fs.exists(@pathx.join(root, "moon.mod")) &&
    @fs.exists(@pathx.join(root, "cmd/main/moon.pkg"))
  let mut exit_code = -1
  let mut stdout = ""
  let mut stderr = ""
  if can_run {
    let collected = Some(
      @process.collect_output(
        "moon",
        ["run", "cmd/main", "--", "daemon", "tick"],
        cwd=root,
      ),
    ) catch {
      error => {
        stderr = "Could not run Moontown daemon tick: \{error}"
        None
      }
    }
    match collected {
      Some((code, out, err)) => {
        exit_code = code
        stdout = out.text()
        stderr = err.text()
      }
      None => ()
    }
  } else {
    stderr = "Configured root is not a runnable Moontown checkout: \{root}"
  }
  let postflight_repair = sync_all_pdf_watch_standing_goals(root) catch {
    _ => Json::object({ "ok": false, "status": "repair_failed" })
  }
  let record : Json = {
    "id": id,
    "ok": exit_code == 0,
    "status": if exit_code == 0 {
      "daemon tick completed"
    } else {
      "daemon tick failed"
    },
    "exit_code": exit_code,
    "path": path,
    "stdout": trim_for_record(stdout),
    "stderr": trim_for_record(stderr),
    "moondesk_standing_goal_preflight_repair": preflight_repair,
    "moondesk_standing_goal_postflight_repair": postflight_repair,
  }
  @fsx.write_to_file(absolute, record.stringify(indent=2) + "\n", create=0o644) catch {
    _ => ()
  }
  send_json(conn, method_, record)
}
