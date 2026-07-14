///|
pub fn protocol_version() -> String {
  @mooncode_core.protocol_version()
}

///|
pub fn conversation_contract_id() -> String {
  @mooncode_core.conversation_contract_id()
}

///|
pub fn conversation_kind() -> String {
  @mooncode_core.conversation_kind()
}

///|
pub fn conversation_watch_contract_id() -> String {
  @mooncode_core.conversation_watch_contract_id()
}

///|
pub fn conversation_watch_response(
  session_id~ : String,
  revision~ : Int,
  next_sequence~ : Int,
  changed~ : Bool,
  heartbeat~ : Bool,
  terminal~ : Bool,
  retry_after_ms~ : Int,
  snapshot~ : Json,
) -> Json {
  @mooncode_core.conversation_watch_response(
    session_id~,
    revision~,
    next_sequence~,
    changed~,
    heartbeat~,
    terminal~,
    retry_after_ms~,
    snapshot~,
  )
}

///|
pub fn desktop_capabilities_endpoint() -> String {
  "/api/mooncode/capabilities"
}

///|
pub fn desktop_status_endpoint() -> String {
  "/api/mooncode/status"
}

///|
pub fn desktop_sessions_endpoint() -> String {
  "/api/mooncode/sessions"
}

///|
pub fn desktop_session_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>"
}

///|
pub fn desktop_session_watch_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/watch?since_revision=<revision>&since_sequence=<sequence>"
}

///|
pub fn desktop_session_commands_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/commands"
}

///|
fn desktop_route_contract(path : String, methods : Array[String]) -> Json {
  { "path": path, "methods": string_array_json(methods) }
}

///|
pub fn desktop_projection_route_contracts() -> Array[Json] {
  [
    desktop_route_contract(desktop_status_endpoint(), ["GET", "HEAD"]),
    desktop_route_contract(desktop_capabilities_endpoint(), ["GET", "HEAD"]),
    desktop_route_contract(desktop_sessions_endpoint(), ["GET", "HEAD", "POST"]),
    desktop_route_contract(desktop_session_endpoint(), ["GET", "HEAD"]),
    desktop_route_contract(desktop_session_watch_endpoint(), ["GET", "HEAD"]),
    desktop_route_contract(desktop_session_commands_endpoint(), ["POST"]),
  ]
}

///|
pub fn moonclaw_native_turn_endpoint(session_id : String) -> String {
  @mooncode_core.native_session_turns_endpoint(session_id)
}

///|
pub fn moonclaw_native_session_listing_endpoint(book_root : String) -> String {
  @mooncode_core.native_session_listing_endpoint(book_root)
}

///|
pub fn moonclaw_native_session_show_endpoint(
  session_id : String,
  book_root : String,
) -> String {
  @mooncode_core.native_session_show_endpoint(session_id, book_root)
}

///|
pub fn moonclaw_native_stream_endpoint(
  session_id : String,
  book_root : String,
  format : String,
  since : Int,
  wait_ms? : Int = 0,
  poll_ms? : Int = 100,
) -> String {
  @mooncode_core.native_stream_endpoint(
    session_id,
    book_root,
    format,
    since,
    wait_ms~,
    poll_ms~,
  )
}

///|
fn supported_engine_endpoints() -> Array[String] {
  let endpoints : Array[String] = ["/v1/models"]
  for endpoint in @mooncode_core.native_capability_required_endpoints() {
    endpoints.push(endpoint)
  }
  for contract in desktop_projection_route_contracts() {
    let path = json_string(contract, "path", default="")
    if path != "" {
      endpoints.push(path)
    }
  }
  endpoints
}
