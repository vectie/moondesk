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
  if lane == "review" || lane == "runtime" || lane == "transcript" {
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
  } else if lane == "diff" || lower.contains("write") || lower.contains("edit") {
    "review"
  } else if lane == "artifact" || lower.contains("package_app_tool") {
    "review"
  } else if lane == "tool" &&
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
    if json_string(event, "lane", default="") != "review" ||
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

///|
pub fn tool_authorization_contract(
  session_id : String,
  manifest : Json,
) -> Json {
  {
    "kind": "mooncode-tool-authorization-contract",
    "protocol": "mooncode.v1",
    "session_id": session_id,
    "endpoint": "/api/mooncode/sessions/\{session_id}/tool-authorization",
    "method": "POST",
    "runtime_owner": "moonclaw",
    "approval_owner": "moondesk",
    "review_owner": "moonbook",
    "decisions": ["allowed", "requires_approval", "blocked"],
    "request_fields": [
      "tool_call_id", "tool_name", "name", "arguments", "path", "command", "tool_call",
    ],
    "rule": "MoonClaw asks before executing a tool. Moondesk records gated shell/write/edit/package previews as pending approval rows and returns the current decision; MoonClaw enforces the decision.",
    "current_tool_approvals": manifest,
  }
}

///|
pub fn tool_authorization_response(
  session_id : String,
  preview : Json,
  events : Array[Json],
  tool_approvals_manifest : Json,
) -> Json {
  let approval = tool_event_approval(preview)
  let target = tool_approval_target(preview)
  let approvals = tool_approval_entries(events)
  let entry = tool_authorization_matching_approval(approvals, target)
  let state = match entry {
    Some(approval_entry) =>
      json_string(approval_entry, "approval_state", default="pending")
    None => if approval == "" { "auto" } else { "pending" }
  }
  let decision = match state {
    "auto" | "approved" => "allowed"
    "rejected" => "blocked"
    _ => if approval == "" { "allowed" } else { "requires_approval" }
  }
  let approval_entry = match entry {
    Some(approval_entry) => approval_entry
    None => Json::object({})
  }
  {
    "kind": "mooncode-tool-authorization",
    "protocol": "mooncode.v1",
    "session_id": session_id,
    "decision": decision,
    "allowed": decision == "allowed",
    "requires_approval": decision == "requires_approval",
    "blocked": decision == "blocked",
    "approval": if approval == "" {
      "auto"
    } else {
      approval
    },
    "approval_state": state,
    "target": target,
    "tool_call_id": json_string(preview, "tool_call_id", default=""),
    "tool_id": tool_id_from_event(preview),
    "path": json_string(preview, "path", default=""),
    "command": json_string(preview, "command", default=""),
    "reason": tool_authorization_reason(decision, approval, state),
    "preview_event": preview,
    "approval_entry": approval_entry,
    "tool_approvals": tool_approvals_manifest,
  }
}

///|
pub fn tool_authorization_has_target(
  events : Array[Json],
  target : String,
) -> Bool {
  if target == "" {
    return false
  }
  for approval in tool_approval_entries(events) {
    if json_string(approval, "target", default="") == target {
      return true
    }
  }
  false
}

///|
fn tool_authorization_reason(
  decision : String,
  approval : String,
  state : String,
) -> String {
  match decision {
    "allowed" =>
      if state == "approved" {
        "matching MoonCode tool approval is approved"
      } else {
        "tool does not require operator approval"
      }
    "blocked" => "matching MoonCode tool approval was rejected"
    _ =>
      if approval == "" {
        "tool does not require operator approval"
      } else {
        "tool requires \{approval} approval before MoonClaw may execute it"
      }
  }
}

///|
fn tool_authorization_matching_approval(
  approvals : Array[Json],
  target : String,
) -> Json? {
  for approval in approvals {
    if json_string(approval, "target", default="") == target {
      return Some(approval)
    }
  }
  None
}
