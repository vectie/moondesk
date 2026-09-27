///|
async fn handle_mooncode_session_media(
  workspace_root : String,
  session_id : String,
  command_id : String,
  index : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  if !mooncode_media_safe_segment(session_id) ||
    !mooncode_media_safe_segment(command_id) ||
    !mooncode_media_safe_index(index) {
    send_api_error(conn, method_, 404, "Not Found", "Unknown Code image")
    return
  }
  let book_root = match
    moonclaw_runtime_session_book_root(workspace_root, session_id) {
    Ok(value) => value
    Err(error) => {
      let (code, reason) = mooncode_session_scope_error_status(error)
      send_api_error(conn, method_, code, reason, error)
      return
    }
  }
  let daemon = ensure_moonclaw_daemon_running(
    workspace_root,
    action="read-session-media",
  )
  let config = match moonclaw_load_control_config(daemon) {
    Ok(value) => value
    Err(error) => {
      send_api_error(conn, method_, 503, "Service Unavailable", error)
      return
    }
  }
  let endpoint = "/v1/code/sessions/\{session_id}/media/\{command_id}/\{index}?book_root=\{encode_query_value(book_root)}"
  let media = match
    moonclaw_get_media_with_control_config(daemon, endpoint, config) {
    Ok(value) => value
    Err(error) => {
      send_api_error(conn, method_, 502, "Bad Gateway", error)
      return
    }
  }
  let media_type = json_string(media, "media_type", default="")
  let encoded = json_string(media, "data_base64", default="")
  if !["image/png", "image/jpeg", "image/webp"].contains(media_type) ||
    encoded == "" ||
    encoded.length() > 11 * 1024 * 1024 {
    send_api_error(conn, method_, 502, "Bad Gateway", "Invalid Code image")
    return
  }
  let bytes = @base64.decode(encoded) catch {
    _ => {
      send_api_error(conn, method_, 502, "Bad Gateway", "Invalid Code image")
      return
    }
  }
  if bytes.length() == 0 ||
    bytes.length() > 8 * 1024 * 1024 ||
    @base64.encode(bytes) != encoded {
    send_api_error(conn, method_, 502, "Bad Gateway", "Invalid Code image")
    return
  }
  conn.send_response(200, "OK", extra_headers={
    "content-type": media_type,
    "cache-control": "private, no-store",
    "x-content-type-options": "nosniff",
  })
  if method_ is Get {
    conn.write(bytes)
  }
  conn.end_response()
}

///|
fn mooncode_media_safe_segment(value : String) -> Bool {
  if value == "" || value.length() > 160 {
    return false
  }
  for ch in value {
    if !query_safe_char(ch) {
      return false
    }
  }
  true
}

///|
fn mooncode_media_safe_index(value : String) -> Bool {
  let index = @string.parse_int(value) catch { _ => -1 }
  index >= 0 && index < 12 && index.to_string() == value
}
