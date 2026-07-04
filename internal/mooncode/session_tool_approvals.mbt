///|
pub fn tool_approval_entries(events : Array[Json]) -> Array[Json] {
  let entries : Array[Json] = []
  let seen : Map[String, Bool] = {}
  for event in events {
    let approval = tool_event_approval(event)
    if approval == "" {
      continue
    }
    let key = tool_approval_target(event)
    if seen.get(key).unwrap_or(false) {
      continue
    }
    seen[key] = true
    entries.push(tool_approval_entry(event, events, approval))
  }
  entries
}

///|
pub fn count_tool_approval_state(
  approvals : Array[Json],
  state : String,
) -> Int {
  let mut count = 0
  for approval in approvals {
    if json_string(approval, "approval_state", default="") == state {
      count += 1
    }
  }
  count
}

///|
fn tool_approval_entry(
  event : Json,
  events : Array[Json],
  approval : String,
) -> Json {
  let target = tool_approval_target(event)
  let state = tool_approval_state_for_target(target, events)
  let packet = summary_json_object_field_or_empty(event, "command_packet")
  {
    "id": "mooncode-tool-approval:\{target}",
    "event_id": json_string(event, "id", default=""),
    "tool_call_id": json_string(event, "tool_call_id", default=""),
    "command_id": json_string(packet, "command_id", default=""),
    "command_action": json_string(packet, "action", default=""),
    "command_packet": packet,
    "tool_id": tool_id_from_event(event),
    "title": json_string(event, "title", default="Tool approval"),
    "status": json_string(event, "status", default=""),
    "approval": approval,
    "approval_state": state,
    "created_at": json_string(event, "created_at", default=""),
    "detail": json_string(event, "detail", default=""),
    "path": json_string(event, "path", default=""),
    "command": json_string(event, "command", default=""),
    "target": target,
    "target_kind": tool_approval_target_kind(event),
    "target_label": tool_approval_target_label(event),
    "approved_review_count": tool_approval_review_count(
      target, "approve_tool", events,
    ),
    "rejected_review_count": tool_approval_review_count(
      target, "reject_tool", events,
    ),
  }
}

///|
pub fn tool_event_approval(event : Json) -> String {
  let lane = json_string(event, "lane", default="")
  if lane == event_lane_review() ||
    lane == event_lane_runtime() ||
    lane == event_lane_transcript() {
    return ""
  }
  let lower = [
      json_string(event, "kind", default=""),
      json_string(event, "title", default=""),
      json_string(event, "detail", default=""),
      json_string(event, "command", default=""),
    ]
    .join("\n")
    .to_lower()
  if lower.contains(".manifest") ||
    lower.contains("_set.manifest") ||
    lower.contains("package.index") {
    ""
  } else if lane == event_lane_diff() ||
    lower.contains("write") ||
    lower.contains("edit") {
    event_lane_review()
  } else if lane == event_lane_artifact() || lower.contains("package_app_tool") {
    event_lane_review()
  } else if lane == event_lane_tool() &&
    (
      lower.contains("shell") ||
      lower.contains("execute_command") ||
      json_string(event, "command", default="") != ""
    ) {
    "policy"
  } else {
    ""
  }
}

///|
pub fn tool_id_from_event(event : Json) -> String {
  let kind = json_string(event, "kind", default="")
  if kind.has_prefix("tool.") {
    kind["tool.".length():].to_owned()
  } else if kind == "" {
    "tool"
  } else {
    kind
  }
}

///|
pub fn tool_approval_target(event : Json) -> String {
  let tool_call_id = json_string(event, "tool_call_id", default="")
  if tool_call_id != "" {
    return "tool_call:\{tool_call_id}"
  }
  let path = json_string(event, "path", default="")
  if path != "" {
    return path
  }
  let command = json_string(event, "command", default="")
  if command != "" {
    return command
  }
  json_string(event, "id", default="tool:\{event.stringify()}")
}

///|
fn tool_approval_target_kind(event : Json) -> String {
  if json_string(event, "tool_call_id", default="") != "" {
    "tool_call"
  } else if json_string(event, "path", default="") != "" {
    "path"
  } else if json_string(event, "command", default="") != "" {
    "command"
  } else {
    "event"
  }
}

///|
fn tool_approval_target_label(event : Json) -> String {
  let path = json_string(event, "path", default="")
  if path != "" {
    return path
  }
  let command = json_string(event, "command", default="")
  if command != "" {
    return command
  }
  let tool_call_id = json_string(event, "tool_call_id", default="")
  if tool_call_id != "" {
    return tool_call_id
  }
  json_string(event, "id", default="")
}

///|
fn tool_approval_state_for_target(
  target : String,
  events : Array[Json],
) -> String {
  if tool_approval_review_count(target, "reject_tool", events) > 0 {
    "rejected"
  } else if tool_approval_review_count(target, "approve_tool", events) > 0 {
    "approved"
  } else {
    "pending"
  }
}

///|
fn tool_approval_review_count(
  target : String,
  command : String,
  events : Array[Json],
) -> Int {
  let mut count = 0
  for event in events {
    if json_string(event, "lane", default="") != event_lane_review() ||
      json_string(event, "command", default="") != command ||
      json_string(event, "status", default="") == "failed" {
      continue
    }
    let event_path = json_string(event, "path", default="")
    if target == "" || event_path == "" || event_path == target {
      count += 1
    }
  }
  count
}
