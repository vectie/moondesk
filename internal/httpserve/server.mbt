///|
pub struct Server {
  server : @http.Server
  port : Int
}

///|
priv struct RunRef {
  workspace_id : String
  run_id : String
  run_root : String
}

///|
pub fn Server::port(self : Server) -> Int {
  self.port
}

///|
pub fn Server::close(self : Server) -> Unit {
  self.server.close()
}

///|
pub fn Server::new(
  host : String,
  port : Int,
  dual_stack? : Bool = true,
  reuse_addr? : Bool = false,
) -> Server raise {
  let host = if host == "localhost" { "127.0.0.1" } else { host }
  let server = @http.Server::new(
    @socket.Addr::parse("\{host}:\{port}"),
    dual_stack~,
    reuse_addr~,
  )
  { server, port: server.addr().port() }
}

///|
pub async fn Server::serve_directory(self : Server, root : String) -> Unit {
  self.server.run_forever(
    (request, _, conn) => {
      handle_file_request(root, request.meth, strip_query(request.path), conn)
    },
    allow_failure=true,
  )
}

///|
pub async fn Server::serve_desk(
  self : Server,
  ui_root : String,
  workspace_root : String,
) -> Unit {
  let ui_root = @pathx.normalize(ui_root)
  let workspace_root = @pathx.normalize(workspace_root)
  self.server.run_forever(
    (request, body, conn) => {
      handle_desk_request(ui_root, workspace_root, request, body, conn)
    },
    allow_failure=true,
  )
}

///|
async fn handle_desk_request(
  ui_root : String,
  workspace_root : String,
  request : @http.Request,
  body : &@io.Reader,
  conn : @http.ServerConnection,
) -> Unit {
  let path = strip_query(request.path)
  if path == "/api" || path.has_prefix("/api/") {
    handle_api_request(workspace_root, request.meth, request.path, body, conn)
  } else {
    handle_file_request(ui_root, request.meth, path, conn)
  }
}

///|
async fn handle_api_request(
  workspace_root : String,
  method_ : @http.RequestMethod,
  request_path : String,
  body : &@io.Reader,
  conn : @http.ServerConnection,
) -> Unit {
  let segments = path_segments(strip_query(request_path))
  match segments {
    ["api", "workspaces"] =>
      if is_read_method(method_) {
        send_json(conn, method_, discover_workspaces(workspace_root).to_json())
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "workspaces", workspace_id, "entries"] =>
      if is_read_method(method_) {
        handle_workspace_entries(
          workspace_root, workspace_id, request_path, method_, conn,
        )
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "workspaces", workspace_id, "preview"] =>
      if is_read_method(method_) {
        handle_workspace_preview(
          workspace_root, workspace_id, request_path, method_, conn,
        )
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "workspaces", workspace_id, "raw"] =>
      if is_read_method(method_) {
        handle_workspace_raw(
          workspace_root, workspace_id, request_path, method_, conn,
        )
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "workspaces", workspace_id, "inbox"] =>
      if method_ is @http.RequestMethod::Post {
        handle_workspace_inbox(
          workspace_root, workspace_id, body, method_, conn,
        )
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "workspaces", workspace_id, "reveal"] =>
      if method_ is @http.RequestMethod::Post {
        handle_workspace_reveal(
          workspace_root, workspace_id, body, method_, conn,
        )
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "search"] =>
      if is_read_method(method_) {
        handle_search(workspace_root, request_path, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "town", "state"] =>
      if is_read_method(method_) {
        handle_town_state(workspace_root, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "town", "daemon"] =>
      if is_read_method(method_) {
        handle_town_daemon(workspace_root, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "town", "analytics"] =>
      if is_read_method(method_) {
        handle_town_analytics(workspace_root, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "town", "messages"] =>
      if is_read_method(method_) {
        handle_town_messages(workspace_root, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "town", "requests"] =>
      if is_read_method(method_) {
        handle_town_requests(workspace_root, method_, conn)
      } else if method_ is @http.RequestMethod::Post {
        handle_town_request(workspace_root, body, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "town", "standing-goals"] =>
      if is_read_method(method_) {
        handle_town_standing_goals(workspace_root, method_, conn)
      } else if method_ is @http.RequestMethod::Post {
        handle_create_standing_goal(workspace_root, body, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "town", "dispatch"] =>
      if method_ is @http.RequestMethod::Post {
        handle_town_dispatch(workspace_root, body, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "moonclaw", "runs"] =>
      if is_read_method(method_) {
        handle_moonclaw_runs(workspace_root, request_path, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "moonclaw", "runs", run_id, "artifacts"] =>
      if is_read_method(method_) {
        handle_moonclaw_artifacts(workspace_root, run_id, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    _ => send_api_error(conn, method_, 404, "Not Found", "Not Found")
  }
}

///|
async fn handle_file_request(
  root : String,
  method_ : @http.RequestMethod,
  path : StringView,
  conn : @http.ServerConnection,
) -> Unit {
  let root = @pathx.normalize(root)
  guard method_ is @http.RequestMethod::Get ||
    method_ is @http.RequestMethod::Head else {
    send_status(conn, 405, "Method Not Allowed", "Method Not Allowed\n")
    return
  }
  match resolve_request_path(root, path) {
    Some(file_path) =>
      if @fs.exists(file_path) {
        send_file(conn, method_, file_path, 200, "OK")
      } else {
        send_status(conn, 404, "Not Found", "Not Found\n")
      }
    None => send_status(conn, 400, "Bad Request", "Bad Request\n")
  }
}

///|
fn resolve_request_path(root : String, request_path : StringView) -> String? {
  let request_path = strip_query(request_path.to_string())
  let relative = match request_path {
    "/" => "index.html"
    ['/', .. path] => path.to_string()
    _ => return None
  }
  let normalized = @pathx.normalize(relative)
  if normalized == "." {
    return Some(@pathx.join(root, "index.html"))
  }
  if normalized == ".." || normalized.has_prefix("../") {
    return None
  }
  let resolved = @pathx.join(root, normalized)
  let expected_prefix = root + "/"
  if resolved == root || resolved.has_prefix(expected_prefix) {
    Some(resolved)
  } else {
    None
  }
}

///|
async fn discover_workspaces(
  workspace_root : String,
) -> Array[@desk.DeskWorkspace] {
  let root = @pathx.normalize(workspace_root)
  let books_root = @pathx.join(root, ".moontown/books")
  let workspaces : Array[@desk.DeskWorkspace] = []
  if is_directory(books_root) {
    for name in read_directory_names(books_root, include_hidden=false) {
      let book_root = @pathx.join(books_root, name)
      if is_directory(book_root) {
        workspaces.push(
          @desk.workspace(
            id=@desk.stable_id("book", name),
            name~,
            root_path=book_root,
            kind=@desk.WorkspaceKind::MoonBook,
          ),
        )
      }
    }
  }
  if workspaces.length() > 0 {
    return workspaces
  }
  let kind = if is_directory(@pathx.join(root, ".moontown")) {
    @desk.WorkspaceKind::TownRoot
  } else {
    @desk.WorkspaceKind::LooseFolder
  }
  [
    @desk.workspace(
      id=@desk.stable_id("root", root),
      name=@desk.display_name(root),
      root_path=root,
      kind~,
    ),
  ]
}

///|
async fn find_workspace(
  workspace_root : String,
  workspace_id : String,
) -> @desk.DeskWorkspace? {
  for workspace in discover_workspaces(workspace_root) {
    if workspace.id == workspace_id {
      return Some(workspace)
    }
  }
  None
}

///|
async fn handle_workspace_entries(
  workspace_root : String,
  workspace_id : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(workspace) => workspace
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
      return
    }
  }
  let relative = decode_query_value(
    query_value(request_path, "path").unwrap_or(""),
  )
  match resolve_workspace_path(workspace.root_path, relative) {
    Some((absolute, clean_relative)) =>
      if is_directory(absolute) {
        let entries = list_workspace_entries(
          workspace, clean_relative, absolute,
        )
        send_json(conn, method_, entries.to_json())
      } else if @fs.exists(absolute) {
        send_json(
          conn,
          method_,
          [
            @desk.file_entry(
              workspace_id=workspace.id,
              path=clean_relative,
              writable=is_writable_entry(clean_relative),
            ),
          ].to_json(),
        )
      } else {
        send_api_error(conn, method_, 404, "Not Found", "Entry path not found")
      }
    None => send_api_error(conn, method_, 400, "Bad Request", "Invalid path")
  }
}

///|
async fn handle_workspace_preview(
  workspace_root : String,
  workspace_id : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(workspace) => workspace
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
      return
    }
  }
  let relative = decode_query_value(
    query_value(request_path, "path").unwrap_or(""),
  )
  match resolve_workspace_path(workspace.root_path, relative) {
    Some((absolute, clean_relative)) =>
      if is_directory(absolute) {
        let entries = list_workspace_entries(
          workspace, clean_relative, absolute,
        )
        let body = entries.map(entry => entry.path).join("\n")
        let entry = @desk.file_entry(
          workspace_id=workspace.id,
          path=clean_relative,
          is_directory=true,
          writable=is_writable_entry(clean_relative),
        )
        send_json(conn, method_, @desk.preview(entry, body~).to_json())
      } else if @fs.exists(absolute) {
        let entry = @desk.file_entry(
          workspace_id=workspace.id,
          path=clean_relative,
          writable=is_writable_entry(clean_relative),
        )
        let body = if is_binary_preview(entry.kind) {
          "/api/workspaces/\{workspace.id}/raw?path=\{clean_relative}"
        } else {
          @fs.read_file(absolute).text() catch {
            _ => ""
          }
        }
        let warnings = if !is_binary_preview(entry.kind) && body == "" {
          ["File could not be read as UTF-8 text."]
        } else {
          []
        }
        send_json(
          conn,
          method_,
          @desk.preview(entry, body~, warnings~).to_json(),
        )
      } else {
        send_api_error(conn, method_, 404, "Not Found", "Entry path not found")
      }
    None => send_api_error(conn, method_, 400, "Bad Request", "Invalid path")
  }
}

///|
async fn handle_workspace_raw(
  workspace_root : String,
  workspace_id : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(workspace) => workspace
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
      return
    }
  }
  let relative = decode_query_value(
    query_value(request_path, "path").unwrap_or(""),
  )
  match resolve_workspace_path(workspace.root_path, relative) {
    Some((absolute, _)) =>
      if @fs.exists(absolute) && !is_directory(absolute) {
        send_file(conn, method_, absolute, 200, "OK")
      } else {
        send_api_error(conn, method_, 404, "Not Found", "Entry path not found")
      }
    None => send_api_error(conn, method_, 400, "Bad Request", "Invalid path")
  }
}

///|
async fn handle_workspace_inbox(
  workspace_root : String,
  workspace_id : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(workspace) => workspace
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
      return
    }
  }
  let payload = match read_json_body(body) {
    Some(json) => json
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  let title = json_string(payload, "title", default="Moondesk inbox note")
  let content = json_string(
    payload,
    "content",
    default=json_string(payload, "prompt", default=""),
  )
  match json_string_opt(payload, "path") {
    Some(path) => {
      let relative = decode_query_value(path)
      match resolve_workspace_path(workspace.root_path, relative) {
        Some((absolute, clean_relative)) =>
          if !is_writable_entry(clean_relative) {
            send_api_error(
              conn, method_, 400, "Bad Request", "Inbox edits must stay under inbox/",
            )
            return
          } else {
            let parent = @pathx.dirname(absolute).to_string()
            @fsx.make_directory(parent, recursive=true, exists_ok=true) catch {
              _ => {
                send_api_error(
                  conn, method_, 500, "Internal Server Error", "Could not create inbox directory",
                )
                return
              }
            }
            @fsx.write_to_file(absolute, content, create=0o644) catch {
              _ => {
                send_api_error(
                  conn, method_, 500, "Internal Server Error", "Could not edit inbox note",
                )
                return
              }
            }
            send_json(conn, method_, {
              "ok": true,
              "workspace_id": workspace.id,
              "path": clean_relative,
            })
            return
          }
        None => {
          send_api_error(
            conn, method_, 400, "Bad Request", "Invalid inbox path",
          )
          return
        }
      }
    }
    None => ()
  }
  let inbox_root = @pathx.join(workspace.root_path, "inbox")
  @fsx.make_directory(inbox_root, recursive=true, exists_ok=true) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not create inbox",
      )
      return
    }
  }
  let filename = @desk.stable_id("note", title) +
    "-" +
    @async.now().to_string() +
    ".md"
  let relative = @pathx.join("inbox", filename)
  let absolute = @pathx.join(workspace.root_path, relative)
  let markdown = "# \{title}\n\n\{content}\n"
  @fsx.write_to_file(absolute, markdown, create=0o644) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not write inbox note",
      )
      return
    }
  }
  send_json(conn, method_, {
    "ok": true,
    "workspace_id": workspace.id,
    "path": relative,
  })
}

///|
async fn handle_workspace_reveal(
  workspace_root : String,
  workspace_id : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(workspace) => workspace
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
      return
    }
  }
  let payload = read_json_body(body).unwrap_or(Json::object({}))
  let relative = json_string(payload, "path", default="")
  match resolve_workspace_path(workspace.root_path, relative) {
    Some((absolute, clean_relative)) =>
      if @fs.exists(absolute) {
        let code = reveal_path(absolute)
        send_json(conn, method_, {
          "ok": code == 0,
          "status": if code == 0 {
            "revealed"
          } else {
            "reveal failed"
          },
          "exit_code": code,
          "workspace_id": workspace.id,
          "path": clean_relative,
          "absolute_path": absolute,
        })
      } else {
        send_api_error(conn, method_, 404, "Not Found", "Entry path not found")
      }
    None => send_api_error(conn, method_, 400, "Bad Request", "Invalid path")
  }
}

///|
async fn reveal_path(absolute : String) -> Int {
  let mac = @process.run("open", ["-R", absolute]) catch { _ => -1 }
  if mac == 0 {
    return mac
  }
  let target = if is_directory(absolute) {
    absolute
  } else {
    @pathx.dirname(absolute).to_string()
  }
  @process.run("xdg-open", [target]) catch {
    _ => mac
  }
}

///|
async fn handle_search(
  workspace_root : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let query = decode_query_value(
      query_value(request_path, "query").unwrap_or(""),
    )
    .trim()
    .to_string()
  if query == "" {
    send_json(conn, method_, Json::array([]))
    return
  }
  let workspace_filter = query_value(request_path, "workspace")
  let query_lower = query.to_lower()
  let hits : Array[Json] = []
  for workspace in discover_workspaces(workspace_root) {
    match workspace_filter {
      Some(id) if id != workspace.id => continue
      _ => ()
    }
    collect_search_hits(workspace, "", query_lower, hits, 0, 80)
    if hits.length() >= 80 {
      break
    }
  }
  send_json(conn, method_, Json::array(hits))
}

///|
async fn collect_search_hits(
  workspace : @desk.DeskWorkspace,
  relative : String,
  query_lower : String,
  hits : Array[Json],
  depth : Int,
  limit : Int,
) -> Unit {
  if hits.length() >= limit || depth > 6 {
    return
  }
  let absolute = if relative == "" {
    workspace.root_path
  } else {
    @pathx.join(workspace.root_path, relative)
  }
  for name in read_directory_names(absolute, include_hidden=true) {
    if hits.length() >= limit {
      break
    }
    if should_hide_file_entry(name) {
      continue
    }
    let child_relative = if relative == "" {
      name
    } else {
      relative + "/" + name
    }
    let child_absolute = @pathx.join(workspace.root_path, child_relative)
    if is_directory(child_absolute) {
      collect_search_hits(
        workspace,
        child_relative,
        query_lower,
        hits,
        depth + 1,
        limit,
      )
    } else {
      let entry = @desk.file_entry(
        workspace_id=workspace.id,
        path=child_relative,
        writable=is_writable_entry(child_relative),
      )
      if !is_searchable_entry(entry.kind) {
        continue
      }
      let path_match = child_relative.to_lower().contains(query_lower)
      let text = @fs.read_file(child_absolute).text() catch { _ => "" }
      let body_match = text.to_lower().contains(query_lower)
      if path_match || body_match {
        hits.push({
          "workspace_id": workspace.id,
          "workspace_name": workspace.name,
          "path": entry.path,
          "title": entry.display_name,
          "kind": entry.kind,
          "source_layer": entry.source_layer,
          "snippet": search_snippet(text, query_lower, fallback=entry.path),
        })
      }
    }
  }
}

///|
fn is_searchable_entry(kind : @desk.EntryKind) -> Bool {
  match kind {
    @desk.EntryKind::Markdown
    | @desk.EntryKind::Html
    | @desk.EntryKind::Json
    | @desk.EntryKind::Text
    | @desk.EntryKind::Unknown => true
    _ => false
  }
}

///|
fn search_snippet(
  text : String,
  query_lower : String,
  fallback~ : String,
) -> String {
  let trimmed = text.trim().to_string()
  if trimmed == "" {
    return fallback
  }
  let lower = trimmed.to_lower()
  let start = match lower.find(query_lower) {
    Some(index) if index > 60 => index - 60
    Some(_) => 0
    None => 0
  }
  let remaining = trimmed.length() - start
  let take = if remaining > 180 { 180 } else { remaining }
  trimmed[start:start + take].replace_all(old="\n", new=" ").to_string()
}

///|
async fn handle_town_state(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let state_path = @pathx.join(
    @pathx.normalize(workspace_root),
    ".moontown/town.json",
  )
  if @fs.exists(state_path) {
    send_json_text(conn, method_, @fs.read_file(state_path).text())
  } else {
    send_json(conn, method_, Json::object({}))
  }
}

///|
async fn handle_town_daemon(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let daemon = read_json_file_or_object(town_daemon_path(workspace_root))
  send_json(conn, method_, daemon)
}

///|
async fn handle_town_standing_goals(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  send_json(
    conn,
    method_,
    Json::array(read_json_array_file(town_standing_goals_path(workspace_root))),
  )
}

///|
async fn handle_create_standing_goal(
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
  let root = @pathx.normalize(workspace_root)
  let town_root = @pathx.join(root, ".moontown")
  @fsx.make_directory(town_root, recursive=true, exists_ok=true) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not create town state directory",
      )
      return
    }
  }
  let path = town_standing_goals_path(root)
  let daemon = read_json_file_or_object(town_daemon_path(root))
  let record = standing_goal_record_from_payload(
    payload,
    daemon_tick=json_int(daemon, "tick_sequence", default=0),
  )
  let goals = upsert_record_by_id(read_json_array_file(path), record)
  @fsx.write_to_file(
    path,
    Json::array(goals).stringify(indent=2) + "\n",
    create=0o644,
  ) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not write standing goal",
      )
      return
    }
  }
  send_json(conn, method_, record)
}

///|
async fn handle_town_dispatch(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  ignore(body)
  let root = @pathx.normalize(workspace_root)
  let dispatch_root = @pathx.join(root, ".moontown/moondesk-dispatches")
  @fsx.make_directory(dispatch_root, recursive=true, exists_ok=true) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not create dispatch ledger",
      )
      return
    }
  }
  let id = @desk.stable_id("dispatch", @async.now().to_string())
  let path = ".moontown/moondesk-dispatches/" + id + ".json"
  let absolute = @pathx.join(root, path)
  let can_run = @fs.exists(@pathx.join(root, "moon.mod")) &&
    @fs.exists(@pathx.join(root, "cmd/main/moon.pkg"))
  let mut exit_code = -1
  let mut stdout = ""
  let mut stderr = ""
  if can_run {
    let collected = Some(
      @process.collect_output(
        "moon",
        ["run", "cmd/main", "--", "daemon", "tick"],
        cwd=root,
      ),
    ) catch {
      error => {
        stderr = "Could not run Moontown daemon tick: \{error}"
        None
      }
    }
    match collected {
      Some((code, out, err)) => {
        exit_code = code
        stdout = out.text()
        stderr = err.text()
      }
      None => ()
    }
  } else {
    stderr = "Configured root is not a runnable Moontown checkout: \{root}"
  }
  let record : Json = {
    "id": id,
    "ok": exit_code == 0,
    "status": if exit_code == 0 {
      "daemon tick completed"
    } else {
      "daemon tick failed"
    },
    "exit_code": exit_code,
    "path": path,
    "stdout": trim_for_record(stdout),
    "stderr": trim_for_record(stderr),
  }
  @fsx.write_to_file(absolute, record.stringify(indent=2) + "\n", create=0o644) catch {
    _ => ()
  }
  send_json(conn, method_, record)
}

///|
async fn handle_town_analytics(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let root = @pathx.normalize(workspace_root)
  let daemon = read_json_file_or_object(town_daemon_path(root))
  let daemon_tick = json_int(daemon, "tick_sequence", default=0)
  let goals = read_json_array_file(town_standing_goals_path(root))
  let watcher_records = read_watcher_records(root, 400)
  let request_count = count_matching_files(
    @pathx.join(root, ".moontown/moondesk-requests"),
    ".json",
  )
  let message_count = count_matching_files(
    @pathx.join(root, ".moontown/book-results"),
    ".json",
  )
  let run_count = count_run_workspaces(root)
  let active_goal_count = json_string_array_len(daemon, "active_goal_ids")
  send_json(conn, method_, {
    "daemon_tick": daemon_tick,
    "standing_goal_count": goals.length(),
    "due_goal_count": count_due_goals(goals, daemon_tick),
    "active_goal_count": active_goal_count,
    "request_count": request_count,
    "message_count": message_count,
    "run_count": run_count,
    "watcher_run_count": watcher_records.length(),
    "updates": count_watcher_decision(watcher_records, "Update"),
    "no_changes": count_watcher_decision(watcher_records, "NoChange"),
    "needs_review": count_watcher_decision(watcher_records, "NeedsReview"),
    "failures": count_watcher_decision(watcher_records, "Failed"),
    "deferred": count_watcher_decision(watcher_records, "Deferred"),
    "next_due_tick": next_due_tick(goals),
  })
}

///|
async fn handle_town_messages(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let results_root = @pathx.join(
    @pathx.normalize(workspace_root),
    ".moontown/book-results",
  )
  let messages : Array[Json] = []
  let names = read_directory_names(results_root, include_hidden=false)
  let start = if names.length() > 40 { names.length() - 40 } else { 0 }
  for index = start; index < names.length(); index = index + 1 {
    let name = names[index]
    if !name.has_suffix(".json") {
      continue
    }
    messages.push({
      "id": @desk.stable_id("message", name),
      "path": "book-results/" + name,
      "title": name,
      "kind": "book-result",
    })
  }
  send_json(conn, method_, Json::array(messages))
}

///|
async fn handle_town_requests(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let requests_root = @pathx.join(
    @pathx.normalize(workspace_root),
    ".moontown/moondesk-requests",
  )
  let requests : Array[Json] = []
  let names = read_directory_names(requests_root, include_hidden=false)
  let start = if names.length() > 80 { names.length() - 80 } else { 0 }
  for index = start; index < names.length(); index = index + 1 {
    let name = names[index]
    if !name.has_suffix(".json") {
      continue
    }
    let absolute = @pathx.join(requests_root, name)
    let record = @json.parse(@fs.read_file(absolute).text()) catch {
      _ => {
        let fallback : Json = {
          "id": @desk.stable_id("request", name),
          "status": "unreadable",
          "path": ".moontown/moondesk-requests/" + name,
          "request": { "title": name },
        }
        fallback
      }
    }
    requests.push(record)
  }
  send_json(conn, method_, Json::array(requests))
}

///|
async fn handle_town_request(
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
  let root = @pathx.normalize(workspace_root)
  let requests_root = @pathx.join(root, ".moontown/moondesk-requests")
  @fsx.make_directory(requests_root, recursive=true, exists_ok=true) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not create request ledger",
      )
      return
    }
  }
  let title = json_string(payload, "title", default="Moondesk request")
  let id = @desk.stable_id("request", title + "-" + @async.now().to_string())
  let relative = ".moontown/moondesk-requests/" + id + ".json"
  let absolute = @pathx.join(root, relative)
  let record : Json = {
    "id": id,
    "status": "staged",
    "path": relative,
    "request": payload,
  }
  @fsx.write_to_file(absolute, record.stringify(indent=2) + "\n", create=0o644) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not write request",
      )
      return
    }
  }
  send_json(conn, method_, record)
}

///|
async fn handle_moonclaw_runs(
  workspace_root : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let requested_workspace = query_value(request_path, "workspace")
  let runs : Array[@desk.DeskRunProjection] = []
  for workspace in discover_workspaces(workspace_root) {
    match requested_workspace {
      Some(id) if id != workspace.id => continue
      _ => ()
    }
    let run_root = @pathx.join(workspace.root_path, "moonclaw-jobs")
    let names = read_directory_names(run_root, include_hidden=false)
    let start = if names.length() > 80 { names.length() - 80 } else { 0 }
    for index = start; index < names.length(); index = index + 1 {
      let name = names[index]
      if !name.has_prefix("run-") {
        continue
      }
      let absolute = @pathx.join(run_root, name)
      if !is_directory(absolute) {
        continue
      }
      let artifacts = run_artifacts(workspace, name, absolute)
      let status = if @fs.exists(@pathx.join(absolute, "result.json")) {
        "ready"
      } else {
        "available"
      }
      runs.push(
        @desk.run_projection(
          run_id=name,
          book_id=workspace.id,
          status~,
          phase="workspace",
          summary="MoonClaw run workspace with \{artifacts.length()} visible artifacts.",
          artifacts~,
        ),
      )
    }
  }
  send_json(conn, method_, runs.to_json())
}

///|
async fn handle_moonclaw_artifacts(
  workspace_root : String,
  run_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match find_run(workspace_root, run_id) {
    Some(run) => {
      let workspace = find_workspace(workspace_root, run.workspace_id).unwrap()
      send_json(
        conn,
        method_,
        run_artifacts(workspace, run.run_id, run.run_root).to_json(),
      )
    }
    None => send_api_error(conn, method_, 404, "Not Found", "Unknown run")
  }
}

///|
async fn find_run(workspace_root : String, run_id : String) -> RunRef? {
  for workspace in discover_workspaces(workspace_root) {
    let run_root = @pathx.join(workspace.root_path, "moonclaw-jobs")
    let candidate = @pathx.join(run_root, run_id)
    if is_directory(candidate) {
      return Some({ workspace_id: workspace.id, run_id, run_root: candidate })
    }
  }
  None
}

///|
async fn run_artifacts(
  workspace : @desk.DeskWorkspace,
  run_id : String,
  run_root : String,
) -> Array[@desk.DeskRunArtifact] {
  let artifacts : Array[@desk.DeskRunArtifact] = []
  for artifact_name in ["report.md", "result.json"] {
    let absolute = @pathx.join(run_root, artifact_name)
    if @fs.exists(absolute) {
      let path = "moonclaw-jobs/" + run_id + "/" + artifact_name
      artifacts.push(
        @desk.run_artifact(id=@desk.stable_id(run_id, path), path~),
      )
    }
  }
  let outputs_root = @pathx.join(run_root, "outputs")
  for name in read_directory_names(outputs_root, include_hidden=false) {
    if artifacts.length() >= 32 {
      break
    }
    if !(name.has_suffix(".md") || name.has_suffix(".json")) {
      continue
    }
    let absolute = @pathx.join(outputs_root, name)
    if @fs.exists(absolute) && !is_directory(absolute) {
      let path = "moonclaw-jobs/" + run_id + "/outputs/" + name
      artifacts.push(
        @desk.run_artifact(id=@desk.stable_id(run_id, path), path~),
      )
    }
  }
  ignore(workspace)
  artifacts
}

///|
async fn list_workspace_entries(
  workspace : @desk.DeskWorkspace,
  relative : String,
  absolute : String,
) -> Array[@desk.DeskFileEntry] {
  let entries : Array[@desk.DeskFileEntry] = []
  for name in read_directory_names(absolute, include_hidden=true) {
    if should_hide_file_entry(name) {
      continue
    }
    let child_relative = if relative == "" {
      name
    } else {
      relative + "/" + name
    }
    let child_absolute = @pathx.join(workspace.root_path, child_relative)
    entries.push(
      @desk.file_entry(
        workspace_id=workspace.id,
        path=child_relative,
        is_directory=is_directory(child_absolute),
        writable=is_writable_entry(child_relative),
      ),
    )
  }
  entries
}

///|
fn should_hide_file_entry(name : String) -> Bool {
  name == ".git" ||
  name == ".DS_Store" ||
  name == "node_modules" ||
  name == "_build" ||
  name == ".moonclaw-worktrees"
}

///|
fn is_writable_entry(path : String) -> Bool {
  path == "inbox" || path.has_prefix("inbox/")
}

///|
fn is_binary_preview(kind : @desk.EntryKind) -> Bool {
  kind is @desk.EntryKind::Image
}

///|
async fn read_directory_names(
  path : String,
  include_hidden? : Bool = true,
) -> Array[String] {
  let dir = @fs.opendir(path) catch { _ => return [] }
  defer dir.close()
  let names = dir.read_all(include_hidden~) catch { _ => return [] }
  names.sort()
  names
}

///|
async fn is_directory(path : String) -> Bool {
  let kind = @fs.kind(path) catch { _ => return false }
  match kind {
    @fs.FileKind::Directory => true
    _ => false
  }
}

///|
fn resolve_workspace_path(
  workspace_root : String,
  relative : String,
) -> (String, String)? {
  let root = @pathx.normalize(workspace_root)
  let clean = match clean_relative_path(relative) {
    Some(path) => path
    None => return None
  }
  let absolute = if clean == "" { root } else { @pathx.join(root, clean) }
  let expected_prefix = root + "/"
  if absolute == root || absolute.has_prefix(expected_prefix) {
    Some((absolute, clean))
  } else {
    None
  }
}

///|
fn clean_relative_path(relative : String) -> String? {
  if relative.has_prefix("/") || @pathx.is_absolute(relative) {
    return None
  }
  let trimmed = relative.trim(chars=['/']).to_string()
  if trimmed == "" {
    return Some("")
  }
  let normalized = @pathx.normalize(trimmed)
  if normalized == "." {
    Some("")
  } else if normalized == ".." || normalized.has_prefix("../") {
    None
  } else {
    Some(normalized)
  }
}

///|
fn is_read_method(method_ : @http.RequestMethod) -> Bool {
  method_ is @http.RequestMethod::Get || method_ is @http.RequestMethod::Head
}

///|
fn strip_query(path : String) -> String {
  match path.find("?") {
    Some(index) => path[:index].to_string()
    None => path
  }
}

///|
fn query_value(path : String, key : String) -> String? {
  match path.find("?") {
    Some(index) => {
      for piece in path[index + 1:].split("&") {
        let entry = piece.to_string()
        match entry.find("=") {
          Some(split) =>
            if entry[:split] == key {
              return Some(entry[split + 1:].to_string())
            }
          None => ()
        }
      }
      None
    }
    None => None
  }
}

///|
fn decode_query_value(text : String) -> String {
  text
  .replace_all(old="+", new=" ")
  .replace_all(old="%2F", new="/")
  .replace_all(old="%2f", new="/")
  .replace_all(old="%2E", new=".")
  .replace_all(old="%2e", new=".")
  .replace_all(old="%3A", new=":")
  .replace_all(old="%3a", new=":")
  .replace_all(old="%20", new=" ")
  .to_string()
}

///|
fn path_segments(path : String) -> Array[String] {
  let path = match path {
    ['/', .. rest] => rest.to_string()
    _ => path
  }
  let segments : Array[String] = []
  for segment in path.split("/") {
    let segment = segment.to_string()
    if segment != "" {
      segments.push(segment)
    }
  }
  segments
}

///|
async fn read_json_body(body : &@io.Reader) -> Json? {
  let text = body.read_all().text()
  if text.trim().to_string() == "" {
    return Some(Json::object({}))
  }
  Some(@json.parse(text)) catch {
    _ => None
  }
}

///|
fn json_string(json : Json, key : String, default~ : String) -> String {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::String(value)) => value
        _ => default
      }
    _ => default
  }
}

///|
fn json_string_opt(json : Json, key : String) -> String? {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::String(value)) => Some(value)
        _ => None
      }
    _ => None
  }
}

///|
fn json_int(json : Json, key : String, default~ : Int) -> Int {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(value) =>
          @json.from_json(value) catch {
            _ =>
              match value {
                Json::String(text) =>
                  @string.parse_int(text) catch {
                    _ => default
                  }
                _ => default
              }
          }
        None => default
      }
    _ => default
  }
}

///|
fn json_bool(json : Json, key : String, default~ : Bool) -> Bool {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(value) => @json.from_json(value) catch { _ => default }
        None => default
      }
    _ => default
  }
}

///|
fn json_string_array_len(json : Json, key : String) -> Int {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(value) => {
          let items : Array[String] = @json.from_json(value) catch { _ => [] }
          items.length()
        }
        None => 0
      }
    _ => 0
  }
}

///|
async fn read_json_file_or_object(path : String) -> Json {
  if !@fs.exists(path) {
    return Json::object({})
  }
  @json.parse(@fs.read_file(path).text()) catch {
    _ => Json::object({})
  }
}

///|
async fn read_json_array_file(path : String) -> Array[Json] {
  if !@fs.exists(path) {
    return []
  }
  let parsed = @json.parse(@fs.read_file(path).text()) catch { _ => return [] }
  @json.from_json(parsed) catch {
    _ => []
  }
}

///|
fn town_daemon_path(workspace_root : String) -> String {
  @pathx.join(@pathx.normalize(workspace_root), ".moontown/daemon.json")
}

///|
fn town_standing_goals_path(workspace_root : String) -> String {
  @pathx.join(@pathx.normalize(workspace_root), ".moontown/standing-goals.json")
}

///|
fn clamp_int(value : Int, min : Int, max : Int) -> Int {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
fn standing_goal_record_from_payload(
  payload : Json,
  daemon_tick~ : Int,
) -> Json {
  let title = json_string(payload, "title", default="Moondesk standing watch")
  let id = json_string(payload, "id", default=@desk.stable_id("watch", title))
  let cadence = clamp_int(
    json_int(payload, "cadence_ticks", default=60),
    1,
    525600,
  )
  let quality = clamp_int(
    json_int(payload, "quality_threshold", default=85),
    1,
    100,
  )
  let next_due = json_int(payload, "next_due_tick", default=daemon_tick)
  {
    "id": id,
    "title": title,
    "prompt": json_string(payload, "prompt", default=""),
    "target_book_id": json_string(payload, "target_book_id", default=""),
    "cadence_ticks": cadence,
    "next_due_tick": next_due,
    "last_run_tick": match json_int(payload, "last_run_tick", default=-1) {
      -1 => Json::null()
      tick => tick.to_json()
    },
    "enabled": json_bool(payload, "enabled", default=true),
    "source_policy": json_string(payload, "source_policy", default="web-first"),
    "quality_threshold": quality,
  }
}

///|
fn upsert_record_by_id(records : Array[Json], record : Json) -> Array[Json] {
  let id = json_string(record, "id", default="")
  let next : Array[Json] = []
  let mut replaced = false
  for item in records {
    if json_string(item, "id", default="") == id {
      next.push(record)
      replaced = true
    } else {
      next.push(item)
    }
  }
  if !replaced {
    next.push(record)
  }
  next
}

///|
fn trim_for_record(text : String) -> String {
  let text = text.trim().to_string()
  if text.length() > 4000 {
    text[:4000].to_string()
  } else {
    text
  }
}

///|
async fn read_watcher_records(root : String, limit : Int) -> Array[Json] {
  let records : Array[Json] = []
  let watcher_root = @pathx.join(root, ".moontown/watchers")
  for name in read_directory_names(watcher_root, include_hidden=false) {
    if !name.has_suffix(".jsonl") {
      continue
    }
    let text = @fs.read_file(@pathx.join(watcher_root, name)).text() catch {
      _ => continue
    }
    for line in text.split("\n") {
      let line = line.to_string().trim().to_string()
      if line == "" {
        continue
      }
      let record = Some(@json.parse(line)) catch { _ => None }
      match record {
        Some(record) => if records.length() < limit { records.push(record) }
        None => ()
      }
    }
  }
  records
}

///|
fn count_watcher_decision(records : Array[Json], decision : String) -> Int {
  let mut count = 0
  for record in records {
    if json_string(record, "decision", default="") == decision {
      count += 1
    }
  }
  count
}

///|
fn count_due_goals(goals : Array[Json], daemon_tick : Int) -> Int {
  let mut count = 0
  for goal in goals {
    if json_bool(goal, "enabled", default=true) &&
      daemon_tick >= json_int(goal, "next_due_tick", default=0) {
      count += 1
    }
  }
  count
}

///|
fn next_due_tick(goals : Array[Json]) -> Int {
  let mut found = false
  let mut next = 0
  for goal in goals {
    if !json_bool(goal, "enabled", default=true) {
      continue
    }
    let due = json_int(goal, "next_due_tick", default=0)
    if !found || due < next {
      found = true
      next = due
    }
  }
  if found {
    next
  } else {
    0
  }
}

///|
async fn count_matching_files(root : String, suffix : String) -> Int {
  let mut count = 0
  for name in read_directory_names(root, include_hidden=false) {
    if name.has_suffix(suffix) {
      count += 1
    }
  }
  count
}

///|
async fn count_run_workspaces(workspace_root : String) -> Int {
  let mut count = 0
  for workspace in discover_workspaces(workspace_root) {
    let run_root = @pathx.join(workspace.root_path, "moonclaw-jobs")
    for name in read_directory_names(run_root, include_hidden=false) {
      if name.has_prefix("run-") && is_directory(@pathx.join(run_root, name)) {
        count += 1
      }
    }
  }
  count
}

///|
async fn send_file(
  conn : @http.ServerConnection,
  method_ : @http.RequestMethod,
  path : String,
  code : Int,
  reason : String,
) -> Unit {
  conn.send_response(code, reason, extra_headers={
    "content-type": content_type(path),
  })
  if method_ is @http.RequestMethod::Head {
    conn.end_response()
    return
  }
  conn.write(@fs.read_file(path).binary())
  conn.end_response()
}

///|
async fn send_status(
  conn : @http.ServerConnection,
  code : Int,
  reason : String,
  body : String,
) -> Unit {
  conn.send_response(code, reason, extra_headers={
    "content-type": "text/plain; charset=utf-8",
  })
  conn.write(body)
  conn.end_response()
}

///|
async fn send_json(
  conn : @http.ServerConnection,
  method_ : @http.RequestMethod,
  body : Json,
) -> Unit {
  send_json_text(conn, method_, body.stringify(indent=2) + "\n")
}

///|
async fn send_json_text(
  conn : @http.ServerConnection,
  method_ : @http.RequestMethod,
  body : String,
) -> Unit {
  conn.send_response(200, "OK", extra_headers={
    "content-type": "application/json; charset=utf-8",
  })
  if method_ is @http.RequestMethod::Head {
    conn.end_response()
    return
  }
  conn.write(body)
  conn.end_response()
}

///|
async fn send_api_error(
  conn : @http.ServerConnection,
  method_ : @http.RequestMethod,
  code : Int,
  reason : String,
  message : String,
) -> Unit {
  conn.send_response(code, reason, extra_headers={
    "content-type": "application/json; charset=utf-8",
  })
  if method_ is @http.RequestMethod::Head {
    conn.end_response()
    return
  }
  let body : Json = { "error": message }
  conn.write(body.stringify(indent=2) + "\n")
  conn.end_response()
}

///|
fn content_type(path : String) -> String {
  match @pathx.ext(path) {
    ".html" => "text/html; charset=utf-8"
    ".css" => "text/css; charset=utf-8"
    ".js" => "application/javascript"
    ".json" => "application/json"
    ".svg" => "image/svg+xml"
    ".png" => "image/png"
    ".jpg" | ".jpeg" => "image/jpeg"
    ".gif" => "image/gif"
    ".webp" => "image/webp"
    ".ico" => "image/x-icon"
    ".txt" | ".md" => "text/plain; charset=utf-8"
    _ => "application/octet-stream"
  }
}

///|
test "resolve request path rejects traversal" {
  assert_eq(
    resolve_request_path("/tmp/moondesk", "/"),
    Some("/tmp/moondesk/index.html"),
  )
  assert_eq(resolve_request_path("/tmp/moondesk", "/../secret"), None)
}

///|
test "api path helpers handle queries and traversal" {
  assert_eq(
    strip_query("/api/workspaces/book/entries?path=wiki"),
    "/api/workspaces/book/entries",
  )
  assert_eq(
    query_value("/api?path=wiki%2Findex.md&other=1", "path"),
    Some("wiki%2Findex.md"),
  )
  assert_eq(decode_query_value("wiki%2Findex.md"), "wiki/index.md")
  assert_eq(path_segments("/api/workspaces"), ["api", "workspaces"])
  assert_eq(clean_relative_path("wiki/../raw/README.md"), Some("raw/README.md"))
  assert_eq(clean_relative_path("../secret"), None)
  assert_eq(clean_relative_path("/tmp/secret"), None)
}

///|
test "request body helpers handle optional strings" {
  let payload : Json = { "title": "Draft", "path": "inbox/draft.md" }
  assert_eq(json_string(payload, "title", default="Fallback"), "Draft")
  assert_eq(json_string_opt(payload, "path"), Some("inbox/draft.md"))
  assert_eq(json_string_opt(payload, "missing"), None)
}

///|
test "standing goal records normalize host payloads" {
  let record = standing_goal_record_from_payload(
    {
      "title": "Track APIs",
      "prompt": "Watch API docs",
      "target_book_id": "research-api",
      "cadence_ticks": "0",
      "quality_threshold": 120,
      "source_policy": "web-first",
    },
    daemon_tick=42,
  )
  assert_eq(json_string(record, "id", default=""), "watch-track-apis")
  assert_eq(json_int(record, "cadence_ticks", default=0), 1)
  assert_eq(json_int(record, "quality_threshold", default=0), 100)
  assert_eq(json_int(record, "next_due_tick", default=0), 42)
}

///|
test "standing goal upsert replaces by id" {
  let original : Json = { "id": "watch-a", "title": "A" }
  let replacement : Json = { "id": "watch-a", "title": "B" }
  let records = upsert_record_by_id([original], replacement)
  assert_eq(records.length(), 1)
  assert_eq(json_string(records[0], "title", default=""), "B")
}

///|
test "search snippets are bounded and single line" {
  let snippet = search_snippet(
    "alpha beta gamma\ndelta epsilon zeta",
    "epsilon",
    fallback="fallback",
  )
  assert_true(snippet.contains("epsilon"))
  assert_eq(snippet.contains("\n"), false)
}
