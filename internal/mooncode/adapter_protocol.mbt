///|
pub fn protocol_version() -> String {
  @mooncode_core.protocol_version()
}

///|
pub fn conversation_contract_id() -> String {
  let surface = adapter_capability_surface(@mooncode_core.mooncode_capability())
  json_string(
    adapter_surface_field(surface, "conversation_contract"),
    "contract_id",
    default="",
  )
}

///|
pub fn conversation_kind() -> String {
  let surface = adapter_capability_surface(@mooncode_core.mooncode_capability())
  json_string(
    adapter_surface_field(surface, "conversation_contract"),
    "conversation_kind",
    default="",
  )
}

///|
pub fn conversation_turn_kind() -> String {
  let surface = adapter_capability_surface(@mooncode_core.mooncode_capability())
  json_string(
    adapter_surface_field(surface, "conversation_contract"),
    "turn_kind",
    default="",
  )
}

///|
pub fn conversation_watch_contract_id() -> String {
  let surface = adapter_capability_surface(@mooncode_core.mooncode_capability())
  json_string(
    adapter_surface_field(surface, "conversation_watch_write_contract"),
    "contract_id",
    default="",
  )
}

///|
pub fn conversation_watch_response_for_cursor(
  session_id~ : String,
  cursor~ : @mooncode_core.MoonCodeWatchCursor,
  changed~ : Bool,
  heartbeat~ : Bool,
  terminal~ : Bool,
  retry_after_ms~ : Int,
  snapshot~ : Json,
) -> Json {
  @mooncode_core.conversation_watch_response_for_cursor(
    session_id~,
    cursor~,
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
pub fn desktop_session_lifecycle_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/lifecycle"
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
    desktop_route_contract(desktop_session_lifecycle_endpoint(), ["POST"]),
  ]
}

///|
fn adapter_hex_digit(value : Int) -> String {
  match value {
    0 => "0"
    1 => "1"
    2 => "2"
    3 => "3"
    4 => "4"
    5 => "5"
    6 => "6"
    7 => "7"
    8 => "8"
    9 => "9"
    10 => "A"
    11 => "B"
    12 => "C"
    13 => "D"
    14 => "E"
    15 => "F"
    _ => abort("hex digit must be in 0..15")
  }
}

///|
fn adapter_endpoint_component(value : String) -> String {
  let pieces : Array[String] = []
  for byte in @encoding/utf8.encode(value) {
    if (byte >= b'a' && byte <= b'z') ||
      (byte >= b'A' && byte <= b'Z') ||
      (byte >= b'0' && byte <= b'9') ||
      byte == b'-' ||
      byte == b'_' ||
      byte == b'.' ||
      byte == b'~' {
      pieces.push(byte.to_char().to_string())
    } else {
      let number = byte.to_int()
      pieces.push(
        "%" + adapter_hex_digit(number / 16) + adapter_hex_digit(number % 16),
      )
    }
  }
  pieces.join("")
}

///|
fn adapter_native_endpoint(
  segments : Array[String],
  query? : Array[(String, String)] = [],
) -> String {
  let encoded = segments.map(adapter_endpoint_component)
  let path = "/" + encoded.join("/")
  if query.length() == 0 {
    return path
  }
  let fields = query.map(field => {
    let (key, value) = field
    adapter_endpoint_component(key) + "=" + adapter_endpoint_component(value)
  })
  path + "?" + fields.join("&")
}

///|
pub fn moonclaw_native_turn_endpoint(session_id : String) -> String {
  adapter_native_endpoint(["v1", "code", "sessions", session_id, "turns"])
}

///|
pub fn moonclaw_native_session_listing_endpoint(book_root : String) -> String {
  adapter_native_endpoint(["v1", "code", "sessions"], query=[
    ("book_root", book_root),
    ("format", "listing"),
  ])
}

///|
pub fn moonclaw_native_archived_session_listing_endpoint(
  book_root : String,
) -> String {
  adapter_native_endpoint(["v1", "code", "sessions"], query=[
    ("book_root", book_root),
    ("format", "listing"),
    ("scope", "archived"),
  ])
}

///|
pub fn moonclaw_native_session_lifecycle_endpoint(
  session_id : String,
) -> String {
  adapter_native_endpoint(["v1", "code", "sessions", session_id, "lifecycle"])
}

///|
pub fn moonclaw_native_session_show_endpoint(
  session_id : String,
  book_root : String,
) -> String {
  adapter_native_endpoint(["v1", "code", "sessions", session_id], query=[
    ("book_root", book_root),
  ])
}

///|
pub fn moonclaw_native_stream_endpoint(
  session_id : String,
  book_root : String,
  format : String,
  cursor : @mooncode_core.MoonCodeWatchCursor,
  wait_ms? : Int = 0,
  poll_ms? : Int = 100,
) -> String {
  adapter_native_endpoint(["v1", "code", "sessions", session_id, "stream"], query=[
    ("book_root", book_root),
    ("format", format),
    ("since", cursor.sequence()),
    ("wait_ms", wait_ms.to_string()),
    ("poll_ms", poll_ms.to_string()),
  ])
}

///|
fn supported_engine_endpoints() -> Array[String] {
  let endpoints : Array[String] = ["/v1/models"]
  let surface = adapter_capability_surface(@mooncode_core.mooncode_capability())
  for endpoint in adapter_surface_strings(surface, "required_endpoints") {
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
