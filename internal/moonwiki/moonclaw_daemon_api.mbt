///|
async fn handle_moonclaw_daemon(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  send_json(conn, method_, moonclaw_daemon_status(workspace_root))
}

///|
async fn handle_moonclaw_models(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let daemon = moonclaw_daemon_status(workspace_root)
  if !json_bool(daemon, "running", default=false) {
    send_json(
      conn,
      method_,
      api_contract_response(
        { "daemon": daemon, "models": Json::array([]) },
        ok=false,
        status="moonclaw_unreachable",
        message=json_string(
          daemon,
          "message",
          default="MoonClaw daemon is not running",
        ),
        next_action=json_string(
          daemon,
          "next_action",
          default="configure_or_start_moonclaw",
        ),
      ),
    )
    return
  }
  match moonclaw_get_json(daemon, "/v1/models") {
    Ok(payload) => {
      let ready = moonclaw_models_response_ready(payload)
      send_json(
        conn,
        method_,
        api_contract_response(
          {
            "daemon": daemon,
            "models": json_array(payload, "models"),
            "default_model": json_string(payload, "default_model", default=""),
          },
          ok=ready,
          status=if ready { "ready" } else { "moonclaw_models_unavailable" },
          message=if ready {
            "MoonClaw models are available"
          } else {
            "MoonClaw has no executable default model"
          },
          next_action=if ready { "use_moonclaw" } else { "configure_model" },
        ),
      )
    }
    Err(message) =>
      send_json(
        conn,
        method_,
        api_contract_response(
          {
            "daemon": moonclaw_daemon_with_message(daemon, message),
            "models": Json::array([]),
          },
          ok=false,
          status="moonclaw_models_unavailable",
          message~,
          next_action="inspect_moonclaw_daemon",
        ),
      )
  }
}

///|
async fn handle_moonclaw_daemon_action(
  workspace_root : String,
  action : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let result = if action == "install" {
    install_moonclaw_release(workspace_root)
  } else {
    ensure_moonclaw_daemon_running(
      workspace_root,
      action=if action == "retry" { "restart" } else { "start" },
    )
  }
  send_json(conn, method_, result)
}

///|
async fn moonclaw_daemon_status(workspace_root : String) -> Json {
  let context = workspace_context(workspace_root)
  let root = context.suite_root
  let info_path = moonclaw_daemon_info_path(root)
  let descriptor = moonclaw_service_descriptor(root, "daemon")
  let service_cwd = json_string(descriptor, "cwd", default=root)
  let service_configured = json_bool(descriptor, "configured", default=false)
  let managed_install = json_bool(descriptor, "managed_install", default=false)
  let installed_version = json_string(descriptor, "version", default="")
  let service_source = if managed_install {
    "managed"
  } else if service_configured {
    "external"
  } else {
    "missing"
  }
  if !@fsx.exists(info_path) {
    let message = if managed_install {
      "MoonClaw " + installed_version + " is installed but not running"
    } else if service_configured {
      "An external MoonClaw service is configured but not running"
    } else {
      "MoonClaw is not installed"
    }
    return api_contract_response(
      {
        "ok": false,
        "running": false,
        "port": 0,
        "pid": 0,
        "info_path": info_path,
        "moonclaw_root": service_cwd,
        "service_configured": service_configured,
        "service_config_path": json_string(
          descriptor,
          "config_path",
          default="",
        ),
        "service_command": json_string(descriptor, "display", default=""),
        "managed_install": managed_install,
        "managed_running": false,
        "installed_version": installed_version,
        "running_version": "",
        "service_source": service_source,
        "service_path": moonsuite_product_artifact_for_workspace_root(
          root, "moonclaw", "",
        ),
      },
      ok=false,
      status="daemon_info_missing",
      message~,
      next_action=if managed_install || service_configured {
        "start_moonclaw"
      } else {
        "install_moonclaw"
      },
    )
  }
  let info = read_json_file_or_object(info_path)
  let port = json_int(info, "port", default=0)
  let pid = json_int(info, "pid", default=0)
  let running_version = json_string(info, "version", default="")
  let alive = pid > 0 && process_is_alive(pid)
  let port_reachable = port > 0 && moonclaw_port_reachable(port)
  let existing_allowed = service_configured ||
    moonclaw_allows_unconfigured_existing_daemon(context)
  let reachable = moonclaw_existing_daemon_reachable(
    alive, port, port_reachable, existing_allowed,
  )
  let managed_running = reachable &&
    managed_install &&
    running_version.has_prefix(installed_version)
  let message = if managed_running {
    "MoonClaw " + installed_version + " is installed and running"
  } else if reachable && managed_install {
    "MoonClaw " +
    installed_version +
    " is installed, but a different MoonClaw service is running"
  } else if reachable {
    "MoonClaw is running from an external service; a MoonDesk-managed installation is not installed"
  } else if managed_install {
    "MoonClaw " + installed_version + " is installed but not running"
  } else if service_configured {
    "An external MoonClaw service is configured but not running"
  } else if alive && port > 0 && !existing_allowed {
    "MoonClaw daemon info exists but this temporary workspace needs an explicit service config"
  } else if alive && port > 0 {
    "MoonClaw daemon info exists but the HTTP port is not reachable"
  } else {
    "MoonClaw is not installed"
  }
  api_contract_response(
    {
      "ok": reachable,
      "running": reachable,
      "port": port,
      "pid": pid,
      "info_path": info_path,
      "moonclaw_root": service_cwd,
      "service_configured": service_configured,
      "service_config_path": json_string(descriptor, "config_path", default=""),
      "service_command": json_string(descriptor, "display", default=""),
      "managed_install": managed_install,
      "managed_running": managed_running,
      "installed_version": installed_version,
      "running_version": running_version,
      "service_source": service_source,
      "service_path": moonsuite_product_artifact_for_workspace_root(
        root, "moonclaw", "",
      ),
    },
    ok=reachable,
    status=if reachable {
      "running"
    } else if alive && port > 0 && !existing_allowed {
      "service_config_required"
    } else if alive && port > 0 {
      "port_unreachable"
    } else {
      "process_unreachable"
    },
    message~,
    next_action=if managed_running {
      "use_moonclaw"
    } else if reachable {
      "install_moonclaw"
    } else if service_configured {
      "restart_moonclaw"
    } else {
      "configure_moonclaw_service"
    },
  )
}

///|
async fn ensure_moonclaw_daemon_running(
  workspace_root : String,
  action? : String = "start",
) -> Json {
  let status = moonclaw_daemon_status(workspace_root)
  if json_bool(status, "running", default=false) {
    return status
  }
  if !json_bool(status, "service_configured", default=false) {
    return status
  }
  let root = workspace_context(workspace_root).suite_root
  let start = start_moonclaw_daemon(root, action~)
  if !json_bool(start, "ok", default=false) {
    return start
  }
  moonclaw_daemon_status(workspace_root)
}

///|
async fn start_moonclaw_daemon(
  root : String,
  action? : String = "start",
) -> Json {
  let descriptor = moonclaw_service_descriptor(root, "daemon")
  if !json_bool(descriptor, "configured", default=false) {
    return moonclaw_daemon_lifecycle_result(
      root,
      action~,
      ok=false,
      status="not-configured",
      message="MoonClaw daemon service is not configured for this workspace",
    )
  }
  let state_dir = moonsuite_product_artifact_for_workspace_root(
    root, "moonclaw", "moondesk-daemon-lifecycle",
  )
  @fsx.make_directory(state_dir, recursive=true, exists_ok=true) catch {
    _ =>
      return moonclaw_daemon_lifecycle_result(
        root,
        action~,
        ok=false,
        status="failed",
        message="Could not create MoonClaw daemon lifecycle directory",
      )
  }
  let id = @desk.stable_id("moonclaw-daemon", @async.now().to_string())
  let stdout_path = @pathx.join(state_dir, id + ".out.log")
  let stderr_path = @pathx.join(state_dir, id + ".err.log")
  let stdout_file = @process.redirect_to_file(
    stdout_path,
    append=true,
    create_mode=OpenOrCreate,
    permission=0o644,
  ) catch {
    _ =>
      return moonclaw_daemon_lifecycle_result(
        root,
        action~,
        ok=false,
        status="failed",
        message="Could not open MoonClaw daemon stdout log",
      )
  }
  let stderr_file = @process.redirect_to_file(
    stderr_path,
    append=true,
    create_mode=OpenOrCreate,
    permission=0o644,
  ) catch {
    _ =>
      return moonclaw_daemon_lifecycle_result(
        root,
        action~,
        ok=false,
        status="failed",
        message="Could not open MoonClaw daemon stderr log",
      )
  }
  let executable = json_string(descriptor, "command", default="")
  let args = json_string_array_items(descriptor, "args")
  let cwd = json_string(descriptor, "cwd", default=root)
  let command = json_string(descriptor, "display", default="")
  let pid = @process.spawn_orphan(
    executable,
    args,
    cwd~,
    stdout=stdout_file,
    stderr=stderr_file,
  ) catch {
    error =>
      return moonclaw_daemon_lifecycle_result(
        root,
        action~,
        ok=false,
        status="failed",
        message="Could not start MoonClaw daemon: \{error}",
        command~,
        stdout_path~,
        stderr_path~,
      )
  }
  let info_path = moonclaw_daemon_info_path(root)
  let mut reachable = false
  let mut exited = false
  let mut checks = 0
  while checks < 120 {
    @async.sleep(500)
    let status = moonclaw_daemon_status(root)
    if json_bool(status, "running", default=false) {
      reachable = true
      break
    }
    if pid > 0 && !process_is_alive(pid) {
      exited = true
      break
    }
    checks += 1
  }
  let failure_detail = if exited {
    moonclaw_startup_failure_detail(stderr_path, stdout_path)
  } else {
    ""
  }
  moonclaw_daemon_lifecycle_result(
    root,
    action~,
    ok=reachable,
    status=if reachable {
      "running"
    } else if exited {
      "exited"
    } else {
      "starting"
    },
    running=reachable,
    message=if reachable {
      "MoonClaw daemon started"
    } else if exited && failure_detail != "" {
      failure_detail
    } else if exited {
      "MoonClaw daemon exited before it became reachable"
    } else {
      "MoonClaw daemon was spawned but is not reachable yet"
    },
    pid~,
    command~,
    info_path~,
    stdout_path~,
    stderr_path~,
  )
}

///|
async fn moonclaw_startup_failure_detail(
  stderr_path : String,
  stdout_path : String,
) -> String {
  let stderr_text = @fs.read_file(stderr_path).text() catch { _ => "" }
  let stderr_text = stderr_text.trim().to_owned()
  if stderr_text != "" {
    return "MoonClaw daemon exited: " + stderr_text
  }
  let stdout_text = @fs.read_file(stdout_path).text() catch { _ => "" }
  let stdout_text = stdout_text.trim().to_owned()
  if stdout_text != "" {
    return "MoonClaw daemon exited: " + stdout_text
  }
  ""
}

///|
fn moonclaw_daemon_lifecycle_result(
  root : String,
  action~ : String,
  ok~ : Bool,
  status~ : String,
  message~ : String,
  running? : Bool = false,
  pid? : Int = 0,
  command? : String = "",
  info_path? : String = "",
  stdout_path? : String = "",
  stderr_path? : String = "",
) -> Json {
  api_contract_response(
    {
      "action": action,
      "running": running,
      "pid": pid,
      "command": command,
      "info_path": if info_path == "" {
        moonclaw_daemon_info_path(root)
      } else {
        info_path
      },
      "stdout_path": stdout_path,
      "stderr_path": stderr_path,
    },
    ok~,
    status~,
    message~,
    next_action=if ok { "use_moonclaw" } else { "inspect_moonclaw_daemon" },
  )
}

///|
fn moonclaw_existing_daemon_reachable(
  alive : Bool,
  port : Int,
  port_reachable : Bool,
  existing_allowed : Bool,
) -> Bool {
  existing_allowed && alive && port > 0 && port_reachable
}

///|
fn moonclaw_allows_unconfigured_existing_daemon(
  context : WorkspaceContext,
) -> Bool {
  let root = context.suite_root
  !(root.has_prefix("/tmp/") ||
  root.has_prefix("/private/tmp/") ||
  root.has_prefix("/var/folders/") ||
  root.has_prefix("/private/var/folders/"))
}

///|
async fn process_is_alive(pid : Int) -> Bool {
  let code = run_process_quiet("kill", ["-0", pid.to_string()])
  if code != 0 {
    return false
  }
  let (status_code, stdout, _) = run_process_capture("ps", [
    "-p",
    pid.to_string(),
    "-o",
    "stat=",
  ])
  status_code == 0 && process_status_is_alive(stdout)
}

///|
fn process_status_is_alive(status : String) -> Bool {
  let status = status.trim().to_owned()
  status != "" && !status.has_prefix("Z")
}

///|
async fn moonclaw_port_reachable(port : Int) -> Bool {
  let (response, body) = @http.get("http://127.0.0.1:\{port}/v1/health") catch {
    _ => return false
  }
  if response.code != 200 {
    return false
  }
  let health = @json.parse(body.text()) catch { _ => return false }
  json_bool(health, "ok", default=false) &&
  json_string(health, "service", default="") == "moonclaw"
}

///|
fn moonclaw_daemon_info_path(workspace_root : String) -> String {
  moonsuite_product_artifact_for_workspace_root(
    workspace_root, "moonclaw", "daemon.json",
  )
}

///|
fn moonclaw_daemon_with_message(daemon : Json, message : String) -> Json {
  @mooncore.session_with_field(
    @mooncore.session_with_field(daemon, "ok", false.to_json()),
    "message",
    message.to_json(),
  )
}

///|
async fn moonclaw_get_json(
  daemon : Json,
  path : String,
) -> Result[Json, String] {
  let port = json_int(daemon, "port", default=0)
  if port <= 0 {
    return Err("MoonClaw daemon port is not available")
  }
  let (response, data) = @http.get("http://127.0.0.1:\{port}\{path}") catch {
    error => return Err("MoonClaw GET \{path} failed: \{error}")
  }
  let text = data.text() catch { _ => "" }
  if response.code < 200 || response.code > 299 {
    return Err("MoonClaw GET \{path} returned \{response.code}: \{text}")
  }
  Ok(@json.parse(text) catch { _ => Json::object({}) })
}

///|
async fn moonclaw_get_text(
  daemon : Json,
  path : String,
) -> Result[String, String] {
  let port = json_int(daemon, "port", default=0)
  if port <= 0 {
    return Err("MoonClaw daemon port is not available")
  }
  let (response, data) = @http.get("http://127.0.0.1:\{port}\{path}") catch {
    error => return Err("MoonClaw GET \{path} failed: \{error}")
  }
  let text = data.text() catch { _ => "" }
  if response.code < 200 || response.code > 299 {
    return Err("MoonClaw GET \{path} returned \{response.code}: \{text}")
  }
  Ok(text)
}

///|
async fn moonclaw_post_json(
  daemon : Json,
  path : String,
  body : Json,
) -> Result[Json, String] {
  let port = json_int(daemon, "port", default=0)
  if port <= 0 {
    return Err("MoonClaw daemon port is not available")
  }
  let (response, data) = @http.post("http://127.0.0.1:\{port}\{path}", body, headers={
    "Content-Type": "application/json",
  }) catch {
    error => return Err("MoonClaw POST \{path} failed: \{error}")
  }
  let text = data.text() catch { _ => "" }
  if response.code < 200 || response.code > 299 {
    return Err("MoonClaw POST \{path} returned \{response.code}: \{text}")
  }
  Ok(@json.parse(text) catch { _ => Json::object({}) })
}

///|
fn json_object_field(json : Json, key : String) -> Json? {
  @mooncore.json_object_field(json, key)
}

///|
fn json_array(json : Json, key : String) -> Json {
  Json::array(json_array_items(json, key))
}

///|
fn json_array_items(json : Json, key : String) -> Array[Json] {
  @mooncore.json_array_items(json, key)
}
