///|
pub fn command_tool_authorization_snapshot(
  session : Json,
  command_packet : Json,
) -> Json {
  let action = json_string(command_packet, "action", default="prompt")
  let session_id = json_string(
    session,
    "id",
    default=json_string(command_packet, "session_id", default=""),
  )
  let manifest = command_json_object_field_or_empty(
    session, "mooncode_last_tool_approvals_manifest",
  )
  let status = json_string(manifest, "status", default="empty")
  let pending = command_json_int(manifest, "pending_approval_count", default=0)
  let approved = command_json_int(
    manifest,
    "approved_approval_count",
    default=0,
  )
  let rejected = command_json_int(
    manifest,
    "rejected_approval_count",
    default=0,
  )
  let authorization_needed = command_uses_authorized_tools(action)
  let enforcement_state = if rejected > 0 {
    "blocked-by-rejected-tool"
  } else if pending > 0 {
    "requires-approval"
  } else if !authorization_needed {
    "not-required"
  } else if status == "empty" {
    "no-gated-tools-seen"
  } else {
    "authorized"
  }
  {
    "kind": "mooncode-tool-authorization-snapshot",
    "protocol": protocol_version(),
    "session_id": session_id,
    "command_id": json_string(command_packet, "command_id", default=""),
    "action": action,
    "authorization_needed": authorization_needed,
    "enforcement_state": enforcement_state,
    "runtime_may_execute": rejected == 0 && pending == 0,
    "runtime_must_enforce": authorization_needed,
    "tool_authorization_endpoint": "/api/mooncode/sessions/\{session_id}/tool-authorization",
    "manifest_status": status,
    "manifest_path": json_string(manifest, "manifest_path", default=""),
    "approval_count": command_json_int(manifest, "approval_count", default=0),
    "pending_approval_count": pending,
    "approved_approval_count": approved,
    "rejected_approval_count": rejected,
    "approvals": command_json_array_field_or_empty(manifest, "approvals"),
    "current_tool_approvals": manifest,
    "rule": "MoonClaw must request/verify authorization before executing gated tools; pending or rejected approval rows block execution unless the runtime receives a later approving snapshot.",
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "review": "moonbook",
      "standalone_component": "mooncode",
    },
  }
}

///|
fn command_uses_authorized_tools(action : String) -> Bool {
  let tools = native_command_tool_sequence(action)
  command_string_array_contains(tools, "edit") ||
  command_string_array_contains(tools, "write") ||
  command_string_array_contains(tools, "shell") ||
  command_string_array_contains(tools, "moon_check") ||
  command_string_array_contains(tools, "apply_patch") ||
  command_string_array_contains(tools, "revert_patch") ||
  command_string_array_contains(tools, "package_app_tool")
}
