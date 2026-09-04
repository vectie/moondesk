///|
async fn collect_search_hits(
  workspace : @desk.DeskWorkspace,
  relative : String,
  query_lower : String,
  hits : Array[Json],
  depth : Int,
  limit : Int,
  mode : String,
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
        mode,
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
      if mode == "code" && !is_code_search_path(child_relative) {
        continue
      }
      let text = source_semantics_read_bounded_file(child_absolute, 524_288) catch {
        _ => ""
      }
      match search_match_detail(mode, child_relative, text, query_lower) {
        None => ()
        Some(detail) =>
          hits.push({
            "workspace_id": workspace.id,
            "workspace_name": workspace.name,
            "path": entry.path,
            "title": entry.display_name,
            "kind": entry.kind,
            "source_layer": entry.source_layer,
            "snippet": detail,
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
  let mode = match
    decode_query_value(query_value(request_path, "mode").unwrap_or("files")) {
    "code" => "code"
    "semantic" => "semantic"
    "structure" => "structure"
    "issues" => "issues"
    _ => "files"
  }
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
    collect_search_hits(workspace, "", query_lower, hits, 0, 80, mode)
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
fn search_query_terms(query_lower : String) -> Array[String] {
  query_lower
  .replace_all(old="-", new=" ")
  .replace_all(old="_", new=" ")
  .split(" ")
  .map(term => term.trim().to_owned())
  .filter(term => term.length() > 1)
  .collect()
}

///|
fn search_structural_line(text : String, query_lower : String) -> String? {
  for line in text.split("\n") {
    let trimmed = line.trim().to_owned()
    let lower = trimmed.to_lower()
    let structural = trimmed.has_prefix("#") ||
      lower.has_prefix("fn ") ||
      lower.has_prefix("pub fn ") ||
      lower.has_prefix("struct ") ||
      lower.has_prefix("enum ") ||
      lower.has_prefix("type ") ||
      lower.has_prefix("class ") ||
      lower.has_prefix("interface ") ||
      lower.has_prefix("formula:") ||
      lower.contains("<table") ||
      lower.contains("<slide")
    if structural && lower.contains(query_lower) {
      return Some(trimmed)
    }
  }
  None
}

///|
fn search_issue_line(text : String, query_lower : String) -> String? {
  for line in text.split("\n") {
    let trimmed = line.trim().to_owned()
    let lower = trimmed.to_lower()
    let issue = lower.contains("warning") ||
      lower.contains("error") ||
      lower.contains("todo") ||
      lower.contains("fixme") ||
      lower.contains("needs review") ||
      lower.contains("open question") ||
      lower.contains("risk")
    if issue && (query_lower == "issues" || lower.contains(query_lower)) {
      return Some(trimmed)
    }
  }
  None
}

///|
fn search_match_detail(
  mode : String,
  path : String,
  text : String,
  query_lower : String,
) -> String? {
  let path_lower = path.to_lower()
  let body_lower = text.to_lower()
  match mode {
    "semantic" => {
      let terms = search_query_terms(query_lower)
      if terms.is_empty() {
        return None
      }
      let matched = terms.filter(term => {
        path_lower.contains(term) || body_lower.contains(term)
      })
      let required = if terms.length() <= 2 {
        1
      } else {
        (terms.length() + 1) / 2
      }
      if matched.length() < required {
        None
      } else {
        Some(
          "Meaning match · " +
          matched.join(", ") +
          " · " +
          search_snippet(text, matched[0], fallback=path),
        )
      }
    }
    "structure" =>
      match search_structural_line(text, query_lower) {
        Some(line) => Some("Structure match · " + line)
        None =>
          if path_lower.contains(query_lower) {
            Some("Structure path · " + path)
          } else {
            None
          }
      }
    "issues" =>
      match search_issue_line(text, query_lower) {
        Some(line) => Some("Issue match · " + line)
        None => None
      }
    "code" =>
      if path_lower.contains(query_lower) || body_lower.contains(query_lower) {
        Some(
          "Code match · " + search_snippet(text, query_lower, fallback=path),
        )
      } else {
        None
      }
    _ =>
      if path_lower.contains(query_lower) || body_lower.contains(query_lower) {
        Some(search_snippet(text, query_lower, fallback=path))
      } else {
        None
      }
  }
}

///|
fn is_code_search_path(path : String) -> Bool {
  let lower = path.to_lower()
  lower.has_suffix(".mbt") ||
  lower.has_suffix(".js") ||
  lower.has_suffix(".mjs") ||
  lower.has_suffix(".ts") ||
  lower.has_suffix(".tsx")
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
