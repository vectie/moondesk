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
