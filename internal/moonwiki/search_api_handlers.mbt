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
async fn handle_search(
  workspace_root : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let evidence_contract = query_value(request_path, "contract")
    is Some("pages-search.v1")
  let query = decode_query_value(
      query_value(request_path, "query").unwrap_or(""),
    )
    .trim()
    .to_owned()
  if query == "" {
    send_search_response(
      conn,
      method_,
      evidence_contract,
      [],
      query,
      "",
      ok=true,
      status="ready",
      message="Search completed",
    )
    return
  }
  let workspace_filter = decode_query_value(
      query_value(request_path, "workspace").unwrap_or(""),
    )
    .trim()
    .to_owned()
  let query_lower = query.to_lower()
  let discovered = discover_workspaces(workspace_root)
  let selected : Array[@desk.DeskWorkspace] = []
  for workspace in discovered {
    if workspace_filter == "" || workspace_filter == workspace.id {
      selected.push(workspace)
    }
  }
  if workspace_filter != "" && selected.is_empty() && evidence_contract {
    send_search_response(
      conn,
      method_,
      true,
      [],
      query,
      workspace_filter,
      ok=false,
      status="workspace-not-found",
      message="The selected book is no longer available",
    )
    return
  }
  if evidence_contract {
    for workspace in selected {
      if !search_scope_available(workspace.root_path) {
        send_search_response(
          conn,
          method_,
          true,
          [],
          query,
          workspace_filter,
          ok=false,
          status="scope-unavailable",
          message="The selected search scope cannot be read",
        )
        return
      }
    }
  }
  let hits : Array[Json] = []
  for workspace in selected {
    collect_search_hits(workspace, "", query_lower, hits, 0, 80)
    if hits.length() >= 80 {
      break
    }
  }
  send_search_response(
    conn,
    method_,
    evidence_contract,
    hits,
    query,
    workspace_filter,
    ok=true,
    status="ready",
    message="Search completed",
  )
}

///|
async fn search_scope_available(path : String) -> Bool {
  if !is_directory(path) {
    return false
  }
  let dir = @fs.opendir(path) catch { _ => return false }
  defer dir.close()
  ignore(dir.read_all(include_hidden=true) catch { _ => return false })
  true
}

///|
async fn send_search_response(
  conn : @http.ServerConnection,
  method_ : @http.RequestMethod,
  evidence_contract : Bool,
  hits : Array[Json],
  query : String,
  workspace_id : String,
  ok~ : Bool,
  status~ : String,
  message~ : String,
) -> Unit {
  if !evidence_contract {
    send_json(conn, method_, Json::array(hits))
    return
  }
  send_json(
    conn,
    method_,
    api_contract_response(
      {
        "contract": "pages-search.v1",
        "query": query,
        "workspace_id": workspace_id,
        "hits": Json::array(hits),
      },
      ok~,
      status~,
      message~,
    ),
  )
}

///|
fn is_searchable_entry(kind : @desk.EntryKind) -> Bool {
  match kind {
    Markdown | Html | Json | Text | Unknown => true
    _ => false
  }
}

///|
fn search_snippet(
  text : String,
  query_lower : String,
  fallback~ : String,
) -> String {
  let trimmed = text.trim().to_owned()
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
  trimmed[start:start + take].replace_all(old="\n", new=" ").to_owned()
}

///|
async fn handle_town_state(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let root = workspace_context(workspace_root).suite_root
  let state_path = @pathx.join(moontown_product_root(root), "town.json")
  if @fs.exists(state_path) {
    let state = read_json_file_or_object(state_path)
    send_json(
      conn,
      method_,
      api_contract_response(
        state,
        ok=true,
        status="ready",
        message="MoonTown state is available",
      ),
    )
  } else {
    let descriptor = town_service_descriptor(root, "daemon")
    send_json(
      conn,
      method_,
      api_contract_response(
        api_service_fields(
          { "state_path": state_path, "state": Json::object({}) },
          service_configured=json_bool(descriptor, "configured", default=false),
          service_config_path=json_string(descriptor, "config_path", default=""),
          service_command=json_string(descriptor, "display", default=""),
          service_path=moontown_product_root(root),
        ),
        ok=false,
        status="state_missing",
        message="MoonTown state has not been created yet",
        next_action=if json_bool(descriptor, "configured", default=false) {
          "start_moontown_daemon"
        } else {
          "configure_moontown_service"
        },
      ),
    )
  }
}
