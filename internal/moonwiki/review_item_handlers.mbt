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
    for review_root in ["reviews", "review", "book/reviews", "book/review"] {
      collect_review_directory(workspace, review_root, items, limit)
      if items.length() >= limit {
        return items
      }
    }
  }
  for
    event in collect_town_event_records(@pathx.normalize(workspace_root), limit) {
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
      collect_review_directory(workspace, path, items, limit)
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
