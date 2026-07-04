///|
// Native MoonCode action metadata used by execution and result contracts.

///|
pub fn native_command_tool_sequence(action : String) -> Array[String] {
  match action {
    "run_tests" | "run_build" =>
      ["read", "moon_ide", "moon_cmd", "moon_check", "shell", "finish"]
    "run_eval" =>
      ["read", "moon_ide", "moon_cmd", "moon_check", "shell", "finish"]
    "package" =>
      [
        "read", "moon_ide", "moon_cmd", "moon_check", "shell", "package_app_tool",
        "finish",
      ]
    "commit" =>
      ["read", "moon_ide", "moon_cmd", "moon_check", "shell", "finish"]
    "accept" => ["read", "package_app_tool", "finish"]
    "reject" => ["read", "finish"]
    "apply_patch" =>
      ["read", "moon_ide", "apply_patch", "moon_cmd", "moon_check", "finish"]
    "revert_patch" =>
      ["read", "moon_ide", "revert_patch", "moon_cmd", "moon_check", "finish"]
    "approve_tool" | "reject_tool" => ["finish"]
    "prompt" | "steer" =>
      ["moon_ide", "read", "edit", "write", "moon_cmd", "moon_check", "finish"]
    "cancel" => ["finish"]
    _ => ["finish"]
  }
}

///|
pub fn native_command_expected_events(action : String) -> Array[String] {
  match action {
    "run_tests" | "run_build" =>
      [
        event_tool_call(),
        event_tool_result(),
        event_test_result(),
        event_runtime_finished(),
      ]
    "run_eval" =>
      [
        event_tool_call(),
        event_tool_result(),
        event_test_result(),
        "eval_report.manifest",
        event_runtime_finished(),
      ]
    "package" =>
      [
        event_tool_call(),
        event_tool_result(),
        event_artifact(),
        "package.manifest",
        "package.index",
        event_package_verified(),
        event_runtime_finished(),
      ]
    "commit" =>
      [
        event_tool_call(),
        event_tool_result(),
        event_commit_created(),
        event_runtime_finished(),
      ]
    "apply_patch" =>
      [
        event_tool_call(),
        event_diff(),
        event_patch_applied(),
        event_test_result(),
        event_runtime_finished(),
      ]
    "revert_patch" =>
      [
        event_tool_call(),
        event_diff(),
        event_patch_reverted(),
        event_test_result(),
        event_runtime_finished(),
      ]
    "accept" | "reject" =>
      ["review.receipt", event_artifact(), event_runtime_finished()]
    "approve_tool" | "reject_tool" =>
      ["tool_authorization", "review.receipt", event_runtime_finished()]
    "prompt" | "steer" =>
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
    "cancel" => [event_runtime_aborted(), event_runtime_finished()]
    _ => [event_runtime_update(), event_runtime_finished()]
  }
}

///|
pub fn native_command_required_outputs(action : String) -> Array[String] {
  match action {
    "run_tests" => ["test command", "exit code", "test_result event"]
    "run_build" => ["build command", "exit code", "test_result event"]
    "run_eval" =>
      [
        "tool_harness result", "file_edit result", "patch_review result", "command_execution result",
        "package_output result", "native eval report", "eval_report.manifest event",
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
    "run_build" =>
      if context_path.has_suffix(".mbt") || context_path.contains("moon.pkg") {
        ["moon build", "moon check"]
      } else {
        [
          "moon build", "moon check", "package-specific build command if present",
        ]
      }
    "run_eval" =>
      [
        "run tool_harness eval fixtures",
        "run file_edit eval fixtures",
        "run patch_review eval fixtures",
        "run command_execution eval fixtures",
        "run package_output eval fixtures",
        "POST \{desktop_session_eval_report_endpoint()}",
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
