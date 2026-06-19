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
      if is_read_method(method_) {
        handle_town_state(workspace_root, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "town", "daemon"] => {
      if is_read_method(method_) {
        handle_town_daemon(workspace_root, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "town", "daemon", "status"] => {
      if is_read_method(method_) {
        handle_daemon_lifecycle(workspace_root, "status", body, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "town", "daemon", "supervision"] => {
      if is_read_method(method_) || method_ is Post {
        handle_daemon_supervision(workspace_root, body, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "town", "daemon", "launch-agent"] => {
      if is_read_method(method_) || method_ is Post {
        handle_launch_agent(workspace_root, body, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "town", "daemon", action] => {
      if method_ is Post &&
        (action == "start" || action == "stop" || action == "restart") {
        handle_daemon_lifecycle(workspace_root, action, body, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "town", "analytics"] => {
      if is_read_method(method_) {
        handle_town_analytics(workspace_root, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "town", "progress"] => {
      if is_read_method(method_) {
        handle_town_progress(workspace_root, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "town", "events"] => {
      if is_read_method(method_) {
        handle_town_events(workspace_root, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "town", "calendar.ics"] => {
      if is_read_method(method_) {
        handle_town_calendar(workspace_root, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "town", "messages"] => {
      if is_read_method(method_) {
        handle_town_messages(workspace_root, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "town", "requests"] => {
      if is_read_method(method_) {
        handle_town_requests(workspace_root, method_, conn)
      } else if method_ is Post {
        handle_town_request(workspace_root, body, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "town", "standing-goals"] => {
      if is_read_method(method_) {
        handle_town_standing_goals(workspace_root, method_, conn)
      } else if method_ is Post {
        handle_create_standing_goal(workspace_root, body, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "town", "control"] => {
      if method_ is Post {
        handle_town_dispatch(workspace_root, body, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    _ => false
  }
}
