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
  let action = @mooncode.command_action(payload)
  if !@mooncode.command_is_supported(action) {
    send_api_error(
      conn,
      method_,
      400,
      "Bad Request",
      "Unsupported MoonCode command: \{action}",
    )
    return
  }
  let context_path = @mooncode.command_context_path(payload)
  let message = @mooncode.command_message(action, payload)
  let now = @async.now().to_string()
  match
    submit_mooncode_turn(
      workspace_root, session, payload, action, message, now, context_path,
    ) {
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
