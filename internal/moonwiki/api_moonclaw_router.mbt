///|
async fn route_moonclaw_api(
  workspace_root : String,
  segments : Array[String],
  method_ : @http.RequestMethod,
  request_path : String,
  body : &@io.Reader,
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
    ["api", "moonclaw", "daemon", action] => {
      let endpoint = @desk.moonclaw_route("daemon/" + action)
      if ["install", "start", "retry"].contains(action) {
        if desktop_api_route_accepts_post(endpoint, method_) {
          ignore(body)
          handle_moonclaw_daemon_action(workspace_root, action, method_, conn)
        } else {
          send_desktop_api_method_not_allowed(conn, method_, endpoint)
        }
      } else {
        send_method_not_allowed_with_methods(conn, method_, ["POST"])
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
    ["api", "moonclaw", "auth", "status"] => {
      let endpoint = @desk.moonclaw_route("auth/status")
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_moonclaw_auth_status(workspace_root, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "moonclaw", "auth", "codex", "start"] => {
      let endpoint = @desk.moonclaw_route("auth/codex/start")
      if desktop_api_route_accepts_post(endpoint, method_) {
        ignore(body)
        handle_moonclaw_auth_start(workspace_root, "codex", method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "moonclaw", "auth", "copilot", "start"] => {
      let endpoint = @desk.moonclaw_route("auth/copilot/start")
      if desktop_api_route_accepts_post(endpoint, method_) {
        ignore(body)
        handle_moonclaw_auth_start(workspace_root, "copilot", method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "moonclaw", "config", "openrouter-key"] => {
      let endpoint = @desk.moonclaw_route("config/openrouter-key")
      if desktop_api_route_accepts_post(endpoint, method_) {
        handle_moonclaw_openrouter_key(workspace_root, body, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "moonclaw", "supervisors", "activate"] => {
      let endpoint = @desk.moonclaw_supervisor_activation_route()
      if desktop_api_route_accepts_post(endpoint, method_) {
        handle_moonclaw_supervisor_activation(
          workspace_root, body, method_, conn,
        )
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "moonclaw", "supervisor-bridge"] => {
      let endpoint = @desk.moonclaw_supervisor_bridge_route()
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_supervisor_bridge_status(workspace_root, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "moonclaw", "supervisor-bridge", "grant-and-sync"] => {
      let endpoint = @desk.moonclaw_supervisor_bridge_route(
        endpoint="grant-and-sync",
      )
      if desktop_api_route_accepts_post(endpoint, method_) {
        handle_supervisor_bridge_sync(workspace_root, body, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "moonclaw", "supervisor-bridge", "receipts", kind, target_id] => {
      let endpoint = @desk.moonclaw_supervisor_bridge_receipt_route()
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_supervisor_bridge_receipt(
          workspace_root, kind, target_id, method_, conn,
        )
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "moonclaw", "supervisors", supervisor_id, "status"] => {
      let endpoint = @desk.moonclaw_supervisor_route("status")
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_moonclaw_supervisor_read(
          workspace_root, supervisor_id, "status", request_path, method_, conn,
        )
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "moonclaw", "supervisors", supervisor_id, "events"] => {
      let endpoint = @desk.moonclaw_supervisor_route("events")
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_moonclaw_supervisor_read(
          workspace_root, supervisor_id, "events", request_path, method_, conn,
        )
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "moonclaw", "supervisors", supervisor_id, "commands", action] => {
      let endpoint = @desk.moonclaw_supervisor_route("commands/" + action)
      if moonclaw_supervisor_command_allowed(action) {
        if desktop_api_route_accepts_post(endpoint, method_) {
          handle_moonclaw_supervisor_command(
            workspace_root, supervisor_id, action, body, method_, conn,
          )
        } else {
          send_desktop_api_method_not_allowed(conn, method_, endpoint)
        }
      } else {
        send_api_error(
          conn, method_, 404, "Not Found", "Unknown supervisor command",
        )
      }
      true
    }
    _ => false
  }
}
