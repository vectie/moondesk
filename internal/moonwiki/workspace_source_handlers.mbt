///|
async fn handle_workspace_source(
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
  guard payload is { "expected_content": String(expected), .. } else {
    send_api_error(
      conn, method_, 400, "Bad Request", "Source save requires an explicit expected_content baseline",
    )
    return
  }
  match save_workspace_source(workspace, path, content, expected) {
    Ok(saved) => send_json(conn, method_, saved)
    Err(error) =>
      send_api_json_error(
        conn,
        method_,
        json_int(error, "code", default=400),
        json_string(error, "reason", default="Bad Request"),
        error,
      )
  }
}

///|
async fn save_workspace_source(
  workspace : @desk.DeskWorkspace,
  path : String,
  content : String,
  expected_content : String,
) -> Result[Json, Json] {
  let relative = decode_query_value(path)
  match
    @fsx.compare_and_write_confined_text(
      workspace.root_path,
      relative,
      expected_content,
      content,
    ) {
    Saved =>
      Ok({
        "ok": true,
        "workspace_id": workspace.id,
        "path": relative,
        "content": content,
      })
    Conflict(current) =>
      Err({
        "code": 409,
        "reason": "Conflict",
        "error": "File changed after this draft was opened",
        "path": relative,
        "current_content": current,
      })
    InvalidTarget =>
      Err({
        "code": 400,
        "reason": "Bad Request",
        "error": "Source path is missing or outside the selected workspace",
      })
    UnsupportedText =>
      Err({
        "code": 415,
        "reason": "Unsupported Media Type",
        "error": "Source editor supports UTF-8 text files only",
      })
    WriteFailed =>
      Err({
        "code": 500,
        "reason": "Internal Server Error",
        "error": "Could not save source file; the draft is preserved",
      })
  }
}
