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
    @pathx.dirname(absolute).to_owned()
  }
  @process.run("xdg-open", [target]) catch {
    _ => mac
  }
}
