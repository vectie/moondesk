///|
pub fn mooncode_sessions_url(workspace_id : String) -> String {
  if workspace_id == "" {
    desktop_api_url(["api", "mooncode", "sessions"])
  } else {
    desktop_api_url(["api", "mooncode", "sessions"], query=[
      ("workspace", workspace_id),
    ])
  }
}

///|
pub fn mooncode_session_listing_url(workspace_id : String) -> String {
  if workspace_id == "" {
    desktop_api_url(["api", "mooncode", "sessions"], query=[
      ("format", "listing"),
    ])
  } else {
    desktop_api_url(["api", "mooncode", "sessions"], query=[
      ("workspace", workspace_id),
      ("format", "listing"),
    ])
  }
}

///|
pub fn mooncode_archived_session_listing_url() -> String {
  desktop_api_url(["api", "mooncode", "sessions"], query=[
    ("format", "listing"),
    ("scope", "archived"),
  ])
}

///|
pub fn mooncode_session_url(session_id : String) -> String {
  desktop_api_url(["api", "mooncode", "sessions", session_id])
}

///|
pub fn mooncode_session_media_url(
  session_id : String,
  command_id : String,
  image_index : Int32,
) -> String {
  desktop_api_url([
    "api",
    "mooncode",
    "sessions",
    session_id,
    "media",
    command_id,
    image_index.to_string(),
  ])
}

///|
pub fn mooncode_work_continuations_url() -> String {
  desktop_api_url(["api", "mooncode", "work-handoff", "continuations"])
}

///|
pub fn mooncode_work_human_revisions_url() -> String {
  desktop_api_url(["api", "mooncode", "work-handoff", "human-revisions"])
}

///|
/// Keep the established URLSearchParams form encoding for exact handoff links.
pub fn mooncode_work_handoff_url(
  session_id : String,
  command_id : String,
  book_root : String,
) -> String {
  let fields = [
    ("session_id", session_id),
    ("command_id", command_id),
    ("book_root", book_root),
    ("include_session", "true"),
    ("include_context", "true"),
  ]
  desktop_api_url(["api", "mooncode", "work-handoff"]) +
  "?" +
  fields
  .map(field => {
    mooncode_handoff_query_component(field.0) +
    "=" +
    mooncode_handoff_query_component(field.1)
  })
  .join("&")
}

///|
fn mooncode_handoff_query_component(value : String) -> String {
  let encoded : Array[String] = []
  for byte in @encoding/utf8.encode(value) {
    if byte == b' ' {
      encoded.push("+")
    } else if (byte >= b'A' && byte <= b'Z') ||
      (byte >= b'a' && byte <= b'z') ||
      (byte >= b'0' && byte <= b'9') ||
      [b'*', b'-', b'.', b'_'].contains(byte) {
      encoded.push(byte.to_char().to_string())
    } else {
      encoded.push(percent_encoded_byte(byte))
    }
  }
  encoded.join("")
}

///|
pub fn mooncode_session_chat_url(
  session_id : String,
  since_revision : Int32,
) -> String {
  if since_revision > 0 {
    desktop_api_url(["api", "mooncode", "sessions", session_id], query=[
      ("format", "chat"),
      ("since_revision", since_revision.to_string()),
    ])
  } else {
    desktop_api_url(["api", "mooncode", "sessions", session_id], query=[
      ("format", "chat"),
    ])
  }
}

///|
pub fn mooncode_session_watch_url(
  session_id : String,
  since_revision : String,
  since_sequence : String,
) -> String {
  desktop_api_url(["api", "mooncode", "sessions", session_id, "watch"], query=[
    ("since_revision", since_revision),
    ("since_sequence", since_sequence),
    ("wait_ms", "15000"),
    ("poll_ms", "100"),
  ])
}

///|
pub fn mooncode_session_commands_url(session_id : String) -> String {
  mooncode_session_url(session_id) + "/commands"
}

///|
pub fn mooncode_session_lifecycle_url(session_id : String) -> String {
  mooncode_session_url(session_id) + "/lifecycle"
}

///|
pub fn mooncode_session_runtime_service_url(session_id : String) -> String {
  mooncode_session_url(session_id) + "/runtime-service"
}

///|
pub fn mooncode_sandbox_promotion_url() -> String {
  desktop_api_url(["api", "mooncode", "execution-sandbox", "promote"])
}

///|
/// Read a stored return receipt without retrying execution or promotion.
pub fn mooncode_sandbox_promotion_receipt_url() -> String {
  desktop_api_url(["api", "mooncode", "execution-sandbox", "promotion-receipt"])
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
fn percent_hex_digit(value : Int32) -> String {
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
