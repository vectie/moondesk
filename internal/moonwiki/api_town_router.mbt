///|
async fn route_town_api(
  workspace_root : String,
  segments : Array[String],
  method_ : @http.RequestMethod,
  body : &@io.Reader,
  conn : @http.ServerConnection,
) -> Bool {
  match segments {
    ["api", "town", "state"] => {
      let endpoint = @desk.town_route("state")
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_town_state(workspace_root, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "town", "daemon"] => {
      let endpoint = @desk.town_route("daemon")
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_town_daemon(workspace_root, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "town", "daemon", "status"] => {
      let endpoint = @desk.town_route("daemon/status")
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_daemon_lifecycle(workspace_root, "status", body, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "town", "daemon", "supervision"] => {
      let endpoint = @desk.town_route("daemon/supervision")
      if desktop_api_route_accepts_read(endpoint, method_) ||
        desktop_api_route_accepts_post(endpoint, method_) {
        handle_daemon_supervision(workspace_root, body, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "town", "daemon", "launch-agent"] => {
      let endpoint = @desk.town_route("daemon/launch-agent")
      if desktop_api_route_accepts_read(endpoint, method_) ||
        desktop_api_route_accepts_post(endpoint, method_) {
        handle_launch_agent(workspace_root, body, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "town", "daemon", action] => {
      let endpoint = @desk.town_route("daemon/" + action)
      if desktop_api_route_accepts_post(endpoint, method_) {
        handle_daemon_lifecycle(workspace_root, action, body, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "town", "analytics"] => {
      let endpoint = @desk.town_route("analytics")
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_town_analytics(workspace_root, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "town", "progress"] => {
      let endpoint = @desk.town_route("progress")
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_town_progress(workspace_root, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "town", "events"] => {
      let endpoint = @desk.town_route("events")
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_town_events(workspace_root, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "town", "calendar.ics"] => {
      let endpoint = @desk.town_route("calendar.ics")
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_town_calendar(workspace_root, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "town", "messages"] => {
      let endpoint = @desk.town_route("messages")
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_town_messages(workspace_root, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "town", "requests"] => {
      let endpoint = @desk.town_route("requests")
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_town_requests(workspace_root, method_, conn)
      } else if desktop_api_route_accepts_post(endpoint, method_) {
        handle_town_request(workspace_root, body, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "town", "standing-goals"] => {
      let endpoint = @desk.town_route("standing-goals")
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_town_standing_goals(workspace_root, method_, conn)
      } else if desktop_api_route_accepts_post(endpoint, method_) {
        handle_create_standing_goal(workspace_root, body, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "town", "dispatch"] => {
      let endpoint = @desk.town_route("dispatch")
      if desktop_api_route_accepts_post(endpoint, method_) {
        handle_town_dispatch(workspace_root, body, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    _ => false
  }
}
