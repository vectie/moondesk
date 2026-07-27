///|
fn town_platform_evidence_from_values(
  platform : String,
  architecture : String,
) -> Json {
  let normalized_platform = match platform.trim().to_lower() {
    "darwin" | "macos" => "macos"
    "linux" => "linux"
    value => value.to_owned()
  }
  let normalized_architecture = match architecture.trim().to_lower() {
    "aarch64" | "arm64" => "arm64"
    "amd64" | "x86_64" => "x86_64"
    value => value.to_owned()
  }
  {
    "supported": (
      normalized_platform == "macos" || normalized_platform == "linux"
    ) &&
    (normalized_architecture == "arm64" || normalized_architecture == "x86_64"),
    "platform": normalized_platform,
    "architecture": normalized_architecture,
  }
}

///|
async fn town_platform_evidence() -> Json {
  let (_, system, _) = run_process_capture("uname", ["-s"])
  let (_, machine, _) = run_process_capture("uname", ["-m"])
  town_platform_evidence_from_values(system, machine)
}

///|
fn town_installation_evidence_from_values(
  configured : Bool,
  launch_agent_matches : Bool,
) -> Json {
  {
    "installed": configured || launch_agent_matches,
    "source": if configured {
      "service-configured"
    } else if launch_agent_matches {
      "launch-agent"
    } else {
      "none"
    },
  }
}

///|
fn town_configuration_evidence_from_values(
  installed : Bool,
  configured : Bool,
  configuration_valid? : Bool = true,
  configuration_reason? : String = "",
) -> Json {
  {
    "configured": configured,
    "valid": !installed || (configured && configuration_valid),
    "reason": if !installed {
      "not-installed"
    } else if !configured {
      "service-configuration-missing"
    } else if configuration_reason != "" {
      configuration_reason
    } else if configuration_valid {
      "service-configured"
    } else {
      "command-unavailable"
    },
  }
}

///|
fn town_configuration_evidence_from_descriptor(
  installed : Bool,
  descriptor : Json,
) -> Json {
  let configured = json_bool(descriptor, "configured", default=false)
  let valid = json_bool(descriptor, "configuration_valid", default=configured)
  town_configuration_evidence_from_values(
    installed,
    configured,
    configuration_valid=valid,
    configuration_reason=json_string(
      descriptor,
      "configuration_reason",
      default=if valid { "configuration-valid" } else { "command-unavailable" },
    ),
  )
}

///|
async fn town_installation_evidence(root : String, descriptor : Json) -> Json {
  let configured = json_bool(descriptor, "configured", default=false)
  let plist_path = launch_agent_plist_path(root)
  let launch_agent_matches = if @fsx.exists(plist_path) {
    let contents = @fs.read_file(plist_path).text() catch { _ => "" }
    contents.contains("<string>\{xml_escape(root)}</string>")
  } else {
    false
  }
  town_installation_evidence_from_values(configured, launch_agent_matches)
}

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
      "MoonTown daemon is running"
    } else if pid > 0 {
      "MoonTown daemon is not running"
    } else {
      "MoonTown daemon has not been started by MoonDesk"
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
  let installation_evidence = town_installation_evidence(root, descriptor)
  let configuration_evidence = town_configuration_evidence_from_descriptor(
    json_bool(installation_evidence, "installed", default=false),
    descriptor,
  )
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
    "platform_evidence": town_platform_evidence(),
    "installation_evidence": installation_evidence,
    "configuration_evidence": configuration_evidence,
  }
}

///|
async fn daemon_policy_record(root : String, action~ : String) -> Json {
  let policy = read_daemon_policy(root)
  let descriptor = town_service_descriptor(root, "daemon")
  let installation_evidence = town_installation_evidence(root, descriptor)
  let configuration_evidence = town_configuration_evidence_from_descriptor(
    json_bool(installation_evidence, "installed", default=false),
    descriptor,
  )
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
    "platform_evidence": town_platform_evidence(),
    "installation_evidence": installation_evidence,
    "configuration_evidence": configuration_evidence,
  }
}
