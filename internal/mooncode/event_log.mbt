///|
pub fn sessions_relative_dir() -> String {
  ".moontown/mooncode-sessions"
}

///|
pub fn session_log_relative_dir(session_id : String) -> String {
  sessions_relative_dir() + "/" + session_id
}

///|
pub fn event_log_relative_path(session_id : String) -> String {
  session_log_relative_dir(session_id) + "/events.jsonl"
}

///|
pub fn command_log_relative_path(session_id : String) -> String {
  session_log_relative_dir(session_id) + "/commands.jsonl"
}

///|
pub fn runtime_command_log_relative_path(session_id : String) -> String {
  session_log_relative_dir(session_id) + "/runtime-commands.jsonl"
}

///|
pub fn runtime_dispatch_log_relative_path(session_id : String) -> String {
  session_log_relative_dir(session_id) + "/runtime-dispatches.jsonl"
}

///|
pub fn session_snapshot_relative_path(session_id : String) -> String {
  session_log_relative_dir(session_id) + "/session.json"
}

///|
pub fn stream_checkpoint_relative_dir(session_id : String) -> String {
  session_log_relative_dir(session_id) + "/stream-checkpoints"
}

///|
pub fn stream_checkpoint_relative_path(
  session_id : String,
  consumer_id : String,
) -> String {
  let safe_consumer = artifact_safe_id(consumer_id, fallback="default")
  stream_checkpoint_relative_dir(session_id) + "/" + safe_consumer + ".json"
}

///|
pub fn session_id_valid(session_id : String) -> Bool {
  session_id != "" &&
  session_id != "." &&
  session_id != ".." &&
  !session_id.contains("/") &&
  !session_id.contains("\\")
}

///|
pub fn event_record(
  id~ : String,
  lane~ : String,
  kind~ : String,
  title~ : String,
  status~ : String,
  created_at~ : String,
  detail~ : String,
  path? : String = "",
  diff? : String = "",
  command? : String = "",
  exit_code? : Int = 0,
  command_packet? : Json = Json::object({}),
) -> Json {
  {
    "id": id,
    "lane": lane,
    "kind": kind,
    "title": title,
    "status": status,
    "created_at": created_at,
    "detail": trim_event_text(detail),
    "path": path,
    "diff": trim_event_text(diff),
    "command": command,
    "exit_code": exit_code,
    "command_packet": command_packet,
  }
}

///|
pub fn normalize_event_record(event : Json) -> Json {
  let object : Map[String, Json] = {}
  match event {
    Json::Object(fields) =>
      for key, value in fields {
        object[key] = value
      }
    _ => ()
  }
  let lane = json_string(event, "lane", default="runtime")
  let kind = json_string(event, "kind", default="runtime_update")
  let title = json_string(event, "title", default=kind)
  let detail = json_string(event, "detail", default="")
  let created_at = json_string(event, "created_at", default="")
  let fallback_id = stable_event_id(
    lane + ":" + kind + ":" + title + ":" + created_at + ":" + detail,
  )
  object["id"] = json_string(event, "id", default=fallback_id).to_json()
  object["lane"] = lane.to_json()
  object["kind"] = kind.to_json()
  object["title"] = title.to_json()
  object["status"] = json_string(event, "status", default="info").to_json()
  object["created_at"] = created_at.to_json()
  object["detail"] = trim_event_text(detail).to_json()
  object["path"] = json_string(event, "path", default="").to_json()
  object["diff"] = trim_event_text(json_string(event, "diff", default="")).to_json()
  object["command"] = json_string(event, "command", default="").to_json()
  object["exit_code"] = event_json_int(event, "exit_code", default=0).to_json()
  object["command_packet"] = event_json_object_field_or_empty(
    event, "command_packet",
  )
  Json::object(object)
}

///|
pub fn parse_event_log_text(text : String) -> Array[Json] {
  parse_jsonl_records(text, fn(record) {
    json_string(record, "id", default="") != ""
  })
}

///|
pub fn parse_command_log_text(text : String) -> Array[Json] {
  parse_jsonl_records(text, fn(record) {
    json_string(record, "protocol", default="") == "mooncode.v1" &&
    json_string(record, "command_id", default="") != ""
  })
}

///|
pub fn parse_runtime_command_log_text(text : String) -> Array[Json] {
  parse_jsonl_records(text, fn(record) {
    json_string(record, "protocol", default="") == "mooncode.v1" &&
    json_string(record, "kind", default="") == "mooncode.runtime-command" &&
    json_string(record, "command_id", default="") != ""
  })
}

///|
pub fn parse_runtime_dispatch_log_text(text : String) -> Array[Json] {
  parse_jsonl_records(text, fn(record) {
    json_string(record, "protocol", default="") == "mooncode.v1" &&
    json_string(record, "kind", default="") == "mooncode.runtime-dispatch" &&
    json_string(record, "command_id", default="") != ""
  })
}

///|
pub fn merge_events(
  projected : Array[Json],
  inline_events : Array[Json],
  durable_events : Array[Json],
) -> Array[Json] {
  let merged : Array[Json] = []
  let seen : Map[String, Bool] = {}
  for group in [projected, inline_events, durable_events] {
    for event in group {
      let id = json_string(event, "id", default="")
      if id == "" || seen.get(id).unwrap_or(false) {
        continue
      }
      seen[id] = true
      merged.push(event)
    }
  }
  merged
}

///|
pub fn jsonl_text(items : Array[Json]) -> String {
  if items.length() == 0 {
    ""
  } else {
    [ for item in items => item.stringify() ].join("\n") + "\n"
  }
}

///|
fn parse_jsonl_records(text : String, keep : (Json) -> Bool) -> Array[Json] {
  let records : Array[Json] = []
  for line in text.split("\n") {
    let trimmed = line.trim()
    if trimmed.is_empty() {
      continue
    }
    let record = @json.parse(trimmed.to_owned()) catch { _ => continue }
    if keep(record) {
      records.push(record)
    }
  }
  records
}

///|
fn trim_event_text(text : String) -> String {
  let trimmed = text.trim().to_owned()
  if trimmed.length() > 4000 {
    trimmed[:4000].to_owned()
  } else {
    trimmed
  }
}

///|
fn stable_event_id(seed : String) -> String {
  let digest = @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding/utf8.encode(seed).to_fixedarray()),
  )
  "mooncode-event-" + digest[:16].to_owned()
}

///|
fn event_json_object_field_or_empty(json : Json, key : String) -> Json {
  match event_json_object_field(json, key) {
    Some(Json::Object(_) as value) => value
    _ => Json::object({})
  }
}

///|
fn event_json_object_field(json : Json, key : String) -> Json? {
  match json {
    Json::Object(fields) => fields.get(key)
    _ => None
  }
}

///|
fn event_json_int(json : Json, key : String, default~ : Int) -> Int {
  match event_json_object_field(json, key) {
    Some(Json::Number(value, ..)) => value.to_int()
    Some(Json::String(value)) => @string.parse_int(value) catch { _ => default }
    _ => default
  }
}

///|
test "mooncode event record trims durable text fields" {
  let long = "x".repeat(4010)
  let event = event_record(
    id="event-1",
    lane="runtime",
    kind="runtime.note",
    title="Note",
    status="queued",
    created_at="2026-06-15T00:00:00Z",
    detail=long,
    diff=long,
  )
  assert_eq(json_string(event, "detail", default="").length(), 4000)
  assert_eq(json_string(event, "diff", default="").length(), 4000)
}

///|
test "mooncode normalizes sparse runtime event records" {
  let event : Json = {
    "detail": "  running tool  ",
    "diff": "  patch  ",
    "command_packet": { "command_id": "cmd-1" },
  }
  let normalized = normalize_event_record(event)
  assert_true(
    json_string(normalized, "id", default="").has_prefix("mooncode-event-"),
  )
  assert_eq(json_string(normalized, "lane", default=""), "runtime")
  assert_eq(json_string(normalized, "kind", default=""), "runtime_update")
  assert_eq(json_string(normalized, "title", default=""), "runtime_update")
  assert_eq(json_string(normalized, "status", default=""), "info")
  assert_eq(json_string(normalized, "detail", default=""), "running tool")
  assert_eq(json_string(normalized, "diff", default=""), "patch")
  assert_eq(json_string(normalized, "path", default="x"), "")
  assert_eq(event_json_int(normalized, "exit_code", default=-1), 0)
  let packet = event_json_object_field_or_empty(normalized, "command_packet")
  assert_eq(json_string(packet, "command_id", default=""), "cmd-1")
}

///|
test "mooncode parses durable jsonl protocol records" {
  let event = event_record(
    id="event-1",
    lane="runtime",
    kind="runtime.note",
    title="Note",
    status="queued",
    created_at="2026-06-15T00:00:00Z",
    detail="hello",
  )
  let command : Json = {
    "protocol": "mooncode.v1",
    "kind": "mooncode.command",
    "command_id": "cmd-1",
    "action": "prompt",
  }
  let runtime : Json = {
    "protocol": "mooncode.v1",
    "kind": "mooncode.runtime-command",
    "command_id": "cmd-1",
    "serve_command": "prompt",
  }
  let dispatch : Json = {
    "protocol": "mooncode.v1",
    "kind": "mooncode.runtime-dispatch",
    "command_id": "cmd-1",
    "status": "bridged",
  }
  let text = jsonl_text([event, command, runtime, dispatch]) + "not-json\n"
  assert_eq(parse_event_log_text(text).length(), 1)
  assert_eq(parse_command_log_text(text).length(), 3)
  assert_eq(parse_runtime_command_log_text(text).length(), 1)
  assert_eq(parse_runtime_dispatch_log_text(text).length(), 1)
}

///|
test "mooncode event merge dedupes by durable event id" {
  let event = event_record(
    id="event-1",
    lane="review",
    kind="command.accept",
    title="Accept",
    status="queued",
    created_at="2026-06-15T00:00:00Z",
    detail="accepted",
  )
  let merged = merge_events([], [event], [event])
  assert_eq(merged.length(), 1)
  assert_eq(json_string(merged[0], "lane", default=""), "review")
}

///|
test "mooncode session id validation stays storage-backend neutral" {
  assert_true(session_id_valid("mooncode-20260615-000000"))
  assert_false(session_id_valid(""))
  assert_false(session_id_valid("."))
  assert_false(session_id_valid(".."))
  assert_false(session_id_valid("../x"))
  assert_false(session_id_valid("a\\b"))
}

///|
test "mooncode sidecar relative paths define durable session layout" {
  assert_eq(sessions_relative_dir(), ".moontown/mooncode-sessions")
  assert_eq(session_log_relative_dir("s1"), ".moontown/mooncode-sessions/s1")
  assert_eq(
    event_log_relative_path("s1"),
    ".moontown/mooncode-sessions/s1/events.jsonl",
  )
  assert_eq(
    command_log_relative_path("s1"),
    ".moontown/mooncode-sessions/s1/commands.jsonl",
  )
  assert_eq(
    runtime_command_log_relative_path("s1"),
    ".moontown/mooncode-sessions/s1/runtime-commands.jsonl",
  )
  assert_eq(
    runtime_dispatch_log_relative_path("s1"),
    ".moontown/mooncode-sessions/s1/runtime-dispatches.jsonl",
  )
  assert_eq(
    session_snapshot_relative_path("s1"),
    ".moontown/mooncode-sessions/s1/session.json",
  )
  assert_eq(
    stream_checkpoint_relative_dir("s1"),
    ".moontown/mooncode-sessions/s1/stream-checkpoints",
  )
  assert_eq(
    stream_checkpoint_relative_path("s1", "moondesk-ui"),
    ".moontown/mooncode-sessions/s1/stream-checkpoints/moondesk-ui.json",
  )
  assert_eq(
    stream_checkpoint_relative_path("s1", "moondesk/ui"),
    ".moontown/mooncode-sessions/s1/stream-checkpoints/default.json",
  )
}
