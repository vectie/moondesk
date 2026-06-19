///|
pub fn command_advertised_actions() -> Array[String] {
  [
    "prompt", "steer", "run_tests", "run_build", "run_eval", "package", "commit",
    "accept", "reject", "approve_tool", "reject_tool", "apply_patch", "revert_patch",
    "cancel",
  ]
}

///|
pub fn command_supported_actions() -> Array[String] {
  let actions = command_advertised_actions()
  actions.push("note")
  actions
}

///|
pub fn command_is_supported(action : String) -> Bool {
  command_supported_actions().contains(action)
}

///|
pub fn command_control(action : String) -> String {
  match action {
    "prompt" => "prompt"
    "steer" => "steer"
    "cancel" => "cancel"
    _ => "command"
  }
}

///|
pub fn command_approval(action : String) -> String {
  match action {
    "accept" | "reject" | "package" | "commit" => "operator"
    "approve_tool" | "reject_tool" => "operator"
    "apply_patch" | "revert_patch" => "operator"
    "run_tests" | "run_build" | "run_eval" => "auto"
    "cancel" => "operator"
    "prompt" | "steer" => "user"
    _ => "none"
  }
}

///|
pub fn command_tool_hints(action : String) -> Array[String] {
  match action {
    "run_tests" | "run_build" => ["moon_ide", "moon_cmd", "moon_check", "shell"]
    "run_eval" =>
      ["eval_harness", "moon_ide", "moon_cmd", "shell", "moon_check"]
    "package" =>
      ["package_app_tool", "moon_ide", "moon_cmd", "moon_check", "shell"]
    "commit" =>
      ["read", "moon_ide", "moon_cmd", "moon_check", "shell", "finish"]
    "accept" => ["finish", "package_app_tool"]
    "reject" => ["finish"]
    "approve_tool" | "reject_tool" =>
      ["read", "edit", "write", "shell", "moon_ide", "moon_cmd", "moon_check"]
    "apply_patch" => ["moon_ide", "apply_patch", "moon_cmd", "moon_check"]
    "revert_patch" => ["moon_ide", "revert_patch", "moon_cmd", "moon_check"]
    "prompt" | "steer" =>
      [
        "moon_ide", "read", "edit", "write", "shell", "moon_cmd", "moon_check", "finish",
      ]
    "cancel" => []
    _ => []
  }
}

///|
pub fn command_expected_lanes(action : String) -> Array[String] {
  match action {
    "run_tests" | "run_build" => ["test", "tool", "runtime"]
    "run_eval" => ["runtime", "test", "review"]
    "package" => ["artifact", "test", "review"]
    "commit" => ["review", "runtime", "tool"]
    "accept" | "reject" => ["review", "artifact"]
    "approve_tool" | "reject_tool" => ["tool", "runtime", "review"]
    "apply_patch" | "revert_patch" => ["diff", "test", "review"]
    "prompt" | "steer" =>
      ["transcript", "runtime", "tool", "diff", "test", "artifact", "review"]
    "cancel" => ["runtime"]
    _ => ["runtime"]
  }
}

///|
pub fn command_lane(action : String) -> String {
  match action {
    "run_tests" | "run_build" | "run_eval" => "test"
    "package" => "artifact"
    "commit" => "review"
    "accept"
    | "reject"
    | "approve_tool"
    | "reject_tool"
    | "apply_patch"
    | "revert_patch" => "review"
    "prompt" | "steer" | "cancel" => "runtime"
    _ => "runtime"
  }
}

///|
pub fn command_title(action : String, status : String) -> String {
  let label = match action {
    "run_tests" => "Run tests"
    "run_build" => "Run build"
    "run_eval" => "Run eval"
    "package" => "Package result"
    "commit" => "Commit result"
    "accept" => "Accept result"
    "reject" => "Reject result"
    "approve_tool" => "Approve tool"
    "reject_tool" => "Reject tool"
    "apply_patch" => "Apply patch"
    "revert_patch" => "Revert patch"
    "cancel" => "Cancel session"
    "prompt" => "Prompt"
    "steer" => "Steer"
    _ => "Note"
  }
  "\{label}: \{status}"
}
