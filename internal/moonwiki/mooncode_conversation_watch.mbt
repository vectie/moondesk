///|
async fn handle_mooncode_session_watch(
  workspace_root : String,
  session_id : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let cursor = @mooncode_core.mooncode_watch_cursor(
    query_value(request_path, "since_revision").unwrap_or("0"),
    query_value(request_path, "since_sequence").unwrap_or("0"),
  ) catch {
    _ => {
      send_api_error(
        conn, method_, 400, "Bad Request", "Invalid MoonCode watch cursor",
      )
      return
    }
  }
  let book_root = match
    moonclaw_runtime_session_book_root(workspace_root, session_id) {
    Ok(root) => root
    Err(error) => {
      let (code, status) = mooncode_session_scope_error_status(error)
      send_api_error(conn, method_, code, status, error)
      return
    }
  }
  let endpoint = @mooncode.moonclaw_native_watch_endpoint(
    session_id,
    book_root,
    cursor,
    wait_ms=@string.parse_int(
      query_value(request_path, "wait_ms").unwrap_or("15000"),
    ) catch {
      _ => 15000
    },
    poll_ms=@string.parse_int(
      query_value(request_path, "poll_ms").unwrap_or("100"),
    ) catch {
      _ => 100
    },
  )
  let response = match
    moonclaw_get_json(moonclaw_daemon_status(workspace_root), endpoint) {
    Ok(payload) =>
      mooncode_watch_desktop_response(workspace_root, session_id, payload)
    Err(error) => Err(error)
  }
  match response {
    Ok(payload) => send_json(conn, method_, payload)
    Err(error) => send_api_error(conn, method_, 502, "Bad Gateway", error)
  }
}

///|
/// Adapt the native session metadata only; the runtime owns cursor, terminal
/// status and conversation. Heartbeats pass through without fetching a session.
fn mooncode_watch_desktop_response(
  workspace_root : String,
  session_id : String,
  payload : Json,
) -> Result[Json, String] {
  if json_string(payload, "session_id", default="") != session_id {
    return Err("MoonCode watch session mismatch")
  }
  if !json_bool(payload, "changed", default=false) {
    return Ok(payload)
  }
  let record = json_object_field_or_empty(payload, "snapshot")
  if json_string(record, "session_id", default="") != session_id {
    return Err("MoonCode watch snapshot session mismatch")
  }
  let session = moonclaw_runtime_full_session_from_record(
    workspace_root, record,
  )
  Ok(
    mooncode_session_with_field(
      payload,
      "snapshot",
      compact_mooncode_session_command_response(workspace_root, session, {}),
    ),
  )
}
