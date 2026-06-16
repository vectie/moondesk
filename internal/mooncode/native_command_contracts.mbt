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
    "protocol": "mooncode.v1",
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
pub fn native_command_tool_sequence(action : String) -> Array[String] {
  match action {
    "run_tests" => ["read", "moon_check", "shell", "finish"]
    "run_eval" => ["read", "moon_check", "shell", "finish"]
    "package" => ["read", "moon_check", "shell", "package_app_tool", "finish"]
    "commit" => ["read", "moon_check", "shell", "finish"]
    "accept" => ["read", "package_app_tool", "finish"]
    "reject" => ["read", "finish"]
    "apply_patch" | "revert_patch" =>
      ["read", "apply_patch", "moon_check", "finish"]
    "approve_tool" | "reject_tool" => ["finish"]
    "prompt" | "steer" => ["read", "edit", "write", "moon_check", "finish"]
    "cancel" => ["finish"]
    _ => ["finish"]
  }
}

///|
pub fn native_command_expected_events(action : String) -> Array[String] {
  match action {
    "run_tests" => ["tool_call", "tool_result", "test_result", "agent_finished"]
    "run_eval" =>
      [
        "tool_call", "tool_result", "test_result", "eval_report.manifest", "agent_finished",
      ]
    "package" =>
      [
        "tool_call", "tool_result", "artifact", "package.manifest", "package.index",
        "package_verified", "agent_finished",
      ]
    "commit" => ["tool_call", "tool_result", "commit_created", "agent_finished"]
    "apply_patch" =>
      ["tool_call", "diff", "patch_applied", "test_result", "agent_finished"]
    "revert_patch" =>
      ["tool_call", "diff", "patch_reverted", "test_result", "agent_finished"]
    "accept" | "reject" => ["review.receipt", "artifact", "agent_finished"]
    "approve_tool" | "reject_tool" =>
      ["tool_authorization", "review.receipt", "agent_finished"]
    "prompt" | "steer" =>
      [
        "assistant_delta", "reasoning_delta", "tool_call", "tool_result", "diff",
        "test_result", "artifact", "agent_finished",
      ]
    "cancel" => ["agent_aborted", "agent_finished"]
    _ => ["runtime_update", "agent_finished"]
  }
}

///|
pub fn native_command_required_outputs(action : String) -> Array[String] {
  match action {
    "run_tests" => ["test command", "exit code", "test_result event"]
    "run_eval" =>
      [
        "tool_harness result", "file_edit result", "native eval report", "eval_report.manifest event",
      ]
    "package" =>
      [
        "source inventory", "package manifest", "package index", "artifact event",
        "package_verified proof event",
      ]
    "commit" =>
      ["git status before commit", "commit SHA", "commit_created proof event"]
    "accept" => ["review receipt", "accepted MoonBook output note"]
    "reject" => ["review receipt", "rejection note"]
    "apply_patch" =>
      [
        "diff event", "changed paths", "patch_applied proof event", "selected-hunk proof metadata",
        "post-change verification metadata",
      ]
    "revert_patch" =>
      [
        "diff event", "changed paths", "patch_reverted proof event", "selected-hunk proof metadata",
        "post-change verification metadata",
      ]
    "approve_tool" | "reject_tool" => ["tool authorization decision"]
    "prompt" | "steer" =>
      ["transcript progress", "tool/diff/test/artifact events as applicable"]
    "cancel" => ["terminal runtime event"]
    _ => ["runtime update"]
  }
}

///|
pub fn native_command_recommended_commands(
  action : String,
  context_path : String,
) -> Array[String] {
  match action {
    "run_tests" =>
      if context_path.has_suffix(".mbt") || context_path.contains("moon.pkg") {
        ["moon check", "moon test"]
      } else {
        ["moon check", "moon test", "package-specific test command if present"]
      }
    "run_eval" =>
      [
        "run tool_harness eval fixtures", "run file_edit eval fixtures", "POST /api/mooncode/sessions/<id>/eval-report",
      ]
    "package" => ["moon check", "moon test", "build/package selected artifact"]
    "commit" =>
      [
        "git status --short", "git diff --check", "git commit with reviewed message",
      ]
    "apply_patch" | "revert_patch" => ["moon check", "moon test"]
    _ => []
  }
}

///|
pub fn native_command_default_package_kind(action : String) -> String {
  if action == "package" {
    "app-tool"
  } else {
    ""
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

///|
pub fn native_command_result_contract(action : String) -> Json {
  let required_events = native_command_expected_events(action)
  let required_outputs = native_command_required_outputs(action)
  let event_sink = "POST /api/mooncode/sessions/<session-id>/runtime-events"
  let eval_report_sink = if action == "run_eval" {
    "POST /api/mooncode/sessions/<session-id>/eval-report"
  } else {
    ""
  }
  let ack_sink = "POST /api/mooncode/sessions/<session-id>/runtime-replay"
  {
    "kind": "mooncode-native-result-contract",
    "required_events": string_array_json(required_events),
    "required_outputs": string_array_json(required_outputs),
    "event_sink": event_sink,
    "eval_report_sink": eval_report_sink,
    "ack_sink": ack_sink,
    "execution_checklist": Json::array(
      native_command_execution_checklist(
        action, required_events, required_outputs, event_sink, eval_report_sink,
        ack_sink,
      ),
    ),
    "completion_rule": "A runtime consumer should append typed progress events, then acknowledge the command as runtime-completed or failed through runtime replay.",
  }
}

///|
pub fn native_command_execution_checklist(
  action : String,
  required_events : Array[String],
  required_outputs : Array[String],
  event_sink : String,
  eval_report_sink : String,
  ack_sink : String,
) -> Array[Json] {
  let items : Array[Json] = []
  let mut index = 1
  let push_step = fn(
    id : String,
    title : String,
    owner : String,
    required_event : String,
    required_output : String,
    endpoint : String,
    blocking : Bool,
  ) {
    items.push({
      "index": index,
      "id": id,
      "title": title,
      "owner": owner,
      "required_event": required_event,
      "required_output": required_output,
      "endpoint": endpoint,
      "blocking": blocking,
    })
    index += 1
  }
  push_step(
    "claim-command", "Claim the runtime command before execution", "moonclaw-or-standalone-mooncode",
    "runtime-claimed receipt", "claim id", "POST /api/mooncode/sessions/<session-id>/runtime-claim",
    true,
  )
  for tool in native_command_tool_sequence(action) {
    push_step(
      "run-tool-\{tool}",
      "Run tool: \{tool}",
      "moonclaw-or-standalone-mooncode",
      "",
      "",
      "",
      true,
    )
  }
  for event in required_events {
    push_step(
      "emit-event-\{event}",
      "Emit event: \{event}",
      "moonclaw-or-standalone-mooncode",
      event,
      "",
      event_sink,
      true,
    )
  }
  for output in required_outputs {
    push_step(
      "produce-output-\{index}",
      "Produce output: \{output}",
      "moonclaw-or-standalone-mooncode",
      "",
      output,
      "",
      true,
    )
  }
  if eval_report_sink != "" {
    push_step(
      "publish-native-eval-report", "Publish native eval report", "moonclaw-or-standalone-mooncode",
      "native eval report", "eval-report manifest", eval_report_sink, true,
    )
  }
  push_step(
    "ack-command", "Acknowledge command completion", "moonclaw-or-standalone-mooncode",
    "runtime-completed or runtime-failed receipt", "ack receipt", ack_sink, true,
  )
  items
}
