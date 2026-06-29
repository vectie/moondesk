///|
async fn start_managed_daemon(
  root : String,
  action? : String = "start",
) -> Json {
  let descriptor = town_service_descriptor(root, "daemon")
  if !json_bool(descriptor, "configured", default=false) {
    return daemon_result(
      root,
      action,
      ok=false,
      status="not-configured",
      message="Moontown daemon service is not configured for this workspace",
    )
  }
  let current = daemon_status_record(root, "status")
  if json_bool(current, "running", default=false) {
    return daemon_result(
      root,
      action,
      ok=true,
      status="already-running",
      running=true,
      message="Moontown daemon is already running",
      pid=json_int(current, "pid", default=0),
      started_at=json_string(current, "started_at", default=""),
      stdout_path=json_string(current, "stdout_path", default=""),
      stderr_path=json_string(current, "stderr_path", default=""),
    )
  }
  let state_dir = moondesk_daemon_dir(root)
  @fsx.make_directory(state_dir, recursive=true, exists_ok=true) catch {
    _ =>
      return daemon_result(
        root,
        action,
        ok=false,
        status="failed",
        message="Could not create daemon state directory",
      )
  }
  let id = @desk.stable_id("daemon", @async.now().to_string())
  let stdout_path = ".moontown/moondesk-daemon/" + id + ".out.log"
  let stderr_path = ".moontown/moondesk-daemon/" + id + ".err.log"
  let stdout_file = @process.redirect_to_file(
    @pathx.join(root, stdout_path),
    append=true,
    create_mode=OpenOrCreate,
    permission=0o644,
  ) catch {
    _ =>
      return daemon_result(
        root,
        action,
        ok=false,
        status="failed",
        message="Could not open daemon stdout log",
      )
  }
  let stderr_file = @process.redirect_to_file(
    @pathx.join(root, stderr_path),
    append=true,
    create_mode=OpenOrCreate,
    permission=0o644,
  ) catch {
    _ =>
      return daemon_result(
        root,
        action,
        ok=false,
        status="failed",
        message="Could not open daemon stderr log",
      )
  }
  let command = json_string(descriptor, "display", default="")
  let executable = json_string(descriptor, "command", default="")
  let args = json_string_array_items(descriptor, "args")
  let cwd = json_string(descriptor, "cwd", default=root)
  let pid = @process.spawn_orphan(
    executable,
    args,
    cwd~,
    stdout=stdout_file,
    stderr=stderr_file,
  ) catch {
    error =>
      return daemon_result(
        root,
        action,
        ok=false,
        status="failed",
        message="Could not start Moontown daemon: \{error}",
      )
  }
  @async.sleep(150)
  let running = pid_is_running(pid)
  let record = daemon_result(
    root,
    action,
    ok=running,
    status=if running { "running" } else { "exited" },
    running~,
    message=if running {
      "Moontown daemon started"
    } else {
      "Moontown daemon exited immediately"
    },
    pid~,
    command~,
    started_at=@async.now().to_string(),
    stdout_path~,
    stderr_path~,
  )
  write_daemon_lifecycle_state(root, record)
  record
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
      message="Moontown daemon is not running",
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
  let exit_code = @process.run("kill", ["-TERM", pid.to_string()]) catch {
    _ => -1
  }
  @async.sleep(500)
  let mut running = pid_is_running(pid)
  let mut escalated = false
  if exit_code == 0 && running {
    ignore(@process.run("kill", ["-KILL", pid.to_string()]) catch { _ => -1 })
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
        "Moontown daemon stopped after SIGKILL"
      } else {
        "Moontown daemon stopped"
      }
    } else {
      "Could not signal Moontown daemon"
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
  if pid <= 0 {
    false
  } else {
    let alive = run_process_quiet("kill", ["-0", pid.to_string()]) == 0
    if !alive {
      false
    } else {
      !process_stat(pid).has_prefix("Z")
    }
  }
}

///|
async fn process_stat(pid : Int) -> String {
  @async.with_task_group(group => {
    let (pipe, output) = @process.read_from_process()
    let task = group.spawn(() => {
      defer pipe.close()
      @encoding/utf8.decode_lossy(pipe.read_all().binary()).trim().to_owned()
    })
    let code = @process.run(
      "ps",
      ["-p", pid.to_string(), "-o", "stat="],
      stdout=output,
    ) catch {
      _ => -1
    }
    let stat = task.wait()
    if code == 0 {
      stat
    } else {
      ""
    }
  }) catch {
    _ => ""
  }
}
