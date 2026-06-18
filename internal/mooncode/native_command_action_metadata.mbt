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
    "apply_patch" | "revert_patch" =>
      ["read", "moon_ide", "apply_patch", "moon_cmd", "moon_check", "finish"]
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
      ["tool_call", "tool_result", "test_result", "agent_finished"]
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
    "run_build" => ["build command", "exit code", "test_result event"]
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
