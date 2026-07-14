///|
async fn route_mooncode_api(
  workspace_root : String,
  segments : Array[String],
  method_ : @http.RequestMethod,
  request_path : String,
  body : &@io.Reader,
  conn : @http.ServerConnection,
) -> Bool {
  match segments {
    ["api", "mooncode", "status"] => {
      let endpoint = @mooncode.desktop_status_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_status(workspace_root, method_, conn)
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "capabilities"] => {
      let endpoint = @mooncode.desktop_capabilities_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_capabilities(workspace_root, method_, conn)
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions"] => {
      let endpoint = @mooncode.desktop_sessions_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_sessions(workspace_root, request_path, method_, conn)
      } else if mooncode_route_accepts_post(endpoint, method_) {
        handle_create_mooncode_session(workspace_root, body, method_, conn)
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id] => {
      let endpoint = @mooncode.desktop_session_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_session(
          workspace_root, session_id, request_path, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "commands"] => {
      let endpoint = @mooncode.desktop_session_commands_endpoint()
      if mooncode_route_accepts_post(endpoint, method_) {
        handle_mooncode_session_command(
          workspace_root, session_id, body, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "watch"] => {
      let endpoint = @mooncode.desktop_session_watch_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_session_watch(
          workspace_root, session_id, request_path, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    _ => false
  }
}
