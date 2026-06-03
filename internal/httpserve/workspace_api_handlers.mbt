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
async fn handle_workspace_site_asset(
  workspace_root : String,
  workspace_id : String,
  asset_path : String,
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
  let asset_path = decode_query_value(asset_path)
  let asset_path = if asset_path == "" { "index.html" } else { asset_path }
  let relative = @pathx.join("book/site/generated", asset_path)
  if relative != "book/site/generated" &&
    !relative.has_prefix("book/site/generated/") {
    send_api_error(conn, method_, 400, "Bad Request", "Invalid path")
    return
  }
  match resolve_workspace_path(workspace.root_path, relative) {
    Some((absolute, _)) =>
      if @fs.exists(absolute) && !is_directory(absolute) {
        send_file(conn, method_, absolute, 200, "OK")
      } else {
        send_api_error(conn, method_, 404, "Not Found", "Site asset not found")
      }
    None => send_api_error(conn, method_, 400, "Bad Request", "Invalid path")
  }
}

///|
async fn handle_workspace_file_asset(
  workspace_root : String,
  workspace_id : String,
  asset_path : String,
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
  let relative = decode_query_value(asset_path)
  match resolve_workspace_path(workspace.root_path, relative) {
    Some((absolute, _)) =>
      if @fs.exists(absolute) && !is_directory(absolute) {
        send_file(conn, method_, absolute, 200, "OK")
      } else {
        send_api_error(conn, method_, 404, "Not Found", "File not found")
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
async fn handle_workspace_import(
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
  let kind = json_string(payload, "kind", default="note")
  let title = json_string(payload, "title", default="Moondesk import")
  let inbox_root = @pathx.join(workspace.root_path, "inbox/imports")
  @fsx.make_directory(inbox_root, recursive=true, exists_ok=true) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not create import inbox",
      )
      return
    }
  }
  let id = @desk.stable_id("import", title + "-" + @async.now().to_string())
  let relative = "inbox/imports/" + id + ".md"
  let absolute = @pathx.join(workspace.root_path, relative)
  @fsx.write_to_file(
    absolute,
    import_markdown(payload, kind, title),
    create=0o644,
  ) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not write import note",
      )
      return
    }
  }
  let data_url = json_string(payload, "data_url", default="")
  let data_path = if data_url == "" {
    ""
  } else {
    let data_relative = "inbox/imports/" + id + ".data-url.txt"
    @fsx.write_to_file(
      @pathx.join(workspace.root_path, data_relative),
      data_url,
      create=0o644,
    ) catch {
      _ => ()
    }
    data_relative
  }
  send_json(conn, method_, {
    "ok": true,
    "workspace_id": workspace.id,
    "path": relative,
    "kind": kind,
    "data_path": data_path,
  })
}

///|
fn import_markdown(payload : Json, kind : String, title : String) -> String {
  let url = json_string(payload, "url", default="")
  let filename = json_string(payload, "filename", default="")
  let content_type = json_string(payload, "content_type", default="")
  let browser_import_id = json_string(payload, "browser_import_id", default="")
  let note = json_string(payload, "note", default="")
  let content = json_string(payload, "content", default="")
  let mut body = "# \{title}\n\n"
  body = body + "- Import kind: \{kind}\n"
  if url != "" {
    body = body + "- URL: \{url}\n"
  }
  if filename != "" {
    body = body + "- File: \{filename}\n"
  }
  if content_type != "" {
    body = body + "- Content type: \{content_type}\n"
  }
  if browser_import_id != "" {
    body = body + "- Browser import id: \{browser_import_id}\n"
  }
  if note != "" {
    body = body + "\n## Note\n\n\{note}\n"
  }
  if content != "" {
    body = body + "\n## Content\n\n\{content}\n"
  }
  let data_url = json_string(payload, "data_url", default="")
  if data_url != "" {
    body = body +
      "\n## Attachment\n\nThe browser captured an attachment data URL next to this note as `.data-url.txt`.\n"
  }
  body
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
