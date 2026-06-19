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
    Object(fields) =>
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
  object["command_packet"] = canonical_event_command_packet(event)
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
  parse_jsonl_records(text, fn(record) { command_packet_valid(record) })
}

///|
pub fn parse_runtime_command_log_text(text : String) -> Array[Json] {
  parse_jsonl_records(text, fn(record) { runtime_command_record_valid(record) })
}

///|
pub fn parse_runtime_dispatch_log_text(text : String) -> Array[Json] {
  parse_jsonl_records(text, fn(record) { runtime_dispatch_record_valid(record) })
}

///|
pub fn command_packet_valid(command_packet : Json) -> Bool {
  json_string(command_packet, "protocol", default="") == protocol_version() &&
  json_string(command_packet, "command_id", default="") != ""
}

///|
pub fn runtime_command_record_valid(runtime_command : Json) -> Bool {
  command_packet_valid(runtime_command) &&
  json_string(runtime_command, "kind", default="") == kind_runtime_command()
}

///|
pub fn runtime_dispatch_record_valid(receipt : Json) -> Bool {
  command_packet_valid(receipt) &&
  json_string(receipt, "kind", default="") == kind_runtime_dispatch()
}

///|
pub fn session_snapshot_valid(snapshot : Json) -> Bool {
  json_string(snapshot, "kind", default="") == "mooncode-session-snapshot" &&
  json_string(snapshot, "protocol", default="") == protocol_version()
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
pub fn project_session_events(
  projected : Array[Json],
  inline_events : Array[Json],
  durable_events : Array[Json],
) -> Array[Json] {
  let normalized : Array[Json] = []
  for event in merge_events(projected, inline_events, durable_events) {
    normalized.push(normalize_event_record(event))
  }
  normalized
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
pub fn append_jsonl_text(existing : String, item : Json) -> String {
  let prefix = if existing == "" || existing.has_suffix("\n") {
    existing
  } else {
    existing + "\n"
  }
  prefix + item.stringify() + "\n"
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
fn event_json_object_field(json : Json, key : String) -> Json? {
  match json {
    Object(fields) => fields.get(key)
    _ => None
  }
}

///|
fn event_json_int(json : Json, key : String, default~ : Int) -> Int {
  match event_json_object_field(json, key) {
    Some(Number(value, ..)) => value.to_int()
    Some(String(value)) => @string.parse_int(value) catch { _ => default }
    _ => default
  }
}
