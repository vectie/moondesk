///|
async fn handle_mooncode_session_runtime_dispatch(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_mooncode_session_record(workspace_root, session_id) {
    Some(session) => {
      let commands = read_mooncode_runtime_command_log(
        workspace_root, session_id,
      )
      let receipts = read_mooncode_runtime_dispatch_log(
        workspace_root, session_id,
      )
      send_json(
        conn,
        method_,
        @mooncode.runtime_dispatch_response(
          session_id,
          commands,
          receipts,
          workspace_id=json_string(session, "workspace_id", default=""),
          workspace_name=json_string(session, "workspace_name", default=""),
          runtime_session_id=json_string(
            session,
            "mooncode_runtime_session_id",
            default=json_string(session, "id", default=""),
          ),
          dispatch_mode=json_string(
            session,
            "mooncode_dispatch_mode",
            default="unknown",
          ),
          runtime_command_log_path=mooncode_runtime_command_log_path(
            workspace_root, session_id,
          ),
          runtime_dispatch_log_path=mooncode_runtime_dispatch_log_path(
            workspace_root, session_id,
          ),
          lease_now=@async.now().to_string(),
        ),
      )
    }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}
