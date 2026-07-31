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
          [workspace_file_entry(workspace, clean_relative, absolute)].to_json(),
        )
      } else if is_virtual_moonbook_section(workspace, clean_relative) {
        send_json(conn, method_, ([] : Array[@desk.DeskFileEntry]).to_json())
      } else {
        send_api_error(conn, method_, 404, "Not Found", "Entry path not found")
      }
    None => send_api_error(conn, method_, 400, "Bad Request", "Invalid path")
  }
}

///|
async fn handle_workspace_document(
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
  if relative == "" {
    send_api_error(conn, method_, 400, "Bad Request", "Invalid path")
    return
  }
  let (absolute, clean_relative) = match
    resolve_workspace_path(workspace.root_path, relative) {
    Some(resolved) => resolved
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid path")
      return
    }
  }
  let kind = @fs.kind(absolute, follow_symlink=false) catch {
    _ => {
      send_api_error(conn, method_, 404, "Not Found", "Document not found")
      return
    }
  }
  if kind != Regular {
    send_api_error(conn, method_, 404, "Not Found", "Document not found")
    return
  }
  let file = @fs.open(absolute, mode=ReadOnly) catch {
    _ => {
      send_api_error(conn, method_, 404, "Not Found", "Document not found")
      return
    }
  }
  defer file.close()
  let size = file.size() catch {
    _ => {
      send_api_error(conn, method_, 404, "Not Found", "Document not found")
      return
    }
  }
  if size > moonedit_max_document_bytes.to_int64() {
    send_api_error(
      conn, method_, 413, "Content Too Large", "Document is too large",
    )
    return
  }
  let bytes = file.read_exactly(size.to_int()) catch {
    _ => {
      send_api_error(
        conn, method_, 404, "Not Found", "Document could not be read",
      )
      return
    }
  }
  match moonedit_decode_document(bytes) {
    Err(Oversized(_, _)) =>
      send_api_error(
        conn, method_, 413, "Content Too Large", "Document is too large",
      )
    Err(InvalidUtf8) | Err(BinaryControl(_)) =>
      send_api_error(
        conn, method_, 415, "Unsupported Media Type", "Document is not plain text",
      )
    Ok(document) =>
      send_json(conn, method_, {
        "workspace_id": workspace.id,
        "path": clean_relative,
        "provider_id": "moonedit.plain-text.v1",
        "media_type": "text/plain;charset=utf-8",
        "content": document.text,
        "revision": document.revision,
        "writable": false,
        "warnings": ([] : Array[Json]),
      })
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
        let entry = workspace_file_entry(workspace, clean_relative, absolute)
        send_json(conn, method_, @desk.preview(entry, body~).to_json())
      } else if @fs.exists(absolute) {
        let entry = workspace_file_entry(workspace, clean_relative, absolute)
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
      } else if moonbook_section_for_path(clean_relative) is Some(section) &&
        workspace.kind is MoonBook {
        let entry = moonbook_section_entry(workspace, section, absolute)
        send_json(
          conn,
          method_,
          @desk.preview(entry, body="", warnings=[
            "Virtual MoonBook section has no files yet.",
          ]).to_json(),
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
        send_isolated_preview_file(conn, method_, absolute, 200, "OK")
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
