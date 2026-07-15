///|
fn mooncode_session_lifecycle_action_error(payload : Json) -> String? {
  let action = json_string(payload, "action", default="")
  if action != "rename" &&
    action != "archive" &&
    action != "restore" &&
    action != "delete" {
    return Some("Unsupported MoonCode session lifecycle action")
  }
  if action == "rename" {
    let title = json_string(payload, "title", default="").trim().to_owned()
    if title == "" {
      return Some("A non-empty session title is required")
    }
    if title.length() > 160 {
      return Some("Session titles may not exceed 160 characters")
    }
  }
  None
}

///|
fn mooncode_session_lifecycle_native_body(
  payload : Json,
  workspace_root : String,
) -> Json {
  mooncode_session_with_field(payload, "book_root", workspace_root.to_json())
}

///|
fn mooncode_session_lifecycle_error_code(error : String) -> Int {
  if error.contains(" returned 409:") {
    409
  } else if error.contains(" returned 404:") {
    404
  } else {
    502
  }
}

///|
async fn handle_mooncode_session_lifecycle(
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
  match mooncode_session_lifecycle_action_error(payload) {
    Some(error) => {
      send_api_error(conn, method_, 400, "Bad Request", error)
      return
    }
    None => ()
  }
  let daemon = ensure_moonclaw_daemon_running(
    workspace_root,
    action="manage-session",
  )
  if !json_bool(daemon, "running", default=false) {
    send_api_error(
      conn,
      method_,
      503,
      "Service Unavailable",
      json_string(
        daemon,
        "message",
        default="MoonClaw session management is unavailable",
      ),
    )
    return
  }
  let endpoint = @mooncode.moonclaw_native_session_lifecycle_endpoint(
    session_id,
  )
  match
    moonclaw_post_json(
      daemon,
      endpoint,
      mooncode_session_lifecycle_native_body(payload, workspace_root),
    ) {
    Ok(result) => send_json(conn, method_, result)
    Err(error) =>
      send_api_error(
        conn,
        method_,
        mooncode_session_lifecycle_error_code(error),
        if error.contains(" returned 409:") {
          "Conflict"
        } else if error.contains(" returned 404:") {
          "Not Found"
        } else {
          "Bad Gateway"
        },
        error,
      )
  }
}
