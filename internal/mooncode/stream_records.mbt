///|
pub fn stream_mode(since : Int) -> String {
  if since > 0 {
    "append-log-incremental"
  } else {
    "append-log-snapshot"
  }
}

///|
pub fn stream_source() -> String {
  "moondesk-append-log-projection"
}

///|
pub fn stream_meta_record(
  session : Json,
  since~ : Int,
  emitted_count~ : Int,
  latest_sequence~ : Int,
) -> Json {
  {
    "protocol": protocol_version(),
    "stream": stream_mode(since),
    "stream_source": stream_source(),
    "type": "meta",
    "session_id": stream_json_string(session, "id", default=""),
    "workspace_id": stream_json_string(session, "workspace_id", default=""),
    "runtime_session_id": session_runtime_session_id(session),
    "event_count": stream_json_array_items(session, "mooncode_events").length(),
    "since": since,
    "emitted_count": emitted_count,
    "next_since": latest_sequence,
  }
}

///|
pub fn stream_event_record(
  session : Json,
  event : Json,
  sequence : Int,
  since~ : Int,
) -> Json {
  {
    "protocol": protocol_version(),
    "stream": stream_mode(since),
    "stream_source": stream_source(),
    "type": "event",
    "sequence": sequence,
    "session_id": stream_json_string(session, "id", default=""),
    "event": event,
  }
}

///|
pub fn stream_done_record(
  session : Json,
  sequence : Int,
  since~ : Int,
  emitted_count~ : Int,
) -> Json {
  {
    "protocol": protocol_version(),
    "stream": stream_mode(since),
    "stream_source": stream_source(),
    "type": "done",
    "session_id": stream_json_string(session, "id", default=""),
    "sequence": sequence,
    "since": since,
    "emitted_count": emitted_count,
    "next_since": sequence,
  }
}

///|
fn clamp_sequence(sequence : Int, latest_sequence : Int) -> Int {
  if sequence < 0 {
    0
  } else if sequence > latest_sequence {
    latest_sequence
  } else {
    sequence
  }
}

///|
fn stream_clamp_int(value : Int, min : Int, max : Int) -> Int {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
fn stream_owner_record() -> Json {
  {
    "ui": "moondesk",
    "runtime": "moonclaw",
    "standalone_component": "mooncode",
  }
}

///|
fn stream_json_array_items(json : Json, key : String) -> Array[Json] {
  @mooncore.json_array_items(json, key)
}

///|
fn stream_json_string(json : Json, key : String, default~ : String) -> String {
  @mooncore.json_string(json, key, default~)
}

///|
fn stream_json_int(json : Json, key : String, default~ : Int) -> Int {
  @mooncore.json_int(json, key, default~)
}

///|
fn stream_json_int_opt(json : Json, key : String) -> Int? {
  match json {
    Object(object) =>
      match object.get(key) {
        Some(value) => Some(@json.from_json(value) catch { _ => 0 })
        _ => None
      }
    _ => None
  }
}
