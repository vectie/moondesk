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
