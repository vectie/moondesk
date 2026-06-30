///|
async fn handle_workspace_markdown(
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
  let path = json_string(payload, "path", default="")
  let content = json_string(payload, "content", default="")
  match write_workspace_markdown(workspace, path, content) {
    Ok(clean_relative) =>
      send_json(conn, method_, {
        "ok": true,
        "workspace_id": workspace.id,
        "path": clean_relative,
      })
    Err(message) => send_api_error(conn, method_, 400, "Bad Request", message)
  }
}

///|
async fn write_workspace_markdown(
  workspace : @desk.DeskWorkspace,
  path : String,
  content : String,
) -> Result[String, String] {
  let relative = decode_query_value(path)
  match resolve_workspace_path(workspace.root_path, relative) {
    Some((absolute, clean_relative)) =>
      if !is_editable_markdown_path(clean_relative) {
        return Err("Markdown edits must target wiki/*.md or inbox/*.md paths")
      } else if @fs.exists(absolute) && is_directory(absolute) {
        return Err("Markdown edit target is a directory")
      } else {
        let parent = @pathx.dirname(absolute).to_owned()
        @fsx.make_directory(parent, recursive=true, exists_ok=true) catch {
          _ => return Err("Could not create markdown parent directory")
        }
        @fsx.write_to_file(absolute, content, create=0o644) catch {
          _ => return Err("Could not write markdown file")
        }
        Ok(clean_relative)
      }
    None => Err("Invalid markdown path")
  }
}

///|
fn is_editable_markdown_path(path : String) -> Bool {
  is_markdown_file_path(path) &&
  (path.has_prefix("wiki/") || path.has_prefix("inbox/"))
}

///|
fn is_markdown_file_path(path : String) -> Bool {
  path.has_suffix(".md") ||
  path.has_suffix(".markdown") ||
  path.has_suffix(".mbt.md")
}
