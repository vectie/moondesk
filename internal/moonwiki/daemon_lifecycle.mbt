///|
async fn handle_daemon_lifecycle(
  workspace_root : String,
  action : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  ignore(body)
  let root = @pathx.normalize(workspace_root)
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
  let root = @pathx.normalize(workspace_root)
  let result = if method_ is @http.RequestMethod::Get ||
    method_ is @http.RequestMethod::Head {
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

///|
async fn start_managed_daemon(
  root : String,
  action? : String = "start",
) -> Json {
  if !is_runnable_moontown(root) {
    return daemon_result(
      root,
      action,
      ok=false,
      status="not-runnable",
      message="Configured root is not a runnable Moontown checkout",
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
    create=0o644,
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
    create=0o644,
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
  let command = "moon run cmd/main -- daemon run"
  let pid = @process.spawn_orphan(
    "moon",
    ["run", "cmd/main", "--", "daemon", "run"],
    cwd=root,
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
        default="moon run cmd/main -- daemon run",
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
      default="moon run cmd/main -- daemon run",
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
async fn daemon_status_record(root : String, action : String) -> Json {
  let current = read_daemon_lifecycle_state(root)
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
      default="moon run cmd/main -- daemon run",
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
  let enabled = json_bool(policy, "enabled", default=false)
  let desired = json_string(policy, "desired_state", default="stopped")
  if enabled &&
    desired == "running" &&
    !json_bool(status, "running", default=false) &&
    is_runnable_moontown(root) {
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
  command? : String = "moon run cmd/main -- daemon run",
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
  {
    "ok": json_bool(record, "ok", default=false),
    "action": json_string(record, "action", default="status"),
    "status": json_string(record, "status", default="unknown"),
    "running": json_bool(record, "running", default=false),
    "pid": json_int(record, "pid", default=0),
    "command": json_string(
      record,
      "command",
      default="moon run cmd/main -- daemon run",
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
  }
}

///|
async fn daemon_policy_record(root : String, action~ : String) -> Json {
  let policy = read_daemon_policy(root)
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
    "command": "moon run cmd/main -- daemon run",
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
  }
}

///|
async fn is_runnable_moontown(root : String) -> Bool {
  @fs.exists(@pathx.join(root, "moon.mod")) &&
  @fs.exists(@pathx.join(root, "cmd/main/moon.pkg"))
}

///|
async fn pid_is_running(pid : Int) -> Bool {
  if pid <= 0 {
    false
  } else {
    let alive = (@process.run("kill", ["-0", pid.to_string()]) catch {
        _ => -1
      }) ==
      0
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

///|
fn moondesk_daemon_dir(root : String) -> String {
  @pathx.join(root, ".moontown/moondesk-daemon")
}

///|
fn daemon_lifecycle_state_path(root : String) -> String {
  @pathx.join(moondesk_daemon_dir(root), "state.json")
}

///|
fn daemon_policy_path(root : String) -> String {
  @pathx.join(moondesk_daemon_dir(root), "policy.json")
}

///|
async fn read_daemon_lifecycle_state(root : String) -> Json {
  let path = daemon_lifecycle_state_path(root)
  if !@fsx.exists(path) {
    return Json::object({})
  }
  @json.parse(@fsx.read_file(path)) catch {
    _ => Json::object({})
  }
}

///|
async fn read_daemon_policy(root : String) -> Json {
  let path = daemon_policy_path(root)
  if !@fsx.exists(path) {
    return {
      "enabled": false,
      "desired_state": "stopped",
      "restart_count": 0,
      "last_health_check": "",
      "updated_at": "",
    }
  }
  @json.parse(@fsx.read_file(path)) catch {
    _ =>
      {
        "enabled": false,
        "desired_state": "stopped",
        "restart_count": 0,
        "last_health_check": "",
        "updated_at": "",
      }
  }
}

///|
async fn write_daemon_policy(root : String, record : Json) -> Unit {
  @fsx.make_directory(moondesk_daemon_dir(root), recursive=true, exists_ok=true) catch {
    _ => return
  }
  @fsx.write_to_file(
    daemon_policy_path(root),
    record.stringify(indent=2) + "\n",
    create=0o644,
  ) catch {
    _ => ()
  }
}

///|
async fn set_daemon_desired_state(root : String, desired : String) -> Unit {
  let policy = read_daemon_policy(root)
  write_daemon_policy(root, {
    "enabled": json_bool(policy, "enabled", default=false),
    "desired_state": desired,
    "restart_count": json_int(policy, "restart_count", default=0),
    "last_health_check": json_string(policy, "last_health_check", default=""),
    "updated_at": @async.now().to_string(),
  })
}

///|
async fn increment_daemon_restart_count(root : String) -> Unit {
  let policy = read_daemon_policy(root)
  write_daemon_policy(root, {
    "enabled": json_bool(policy, "enabled", default=false),
    "desired_state": json_string(policy, "desired_state", default="running"),
    "restart_count": json_int(policy, "restart_count", default=0) + 1,
    "last_health_check": @async.now().to_string(),
    "updated_at": @async.now().to_string(),
  })
}

///|
async fn touch_daemon_policy_health(root : String) -> Unit {
  let policy = read_daemon_policy(root)
  if json_bool(policy, "enabled", default=false) {
    write_daemon_policy(root, {
      "enabled": true,
      "desired_state": json_string(policy, "desired_state", default="running"),
      "restart_count": json_int(policy, "restart_count", default=0),
      "last_health_check": @async.now().to_string(),
      "updated_at": json_string(policy, "updated_at", default=""),
    })
  }
}

///|
async fn write_daemon_lifecycle_state(root : String, record : Json) -> Unit {
  @fsx.make_directory(moondesk_daemon_dir(root), recursive=true, exists_ok=true) catch {
    _ => return
  }
  @fsx.write_to_file(
    daemon_lifecycle_state_path(root),
    record.stringify(indent=2) + "\n",
    create=0o644,
  ) catch {
    _ => ()
  }
}
