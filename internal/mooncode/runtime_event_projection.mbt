///|
// MoonCode runtime event projection helpers for canonical records and UI-facing labels.

///|
pub fn canonical_event_record(
  event : Json,
  fallback_id~ : String,
  fallback_created_at~ : String,
) -> Json {
  let lane = normalize_event_lane(json_string(event, "lane", default="runtime"))
  let kind = runtime_trimmed_text(
    json_string(event, "kind", default="runtime_update"),
    fallback="runtime_update",
  )
  let created_at = runtime_first_string(
    event,
    ["created_at", "created"],
    default=fallback_created_at,
  )
  let id = runtime_json_string(event, "id", default=fallback_id)
  let command = if kind == "test_result" {
    runtime_first_string(event, ["command", "target", "tool"], default="")
  } else {
    json_string(event, "command", default="")
  }
  let exit_code = runtime_json_int(
    event,
    "exit_code",
    default=runtime_json_int(event, "exit_status", default=0),
  )
  event_record(
    id~,
    lane~,
    kind~,
    title=runtime_trimmed_text(
      json_string(event, "title", default=runtime_event_title(kind)),
      fallback=runtime_event_title(kind),
    ),
    status=runtime_trimmed_text(
      json_string(event, "status", default="done"),
      fallback="done",
    ),
    created_at~,
    detail=runtime_first_string(event, ["detail", "content"], default=""),
    path=json_string(event, "path", default=""),
    diff=json_string(event, "diff", default=""),
    command~,
    exit_code~,
    command_packet=canonical_event_command_packet(event),
  )
}

///|
fn canonical_event_command_packet(event : Json) -> Json {
  let packet = runtime_json_object_field_or_empty(event, "command_packet")
  if json_string(packet, "command_id", default="") != "" {
    return packet
  }
  let raw = runtime_json_object_field_or_empty(event, "raw_event")
  let raw_packet = runtime_json_object_field_or_empty(raw, "command_packet")
  if json_string(raw_packet, "command_id", default="") != "" {
    return raw_packet
  }
  let command_id = runtime_first_string(
    event,
    ["command_id", "commandId", "mooncode_command_id"],
    default="",
  )
  if command_id == "" {
    Json::object({})
  } else {
    {
      "protocol": protocol_version(),
      "kind": kind_command_ref(),
      "command_id": command_id,
      "action": runtime_first_string(
        event,
        ["action", "serve_command"],
        default="prompt",
      ),
      "dispatch": runtime_first_string(
        event,
        ["dispatch"],
        default="moonclaw-native",
      ),
      "runtime_proof": true,
      "session_id": json_string(event, "session_id", default=""),
      "task_id": json_string(event, "task_id", default=""),
    }
  }
}

///|
pub fn tool_authorization_preview_event(
  payload : Json,
  created_at : String,
  fallback_id~ : String,
) -> Json {
  let base = runtime_with_field(payload, "event", "tool_call".to_json())
  let with_created_at = if json_string(base, "created_at", default="") == "" {
    runtime_with_field(base, "created_at", created_at.to_json())
  } else {
    base
  }
  let with_id = if json_string(with_created_at, "id", default="") == "" {
    runtime_with_field(with_created_at, "id", fallback_id.to_json())
  } else {
    with_created_at
  }
  match
    normalize_runtime_event(
      with_id,
      fallback_id~,
      fallback_created_at=created_at,
    ) {
    Some(event) => event
    None => {
      let tool_name = runtime_first_string(
        payload,
        ["tool_name", "name"],
        default="tool",
      )
      let path = runtime_first_string(
        payload,
        ["path", "file", "target"],
        default="",
      )
      let command = runtime_first_string(
        payload,
        ["command", "cmd"],
        default="",
      )
      let detail = runtime_first_string(
        payload,
        ["arguments", "args", "input", "detail"],
        default="",
      )
      let lane = tool_lane(tool_name, path, "", command, detail)
      event_record(
        id=json_string(with_id, "id", default=fallback_id),
        lane~,
        kind=tool_name,
        title="Tool started: \{tool_name}",
        status="running",
        created_at~,
        detail~,
        path~,
        command~,
      )
    }
  }
}

///|
pub fn tool_authorization_preview_projected_event(
  payload : Json,
  created_at : String,
) -> Json {
  tool_authorization_preview_event(
    payload,
    created_at,
    fallback_id=stable_event_id(
      "mooncode-tool-auth:" + payload.stringify() + ":" + created_at,
    ),
  )
}

///|
pub fn normalize_event_lane(lane : String) -> String {
  match lane {
    "transcript"
    | "runtime"
    | "tool"
    | "diff"
    | "test"
    | "artifact"
    | "review" => lane
    _ => "runtime"
  }
}

///|
pub fn runtime_event_title(name : String) -> String {
  match name {
    "max_steps_exhausted" => "Max steps exhausted"
    "turn_failed" => "Turn failed"
    "command_error" => "Command error"
    "steer_applied" => "Steering applied"
    "steer_deferred" => "Steering deferred"
    "steer_dropped" => "Steering dropped"
    _ => name
  }
}

///|
pub fn tool_lane(
  name : String,
  path : String,
  diff : String,
  command : String,
  text : String,
) -> String {
  let lower = "\{name}\n\{path}\n\{command}\n\{text}".to_lower()
  if lower.contains("portable/") ||
    lower.contains("site/generated") ||
    lower.contains("app-tool") ||
    lower.contains("package") {
    "artifact"
  } else if lower.contains("moon test") ||
    lower.contains("moon check") ||
    lower.contains("moon build") ||
    lower.contains("total tests") ||
    lower.contains("test_result") {
    "test"
  } else if diff != "" ||
    lower.contains("write") ||
    lower.contains("edit") ||
    lower.contains("apply_patch") ||
    lower.contains("meta_write_to_file") {
    "diff"
  } else {
    "tool"
  }
}

///|
pub fn event_label(value : String) -> String {
  if value == "" {
    "none"
  } else {
    value
  }
}
