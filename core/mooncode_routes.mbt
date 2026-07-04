///|
pub fn mooncode_sessions_url(workspace_id : String) -> String {
  if workspace_id == "" {
    "/api/mooncode/sessions"
  } else {
    "/api/mooncode/sessions?workspace=\{url_component(workspace_id)}"
  }
}

///|
pub fn mooncode_session_url(session_id : String) -> String {
  "/api/mooncode/sessions/\{url_component(session_id)}"
}

///|
pub fn mooncode_session_stream_url(session_id : String, since : Int) -> String {
  mooncode_session_url(session_id) +
  "/stream?format=jsonl&since=\{since}&live=true&timeout_ms=1000&poll_ms=100"
}

///|
pub fn mooncode_session_stream_state_url(session_id : String) -> String {
  mooncode_session_url(session_id) + "/stream-state"
}

///|
pub fn mooncode_session_commands_url(session_id : String) -> String {
  mooncode_session_url(session_id) + "/commands"
}

///|
pub fn mooncode_session_runtime_service_url(session_id : String) -> String {
  mooncode_session_url(session_id) + "/runtime-service"
}

///|
pub fn url_component(value : String) -> String {
  let pieces : Array[String] = []
  for byte in @encoding/utf8.encode(value) {
    if url_component_unreserved_byte(byte) {
      pieces.push(byte.to_char().to_string())
    } else {
      pieces.push(percent_encoded_byte(byte))
    }
  }
  pieces.join("")
}

///|
fn url_component_unreserved_byte(byte : Byte) -> Bool {
  (byte >= b'a' && byte <= b'z') ||
  (byte >= b'A' && byte <= b'Z') ||
  (byte >= b'0' && byte <= b'9') ||
  byte == b'-' ||
  byte == b'_' ||
  byte == b'.' ||
  byte == b'!' ||
  byte == b'~' ||
  byte == b'*' ||
  byte == b'\'' ||
  byte == b'(' ||
  byte == b')'
}

///|
fn percent_encoded_byte(byte : Byte) -> String {
  let value = byte.to_int()
  "%" + percent_hex_digit(value / 16) + percent_hex_digit(value % 16)
}

///|
fn percent_hex_digit(value : Int) -> String {
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
    _ => "F"
  }
}
