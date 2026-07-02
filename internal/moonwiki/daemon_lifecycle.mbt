///|
async fn handle_daemon_lifecycle(
  workspace_root : String,
  action : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  ignore(body)
  let root = workspace_context(workspace_root).suite_root
  let result = match action {
    "status" => supervised_daemon_status(root, action)
    "start" => {
      set_daemon_desired_state(root, "running")
      start_managed_daemon(root)
    }
    "stop" => stop_managed_daemon(root)
    "restart" => {
      set_daemon_desired_state(root, "running")
      ignore(stop_managed_daemon(root, update_desired=false))
      @async.sleep(350)
      start_managed_daemon(root, action="restart")
    }
    _ =>
      daemon_result(
        root,
        action,
        ok=false,
        status="unsupported",
        message="Unsupported daemon lifecycle action",
      )
  }
  send_json(conn, method_, result)
}

///|
async fn handle_daemon_supervision(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let root = workspace_context(workspace_root).suite_root
  let result = if method_ is Get || method_ is Head {
    daemon_policy_record(root, action="status")
  } else {
    let payload = read_json_body(body).unwrap_or(Json::object({}))
    let enabled = json_bool(payload, "enabled", default=true)
    let desired = if enabled { "running" } else { "stopped" }
    write_daemon_policy(root, {
      "enabled": enabled,
      "desired_state": desired,
      "restart_count": json_int(
        read_daemon_policy(root),
        "restart_count",
        default=0,
      ),
      "last_health_check": @async.now().to_string(),
      "updated_at": @async.now().to_string(),
    })
    if enabled {
      let status = daemon_status_record(root, "supervision")
      if json_bool(status, "running", default=false) {
        daemon_policy_record(root, action="supervision")
      } else {
        increment_daemon_restart_count(root)
        start_managed_daemon(root, action="supervise")
      }
    } else {
      daemon_policy_record(root, action="supervision")
    }
  }
  send_json(conn, method_, result)
}
