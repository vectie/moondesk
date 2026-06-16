///|
pub fn command_packet(
  session : Json,
  payload : Json,
  action : String,
  message : String,
  created_at : String,
  context_path : String,
  command_id~ : String,
) -> Json {
  let workspace_id = json_string(session, "workspace_id", default="")
  let task_id = json_string(session, "moonclaw_task_id", default="")
  {
    "protocol": "mooncode.v1",
    "kind": "mooncode.command",
    "command_id": command_id,
    "action": action,
    "dispatch": command_dispatch(action),
    "approval": command_approval(action),
    "created_at": created_at,
    "session_id": json_string(session, "id", default=""),
    "workspace_id": workspace_id,
    "workspace_name": json_string(session, "workspace_name", default=""),
    "workspace_root": json_string(session, "workspace_root", default=""),
    "task_id": task_id,
    "context_path": context_path,
    "target": if context_path == "" {
      "moonbook"
    } else {
      context_path
    },
    "message": message,
    "web_search": json_bool(payload, "web_search", default=false),
    "force_preflight": json_bool(payload, "force_preflight", default=false),
    "expected_lanes": string_array_json(command_expected_lanes(action)),
    "tool_hints": string_array_json(command_tool_hints(action)),
    "output_contract": {
      "owner": "moonbook",
      "roots": [
        "tools/", "apps/", "book/site/generated/", "portable/app-tool/", "wiki/reviews/",
        "raw/analysis-runs/",
      ],
      "review_required": command_approval(action) == "operator",
    },
    "boundary": {
      "ui_owner": "moondesk",
      "runtime_owner": "moonclaw",
      "artifact_owner": "moonbook",
      "extractable_component": "mooncode",
    },
  }
}

///|
pub fn command_event(
  action~ : String,
  status~ : String,
  detail~ : String,
  created_at~ : String,
  path~ : String,
  command_packet~ : Json,
  event_id~ : String,
) -> Json {
  event_record(
    id=event_id,
    lane=command_lane(action),
    kind="command.\{action}",
    title=command_title(action, status),
    status~,
    created_at~,
    detail~,
    path~,
    command=action,
    command_packet~,
  )
}

///|
pub fn command_runtime_message(
  message : String,
  command_packet : Json,
) -> String {
  message +
  "\n\nMoonCode command packet (JSON, protocol mooncode.v1):\n```json\n" +
  command_packet.stringify(indent=2) +
  "\n```\nUse this packet as the durable command contract. Keep all edits inside the selected MoonBook workspace, emit tool/diff/test/artifact/review events when available, and preserve the output contract."
}

///|
pub fn openseek_serve_command(message : String, command_packet : Json) -> Json {
  let dispatch = json_string(command_packet, "dispatch", default="command")
  let action = json_string(command_packet, "action", default="prompt")
  match dispatch {
    "cancel" => { "command": "cancel" }
    "steer" =>
      {
        "command": "steer",
        "text": command_runtime_message(message, command_packet),
      }
    "prompt" =>
      {
        "command": "prompt",
        "text": command_runtime_message(message, command_packet),
      }
    _ =>
      {
        "command": "prompt",
        "text": "MoonCode action `\{action}` requested.\n\n" +
        command_runtime_message(message, command_packet),
      }
  }
}

///|
pub fn runtime_command_record(
  session : Json,
  payload : Json,
  message : String,
  command_packet : Json,
) -> Json {
  let serve_command = openseek_serve_command(message, command_packet)
  let session_id = json_string(session, "id", default="")
  let tool_authorization = command_tool_authorization_snapshot(
    session, command_packet,
  )
  let native_body = native_command_body(
    session, payload, message, command_packet,
  )
  {
    "protocol": "mooncode.v1",
    "kind": "mooncode.runtime-command",
    "command_id": json_string(command_packet, "command_id", default=""),
    "action": json_string(command_packet, "action", default="prompt"),
    "dispatch": json_string(command_packet, "dispatch", default="prompt"),
    "approval": json_string(command_packet, "approval", default="none"),
    "serve_command": json_string(serve_command, "command", default="prompt"),
    "text": json_string(serve_command, "text", default=""),
    "created_at": json_string(command_packet, "created_at", default=""),
    "session_id": session_id,
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "workspace_root": json_string(session, "workspace_root", default=""),
    "task_id": json_string(session, "moonclaw_task_id", default=""),
    "context_path": json_string(command_packet, "context_path", default=""),
    "target": json_string(command_packet, "target", default="moonbook"),
    "openseek_wire_command": serve_command,
    "openseek_wire_valid": serve_wire_valid(serve_command),
    "native_mooncode_endpoint": "/v1/mooncode/sessions/\{session_id}/commands",
    "tool_authorization": tool_authorization,
    "native_mooncode_body": native_body,
    "execution_summary": native_command_execution_summary(
      command_packet, native_body,
    ),
    "command_packet": command_packet,
    "ordering_rule": "OpenSeek-compatible serve commands and native MoonCode command bodies share the same command_id and append order.",
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "extractable_component": "mooncode",
    },
  }
}

///|
pub fn native_command_body(
  session : Json,
  payload : Json,
  message : String,
  command_packet : Json,
) -> Json {
  let action = json_string(command_packet, "action", default="prompt")
  let context_path = json_string(command_packet, "context_path", default="")
  let tool_authorization = command_tool_authorization_snapshot(
    session, command_packet,
  )
  {
    "protocol": "mooncode.v1",
    "command": action,
    "native_dispatch_mode": "queue-only",
    "text": message,
    "session_id": json_string(session, "id", default=""),
    "book_root": json_string(
      session,
      "workspace_root",
      default=json_string(session, "cwd", default=""),
    ),
    "context_path": context_path,
    "payload": payload,
    "packet": command_packet,
    "execution_plan": native_command_execution_plan(
      action, context_path, payload, command_packet,
    ),
    "tool_authorization": tool_authorization,
    "tool_contract": native_command_tool_contract(action),
    "result_contract": native_command_result_contract(action),
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "artifact": "moonbook",
      "extractable_component": "mooncode",
    },
  }
}

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
    "protocol": "mooncode.v1",
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
    "rule": "MoonClaw or standalone MoonCode must request/verify authorization before executing gated tools; pending or rejected approval rows block execution unless the runtime receives a later approving snapshot.",
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "review": "moonbook",
      "extractable_component": "mooncode",
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
  command_string_array_contains(tools, "package_app_tool")
}

///|
pub fn native_command_execution_summary(
  command_packet : Json,
  native_body : Json,
) -> Json {
  let plan = command_json_object_field_or_empty(native_body, "execution_plan")
  let tool_contract = command_json_object_field_or_empty(
    native_body, "tool_contract",
  )
  let result_contract = command_json_object_field_or_empty(
    native_body, "result_contract",
  )
  let tool_authorization = command_json_object_field_or_empty(
    native_body, "tool_authorization",
  )
  let path_policy = command_json_object_field_or_empty(plan, "path_policy")
  {
    "kind": "mooncode-runtime-execution-summary",
    "protocol": "mooncode.v1",
    "command_id": json_string(command_packet, "command_id", default=""),
    "action": json_string(
      plan,
      "action",
      default=json_string(command_packet, "action", default="prompt"),
    ),
    "dispatch": json_string(
      plan,
      "dispatch",
      default=json_string(command_packet, "dispatch", default="prompt"),
    ),
    "approval": json_string(
      plan,
      "approval",
      default=json_string(command_packet, "approval", default="none"),
    ),
    "target": json_string(
      plan,
      "target",
      default=json_string(command_packet, "target", default="moonbook"),
    ),
    "context_path": json_string(
      plan,
      "context_path",
      default=json_string(command_packet, "context_path", default=""),
    ),
    "tool_sequence": string_array_json(
      command_json_string_array_items(plan, "tool_sequence"),
    ),
    "tool_policy_count": command_json_array_length(plan, "tool_policies"),
    "tool_policies": command_json_array_field_or_empty(plan, "tool_policies"),
    "allowed_tools": string_array_json(
      command_json_string_array_items(tool_contract, "allowed_tools"),
    ),
    "expected_events": string_array_json(
      command_json_string_array_items(plan, "expected_events"),
    ),
    "required_events": string_array_json(
      command_json_string_array_items(result_contract, "required_events"),
    ),
    "required_outputs": string_array_json(
      command_json_string_array_items(plan, "required_outputs"),
    ),
    "execution_checklist": command_json_array_field_or_empty(
      result_contract, "execution_checklist",
    ),
    "checklist_count": command_json_array_length(
      result_contract, "execution_checklist",
    ),
    "recommended_commands": string_array_json(
      command_json_string_array_items(plan, "recommended_commands"),
    ),
    "package_kind": json_string(plan, "package_kind", default=""),
    "review_required": json_bool(plan, "review_required", default=false),
    "event_sink": json_string(result_contract, "event_sink", default=""),
    "ack_sink": json_string(result_contract, "ack_sink", default=""),
    "completion_rule": json_string(
      result_contract,
      "completion_rule",
      default="",
    ),
    "tool_authorization_state": json_string(
      tool_authorization,
      "enforcement_state",
      default="",
    ),
    "tool_authorization_needed": json_bool(
      tool_authorization,
      "authorization_needed",
      default=false,
    ),
    "runtime_may_execute_tools": json_bool(
      tool_authorization,
      "runtime_may_execute",
      default=true,
    ),
    "pending_tool_approval_count": command_json_int(
      tool_authorization,
      "pending_approval_count",
      default=0,
    ),
    "rejected_tool_approval_count": command_json_int(
      tool_authorization,
      "rejected_approval_count",
      default=0,
    ),
    "approval_boundary": json_string(
      tool_contract,
      "approval_boundary",
      default="",
    ),
    "path_rule": json_string(path_policy, "rule", default=""),
  }
}
