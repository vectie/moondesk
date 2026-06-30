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
    send_json(conn, method_, {
      "ok": false,
      "daemon": daemon,
      "models": Json::array([]),
    })
    return
  }
  match moonclaw_get_json(daemon, "/v1/models") {
    Ok(payload) =>
      send_json(conn, method_, {
        "ok": true,
        "daemon": daemon,
        "models": json_array(payload, "models"),
      })
    Err(message) =>
      send_json(conn, method_, {
        "ok": false,
        "daemon": moonclaw_daemon_with_message(daemon, message),
        "models": Json::array([]),
      })
  }
}

///|
async fn moonclaw_daemon_status(workspace_root : String) -> Json {
  let info_path = moonclaw_daemon_info_path()
  let descriptor = moonclaw_service_descriptor(workspace_root, "daemon")
  let service_cwd = json_string(descriptor, "cwd", default=workspace_root)
  let service_configured = json_bool(descriptor, "configured", default=false)
  if !@fsx.exists(info_path) {
    return {
      "ok": false,
      "running": false,
      "port": 0,
      "pid": 0,
      "info_path": info_path,
      "moonclaw_root": service_cwd,
      "service_configured": service_configured,
      "service_config_path": json_string(descriptor, "config_path", default=""),
      "service_command": json_string(descriptor, "display", default=""),
      "message": "MoonClaw daemon info was not found",
    }
  }
  let info = read_json_file_or_object(info_path)
  let port = json_int(info, "port", default=0)
  let pid = json_int(info, "pid", default=0)
  let alive = pid > 0 && process_is_alive(pid)
  let port_reachable = port > 0 && moonclaw_port_reachable(port)
  let existing_allowed = service_configured ||
    moonclaw_allows_unconfigured_existing_daemon(workspace_root)
  let reachable = moonclaw_existing_daemon_reachable(
    alive, port, port_reachable, existing_allowed,
  )
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
    "message": if reachable {
      if service_configured {
        "MoonClaw daemon is running"
      } else {
        "MoonClaw daemon is running without a workspace-local service config"
      }
    } else if alive && port > 0 && !existing_allowed {
      "MoonClaw daemon info exists but this temporary workspace needs an explicit service config"
    } else if alive && port > 0 {
      "MoonClaw daemon info exists but the HTTP port is not reachable"
    } else {
      "MoonClaw daemon info exists but the process is not reachable"
    },
  }
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
  workspace_root : String,
) -> Bool {
  let root = @pathx.normalize(workspace_root)
  !(root.has_prefix("/tmp/") ||
  root.has_prefix("/private/tmp/") ||
  root.has_prefix("/var/folders/") ||
  root.has_prefix("/private/var/folders/"))
}

///|
async fn ensure_moonclaw_daemon(workspace_root : String) -> Json {
  let status = moonclaw_daemon_status(workspace_root)
  if json_bool(status, "running", default=false) {
    return status
  }
  let descriptor = moonclaw_service_descriptor(workspace_root, "daemon")
  if !json_bool(descriptor, "configured", default=false) {
    return moonclaw_daemon_with_message(
      status, "MoonClaw daemon service is not configured for this workspace",
    )
  }
  let log_dir = moonclaw_log_dir()
  @fsx.make_directory(log_dir, recursive=true, exists_ok=true) catch {
    _ => ()
  }
  let stdout_file = @process.redirect_to_file(
    @pathx.join(log_dir, "moondesk-daemon.out.log"),
    append=true,
    create_mode=OpenOrCreate,
    permission=0o644,
  ) catch {
    error =>
      return moonclaw_daemon_with_message(
        status,
        "Could not open MoonClaw daemon stdout log: \{error}",
      )
  }
  let stderr_file = @process.redirect_to_file(
    @pathx.join(log_dir, "moondesk-daemon.err.log"),
    append=true,
    create_mode=OpenOrCreate,
    permission=0o644,
  ) catch {
    error =>
      return moonclaw_daemon_with_message(
        status,
        "Could not open MoonClaw daemon stderr log: \{error}",
      )
  }
  let pid = @process.spawn_orphan(
    json_string(descriptor, "command", default=""),
    json_string_array_items(descriptor, "args"),
    cwd=json_string(descriptor, "cwd", default=workspace_root),
    stdout=stdout_file,
    stderr=stderr_file,
  ) catch {
    error =>
      return moonclaw_daemon_with_message(
        status,
        "Could not start MoonClaw daemon: \{error}",
      )
  }
  wait_for_moonclaw_daemon(workspace_root, pid)
}

///|
async fn process_is_alive(pid : Int) -> Bool {
  let code = run_process_quiet("kill", ["-0", pid.to_string()])
  code == 0
}

///|
async fn moonclaw_port_reachable(port : Int) -> Bool {
  let (response, _) = @http.get("http://localhost:\{port}/v1/models") catch {
    _ => return false
  }
  response.code >= 200 && response.code <= 499
}

///|
async fn wait_for_moonclaw_daemon(workspace_root : String, pid : Int) -> Json {
  ignore(pid)
  for _ in 0..<60 {
    let status = moonclaw_daemon_status(workspace_root)
    if json_bool(status, "running", default=false) {
      return status
    }
    @async.sleep(500)
  }
  moonclaw_daemon_with_message(
    moonclaw_daemon_status(workspace_root),
    "Timed out waiting for MoonClaw daemon to start",
  )
}

///|
fn moonclaw_daemon_info_path() -> String {
  @pathx.join(@sys.get_env_var("HOME").unwrap_or("."), ".moonclaw/daemon.json")
}

///|
fn moonclaw_log_dir() -> String {
  @pathx.join(@sys.get_env_var("HOME").unwrap_or("."), ".moonclaw")
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
  let (response, data) = @http.get("http://localhost:\{port}\{path}") catch {
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
  let (response, data) = @http.get("http://localhost:\{port}\{path}") catch {
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
  let (response, data) = @http.post("http://localhost:\{port}\{path}", body, headers={
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
