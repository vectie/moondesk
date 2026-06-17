///|
// Native MoonCode command execution contracts and tool policies.

///|
pub fn native_command_execution_plan(
  action : String,
  context_path : String,
  payload : Json,
  command_packet : Json,
) -> Json {
  {
    "kind": "mooncode-native-command-execution-plan",
    "protocol": protocol_version(),
    "action": action,
    "dispatch": json_string(command_packet, "dispatch", default="command"),
    "approval": json_string(command_packet, "approval", default="none"),
    "target": if context_path == "" {
      "moonbook"
    } else {
      context_path
    },
    "context_path": context_path,
    "tool_sequence": string_array_json(native_command_tool_sequence(action)),
    "tool_policies": Json::array(
      native_command_tool_policies(action, context_path),
    ),
    "expected_events": string_array_json(native_command_expected_events(action)),
    "required_outputs": string_array_json(
      native_command_required_outputs(action),
    ),
    "recommended_commands": string_array_json(
      native_command_recommended_commands(action, context_path),
    ),
    "package_kind": trimmed_or(
      json_string(payload, "package_kind", default=""),
      fallback=native_command_default_package_kind(action),
    ),
    "review_required": json_string(command_packet, "approval", default="none") ==
    "operator",
    "path_policy": {
      "book_root": json_string(command_packet, "workspace_root", default=""),
      "context_path": context_path,
      "rule": "All reads, edits, shell commands, tests, and generated artifacts must stay inside the selected MoonBook unless an operator approves a broader workspace explicitly.",
    },
  }
}

///|
pub fn native_command_tool_contract(action : String) -> Json {
  {
    "kind": "mooncode-native-tool-contract",
    "allowed_tools": string_array_json(native_command_tool_sequence(action)),
    "tool_policies": Json::array(native_command_tool_policies(action, "")),
    "mutating_tools_require_review": true,
    "shell_requires_bounded_timeout": true,
    "moon_check_required_for_code_changes": true,
    "approval_boundary": "Moondesk records approvals; MoonClaw or standalone mooncode must enforce them before read/edit/write/shell/moon_check/package tools execute.",
  }
}
