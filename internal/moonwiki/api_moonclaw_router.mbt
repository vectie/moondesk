///|
async fn route_moonclaw_api(
  workspace_root : String,
  segments : Array[String],
  method_ : @http.RequestMethod,
  request_path : String,
  conn : @http.ServerConnection,
) -> Bool {
  match segments {
    ["api", "moonclaw", "runs"] => {
      if is_read_method(method_) {
        handle_moonclaw_runs(workspace_root, request_path, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "moonclaw", "progress"] => {
      if is_read_method(method_) {
        handle_moonclaw_progress(workspace_root, request_path, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "moonclaw", "events"] => {
      if is_read_method(method_) {
        handle_moonclaw_events(workspace_root, request_path, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "moonclaw", "runs", run_id, "artifacts"] => {
      if is_read_method(method_) {
        handle_moonclaw_artifacts(workspace_root, run_id, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "moonclaw", "daemon"] => {
      if is_read_method(method_) {
        handle_moonclaw_daemon(workspace_root, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "moonclaw", "models"] => {
      if is_read_method(method_) {
        handle_moonclaw_models(workspace_root, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    _ => false
  }
}
