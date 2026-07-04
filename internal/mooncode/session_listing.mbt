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
    "queued_count": summary_json_int(session, "queued_count", default=0),
    "cwd": session_listing_workspace_root(session),
    "mooncode_runtime_session_id": json_string(
      session,
      "mooncode_runtime_session_id",
      default="",
    ),
    "last_message": json_string(session, "last_message", default=""),
    "mooncode_summary": {
      "event_count": json_array_items(session, "mooncode_command_events").length(),
      "verified_test_count": 0,
      "pending_diff_count": 0,
    },
    "session_url": "/api/mooncode/sessions/\{id}",
    "stream_url": "/api/mooncode/sessions/\{id}/stream?format=jsonl&since=<sequence>",
    "source": "mooncode-session-listing",
    "protocol": protocol_version(),
    "component": "mooncode",
  }
}

///|
pub fn merge_session_listing_rows(
  runtime_rows : Array[Json],
  sessions : Array[Json],
) -> Array[Json] {
  let rows : Array[Json] = []
  let seen : Map[String, Bool] = {}
  for row in runtime_rows {
    let id = json_string(row, "id", default="")
    if id != "" {
      seen[id] = true
      rows.push(row)
    }
  }
  for session in sessions {
    let row = session_listing_row(session, Json::null())
    let id = json_string(row, "id", default="")
    if id == "" || !seen.contains(id) {
      rows.push(row)
      if id != "" {
        seen[id] = true
      }
    }
  }
  rows.sort_by(fn(left, right) { compare_session_listing_rows(left, right) })
  rows
}

///|
pub fn runtime_session_listing_rows(payload : Json) -> Array[Json] {
  match payload {
    Array(items) => normalize_runtime_session_listing_rows(items)
    Object(fields) =>
      match fields.get("sessions") {
        Some(Array(items)) => normalize_runtime_session_listing_rows(items)
        _ => []
      }
    _ => []
  }
}

///|
fn normalize_runtime_session_listing_rows(items : Array[Json]) -> Array[Json] {
  let rows : Array[Json] = []
  for item in items {
    match normalize_runtime_session_listing_row(item) {
      Some(row) => rows.push(row)
      None => ()
    }
  }
  rows
}

///|
fn normalize_runtime_session_listing_row(row : Json) -> Json? {
  match row {
    Object(fields) => {
      guard json_string(row, "id", default="") != "" else { return None }
      let next : Map[String, Json] = {}
      for item in fields {
        next[item.0] = item.1
      }
      if json_string(row, "source", default="") == "" {
        next["source"] = "mooncode-runtime-session-listing".to_json()
      }
      if json_string(row, "protocol", default="") == "" {
        next["protocol"] = protocol_version().to_json()
      }
      if json_string(row, "component", default="") == "" {
        next["component"] = "mooncode".to_json()
      }
      if json_string(row, "workspace_name", default="") == "" {
        next["workspace_name"] = "".to_json()
      }
      if json_string(row, "workspace_id", default="") == "" {
        next["workspace_id"] = "".to_json()
      }
      if json_string(row, "workspace_root", default="") == "" {
        next["workspace_root"] = session_listing_workspace_root(row).to_json()
      }
      if json_string(row, "status", default="") == "" {
        next["status"] = "".to_json()
      }
      if json_string(row, "model", default="") == "" {
        next["model"] = "".to_json()
      }
      if json_string(row, "updated_at", default="") == "" {
        next["updated_at"] = "".to_json()
      }
      if json_string(row, "cwd", default="") == "" {
        next["cwd"] = session_listing_workspace_root(row).to_json()
      }
      if json_string(row, "mooncode_runtime_session_id", default="") == "" {
        next["mooncode_runtime_session_id"] = json_string(row, "id", default="").to_json()
      }
      match fields.get("queued_count") {
        Some(_) => ()
        None => next["queued_count"] = (0).to_json()
      }
      match fields.get("mooncode_summary") {
        Some(_) => ()
        None =>
          next["mooncode_summary"] = {
            "event_count": 0,
            "verified_test_count": 0,
            "pending_diff_count": 0,
          }
      }
      match fields.get("updated_at_ms") {
        Some(_) => ()
        None => next["updated_at_ms"] = Json::null()
      }
      Some(Json::object(next))
    }
    _ => None
  }
}

///|
fn compare_session_listing_rows(left : Json, right : Json) -> Int {
  let left_ms = session_listing_updated_at_ms_text(left)
  let right_ms = session_listing_updated_at_ms_text(right)
  if left_ms != "" || right_ms != "" {
    if left_ms == "" {
      return 1
    }
    if right_ms == "" {
      return -1
    }
    if left_ms.length() != right_ms.length() {
      return right_ms.length().compare(left_ms.length())
    }
    let by_ms = right_ms.compare(left_ms)
    if by_ms != 0 {
      return by_ms
    }
  }
  json_string(right, "updated_at", default="").compare(
    json_string(left, "updated_at", default=""),
  )
}

///|
fn session_listing_updated_at_ms_text(row : Json) -> String {
  match row {
    Object(fields) =>
      match fields.get("updated_at_ms") {
        Some(Number(_, repr=Some(raw))) => session_listing_timestamp_digits(raw)
        Some(Number(value, repr=None)) =>
          session_listing_timestamp_digits(value.to_string())
        Some(String(raw)) => session_listing_timestamp_digits(raw)
        _ => ""
      }
    _ => ""
  }
}

///|
fn session_listing_timestamp_digits(raw : String) -> String {
  let out = StringBuilder()
  for ch in raw {
    if ch >= '0' && ch <= '9' {
      out.write_char(ch)
    } else if ch == '.' {
      break
    }
  }
  out.to_string()
}

///|
pub fn session_listing_title(session : Json) -> String {
  let explicit_first_prompt = first_prompt_field_line(session)
  if explicit_first_prompt != "" {
    return explicit_first_prompt
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
fn first_prompt_field_line(session : Json) -> String {
  for key in ["first_user_prompt", "first_prompt"] {
    let line = compact_listing_line(json_string(session, key, default=""))
    if line != "" {
      return line
    }
  }
  let snapshot = session_listing_object_field_or_empty(session, "snapshot")
  for key in ["first_user_prompt", "first_prompt"] {
    let line = compact_listing_line(json_string(snapshot, key, default=""))
    if line != "" {
      return line
    }
  }
  ""
}

///|
fn session_listing_object_field_or_empty(json : Json, key : String) -> Json {
  match json {
    Object(fields) =>
      match fields.get(key) {
        Some(value) => value
        None => {}
      }
    _ => {}
  }
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
