///|
async fn handle_mooncode_session_package_result(
  workspace_root : String,
  session_id : String,
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
  let session = match read_agent_session_record(workspace_root, session_id) {
    Some(session) => session
    None => {
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
      return
    }
  }
  let ingested_at = @async.now().to_string()
  let ingest_report = @mooncode.package_result_ingest_report(
    payload,
    session_id~,
    ingested_at~,
  )
  let events = json_array_items(ingest_report, "events")
  if events.length() == 0 {
    send_api_error(
      conn, method_, 400, "Bad Request", "No valid MoonCode package result found. Send package_built/package_verified proof with protocol, session_id, command_id, and path.",
    )
    return
  }
  let native = mooncode_forward_package_results_to_native(
    workspace_root,
    session_id,
    json_array_items(ingest_report, "native_requests"),
  )
  let with_runtime_handoff = persist_mooncode_runtime_events_and_projection(
    workspace_root, session_id, session, events,
  ) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not save MoonCode session after package-result ingest",
      )
      return
    }
  }
  let response = @mooncode.package_result_ingest_result_response(
    session_id,
    events,
    read_mooncode_event_log(workspace_root, session_id),
    ingest_report,
    with_runtime_handoff,
    enrich_agent_session_for_response(workspace_root, with_runtime_handoff, []),
    event_log_path=mooncode_event_log_path(workspace_root, session_id),
    native_state=native,
  )
  send_json(conn, method_, response)
}

///|
async fn mooncode_forward_package_results_to_native(
  workspace_root : String,
  session_id : String,
  requests : Array[Json],
) -> Json {
  let endpoint = @mooncode.moonclaw_native_package_result_endpoint(
    session_id, workspace_root,
  )
  let daemon = moonclaw_daemon_status(workspace_root)
  if !json_bool(daemon, "running", default=false) {
    return @mooncode.native_package_result_unavailable_report(
      endpoint,
      requests.length(),
      "MoonClaw daemon is not running",
    )
  }
  if !mooncode_native_runtime_ready(daemon) {
    return @mooncode.native_package_result_unavailable_report(
      endpoint,
      requests.length(),
      "MoonClaw MoonCode runtime is not available",
    )
  }
  let responses : Array[Json] = []
  let errors : Array[Json] = []
  for request in requests {
    let request = agent_session_with_field(
      request,
      "book_root",
      workspace_root.to_json(),
    )
    match moonclaw_post_json(daemon, endpoint, request) {
      Ok(response) => responses.push(response)
      Err(error) => errors.push({ "error": error, "request": request })
    }
  }
  @mooncode.native_package_result_forwarding_report(
    endpoint,
    requests.length(),
    responses,
    errors,
  )
}
