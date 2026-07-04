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
      let endpoint = @desk.moonclaw_route("runs")
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_moonclaw_runs(workspace_root, request_path, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "moonclaw", "progress"] => {
      let endpoint = @desk.moonclaw_route("progress")
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_moonclaw_progress(workspace_root, request_path, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "moonclaw", "events"] => {
      let endpoint = @desk.moonclaw_route("events")
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_moonclaw_events(workspace_root, request_path, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "moonclaw", "runs", run_id, "artifacts"] => {
      let endpoint = @desk.moonclaw_run_artifacts_route()
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_moonclaw_artifacts(workspace_root, run_id, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "moonclaw", "daemon"] => {
      let endpoint = @desk.moonclaw_route("daemon")
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_moonclaw_daemon(workspace_root, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "moonclaw", "models"] => {
      let endpoint = @desk.moonclaw_route("models")
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_moonclaw_models(workspace_root, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    _ => false
  }
}
