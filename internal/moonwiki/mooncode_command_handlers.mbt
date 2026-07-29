///|
async fn handle_mooncode_session_command(
  workspace_root : String,
  session_id : String,
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
  let session = moonclaw_runtime_session_by_id(workspace_root, session_id)
  if json_string(session, "id", default="") != session_id {
    send_api_error(conn, method_, 404, "Not Found", "Unknown MoonCode session")
    return
  }
  let command = match @mooncode.decode_command_submission(payload) {
    Ok(value) => value
    Err(message) => {
      send_api_error(conn, method_, 400, "Bad Request", message)
      return
    }
  }
  let now = @async.now().to_string()
  match submit_mooncode_turn(workspace_root, session, command, payload, now) {
    Ok(response) => send_json(conn, method_, response)
    Err(error) =>
      send_api_error(
        conn,
        method_,
        json_int(error, "code", default=500),
        json_string(error, "reason", default="Internal Server Error"),
        json_string(
          error,
          "message",
          default="Could not start MoonCode runtime",
        ),
      )
  }
}
