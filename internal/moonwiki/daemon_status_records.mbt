///|
async fn daemon_status_record(root : String, action : String) -> Json {
  let current = read_daemon_lifecycle_state(root)
  let descriptor = town_service_descriptor(root, "daemon")
  let pid = json_int(current, "pid", default=0)
  let running = pid > 0 && pid_is_running(pid)
  let status = if running {
    "running"
  } else if pid > 0 {
    "stopped"
  } else {
    "not-started"
  }
  daemon_result(
    root,
    action,
    ok=true,
    status~,
    running~,
    message=if running {
      "Moontown daemon is running"
    } else if pid > 0 {
      "Moontown daemon is not running"
    } else {
      "Moontown daemon has not been started by Moondesk"
    },
    pid~,
    command=json_string(
      current,
      "command",
      default=json_string(descriptor, "display", default=""),
    ),
    started_at=json_string(current, "started_at", default=""),
    stopped_at=json_string(current, "stopped_at", default=""),
    stdout_path=json_string(current, "stdout_path", default=""),
    stderr_path=json_string(current, "stderr_path", default=""),
  )
}

///|
async fn supervised_daemon_status(root : String, action : String) -> Json {
  let status = daemon_status_record(root, action)
  let policy = read_daemon_policy(root)
  let descriptor = town_service_descriptor(root, "daemon")
  let enabled = json_bool(policy, "enabled", default=false)
  let desired = json_string(policy, "desired_state", default="stopped")
  if enabled &&
    desired == "running" &&
    !json_bool(status, "running", default=false) &&
    json_bool(descriptor, "configured", default=false) {
    increment_daemon_restart_count(root)
    start_managed_daemon(root, action="supervise")
  } else {
    touch_daemon_policy_health(root)
    daemon_result_with_policy(root, status)
  }
}

///|
async fn daemon_result(
  root : String,
  action : String,
  ok~ : Bool,
  status~ : String,
  running? : Bool = false,
  message~ : String,
  pid? : Int = 0,
  command? : String = "",
  started_at? : String = "",
  stopped_at? : String = "",
  stdout_path? : String = "",
  stderr_path? : String = "",
) -> Json {
  daemon_result_with_policy(root, {
    "ok": ok,
    "action": action,
    "status": status,
    "running": running,
    "pid": pid,
    "command": command,
    "cwd": root,
    "started_at": started_at,
    "stopped_at": stopped_at,
    "pid_file": daemon_lifecycle_state_path(root),
    "stdout_path": stdout_path,
    "stderr_path": stderr_path,
    "message": message,
  })
}

///|
async fn daemon_result_with_policy(root : String, record : Json) -> Json {
  let policy = read_daemon_policy(root)
  let descriptor = town_service_descriptor(root, "daemon")
  {
    "ok": json_bool(record, "ok", default=false),
    "action": json_string(record, "action", default="status"),
    "status": json_string(record, "status", default="unknown"),
    "running": json_bool(record, "running", default=false),
    "pid": json_int(record, "pid", default=0),
    "command": json_string(
      record,
      "command",
      default=json_string(descriptor, "display", default=""),
    ),
    "cwd": json_string(record, "cwd", default=root),
    "started_at": json_string(record, "started_at", default=""),
    "stopped_at": json_string(record, "stopped_at", default=""),
    "pid_file": json_string(
      record,
      "pid_file",
      default=daemon_lifecycle_state_path(root),
    ),
    "stdout_path": json_string(record, "stdout_path", default=""),
    "stderr_path": json_string(record, "stderr_path", default=""),
    "message": json_string(record, "message", default=""),
    "supervision_enabled": json_bool(policy, "enabled", default=false),
    "desired_state": json_string(policy, "desired_state", default="stopped"),
    "restart_count": json_int(policy, "restart_count", default=0),
    "last_health_check": json_string(policy, "last_health_check", default=""),
    "policy_file": daemon_policy_path(root),
    "service_configured": json_bool(descriptor, "configured", default=false),
    "service_config_path": json_string(descriptor, "config_path", default=""),
    "service_cwd": json_string(descriptor, "cwd", default=root),
  }
}

///|
async fn daemon_policy_record(root : String, action~ : String) -> Json {
  let policy = read_daemon_policy(root)
  let descriptor = town_service_descriptor(root, "daemon")
  {
    "ok": true,
    "action": action,
    "status": if json_bool(policy, "enabled", default=false) {
      "supervised"
    } else {
      "unsupervised"
    },
    "running": json_bool(
      daemon_status_record(root, "status"),
      "running",
      default=false,
    ),
    "pid": json_int(daemon_status_record(root, "status"), "pid", default=0),
    "command": json_string(descriptor, "display", default=""),
    "cwd": root,
    "started_at": json_string(
      daemon_status_record(root, "status"),
      "started_at",
      default="",
    ),
    "stopped_at": json_string(
      daemon_status_record(root, "status"),
      "stopped_at",
      default="",
    ),
    "pid_file": daemon_lifecycle_state_path(root),
    "stdout_path": json_string(
      daemon_status_record(root, "status"),
      "stdout_path",
      default="",
    ),
    "stderr_path": json_string(
      daemon_status_record(root, "status"),
      "stderr_path",
      default="",
    ),
    "message": if json_bool(policy, "enabled", default=false) {
      "Daemon supervision is enabled"
    } else {
      "Daemon supervision is disabled"
    },
    "supervision_enabled": json_bool(policy, "enabled", default=false),
    "desired_state": json_string(policy, "desired_state", default="stopped"),
    "restart_count": json_int(policy, "restart_count", default=0),
    "last_health_check": json_string(policy, "last_health_check", default=""),
    "policy_file": daemon_policy_path(root),
    "service_configured": json_bool(descriptor, "configured", default=false),
    "service_config_path": json_string(descriptor, "config_path", default=""),
    "service_cwd": json_string(descriptor, "cwd", default=root),
  }
}
