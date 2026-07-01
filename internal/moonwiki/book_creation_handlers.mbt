///|
async fn create_pdf_evidence_watch_book_from_payload(
  workspace_root : String,
  payload : Json,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
  pattern_id~ : String,
) -> Unit {
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
  let websites = pdf_watch_websites_from_payload(payload)
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
  let book_root = @pathx.join(moonsuite_books_root(root), book_id)
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
    moonsuite_product_dir(root, "moontown"),
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
