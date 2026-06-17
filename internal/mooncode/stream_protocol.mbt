///|
pub fn stream_checkpoint_sequence(
  payload : Json,
  fallback_since : Int,
  latest_sequence : Int,
) -> Int {
  let requested = match stream_json_int_opt(payload, "last_seen_sequence") {
    Some(sequence) => sequence
    None => stream_json_int(payload, "next_since", default=fallback_since)
  }
  clamp_sequence(requested, latest_sequence)
}

///|
pub fn stream_checkpoint_consumer_id(
  payload : Json,
  query_consumer : String,
) -> String {
  let from_payload = stream_json_string(payload, "consumer_id", default="")
  let candidate = if from_payload != "" {
    from_payload
  } else if query_consumer != "" {
    query_consumer
  } else {
    "moondesk-ui"
  }
  artifact_safe_id(candidate, fallback="moondesk-ui")
}

///|
pub fn stream_checkpoint_record(
  session : Json,
  consumer_id : String,
  last_seen_sequence : Int,
  latest_sequence : Int,
  recorded_at : String,
  checkpoint_path : String,
  stream_endpoint : String,
  resume_endpoint : String,
  stream_state_endpoint : String,
  runtime_event_ingest_endpoint : String,
) -> Json {
  let clamped = clamp_sequence(last_seen_sequence, latest_sequence)
  {
    "protocol": protocol_version(),
    "kind": "mooncode-stream-checkpoint",
    "session_id": stream_json_string(session, "id", default=""),
    "consumer_id": consumer_id,
    "workspace_id": stream_json_string(session, "workspace_id", default=""),
    "workspace_name": stream_json_string(session, "workspace_name", default=""),
    "task_id": stream_json_string(session, "moonclaw_task_id", default=""),
    "last_seen_sequence": clamped,
    "latest_sequence_at_record": latest_sequence,
    "recorded_at": recorded_at,
    "checkpoint_path": checkpoint_path,
    "stream_endpoint": stream_endpoint,
    "resume_endpoint": resume_endpoint,
    "stream_state_endpoint": stream_state_endpoint,
    "runtime_event_ingest_endpoint": runtime_event_ingest_endpoint,
    "owner": stream_owner_record(),
  }
}

///|
pub fn stream_state_record(
  session : Json,
  consumer_id : String,
  requested_since : Int,
  latest_sequence : Int,
  emitted_count : Int,
  event_log_path : String,
  checkpoint_ready : Bool,
  checkpoint_path : String,
  checkpoint : Json,
  tail_events : Array[Json],
  stream_endpoint : String,
  sse_stream_endpoint : String,
  checkpoint_endpoint : String,
  runtime_event_ingest_endpoint : String,
  moondesk_live_endpoint : String,
  native_blocking_tail : String,
) -> Json {
  {
    "protocol": protocol_version(),
    "kind": "mooncode-stream-state",
    "session_id": stream_json_string(session, "id", default=""),
    "consumer_id": consumer_id,
    "workspace_id": stream_json_string(session, "workspace_id", default=""),
    "workspace_name": stream_json_string(session, "workspace_name", default=""),
    "task_id": stream_json_string(session, "moonclaw_task_id", default=""),
    "requested_since": requested_since,
    "latest_sequence": latest_sequence,
    "emitted_count": emitted_count,
    "next_since": latest_sequence,
    "has_more": emitted_count > 0,
    "event_log_path": event_log_path,
    "checkpoint_ready": checkpoint_ready,
    "checkpoint_path": checkpoint_path,
    "checkpoint": checkpoint,
    "tail_events": Json::array(tail_events),
    "stream_endpoint": stream_endpoint,
    "sse_stream_endpoint": sse_stream_endpoint,
    "checkpoint_endpoint": checkpoint_endpoint,
    "runtime_event_ingest_endpoint": runtime_event_ingest_endpoint,
    "poll_contract": {
      "get": "Read current append-log cursor state and tail records after ?since=<sequence>.",
      "live_get": "Use /stream?format=jsonl|sse&since=<sequence>&live=true for bounded live-tail waiting before replay.",
      "post": "Persist {consumer_id,last_seen_sequence} after a UI, MoonClaw, or standalone mooncode consumer has processed a tail batch.",
      "cursor_rule": "Use response.next_since as the next ?since value; sequence numbers are 1-based event positions and ?since means already seen.",
    },
    "live_tail_boundary": {
      "current": "bounded live append-log tail over the Moondesk projection, falling back to MoonClaw native /v1/mooncode stream when available",
      "moondesk_live_endpoint": moondesk_live_endpoint,
      "native_blocking_tail": native_blocking_tail,
      "rule": "Moondesk owns resumable cursor state and live-tail projection; MoonClaw or standalone mooncode owns event production and native blocking runtime streams.",
    },
    "owner": stream_owner_record(),
  }
}

///|
pub fn moondesk_stream_endpoint(
  session_id : String,
  format : String,
  since : Int,
) -> String {
  "/api/mooncode/sessions/\{stream_query_value(session_id)}/stream?format=\{stream_query_value(format)}&since=\{since}"
}

///|
pub fn moondesk_live_stream_endpoint(
  session_id : String,
  format : String,
  since : Int,
  timeout_ms? : Int = 8000,
) -> String {
  moondesk_stream_endpoint(session_id, format, since) +
  "&live=true&timeout_ms=\{timeout_ms}"
}

///|
pub fn moondesk_stream_state_endpoint(
  session_id : String,
  consumer_id : String,
  since : Int,
) -> String {
  "/api/mooncode/sessions/\{stream_query_value(session_id)}/stream-state?consumer=\{stream_query_value(consumer_id)}&since=\{since}"
}

///|
pub fn moondesk_stream_state_base_endpoint(session_id : String) -> String {
  "/api/mooncode/sessions/\{stream_query_value(session_id)}/stream-state"
}

///|
pub fn moondesk_runtime_event_ingest_endpoint(session_id : String) -> String {
  "/api/mooncode/sessions/\{stream_query_value(session_id)}/runtime-events"
}

///|
pub fn moondesk_stream_checkpoint_record(
  session : Json,
  consumer_id : String,
  last_seen_sequence : Int,
  latest_sequence : Int,
  recorded_at : String,
  checkpoint_path : String,
) -> Json {
  let session_id = stream_json_string(session, "id", default="")
  let clamped = clamp_sequence(last_seen_sequence, latest_sequence)
  stream_checkpoint_record(
    session,
    consumer_id,
    last_seen_sequence,
    latest_sequence,
    recorded_at,
    checkpoint_path,
    moondesk_stream_endpoint(session_id, "jsonl", clamped),
    moondesk_stream_endpoint(session_id, "jsonl", clamped),
    moondesk_stream_state_endpoint(session_id, consumer_id, clamped),
    moondesk_runtime_event_ingest_endpoint(session_id),
  )
}

///|
pub fn moondesk_stream_state_record(
  session : Json,
  consumer_id : String,
  requested_since : Int,
  latest_sequence : Int,
  emitted_count : Int,
  event_log_path : String,
  checkpoint_ready : Bool,
  checkpoint_path : String,
  checkpoint : Json,
  tail_events : Array[Json],
  native_blocking_tail : String,
) -> Json {
  let session_id = stream_json_string(session, "id", default="")
  stream_state_record(
    session,
    consumer_id,
    requested_since,
    latest_sequence,
    emitted_count,
    event_log_path,
    checkpoint_ready,
    checkpoint_path,
    checkpoint,
    tail_events,
    moondesk_stream_endpoint(session_id, "jsonl", requested_since),
    moondesk_stream_endpoint(session_id, "sse", requested_since),
    moondesk_stream_state_base_endpoint(session_id),
    moondesk_runtime_event_ingest_endpoint(session_id),
    moondesk_live_stream_endpoint(session_id, "sse", requested_since),
    native_blocking_tail,
  )
}

///|
pub fn moondesk_stream_state_projection_record(
  session : Json,
  events : Array[Json],
  since : Int,
  consumer_id : String,
  event_log_path : String,
  checkpoint_path : String,
  checkpoint : Json,
  native_blocking_tail : String,
) -> Json {
  let latest_sequence = events.length()
  let checkpoint_ready = stream_json_string(checkpoint, "kind", default="") ==
    "mooncode-stream-checkpoint"
  moondesk_stream_state_record(
    session,
    consumer_id,
    since,
    latest_sequence,
    stream_emitted_count(events, since),
    event_log_path,
    checkpoint_ready,
    checkpoint_path,
    checkpoint,
    stream_tail_event_records(session, events, since),
    native_blocking_tail,
  )
}

///|
pub fn stream_emitted_count(events : Array[Json], since : Int) -> Int {
  if since >= events.length() {
    0
  } else {
    events.length() - since
  }
}

///|
pub fn stream_since_value(value : String) -> Int {
  let parsed = @string.parse_int(value) catch { _ => 0 }
  if parsed < 0 {
    0
  } else {
    parsed
  }
}

///|
pub fn stream_live_enabled_value(value : String) -> Bool {
  let normalized = value.to_lower()
  normalized == "1" ||
  normalized == "true" ||
  normalized == "tail" ||
  normalized == "wait"
}

///|
pub fn stream_live_timeout_ms_value(value : String) -> Int {
  stream_clamp_int(@string.parse_int(value) catch { _ => 8000 }, 0, 15000)
}

///|
pub fn stream_live_poll_ms_value(value : String) -> Int {
  stream_clamp_int(@string.parse_int(value) catch { _ => 250 }, 50, 1000)
}

///|
pub fn stream_live_attempt_count(timeout_ms : Int, poll_ms : Int) -> Int {
  if timeout_ms <= 0 {
    0
  } else {
    let count = timeout_ms / poll_ms
    if count * poll_ms < timeout_ms {
      count + 1
    } else if count == 0 {
      1
    } else {
      count
    }
  }
}

///|
pub fn stream_content_type(format : String) -> String {
  if format == "sse" {
    "text/event-stream; charset=utf-8"
  } else {
    "application/x-ndjson; charset=utf-8"
  }
}

///|
fn stream_query_value(text : String) -> String {
  let pieces : Array[String] = []
  for ch in text {
    if stream_query_safe_char(ch) {
      pieces.push(String::from_array([ch]))
    } else {
      stream_append_percent_encoded_char(pieces, ch)
    }
  }
  pieces.join("")
}

///|
fn stream_query_safe_char(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') ||
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= '0' && ch <= '9') ||
  ch == '-' ||
  ch == '_' ||
  ch == '.' ||
  ch == '~'
}

///|
fn stream_append_percent_encoded_char(
  pieces : Array[String],
  ch : Char,
) -> Unit {
  let code = ch.to_int()
  if code <= 0x7F {
    pieces.push(stream_percent_encoded_byte(code))
  } else if code <= 0x7FF {
    pieces.push(stream_percent_encoded_byte(0xC0 + code / 64))
    pieces.push(stream_percent_encoded_byte(0x80 + code % 64))
  } else if code <= 0xFFFF {
    pieces.push(stream_percent_encoded_byte(0xE0 + code / 4096))
    pieces.push(stream_percent_encoded_byte(0x80 + code / 64 % 64))
    pieces.push(stream_percent_encoded_byte(0x80 + code % 64))
  } else {
    pieces.push(stream_percent_encoded_byte(0xF0 + code / 262144))
    pieces.push(stream_percent_encoded_byte(0x80 + code / 4096 % 64))
    pieces.push(stream_percent_encoded_byte(0x80 + code / 64 % 64))
    pieces.push(stream_percent_encoded_byte(0x80 + code % 64))
  }
}

///|
fn stream_percent_encoded_byte(value : Int) -> String {
  let digits = "0123456789ABCDEF"
  "%" +
  digits[value / 16:value / 16 + 1].to_owned() +
  digits[value % 16:value % 16 + 1].to_owned()
}

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
    "task_id": stream_json_string(session, "moonclaw_task_id", default=""),
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
    "extractable_component": "mooncode",
  }
}

///|
fn stream_json_array_items(json : Json, key : String) -> Array[Json] {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::Array(items)) => items
        _ => []
      }
    _ => []
  }
}

///|
fn stream_json_string(json : Json, key : String, default~ : String) -> String {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::String(value)) => value
        _ => default
      }
    _ => default
  }
}

///|
fn stream_json_int(json : Json, key : String, default~ : Int) -> Int {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(value) => @json.from_json(value) catch { _ => default }
        _ => default
      }
    _ => default
  }
}

///|
fn stream_json_int_opt(json : Json, key : String) -> Int? {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(value) => Some(@json.from_json(value) catch { _ => 0 })
        _ => None
      }
    _ => None
  }
}
