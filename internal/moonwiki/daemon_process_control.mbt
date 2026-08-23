///|
async fn start_managed_daemon(
  root : String,
  action? : String = "start",
) -> Json {
  let descriptor = town_service_descriptor(root, "daemon")
  if json_bool(descriptor, "legacy_execution_rejected", default=false) {
    return daemon_result(
      root,
      action,
      ok=false,
      status="misconfigured",
      message="MoonTown daemon service configuration contains rejected host execution fields",
    )
  }
  if !json_bool(descriptor, "configured", default=false) {
    return daemon_result(
      root,
      action,
      ok=false,
      status="not-configured",
      message="MoonTown daemon service is not configured for this workspace",
    )
  }
  if !json_bool(descriptor, "configuration_valid", default=true) {
    return daemon_result(
      root,
      action,
      ok=false,
      status="misconfigured",
      message="MoonTown daemon service configuration is not usable",
    )
  }
  daemon_result(
    root,
    action,
    ok=false,
    status="trusted-binding-unavailable",
    message="MoonTown daemon launch is refused because no trusted host binding is registered",
  )
}

///|
async fn stop_managed_daemon(
  root : String,
  update_desired? : Bool = true,
) -> Json {
  if update_desired {
    set_daemon_desired_state(root, "stopped")
  }
  let current = daemon_status_record(root, "stop")
  let pid = json_int(current, "pid", default=0)
  if pid <= 0 || !json_bool(current, "running", default=false) {
    let record = daemon_result(
      root,
      "stop",
      ok=true,
      status="stopped",
      message="MoonTown daemon is not running",
      pid~,
      command=json_string(
        current,
        "command",
        default=json_string(
          town_service_descriptor(root, "daemon"),
          "display",
          default="",
        ),
      ),
      started_at=json_string(current, "started_at", default=""),
      stopped_at=@async.now().to_string(),
      stdout_path=json_string(current, "stdout_path", default=""),
      stderr_path=json_string(current, "stderr_path", default=""),
    )
    write_daemon_lifecycle_state(root, record)
    return record
  }
  let exit_code = @trusted_host.terminate_pid(pid)
  @async.sleep(500)
  let mut running = pid_is_running(pid)
  let mut escalated = false
  if exit_code == 0 && running {
    ignore(@trusted_host.force_kill_pid(pid))
    escalated = true
    @async.sleep(250)
    running = pid_is_running(pid)
  }
  let record = daemon_result(
    root,
    "stop",
    ok=exit_code == 0,
    status=if running { "stopping" } else { "stopped" },
    running~,
    message=if exit_code == 0 {
      if running {
        "Stop signal sent; daemon is still shutting down"
      } else if escalated {
        "MoonTown daemon stopped after SIGKILL"
      } else {
        "MoonTown daemon stopped"
      }
    } else {
      "Could not signal MoonTown daemon"
    },
    pid~,
    command=json_string(
      current,
      "command",
      default=json_string(
        town_service_descriptor(root, "daemon"),
        "display",
        default="",
      ),
    ),
    started_at=json_string(current, "started_at", default=""),
    stopped_at=if running { "" } else { @async.now().to_string() },
    stdout_path=json_string(current, "stdout_path", default=""),
    stderr_path=json_string(current, "stderr_path", default=""),
  )
  write_daemon_lifecycle_state(root, record)
  record
}

///|
async fn pid_is_running(pid : Int) -> Bool {
  @trusted_host.pid_is_alive(pid)
}
