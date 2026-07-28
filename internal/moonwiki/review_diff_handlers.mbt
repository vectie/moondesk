///|
async fn handle_workspace_review_diff(
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
  let path = decode_query_value(query_value(request_path, "path").unwrap_or(""))
  match resolve_workspace_path(workspace.root_path, path) {
    Some((absolute, clean)) =>
      if @fs.exists(absolute) && !is_directory(absolute) {
        let current = @fs.read_file(absolute).text() catch { _ => "" }
        let base_path = review_base_path(workspace, clean)
        let base_text = match base_path {
          Some(path) =>
            @fs.read_file(@pathx.join(workspace.root_path, path)).text() catch {
              _ => ""
            }
          None => ""
        }
        let diff = @review.line_diff_summary(base_text, current)
        send_json(conn, method_, {
          "ok": true,
          "workspace_id": workspace.id,
          "path": clean,
          "base_path": base_path.unwrap_or(""),
          "comparison_path": clean,
          "added": diff.added(),
          "removed": diff.removed(),
          "changed": diff.changed(),
          "body": diff.body(),
        })
      } else {
        send_json(conn, method_, empty_review_diff(workspace.id, clean))
      }
    None => send_json(conn, method_, empty_review_diff(workspace.id, path))
  }
}

///|
fn empty_review_diff(workspace_id : String, path : String) -> Json {
  {
    "ok": false,
    "workspace_id": workspace_id,
    "path": path,
    "base_path": "",
    "comparison_path": path,
    "added": 0,
    "removed": 0,
    "changed": false,
    "body": "No textual file is selected for review.",
  }
}

///|
async fn review_base_path(
  workspace : @desk.DeskWorkspace,
  path : String,
) -> String? {
  if path.has_prefix("reviews/") {
    let candidate = "wiki/" + path["reviews/".length():].to_owned()
    if @fsx.exists(@pathx.join(workspace.root_path, candidate)) {
      return Some(candidate)
    }
  }
  if path.has_prefix("review/") {
    let candidate = "wiki/" + path["review/".length():].to_owned()
    if @fsx.exists(@pathx.join(workspace.root_path, candidate)) {
      return Some(candidate)
    }
  }
  for suffix in [".base", ".orig", ".previous"] {
    let candidate = path + suffix
    if @fsx.exists(@pathx.join(workspace.root_path, candidate)) {
      return Some(candidate)
    }
  }
  None
}
