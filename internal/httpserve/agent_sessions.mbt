///|
async fn handle_agent_daemon(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  send_json(conn, method_, moonclaw_daemon_status(workspace_root))
}

///|
async fn handle_agent_models(
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
        "daemon": agent_daemon_with_message(daemon, message),
        "models": Json::array([]),
      })
  }
}

///|
async fn handle_agent_tasks(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let daemon = moonclaw_daemon_status(workspace_root)
  if !json_bool(daemon, "running", default=false) {
    send_json(conn, method_, Json::array([]))
    return
  }
  match moonclaw_tasks(daemon) {
    Ok(tasks) => send_json(conn, method_, Json::array(tasks))
    Err(_) => send_json(conn, method_, Json::array([]))
  }
}

///|
async fn handle_agent_sessions(
  workspace_root : String,
  request_path : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  if is_read_method(method_) {
    handle_agent_session_list(workspace_root, request_path, method_, conn)
  } else if method_ is @http.RequestMethod::Post {
    handle_create_agent_session(workspace_root, body, method_, conn)
  } else {
    send_api_error(
      conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
    )
  }
}

///|
async fn handle_agent_session_action(
  workspace_root : String,
  session_id : String,
  action : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  if !(method_ is @http.RequestMethod::Post) {
    send_api_error(
      conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
    )
    return
  }
  match action {
    "message" =>
      handle_agent_session_message(
        workspace_root, session_id, body, method_, conn,
      )
    "cancel" =>
      handle_agent_session_cancel(workspace_root, session_id, method_, conn)
    _ => send_api_error(conn, method_, 404, "Not Found", "Unknown agent action")
  }
}

///|
async fn handle_agent_session_list(
  workspace_root : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace_filter = query_value(request_path, "workspace").unwrap_or("")
  let daemon = moonclaw_daemon_status(workspace_root)
  let tasks = if json_bool(daemon, "running", default=false) {
    moonclaw_tasks(daemon).unwrap_or([])
  } else {
    []
  }
  let sessions : Array[Json] = []
  for record in read_agent_session_records(workspace_root) {
    if workspace_filter != "" &&
      json_string(record, "workspace_id", default="") != workspace_filter {
      continue
    }
    sessions.push(enrich_agent_session_for_response(record, tasks))
  }
  sessions.sort_by(fn(left, right) {
    json_string(right, "updated_at", default="").compare(
      json_string(left, "updated_at", default=""),
    )
  })
  send_json(conn, method_, Json::array(sessions))
}

///|
async fn handle_create_agent_session(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = match read_json_body(body) {
    Some(json) => json
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  let workspace_id = json_string(payload, "workspace_id", default="")
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(workspace) => workspace
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
      return
    }
  }
  let daemon = ensure_moonclaw_daemon(workspace_root)
  if !json_bool(daemon, "running", default=false) {
    send_api_error(
      conn,
      method_,
      503,
      "Service Unavailable",
      json_string(daemon, "message", default="MoonClaw daemon is not running"),
    )
    return
  }
  let task = match ensure_moonclaw_task(daemon, workspace, payload) {
    Ok(task) => task
    Err(message) => {
      send_api_error(conn, method_, 502, "Bad Gateway", message)
      return
    }
  }
  let now = @async.now().to_string()
  let message = json_string(payload, "message", default="")
  let moonclaw_message = agent_workspace_message(payload, workspace, message)
  let title = trimmed_text(
    json_string(payload, "title", default="Agent session for \{workspace.name}"),
    fallback="Agent session for \{workspace.name}",
  )
  let session = agent_session_record(
    id=@desk.stable_id("agent", workspace.id + ":" + title + ":" + now),
    workspace~,
    task~,
    title~,
    created_at=now,
    updated_at=now,
    last_message=message,
    transcript=if message == "" {
      []
    } else {
      [
        agent_message_record(
          role="user",
          content=message,
          status="sending",
          created_at=now,
        ),
      ]
    },
  )
  let session = if message == "" {
    session
  } else {
    match
      send_moonclaw_message(
        daemon,
        json_string(task, "id", default=""),
        moonclaw_message,
        web_search=json_bool(payload, "web_search", default=false),
      ) {
      Ok(response) =>
        append_agent_message(
          update_agent_session_status(session, task),
          role="status",
          content=agent_send_status(response),
          status=if json_bool(response, "queued", default=false) {
            "queued"
          } else {
            "running"
          },
        )
      Err(error) =>
        append_agent_message(
          update_agent_session_status(session, task),
          role="status",
          content=error,
          status="failed",
        )
    }
  }
  write_agent_session_record(workspace_root, session) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not save agent session",
      )
      return
    }
  }
  send_json(conn, method_, enrich_agent_session_for_response(session, [task]))
}

///|
async fn handle_agent_session_message(
  workspace_root : String,
  session_id : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = match read_json_body(body) {
    Some(json) => json
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  let session = match read_agent_session_record(workspace_root, session_id) {
    Some(session) => session
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Unknown agent session")
      return
    }
  }
  let message = trimmed_text(
    json_string(payload, "message", default=""),
    fallback="",
  )
  if message == "" {
    send_api_error(conn, method_, 400, "Bad Request", "Message is required")
    return
  }
  let daemon = ensure_moonclaw_daemon(workspace_root)
  if !json_bool(daemon, "running", default=false) {
    send_api_error(
      conn,
      method_,
      503,
      "Service Unavailable",
      json_string(daemon, "message", default="MoonClaw daemon is not running"),
    )
    return
  }
  let task = match ensure_session_task(daemon, session) {
    Ok(task) => task
    Err(error) => {
      send_api_error(conn, method_, 502, "Bad Gateway", error)
      return
    }
  }
  let task_id = json_string(task, "id", default="")
  let sent_at = @async.now().to_string()
  let moonclaw_message = agent_session_message(payload, session, message)
  let with_user = append_agent_message(
    update_agent_session_status(session, task),
    role="user",
    content=message,
    status="sending",
    created_at=sent_at,
  )
  let next = match
    send_moonclaw_message(
      daemon,
      task_id,
      moonclaw_message,
      web_search=json_bool(payload, "web_search", default=false),
    ) {
    Ok(response) =>
      append_agent_message(
        with_user,
        role="status",
        content=agent_send_status(response),
        status=if json_bool(response, "queued", default=false) {
          "queued"
        } else {
          "running"
        },
      )
    Err(error) =>
      append_agent_message(
        with_user,
        role="status",
        content=error,
        status="failed",
      )
  }
  let next = agent_session_with_field(
    agent_session_with_field(next, "last_message", message.to_json()),
    "updated_at",
    @async.now().to_string().to_json(),
  )
  write_agent_session_record(workspace_root, next) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not save agent session",
      )
      return
    }
  }
  send_json(conn, method_, enrich_agent_session_for_response(next, [task]))
}

///|
async fn handle_agent_session_cancel(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let session = match read_agent_session_record(workspace_root, session_id) {
    Some(session) => session
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Unknown agent session")
      return
    }
  }
  let daemon = moonclaw_daemon_status(workspace_root)
  if !json_bool(daemon, "running", default=false) {
    send_api_error(
      conn, method_, 503, "Service Unavailable", "MoonClaw daemon is not running",
    )
    return
  }
  let task_id = json_string(session, "moonclaw_task_id", default="")
  if task_id == "" {
    send_api_error(
      conn, method_, 400, "Bad Request", "Session has no MoonClaw task",
    )
    return
  }
  let (status, content) = match
    moonclaw_post_json(daemon, "/v1/task/\{task_id}/cancel", Json::object({})) {
    Ok(payload) => ("cancelled", "cancelled: \{payload.stringify()}")
    Err(error) => ("failed", error)
  }
  let next = append_agent_message(session, role="status", content~, status~)
  write_agent_session_record(workspace_root, next) catch {
    _ => ()
  }
  send_json(conn, method_, enrich_agent_session_for_response(next, []))
}

///|
async fn moonclaw_daemon_status(workspace_root : String) -> Json {
  let info_path = moonclaw_daemon_info_path()
  let configured_root = moonclaw_configured_root(workspace_root)
  if !@fsx.exists(info_path) {
    return {
      "ok": false,
      "running": false,
      "port": 0,
      "pid": 0,
      "info_path": info_path,
      "moonclaw_root": configured_root,
      "message": "MoonClaw daemon info was not found",
    }
  }
  let info = read_json_file_or_object(info_path)
  let port = json_int(info, "port", default=0)
  let pid = json_int(info, "pid", default=0)
  let alive = pid > 0 && process_is_alive(pid)
  let reachable = alive && port > 0 && moonclaw_port_reachable(port)
  {
    "ok": reachable,
    "running": reachable,
    "port": port,
    "pid": pid,
    "info_path": info_path,
    "moonclaw_root": configured_root,
    "message": if reachable {
      "MoonClaw daemon is running"
    } else if alive && port > 0 {
      "MoonClaw daemon info exists but the HTTP port is not reachable"
    } else {
      "MoonClaw daemon info exists but the process is not reachable"
    },
  }
}

///|
async fn ensure_moonclaw_daemon(workspace_root : String) -> Json {
  let status = moonclaw_daemon_status(workspace_root)
  if json_bool(status, "running", default=false) {
    return status
  }
  let root = moonclaw_configured_root(workspace_root)
  if root == "" || !is_runnable_moonclaw(root) {
    return agent_daemon_with_message(
      status, "MoonClaw daemon is not running and no runnable MoonClaw checkout was found",
    )
  }
  let executable = match ensure_moonclaw_executable(root) {
    Ok(executable) => executable
    Err(message) => return agent_daemon_with_message(status, message)
  }
  let log_dir = moonclaw_log_dir()
  @fsx.make_directory(log_dir, recursive=true, exists_ok=true) catch {
    _ => ()
  }
  let stdout_file = @process.redirect_to_file(
    @pathx.join(log_dir, "moondesk-daemon.out.log"),
    append=true,
    create=0o644,
  ) catch {
    error =>
      return agent_daemon_with_message(
        status,
        "Could not open MoonClaw daemon stdout log: \{error}",
      )
  }
  let stderr_file = @process.redirect_to_file(
    @pathx.join(log_dir, "moondesk-daemon.err.log"),
    append=true,
    create=0o644,
  ) catch {
    error =>
      return agent_daemon_with_message(
        status,
        "Could not open MoonClaw daemon stderr log: \{error}",
      )
  }
  let pid = @process.spawn_orphan(
    executable,
    ["daemon", "--port", "0", "--serve", @pathx.join(root, "cmd/daemon")],
    cwd=root,
    stdout=stdout_file,
    stderr=stderr_file,
  ) catch {
    error =>
      return agent_daemon_with_message(
        status,
        "Could not start MoonClaw daemon: \{error}",
      )
  }
  wait_for_moonclaw_daemon(workspace_root, pid)
}

///|
async fn process_is_alive(pid : Int) -> Bool {
  let code = @process.run("kill", ["-0", pid.to_string()]) catch { _ => -1 }
  code == 0
}

///|
async fn moonclaw_port_reachable(port : Int) -> Bool {
  let (response, _) = @http.get("http://localhost:\{port}/v1/tasks") catch {
    _ => return false
  }
  response.code >= 200 && response.code <= 499
}

///|
async fn wait_for_moonclaw_daemon(workspace_root : String, pid : Int) -> Json {
  for _ in 0..<60 {
    let status = moonclaw_daemon_status(workspace_root)
    if json_bool(status, "running", default=false) {
      return status
    }
    if pid > 0 && !process_is_alive(pid) {
      return agent_daemon_with_message(
        status, "MoonClaw daemon process exited before writing a live daemon record",
      )
    }
    @async.sleep(500)
  }
  agent_daemon_with_message(
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
async fn moonclaw_configured_root(workspace_root : String) -> String {
  match @sys.get_env_var("MOONCLAW_ROOT") {
    Some(root) if root != "" => @pathx.normalize(root)
    _ => {
      let parent = @pathx.dirname(@pathx.normalize(workspace_root)).to_owned()
      let sibling = @pathx.join(parent, "moonclaw")
      if is_runnable_moonclaw(sibling) {
        sibling
      } else {
        let home_candidate = @pathx.join(
          @sys.get_env_var("HOME").unwrap_or("."),
          "Workspace/moonclaw",
        )
        if is_runnable_moonclaw(home_candidate) {
          home_candidate
        } else {
          ""
        }
      }
    }
  }
}

///|
async fn ensure_moonclaw_executable(root : String) -> Result[String, String] {
  match @sys.get_env_var("MOONCLAW_BIN") {
    Some(path) if path != "" && @fsx.exists(path) =>
      return Ok(@pathx.normalize(path))
    Some(path) if path != "" =>
      return Err("MOONCLAW_BIN does not exist: \{path}")
    _ => ()
  }
  match moonclaw_executable_candidate(root) {
    Some(path) => return Ok(path)
    None => ()
  }
  let output = @process.collect_output(
    "moon",
    ["build", "cmd/main", "--target", "native"],
    cwd=root,
  ) catch {
    error => return Err("Could not build MoonClaw native executable: \{error}")
  }
  if output.0 != 0 {
    return Err(
      "MoonClaw native build failed \{output.0}: \{trim_for_record(output.2.text())}",
    )
  }
  match moonclaw_executable_candidate(root) {
    Some(path) => Ok(path)
    None =>
      Err(
        "MoonClaw native build completed but no cmd/main executable was found",
      )
  }
}

///|
async fn moonclaw_executable_candidate(root : String) -> String? {
  let candidates = [
    "_build/native/debug/build/cmd/main/main.exe", "_build/native/release/build/cmd/main/main.exe",
    "_build/native/debug/build/cmd/main/main", "_build/native/release/build/cmd/main/main",
  ]
  for candidate in candidates {
    let path = @pathx.join(root, candidate)
    if @fsx.exists(path) {
      return Some(path)
    }
  }
  None
}

///|
async fn is_runnable_moonclaw(root : String) -> Bool {
  root != "" &&
  @fsx.exists(@pathx.join(root, "moon.mod.json")) &&
  @fsx.exists(@pathx.join(root, "cmd/main/moon.pkg"))
}

///|
fn agent_daemon_with_message(daemon : Json, message : String) -> Json {
  agent_session_with_field(
    agent_session_with_field(daemon, "ok", false.to_json()),
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
async fn moonclaw_tasks(daemon : Json) -> Result[Array[Json], String] {
  match moonclaw_get_json(daemon, "/v1/tasks") {
    Ok(payload) => Ok(json_array_items(payload, "tasks"))
    Err(error) => Err(error)
  }
}

///|
async fn ensure_moonclaw_task(
  daemon : Json,
  workspace : @desk.DeskWorkspace,
  payload : Json,
) -> Result[Json, String] {
  let existing = match moonclaw_tasks(daemon) {
    Ok(tasks) => find_task_by_cwd(tasks, workspace.root_path)
    Err(_) => None
  }
  if existing is Some(task) {
    return Ok(task)
  }
  let mut body : Json = {
    "name": json_string(
      payload,
      "title",
      default="Moondesk agent - \{workspace.name}",
    ),
    "cwd": workspace.root_path,
    "web_search": json_bool(payload, "web_search", default=false),
  }
  match json_string_opt(payload, "model") {
    Some(model) if model != "" =>
      body = agent_session_with_field(body, "model", model.to_json())
    _ => ()
  }
  match moonclaw_post_json(daemon, "/v1/task", body) {
    Ok(response) =>
      match json_object_field(response, "task") {
        Some(task) => Ok(task)
        None => Err("MoonClaw task creation returned no task")
      }
    Err(error) => {
      let tasks = moonclaw_tasks(daemon).unwrap_or([])
      match find_task_by_cwd(tasks, workspace.root_path) {
        Some(task) => Ok(task)
        None => Err(error)
      }
    }
  }
}

///|
async fn ensure_session_task(
  daemon : Json,
  session : Json,
) -> Result[Json, String] {
  let task_id = json_string(session, "moonclaw_task_id", default="")
  let cwd = json_string(
    session,
    "cwd",
    default=json_string(session, "workspace_root", default=""),
  )
  let tasks = moonclaw_tasks(daemon).unwrap_or([])
  if task_id != "" {
    match find_task_by_id(tasks, task_id) {
      Some(task) => return Ok(task)
      None => ()
    }
  }
  match find_task_by_cwd(tasks, cwd) {
    Some(task) => Ok(task)
    None => {
      let workspace : @desk.DeskWorkspace = @desk.workspace(
        id=json_string(session, "workspace_id", default=""),
        name=json_string(session, "workspace_name", default="Workspace"),
        root_path=cwd,
        kind=@desk.WorkspaceKind::MoonBook,
      )
      ensure_moonclaw_task(daemon, workspace, {
        "title": json_string(session, "title", default="Moondesk agent"),
        "web_search": json_bool(session, "web_search", default=false),
        "model": json_string(session, "model", default=""),
      })
    }
  }
}

///|
async fn send_moonclaw_message(
  daemon : Json,
  task_id : String,
  message : String,
  web_search~ : Bool,
) -> Result[Json, String] {
  if task_id == "" {
    return Err("MoonClaw task id is missing")
  }
  moonclaw_post_json(daemon, "/v1/task/\{task_id}/message", {
    "message": { "role": "user", "content": message },
    "web_search": web_search,
  })
}

///|
fn agent_workspace_message(
  payload : Json,
  workspace : @desk.DeskWorkspace,
  message : String,
) -> String {
  agent_context_message(
    book_name=workspace.name,
    root=workspace.root_path,
    context_path=json_string(payload, "context_path", default=""),
    message~,
  )
}

///|
fn agent_session_message(
  payload : Json,
  session : Json,
  message : String,
) -> String {
  agent_context_message(
    book_name=json_string(session, "workspace_name", default="Workspace"),
    root=json_string(
      session,
      "workspace_root",
      default=json_string(session, "cwd", default=""),
    ),
    context_path=json_string(payload, "context_path", default=""),
    message~,
  )
}

///|
fn agent_context_message(
  book_name~ : String,
  root~ : String,
  context_path~ : String,
  message~ : String,
) -> String {
  "Moondesk context:\n" +
  "- book: \{agent_context_value(book_name)}\n" +
  "- root: \{agent_context_value(root)}\n" +
  "- selected path: \{agent_context_value(context_path)}\n\n" +
  "User request:\n" +
  message
}

///|
fn agent_context_value(value : String) -> String {
  let value = value.trim().to_owned()
  if value == "" {
    "not provided"
  } else {
    value
  }
}

///|
fn agent_send_status(response : Json) -> String {
  let id = json_string(response, "id", default="")
  let queued = json_bool(response, "queued", default=false)
  if id == "" {
    "MoonClaw accepted the message"
  } else if queued {
    "MoonClaw queued message \{id}"
  } else {
    "MoonClaw started message \{id}"
  }
}

///|
fn agent_session_record(
  id~ : String,
  workspace~ : @desk.DeskWorkspace,
  task~ : Json,
  title~ : String,
  created_at~ : String,
  updated_at~ : String,
  last_message~ : String,
  transcript~ : Array[Json],
) -> Json {
  {
    "id": id,
    "workspace_id": workspace.id,
    "workspace_name": workspace.name,
    "workspace_root": workspace.root_path,
    "cwd": workspace.root_path,
    "moonclaw_task_id": json_string(task, "id", default=""),
    "title": title,
    "model": json_string(task, "model", default=""),
    "status": json_string(task, "status", default="created"),
    "port": json_int(task, "port", default=0),
    "web_search": json_bool(task, "web_search", default=false),
    "queued_count": json_array_items(task, "queued_messages").length(),
    "created_at": created_at,
    "updated_at": updated_at,
    "last_message": last_message,
    "transcript": Json::array(transcript),
  }
}

///|
fn update_agent_session_status(session : Json, task : Json) -> Json {
  let next = agent_session_with_field(
    session,
    "moonclaw_task_id",
    json_string(
      task,
      "id",
      default=json_string(session, "moonclaw_task_id", default=""),
    ).to_json(),
  )
  let next = agent_session_with_field(
    next,
    "status",
    json_string(
      task,
      "status",
      default=json_string(session, "status", default="saved"),
    ).to_json(),
  )
  let next = agent_session_with_field(
    next,
    "model",
    json_string(
      task,
      "model",
      default=json_string(session, "model", default=""),
    ).to_json(),
  )
  let next = agent_session_with_field(
    next,
    "port",
    json_int(task, "port", default=json_int(session, "port", default=0)).to_json(),
  )
  let next = agent_session_with_field(
    next,
    "web_search",
    json_bool(
      task,
      "web_search",
      default=json_bool(session, "web_search", default=false),
    ).to_json(),
  )
  agent_session_with_field(
    next,
    "queued_count",
    json_array_items(task, "queued_messages").length().to_json(),
  )
}

///|
fn enrich_agent_session(session : Json, tasks : Array[Json]) -> Json {
  let task_id = json_string(session, "moonclaw_task_id", default="")
  let cwd = json_string(
    session,
    "cwd",
    default=json_string(session, "workspace_root", default=""),
  )
  match find_task_by_id(tasks, task_id) {
    Some(task) => update_agent_session_status(session, task)
    None =>
      match find_task_by_cwd(tasks, cwd) {
        Some(task) => update_agent_session_status(session, task)
        None =>
          agent_session_with_field(
            session,
            "status",
            (if task_id == "" { "draft" } else { "saved" }).to_json(),
          )
      }
  }
}

///|
async fn enrich_agent_session_for_response(
  session : Json,
  tasks : Array[Json],
) -> Json {
  let session = enrich_agent_session(session, tasks)
  sync_agent_conversation_transcript(session)
}

///|
async fn sync_agent_conversation_transcript(session : Json) -> Json {
  let task_id = json_string(session, "moonclaw_task_id", default="")
  if task_id == "" {
    return session
  }
  let events = read_moonclaw_conversation_events(session, task_id)
  let events = if events.length() == 0 {
    read_moonclaw_log_events(session)
  } else {
    events
  }
  if events.length() == 0 {
    return session
  }
  let transcript = merge_agent_transcript(
    json_array_items(session, "transcript"),
    events,
  )
  agent_session_with_field(session, "transcript", Json::array(transcript))
}

///|
async fn read_moonclaw_conversation_events(
  session : Json,
  task_id : String,
) -> Array[Json] {
  for path in moonclaw_conversation_paths(session, task_id) {
    if @fsx.exists(path) {
      let events = json_array_items(read_json_file_or_object(path), "events")
      if events.length() > 0 {
        return events
      }
    }
  }
  []
}

///|
fn moonclaw_conversation_paths(
  session : Json,
  task_id : String,
) -> Array[String] {
  let paths : Array[String] = []
  let cwd = json_string(
    session,
    "cwd",
    default=json_string(session, "workspace_root", default=""),
  )
  if cwd != "" {
    push_unique_path(
      paths,
      @pathx.join(cwd, ".moonclaw/conversations/\{task_id}.json"),
    )
  }
  let home = @sys.get_env_var("HOME").unwrap_or(".")
  push_unique_path(
    paths,
    @pathx.join(home, ".moonclaw/conversations/\{task_id}.json"),
  )
  push_unique_path(
    paths,
    @pathx.join(home, ".moonclaw/.moonclaw/conversations/\{task_id}.json"),
  )
  paths
}

///|
fn push_unique_path(paths : Array[String], path : String) -> Unit {
  for existing in paths {
    if existing == path {
      return
    }
  }
  paths.push(path)
}

///|
async fn read_moonclaw_log_events(session : Json) -> Array[Json] {
  let cwd = json_string(
    session,
    "cwd",
    default=json_string(session, "workspace_root", default=""),
  )
  if cwd == "" {
    return []
  }
  if !agent_session_has_user_message(session) {
    return []
  }
  let path = @pathx.join(cwd, ".moonclaw/log.jsonl")
  if !@fsx.exists(path) {
    return []
  }
  let cutoff = log_event_cutoff(json_int(session, "created_at", default=0))
  let upper = log_event_upper_bound(session)
  let events : Array[Json] = []
  let text = @fs.read_file(path).text() catch { _ => return events }
  for line in text.split("\n") {
    let line = line.trim().to_owned()
    if line == "" {
      continue
    }
    let record = Some(@json.parse(line)) catch { _ => None }
    match record {
      Some(record) =>
        match moonclaw_event_from_log_record(record, cutoff~, upper~) {
          Some(event) => {
            events.push(event)
            if moonclaw_event_is_terminal(event) {
              break
            }
          }
          None => ()
        }
      None => ()
    }
  }
  events
}

///|
fn agent_session_has_user_message(session : Json) -> Bool {
  if json_string(session, "last_message", default="") != "" {
    return true
  }
  for message in json_array_items(session, "transcript") {
    if json_string(message, "role", default="") == "user" {
      return true
    }
  }
  false
}

///|
fn log_event_cutoff(created_at : Int) -> Int {
  if created_at > 1000 {
    created_at - 1000
  } else {
    created_at
  }
}

///|
fn log_event_upper_bound(session : Json) -> Int {
  let status = json_string(session, "status", default="")
  match status {
    "saved" | "draft" | "cancelled" | "failed" => {
      let created_at = json_int(session, "created_at", default=0)
      let updated_at = json_int(session, "updated_at", default=created_at)
      let base = if updated_at > created_at { updated_at } else { created_at }
      if base > 0 {
        base + 300_000
      } else {
        0
      }
    }
    _ => 0
  }
}

///|
fn moonclaw_event_from_log_record(
  record : Json,
  cutoff~ : Int,
  upper? : Int = 0,
) -> Json? {
  let event = match json_object_field(record, "event") {
    Some(event) => event
    None => return None
  }
  let record_time = json_int(record, "time", default=0)
  let event_time = json_int(event, "created", default=record_time)
  if cutoff > 0 && event_time < cutoff && record_time < cutoff {
    None
  } else if upper > 0 && event_time > upper && record_time > upper {
    None
  } else {
    Some(event)
  }
}

///|
fn moonclaw_event_is_terminal(event : Json) -> Bool {
  let desc = match json_object_field(event, "desc") {
    Some(desc) => desc
    None => return false
  }
  match json_string(desc, "msg", default="") {
    "PostConversation" | "Failed" | "Cancelled" => true
    _ => false
  }
}

///|
fn merge_agent_transcript(
  transcript : Array[Json],
  events : Array[Json],
) -> Array[Json] {
  let merged : Array[Json] = []
  for message in transcript {
    merged.push(message)
  }
  for event in events {
    match agent_message_from_moonclaw_event(event) {
      Some(message) if !agent_transcript_has_id(
          merged,
          json_string(message, "id", default=""),
        ) => merged.push(message)
      _ => ()
    }
  }
  merged
}

///|
fn agent_transcript_has_id(messages : Array[Json], id : String) -> Bool {
  if id == "" {
    return false
  }
  for message in messages {
    if json_string(message, "id", default="") == id {
      return true
    }
  }
  false
}

///|
fn agent_message_from_moonclaw_event(event : Json) -> Json? {
  let desc = match json_object_field(event, "desc") {
    Some(desc) => desc
    None => return None
  }
  let msg = json_string(desc, "msg", default="")
  let event_id = json_field_text(
    event,
    "id",
    default=@desk.stable_id("moonclaw-event", desc.stringify()),
  )
  let created_at = json_field_text(event, "created", default=event_id)
  match msg {
    "ModelLoaded" => {
      let name = json_string(desc, "name", default="default model")
      Some(
        agent_message_record_with_id(
          id="moonclaw-\{event_id}",
          role="status",
          content="MoonClaw loaded \{name}",
          status="done",
          created_at~,
        ),
      )
    }
    "PreConversation" =>
      Some(
        agent_message_record_with_id(
          id="moonclaw-\{event_id}",
          role="status",
          content="MoonClaw started the conversation",
          status="running",
          created_at~,
        ),
      )
    "MessageQueued" =>
      Some(
        agent_message_record_with_id(
          id="moonclaw-\{event_id}",
          role="status",
          content="MoonClaw queued a message",
          status="queued",
          created_at~,
        ),
      )
    "MessageUnqueued" =>
      Some(
        agent_message_record_with_id(
          id="moonclaw-\{event_id}",
          role="status",
          content="MoonClaw is processing the message",
          status="running",
          created_at~,
        ),
      )
    "TokenCounted" =>
      Some(
        agent_message_record_with_id(
          id="moonclaw-\{event_id}",
          role="status",
          content="MoonClaw measured context: \{json_int(desc, "token_count", default=0)} tokens",
          status="running",
          created_at~,
        ),
      )
    "ContextPruned" =>
      Some(
        agent_message_record_with_id(
          id="moonclaw-\{event_id}",
          role="status",
          content=moonclaw_context_pruned_text(desc),
          status="running",
          created_at~,
        ),
      )
    "PreToolCall" => {
      let name = json_string(desc, "name", default="tool")
      Some(
        agent_message_record_with_id(
          id="moonclaw-\{event_id}",
          role="tool",
          content="Tool started: \{name}",
          status="running",
          created_at~,
        ),
      )
    }
    "AssistantMessage" => {
      let content = json_string(desc, "content", default="")
      if content == "" {
        None
      } else {
        Some(
          agent_message_record_with_id(
            id="moonclaw-\{event_id}",
            role="assistant",
            content~,
            status="done",
            created_at~,
          ),
        )
      }
    }
    "RequestCompleted" => {
      let content = match json_object_field(desc, "message") {
        Some(message) => openai_message_content_text(message)
        None => ""
      }
      if content == "" {
        None
      } else {
        Some(
          agent_message_record_with_id(
            id="moonclaw-\{event_id}",
            role="assistant",
            content~,
            status="done",
            created_at~,
          ),
        )
      }
    }
    "PostToolCall" => {
      let name = json_string(desc, "name", default="tool")
      let text = json_string(desc, "text", default="")
      let content = if text == "" {
        "Tool finished: \{name}"
      } else {
        "Tool \{name}\n\{text}"
      }
      Some(
        agent_message_record_with_id(
          id="moonclaw-\{event_id}",
          role="tool",
          content~,
          status=if json_object_field(desc, "error") is Some(_) {
            "failed"
          } else {
            "done"
          },
          created_at~,
        ),
      )
    }
    "PostConversation" =>
      Some(
        agent_message_record_with_id(
          id="moonclaw-\{event_id}",
          role="status",
          content="MoonClaw finished the conversation",
          status="done",
          created_at~,
        ),
      )
    "Failed" =>
      Some(
        agent_message_record_with_id(
          id="moonclaw-\{event_id}",
          role="status",
          content=json_field_text(desc, "error", default="MoonClaw failed"),
          status="failed",
          created_at~,
        ),
      )
    "Cancelled" =>
      Some(
        agent_message_record_with_id(
          id="moonclaw-\{event_id}",
          role="status",
          content="MoonClaw cancelled the current task",
          status="cancelled",
          created_at~,
        ),
      )
    _ => None
  }
}

///|
fn moonclaw_context_pruned_text(desc : Json) -> String {
  let origin = json_int(desc, "origin_token_count", default=0)
  let pruned = json_int(desc, "pruned_token_count", default=origin)
  if origin == pruned {
    "MoonClaw prepared context: \{origin} tokens"
  } else {
    "MoonClaw pruned context: \{origin} -> \{pruned} tokens"
  }
}

///|
fn openai_message_content_text(message : Json) -> String {
  match json_object_field(message, "content") {
    Some(Json::String(content)) => content
    Some(Json::Array(parts)) => {
      let chunks : Array[String] = []
      for part in parts {
        match part {
          Json::String(text) => chunks.push(text)
          Json::Object(fields) =>
            match fields.get("text") {
              Some(Json::String(text)) => chunks.push(text)
              _ => ()
            }
          _ => ()
        }
      }
      chunks.join("\n")
    }
    Some(value) => value.stringify()
    None => ""
  }
}

///|
fn json_field_text(json : Json, key : String, default~ : String) -> String {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::String(value)) => value
        Some(Json::Null) | None => default
        Some(value) => value.stringify()
      }
    _ => default
  }
}

///|
fn agent_message_record(
  role~ : String,
  content~ : String,
  status~ : String,
  created_at~ : String,
) -> Json {
  agent_message_record_with_id(
    id=@desk.stable_id("msg", role + ":" + content + ":" + created_at),
    role~,
    content~,
    status~,
    created_at~,
  )
}

///|
fn agent_message_record_with_id(
  id~ : String,
  role~ : String,
  content~ : String,
  status~ : String,
  created_at~ : String,
) -> Json {
  {
    "id": id,
    "role": role,
    "content": trim_for_record(content),
    "status": status,
    "created_at": created_at,
  }
}

///|
fn append_agent_message(
  session : Json,
  role~ : String,
  content~ : String,
  status~ : String,
  created_at? : String = @async.now().to_string(),
) -> Json {
  let messages = json_array_items(session, "transcript")
  messages.push(agent_message_record(role~, content~, status~, created_at~))
  let next = agent_session_with_field(
    session,
    "transcript",
    Json::array(messages),
  )
  agent_session_with_field(next, "updated_at", created_at.to_json())
}

///|
fn agent_session_with_field(session : Json, key : String, value : Json) -> Json {
  let object : Map[String, Json] = {}
  match session {
    Json::Object(fields) =>
      for existing_key, existing_value in fields {
        object[existing_key] = existing_value
      }
    _ => ()
  }
  object[key] = value
  Json::object(object)
}

///|
fn json_object_field(json : Json, key : String) -> Json? {
  match json {
    Json::Object(object) => object.get(key)
    _ => None
  }
}

///|
fn json_array(json : Json, key : String) -> Json {
  Json::array(json_array_items(json, key))
}

///|
fn json_array_items(json : Json, key : String) -> Array[Json] {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::Array(items)) => items
        _ => []
      }
    _ => []
  }
}

///|
fn find_task_by_id(tasks : Array[Json], task_id : String) -> Json? {
  if task_id == "" {
    return None
  }
  for task in tasks {
    if json_string(task, "id", default="") == task_id {
      return Some(task)
    }
  }
  None
}

///|
fn find_task_by_cwd(tasks : Array[Json], cwd : String) -> Json? {
  if cwd == "" {
    return None
  }
  let normalized = @pathx.normalize(cwd)
  for task in tasks {
    if @pathx.normalize(json_string(task, "cwd", default="")) == normalized {
      return Some(task)
    }
  }
  None
}

///|
fn agent_sessions_dir(workspace_root : String) -> String {
  @pathx.join(
    @pathx.normalize(workspace_root),
    ".moontown/moondesk-agent-sessions",
  )
}

///|
async fn read_agent_session_records(workspace_root : String) -> Array[Json] {
  let records : Array[Json] = []
  let root = agent_sessions_dir(workspace_root)
  for name in read_directory_names(root, include_hidden=false) {
    if !name.has_suffix(".json") {
      continue
    }
    let record = read_json_file_or_object(@pathx.join(root, name))
    if json_string(record, "id", default="") != "" {
      records.push(record)
    }
  }
  records
}

///|
async fn read_agent_session_record(
  workspace_root : String,
  session_id : String,
) -> Json? {
  let path = @pathx.join(
    agent_sessions_dir(workspace_root),
    session_id + ".json",
  )
  if !@fsx.exists(path) {
    return None
  }
  let record = read_json_file_or_object(path)
  if json_string(record, "id", default="") == session_id {
    Some(record)
  } else {
    None
  }
}

///|
async fn write_agent_session_record(
  workspace_root : String,
  session : Json,
) -> Unit {
  let id = json_string(session, "id", default="")
  let root = agent_sessions_dir(workspace_root)
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  @fsx.write_to_file(
    @pathx.join(root, id + ".json"),
    session.stringify(indent=2) + "\n",
    create=0o644,
  )
}

///|
fn trimmed_text(value : String, fallback~ : String) -> String {
  let value = value.trim().to_owned()
  if value == "" {
    fallback
  } else {
    value
  }
}

///|
test "agent session merge updates runtime status" {
  let session : Json = {
    "id": "agent-a",
    "workspace_id": "book-a",
    "cwd": "/tmp/book-a",
    "moonclaw_task_id": "task-a",
    "status": "saved",
    "transcript": Json::array([]),
  }
  let task : Json = {
    "id": "task-a",
    "cwd": "/tmp/book-a",
    "status": "generating",
    "model": "test-model",
    "port": 9000,
    "web_search": true,
    "queued_messages": [{ "id": "m1" }],
  }
  let merged = enrich_agent_session(session, [task])
  assert_eq(json_string(merged, "status", default=""), "generating")
  assert_eq(json_int(merged, "queued_count", default=0), 1)
  assert_eq(json_string(merged, "model", default=""), "test-model")
}

///|
test "agent session append keeps transcript records" {
  let session : Json = { "id": "agent-a", "transcript": Json::array([]) }
  let next = append_agent_message(
    session,
    role="user",
    content="Help with code",
    status="queued",
    created_at="1",
  )
  assert_eq(json_array_items(next, "transcript").length(), 1)
  assert_true(
    json_string(json_array_items(next, "transcript")[0], "content", default="").contains(
      "Help",
    ),
  )
}

///|
test "agent context message includes selected book path" {
  let message = agent_context_message(
    book_name="Research Book",
    root="/tmp/book",
    context_path="wiki/index.md",
    message="Fix the failing tests",
  )
  assert_true(message.contains("book: Research Book"))
  assert_true(message.contains("root: /tmp/book"))
  assert_true(message.contains("selected path: wiki/index.md"))
  assert_true(message.contains("Fix the failing tests"))
}

///|
test "agent transcript projects moonclaw conversation events" {
  let transcript = [
    agent_message_record(
      role="user",
      content="Please inspect this workspace",
      status="sent",
      created_at="1",
    ),
  ]
  let events : Array[Json] = [
    {
      "id": "event-assistant",
      "created": "2",
      "desc": {
        "msg": "AssistantMessage",
        "content": "I found a failing test and fixed it.",
        "tool_calls": [],
      },
    },
    {
      "id": "event-tool",
      "created": "3",
      "desc": {
        "msg": "PostToolCall",
        "name": "execute_command",
        "text": "moon test passed",
      },
    },
  ]
  let merged = merge_agent_transcript(transcript, events)
  assert_eq(merged.length(), 3)
  assert_eq(json_string(merged[1], "role", default=""), "assistant")
  assert_true(
    json_string(merged[1], "content", default="").contains("failing test"),
  )
  assert_eq(json_string(merged[2], "role", default=""), "tool")
  assert_true(
    json_string(merged[2], "content", default="").contains("moon test"),
  )
}

///|
test "agent transcript avoids duplicate moonclaw events" {
  let event : Json = {
    "id": "event-assistant",
    "created": "2",
    "desc": { "msg": "AssistantMessage", "content": "Done.", "tool_calls": [] },
  }
  let once = merge_agent_transcript([], [event])
  let twice = merge_agent_transcript(once, [event])
  assert_eq(twice.length(), 1)
}

///|
test "agent transcript projects moonclaw live progress events" {
  let events : Array[Json] = [
    {
      "id": "model",
      "created": "10",
      "desc": { "msg": "ModelLoaded", "name": "test-model" },
    },
    { "id": "start", "created": "11", "desc": { "msg": "PreConversation" } },
    {
      "id": "tokens",
      "created": "12",
      "desc": { "msg": "TokenCounted", "token_count": 42 },
    },
    {
      "id": "context",
      "created": "13",
      "desc": {
        "msg": "ContextPruned",
        "origin_token_count": 42,
        "pruned_token_count": 40,
      },
    },
  ]
  let merged = merge_agent_transcript([], events)
  assert_eq(merged.length(), 4)
  assert_true(
    json_string(merged[0], "content", default="").contains("test-model"),
  )
  assert_eq(json_string(merged[1], "status", default=""), "running")
  assert_true(json_string(merged[2], "content", default="").contains("42"))
  assert_true(
    json_string(merged[3], "content", default="").contains("42 -> 40"),
  )
}

///|
test "agent moonclaw log record filters by session time" {
  let old_record : Json = {
    "time": 9,
    "event": { "id": "old", "created": 9, "desc": { "msg": "PreConversation" } },
  }
  let live_record : Json = {
    "time": 11,
    "event": {
      "id": "live",
      "created": 11,
      "desc": { "msg": "PreConversation" },
    },
  }
  assert_true(moonclaw_event_from_log_record(old_record, cutoff=10) is None)
  assert_true(moonclaw_event_from_log_record(live_record, cutoff=10) is Some(_))
  assert_true(
    moonclaw_event_from_log_record(live_record, cutoff=10, upper=10) is None,
  )
}
