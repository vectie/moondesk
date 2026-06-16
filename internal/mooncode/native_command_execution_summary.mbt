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
