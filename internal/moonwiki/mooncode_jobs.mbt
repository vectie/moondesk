///|
async fn handle_mooncode_session_jobs(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  if !mooncode_media_safe_segment(session_id) {
    send_api_error(conn, method_, 404, "Not Found", "Unknown Code session")
    return
  }
  let book_root = match
    moonclaw_runtime_session_book_root(workspace_root, session_id) {
    Ok(value) => value
    Err(error) => {
      let (code, reason) = mooncode_session_scope_error_status(error)
      send_api_error(conn, method_, code, reason, error)
      return
    }
  }
  let daemon = ensure_moonclaw_daemon_running(
    workspace_root,
    action="read-code-jobs",
  )
  let endpoint = "/v1/code/sessions/\{session_id}/job-history?book_root=\{encode_query_value(book_root)}"
  let history = match moonclaw_get_json(daemon, endpoint) {
    Ok(value) => value
    Err(error) => {
      send_api_error(conn, method_, 503, "Service Unavailable", error)
      return
    }
  }
  if json_string(history, "kind", default="") != "mooncode-job-history.v1" ||
    json_string(history, "owner", default="") != "moonclaw" ||
    json_string(history, "session_id", default="") != session_id ||
    json_array_items(history, "jobs").length() > 50 {
    send_api_error(
      conn, method_, 502, "Bad Gateway", "Invalid Code job history",
    )
    return
  }
  send_json(conn, method_, history)
}
