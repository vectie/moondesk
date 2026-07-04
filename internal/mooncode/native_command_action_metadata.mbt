///|
// Native MoonCode action metadata used by execution and result contracts.

///|
pub fn native_command_tool_sequence(action : String) -> Array[String] {
  if @mooncode_core.command_action_is_test(action) ||
    @mooncode_core.command_action_is_eval(action) ||
    action == command_commit() {
    ["read", "moon_ide", "moon_cmd", "moon_check", "shell", "finish"]
  } else if action == command_package() {
    [
      "read", "moon_ide", "moon_cmd", "moon_check", "shell", "package_app_tool",
      "finish",
    ]
  } else if action == command_accept() {
    ["read", "package_app_tool", "finish"]
  } else if action == command_reject() {
    ["read", "finish"]
  } else if action == command_apply_patch() {
    ["read", "moon_ide", "apply_patch", "moon_cmd", "moon_check", "finish"]
  } else if action == command_revert_patch() {
    ["read", "moon_ide", "revert_patch", "moon_cmd", "moon_check", "finish"]
  } else if @mooncode_core.command_action_is_tool_approval(action) {
    ["finish"]
  } else if @mooncode_core.command_action_is_prompt_or_steer(action) {
    ["moon_ide", "read", "edit", "write", "moon_cmd", "moon_check", "finish"]
  } else {
    ["finish"]
  }
}

///|
pub fn native_command_expected_events(action : String) -> Array[String] {
  if @mooncode_core.command_action_is_test(action) {
    [
      event_tool_call(),
      event_tool_result(),
      event_test_result(),
      event_runtime_finished(),
    ]
  } else if action == command_run_eval() {
    [
      event_tool_call(),
      event_tool_result(),
      event_test_result(),
      "eval_report.manifest",
      event_runtime_finished(),
    ]
  } else if action == command_package() {
    [
      event_tool_call(),
      event_tool_result(),
      event_artifact(),
      "package.manifest",
      "package.index",
      event_package_verified(),
      event_runtime_finished(),
    ]
  } else if action == command_commit() {
    [
      event_tool_call(),
      event_tool_result(),
      event_commit_created(),
      event_runtime_finished(),
    ]
  } else if action == command_apply_patch() {
    [
      event_tool_call(),
      event_diff(),
      event_patch_applied(),
      event_test_result(),
      event_runtime_finished(),
    ]
  } else if action == command_revert_patch() {
    [
      event_tool_call(),
      event_diff(),
      event_patch_reverted(),
      event_test_result(),
      event_runtime_finished(),
    ]
  } else if @mooncode_core.command_action_is_review_decision(action) {
    ["review.receipt", event_artifact(), event_runtime_finished()]
  } else if @mooncode_core.command_action_is_tool_approval(action) {
    ["tool_authorization", "review.receipt", event_runtime_finished()]
  } else if @mooncode_core.command_action_is_prompt_or_steer(action) {
    [
      event_assistant_delta(),
      event_reasoning_delta(),
      event_tool_call(),
      event_tool_result(),
      event_diff(),
      event_test_result(),
      event_artifact(),
      event_runtime_finished(),
    ]
  } else if action == command_cancel() {
    [event_runtime_aborted(), event_runtime_finished()]
  } else {
    [event_runtime_update(), event_runtime_finished()]
  }
}

///|
pub fn native_command_required_outputs(action : String) -> Array[String] {
  if action == command_run_tests() {
    ["test command", "exit code", "test_result event"]
  } else if action == command_run_build() {
    ["build command", "exit code", "test_result event"]
  } else if action == command_run_eval() {
    [
      "tool_harness result", "file_edit result", "patch_review result", "command_execution result",
      "package_output result", "native eval report", "eval_report.manifest event",
    ]
  } else if action == command_package() {
    [
      "source inventory", "package manifest", "package index", "artifact event",
      "package_verified proof event",
    ]
  } else if action == command_commit() {
    ["git status before commit", "commit SHA", "commit_created proof event"]
  } else if action == command_accept() {
    ["review receipt", "accepted MoonBook output note"]
  } else if action == command_reject() {
    ["review receipt", "rejection note"]
  } else if action == command_apply_patch() {
    [
      "diff event", "changed paths", "patch_applied proof event", "selected-hunk proof metadata",
      "post-change verification metadata",
    ]
  } else if action == command_revert_patch() {
    [
      "diff event", "changed paths", "patch_reverted proof event", "selected-hunk proof metadata",
      "post-change verification metadata",
    ]
  } else if @mooncode_core.command_action_is_tool_approval(action) {
    ["tool authorization decision"]
  } else if @mooncode_core.command_action_is_prompt_or_steer(action) {
    ["transcript progress", "tool/diff/test/artifact events as applicable"]
  } else if action == command_cancel() {
    ["terminal runtime event"]
  } else {
    ["runtime update"]
  }
}

///|
pub fn native_command_recommended_commands(
  action : String,
  context_path : String,
) -> Array[String] {
  if action == command_run_tests() {
    if context_path.has_suffix(".mbt") || context_path.contains("moon.pkg") {
      ["moon check", "moon test"]
    } else {
      ["moon check", "moon test", "package-specific test command if present"]
    }
  } else if action == command_run_build() {
    if context_path.has_suffix(".mbt") || context_path.contains("moon.pkg") {
      ["moon build", "moon check"]
    } else {
      ["moon build", "moon check", "package-specific build command if present"]
    }
  } else if action == command_run_eval() {
    [
      "run tool_harness eval fixtures",
      "run file_edit eval fixtures",
      "run patch_review eval fixtures",
      "run command_execution eval fixtures",
      "run package_output eval fixtures",
      "POST \{desktop_session_eval_report_endpoint()}",
    ]
  } else if action == command_package() {
    ["moon check", "moon test", "build/package selected artifact"]
  } else if action == command_commit() {
    [
      "git status --short", "git diff --check", "git commit with reviewed message",
    ]
  } else if @mooncode_core.command_action_is_patch(action) {
    ["moon check", "moon test"]
  } else {
    []
  }
}

///|
pub fn native_command_default_package_kind(action : String) -> String {
  if action == command_package() {
    "app-tool"
  } else {
    ""
  }
}
