///|
pub fn session_listing_row(session : Json, updated_at_ms : Json) -> Json {
  let id = json_string(session, "id", default="")
  {
    "id": id,
    "title": session_listing_title(session),
    "updated_at": json_string(session, "updated_at", default=""),
    "updated_at_ms": updated_at_ms,
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "workspace_root": session_listing_workspace_root(session),
    "status": json_string(session, "status", default=""),
    "model": json_string(session, "model", default=""),
    "last_message": json_string(session, "last_message", default=""),
    "session_url": "/api/mooncode/sessions/\{id}",
    "stream_url": "/api/mooncode/sessions/\{id}/stream?format=jsonl&since=<sequence>",
    "source": "mooncode-session-listing",
    "protocol": "mooncode.v1",
    "component": "mooncode",
  }
}

///|
pub fn session_listing_title(session : Json) -> String {
  let first_user = first_user_transcript_line(session)
  if first_user != "" {
    return first_user
  }
  let last_message = compact_listing_line(
    json_string(session, "last_message", default=""),
  )
  if last_message != "" {
    return last_message
  }
  let title = compact_listing_line(json_string(session, "title", default=""))
  if title != "" {
    return title
  }
  json_string(session, "id", default="")
}

///|
fn first_user_transcript_line(session : Json) -> String {
  for message in json_array_items(session, "transcript") {
    if json_string(message, "role", default="") == "user" {
      let line = compact_listing_line(
        json_string(message, "content", default=""),
      )
      if line != "" {
        return line
      }
    }
  }
  ""
}

///|
fn compact_listing_line(text : String) -> String {
  let trimmed = text.trim()
  let out = StringBuilder()
  let mut last_was_space = false
  for ch in trimmed {
    if ch is ('\n' | '\r') {
      break
    }
    if ch is (' ' | '\t') {
      if !last_was_space {
        out.write_char(' ')
      }
      last_was_space = true
    } else if ch.to_int() < 0x20 ||
      ch.to_int() == 0x7F ||
      (ch.to_int() >= 0x80 && ch.to_int() <= 0x9F) {
      continue
    } else {
      out.write_char(ch)
      last_was_space = false
    }
  }
  out.to_string()
}

///|
fn session_listing_workspace_root(session : Json) -> String {
  let root = json_string(session, "workspace_root", default="")
  if root != "" {
    root
  } else {
    json_string(session, "cwd", default="")
  }
}
