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
  let context = workspace_context(workspace_root)
  let root = context.suite_root
  let book_id = normalize_pdf_watch_book_id(
    json_string(payload, "book_id", default=""),
    topic~,
    pattern_id~,
  )
  let book_root = context.book_root(book_id)
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
  let book_registration = match
    moontown_owner_post_json(workspace_root, "/api/book-registrations", {
      "book_id": book_id,
      "title": book_pattern_title(pattern_id, topic),
      "purpose": purpose,
      "workspace_root": book_root,
      "tags": json_from_string_array(["research", pattern_id]),
      "skills": json_from_string_array(skill_pack),
    }) {
    Ok(value) => value
    Err(error) => {
      send_api_error(
        conn,
        method_,
        503,
        "Service Unavailable",
        "MoonBook was created locally, but MoonTown registration is incomplete: " +
        error,
      )
      return
    }
  }
  let owner_goal_receipt = match
    moontown_owner_post_json(
      workspace_root,
      "/api/operator-requests",
      moontown_owner_watch_payload(goal),
    ) {
    Ok(value) => value
    Err(error) => {
      send_api_error(
        conn,
        method_,
        503,
        "Service Unavailable",
        "MoonBook is registered, but its MoonTown watch is incomplete: " + error,
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
    owner_receipt=owner_goal_receipt,
  ) catch {
    _ =>
      {
        "ok": false,
        "status": "failed",
        "message": "Could not write MoonTown standing goal registration receipt",
      }
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
        "message": "Could not write MoonTown book template request",
      }
  }
  let readiness = pdf_watch_readiness(
    workspace_root, book_root, book_id, pattern_id, goal,
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
    "catalog_entry": json_bool(book_registration, "ok", default=false),
    "readiness": readiness,
  }
  send_json(conn, method_, response)
}
