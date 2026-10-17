///|
async fn handle_mooncode_realtime_session(
  workspace_root : String,
  workspace_id : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  guard find_workspace(workspace_root, workspace_id) is Some(workspace) else {
    send_api_error(
      conn, method_, 404, "Not Found", "Choose a Book for voice conversation",
    )
    return
  }
  guard read_json_body(body) is Some(Object(fields)) else {
    send_api_error(
      conn, method_, 400, "Bad Request", "Invalid voice session request",
    )
    return
  }
  let payload = fields.copy()
  payload["book_root"] = ToJson::to_json(workspace.root_path)
  let daemon = ensure_moonclaw_daemon_running(
    workspace_root,
    action="realtime-session",
  )
  if !json_bool(daemon, "running", default=false) {
    send_api_error(
      conn, method_, 503, "Unavailable", "Start the coding service to use provider voice",
    )
    return
  }
  match
    moonclaw_post_json(
      daemon,
      "/v1/mooncode/realtime-session",
      Json::object(payload),
    ) {
    Ok(result) => send_json(conn, method_, result)
    Err(error) => {
      let outcome = mooncode_session_lifecycle_proxy_failure(error)
      send_api_error(conn, method_, outcome.code, outcome.title, outcome.detail)
    }
  }
}
