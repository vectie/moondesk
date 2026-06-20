///|
async fn handle_mooncode_session_runtime_commands(
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
      let receipts = read_mooncode_runtime_receipt_log(
        workspace_root, session_id,
      )
      let events = read_mooncode_event_log(workspace_root, session_id)
      let daemon = moonclaw_daemon_status(workspace_root)
      send_json(
        conn,
        method_,
        @mooncode.runtime_command_feed_result_response(
          session_id,
          commands,
          receipts,
          events,
          session,
          runtime_command_log_path=mooncode_runtime_command_log_path(
            workspace_root, session_id,
          ),
          runtime_receipt_log_path=mooncode_runtime_receipt_log_path(
            workspace_root, session_id,
          ),
          workspace_root~,
          moonclaw_root=json_string(daemon, "moonclaw_root", default=""),
          host_base_url="",
          native_ready=false,
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

///|
async fn handle_mooncode_session_runtime_control(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_mooncode_session_record(workspace_root, session_id) {
    Some(_) => {
      let commands = read_mooncode_command_log(workspace_root, session_id)
      let runtime_commands = read_mooncode_runtime_command_log(
        workspace_root, session_id,
      )
      let receipts = read_mooncode_runtime_receipt_log(
        workspace_root, session_id,
      )
      let events = read_mooncode_event_log(workspace_root, session_id)
      send_json(
        conn,
        method_,
        @mooncode.runtime_control_response(
          session_id,
          commands,
          runtime_commands,
          receipts,
          events,
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
