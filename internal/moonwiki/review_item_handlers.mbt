///|
async fn handle_review_items(
  workspace_root : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let requested_workspace = query_value(request_path, "workspace")
  send_json(
    conn,
    method_,
    Json::array(collect_review_items(workspace_root, requested_workspace, 120)),
  )
}

///|
async fn handle_review_item_decision(
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
  match write_review_item_decision(workspace_root, payload) {
    Ok(receipt) => send_json(conn, method_, receipt)
    Err(message) => send_api_error(conn, method_, 400, "Bad Request", message)
  }
}

///|
async fn write_review_item_decision(
  workspace_root : String,
  payload : Json,
) -> Result[Json, String] {
  let workspace_id = json_string(payload, "workspace_id", default="")
  let path = decode_query_value(json_string(payload, "path", default=""))
  let decision = json_string(payload, "decision", default="").trim().to_owned()
  let note = json_string(payload, "note", default="").trim().to_owned()
  if decision != "accepted" && decision != "rejected" {
    return Err("Review decision must be accepted or rejected")
  }
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(workspace) => workspace
    None => return Err("Unknown workspace")
  }
  let (_, clean_source) = match
    resolve_workspace_path(workspace.root_path, path) {
    Some(pair) => pair
    None => return Err("Invalid review item path")
  }
  if clean_source == "" {
    return Err("Review item path is required")
  }
  let source_path = @pathx.join(workspace.root_path, clean_source)
  if !@fs.exists(source_path) || is_directory(source_path) {
    return Err("Review item must target an existing file")
  }
  let id = @desk.stable_id(
    "review-decision",
    workspace.id + ":" + clean_source + ":" + decision,
  )
  let receipt_relative = "wiki/reviews/decisions/\{id}.json"
  let receipt_path = @pathx.join(workspace.root_path, receipt_relative)
  let now = @async.now().to_string()
  let receipt : Json = {
    "id": id,
    "kind": "wiki-review-decision",
    "workspace_id": workspace.id,
    "source_path": clean_source,
    "decision": decision,
    "status": decision,
    "note": note,
    "created_at": now,
    "receipt_path": receipt_relative,
  }
  @fsx.make_directory(
    @pathx.dirname(receipt_path),
    recursive=true,
    exists_ok=true,
  ) catch {
    _ => return Err("Could not create review decision directory")
  }
  @fsx.write_to_file(receipt_path, receipt.stringify(indent=2) + "\n") catch {
    _ => return Err("Could not write review decision receipt")
  }
  Ok(receipt)
}

///|
async fn count_review_items(root : String) -> Int {
  collect_review_items(root, None, 10000).length()
}

///|
async fn collect_review_items(
  workspace_root : String,
  requested_workspace : String?,
  limit : Int,
) -> Array[Json] {
  let items : Array[Json] = []
  for workspace in discover_workspaces(workspace_root) {
    match requested_workspace {
      Some(id) if id != workspace.id => continue
      _ => ()
    }
    let decided_paths = review_decided_source_paths(workspace.root_path)
    for
      review_root in [
        "wiki/reviews", "wiki/review", "reviews", "review", "book/reviews", "book/review",
        "book/evidence/browser",
      ] {
      collect_review_directory(
        workspace, review_root, decided_paths, items, limit,
      )
      if items.length() >= limit {
        return items
      }
    }
  }
  for
    event in collect_town_event_records(
      workspace_context(workspace_root).suite_root,
      limit,
    ) {
    if items.length() >= limit {
      break
    }
    let severity = json_string(event, "severity", default="")
    if severity == "review" || severity == "failure" {
      items.push({
        "id": json_string(
          event,
          "id",
          default=@desk.stable_id("review", event.stringify()),
        ),
        "workspace_id": "",
        "path": json_string(event, "path", default=""),
        "title": json_string(event, "title", default="Town event"),
        "kind": json_string(event, "kind", default="event"),
        "status": severity,
        "detail": json_string(event, "detail", default=""),
      })
    }
  }
  items
}

///|
async fn collect_review_directory(
  workspace : @desk.DeskWorkspace,
  relative : String,
  decided_paths : Array[String],
  items : Array[Json],
  limit : Int,
) -> Unit {
  if items.length() >= limit {
    return
  }
  let root = @pathx.join(workspace.root_path, relative)
  if !is_directory(root) {
    return
  }
  for name in read_directory_names(root, include_hidden=false) {
    if items.length() >= limit {
      break
    }
    let path = relative + "/" + name
    let absolute = @pathx.join(workspace.root_path, path)
    if is_directory(absolute) {
      if !review_path_is_completed(path) {
        collect_review_directory(workspace, path, decided_paths, items, limit)
      }
    } else if review_path_is_completed(path) || decided_paths.contains(path) {
      continue
    } else {
      items.push({
        "id": @desk.stable_id("review", workspace.id + ":" + path),
        "workspace_id": workspace.id,
        "path": path,
        "title": @desk.display_name(path),
        "kind": if path.has_suffix(".json") {
          "json"
        } else {
          "file"
        },
        "status": if path.to_lower().contains("fail") {
          "failure"
        } else {
          "review"
        },
        "detail": path,
      })
    }
  }
}

///|
async fn review_decided_source_paths(book_root : String) -> Array[String] {
  let paths : Array[String] = []
  let root = @pathx.join(book_root, "wiki/reviews/decisions")
  if !is_directory(root) {
    return paths
  }
  for name in read_directory_names(root, include_hidden=false) {
    let absolute = @pathx.join(root, name)
    if is_directory(absolute) {
      continue
    }
    let source_path = json_string(
      read_json_file_or_object(absolute),
      "source_path",
      default="",
    )
    if source_path != "" && !paths.contains(source_path) {
      paths.push(source_path)
    }
  }
  paths
}

///|
fn review_path_is_completed(path : String) -> Bool {
  let value = path.to_lower()
  value.contains("/decisions/") ||
  value.contains("approved") ||
  value.contains("accepted") ||
  value.contains("rejected")
}
