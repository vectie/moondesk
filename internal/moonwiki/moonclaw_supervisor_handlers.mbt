///|
fn moonclaw_supervisor_id_allowed(value : String) -> Bool {
  if value == "" || value.length() > 128 {
    return false
  }
  for char in value {
    if !char.is_ascii_alphabetic() &&
      !char.is_ascii_digit() &&
      char != '.' &&
      char != '-' &&
      char != '_' &&
      char != ':' {
      return false
    }
  }
  true
}

///|
fn moonclaw_supervisor_command_allowed(action : String) -> Bool {
  [
    "message", "wake", "steer", "stop", "retry-resume", "delegate", "worker-steer",
    "worker-stop", "worker-retry-resume", "outcome-evidence",
  ].contains(action)
}

///|
fn moonclaw_supervisor_query_integer_allowed(
  value : String,
  max_length : Int,
) -> Bool {
  if value == "" || value.length() > max_length {
    return false
  }
  for char in value {
    if !char.is_ascii_digit() {
      return false
    }
  }
  true
}

///|
fn moonclaw_supervisor_runtime_path(
  supervisor_id : String,
  endpoint : String,
) -> String {
  "/v1/supervisors/" + supervisor_id + "/" + endpoint
}

///|
fn moonclaw_supervisor_events_runtime_path(
  supervisor_id : String,
  request_path : String,
) -> Result[String, String] {
  let fields : Array[(String, String)] = []
  match query_value(request_path, "after_cursor") {
    Some(value) => {
      let value = decode_query_value(value)
      guard moonclaw_supervisor_query_integer_allowed(value, 20) else {
        return Err("after_cursor must be a non-negative integer")
      }
      fields.push(("after_cursor", value))
    }
    None => ()
  }
  match query_value(request_path, "limit") {
    Some(value) => {
      let value = decode_query_value(value)
      guard moonclaw_supervisor_query_integer_allowed(value, 4) else {
        return Err(
          "limit must be a positive integer no longer than four digits",
        )
      }
      let limit = @string.parse_int(value) catch {
        _ => return Err("limit must be a positive integer")
      }
      guard limit > 0 && limit <= 1000 else {
        return Err("limit must be between 1 and 1000")
      }
      fields.push(("limit", limit.to_string()))
    }
    None => ()
  }
  let path = moonclaw_supervisor_runtime_path(supervisor_id, "events")
  if fields.is_empty() {
    Ok(path)
  } else {
    Ok(path + "?" + @desk.desktop_api_query(fields))
  }
}

///|
async fn moonclaw_supervisor_daemon(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Json? {
  let daemon = ensure_moonclaw_daemon_running(workspace_root, action="start")
  if !json_bool(daemon, "running", default=false) {
    send_api_error(
      conn,
      method_,
      503,
      "Service Unavailable",
      json_string(
        daemon,
        "message",
        default="MoonClaw supervisor runtime is not available",
      ),
    )
    return None
  }
  Some(daemon)
}

///|
async fn handle_moonclaw_supervisor_activation(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = match read_json_body(body) {
    Some(value) => value
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  guard moonclaw_supervisor_daemon(workspace_root, method_, conn)
    is Some(daemon) else {
    return
  }
  match moonclaw_post_json(daemon, "/v1/supervisors/activate", payload) {
    Ok(result) => send_json(conn, method_, result)
    Err(error) => send_api_error(conn, method_, 502, "Bad Gateway", error)
  }
}

///|
async fn handle_moonclaw_supervisor_command(
  workspace_root : String,
  supervisor_id : String,
  action : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  guard moonclaw_supervisor_id_allowed(supervisor_id) else {
    send_api_error(conn, method_, 400, "Bad Request", "Invalid supervisor id")
    return
  }
  guard moonclaw_supervisor_command_allowed(action) else {
    send_api_error(
      conn, method_, 404, "Not Found", "Unknown supervisor command",
    )
    return
  }
  let payload = match read_json_body(body) {
    Some(value) => value
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  guard moonclaw_supervisor_daemon(workspace_root, method_, conn)
    is Some(daemon) else {
    return
  }
  let path = moonclaw_supervisor_runtime_path(
    supervisor_id,
    "commands/" + action,
  )
  match moonclaw_post_json(daemon, path, payload) {
    Ok(result) => send_json(conn, method_, result)
    Err(error) => send_api_error(conn, method_, 502, "Bad Gateway", error)
  }
}

///|
async fn handle_moonclaw_supervisor_read(
  workspace_root : String,
  supervisor_id : String,
  endpoint : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  guard moonclaw_supervisor_id_allowed(supervisor_id) else {
    send_api_error(conn, method_, 400, "Bad Request", "Invalid supervisor id")
    return
  }
  let path = if endpoint == "events" {
    match moonclaw_supervisor_events_runtime_path(supervisor_id, request_path) {
      Ok(value) => value
      Err(error) => {
        send_api_error(conn, method_, 400, "Bad Request", error)
        return
      }
    }
  } else {
    moonclaw_supervisor_runtime_path(supervisor_id, "status")
  }
  guard moonclaw_supervisor_daemon(workspace_root, method_, conn)
    is Some(daemon) else {
    return
  }
  match moonclaw_get_json(daemon, path) {
    Ok(result) => send_json(conn, method_, result)
    Err(error) => send_api_error(conn, method_, 502, "Bad Gateway", error)
  }
}
