///|
pub fn command_is_supported(action : String) -> Bool {
  match action {
    "prompt"
    | "steer"
    | "run_tests"
    | "run_eval"
    | "package"
    | "commit"
    | "accept"
    | "reject"
    | "approve_tool"
    | "reject_tool"
    | "apply_patch"
    | "revert_patch"
    | "cancel"
    | "note" => true
    _ => false
  }
}

///|
pub fn command_dispatch(action : String) -> String {
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
    "run_tests" | "run_eval" => "auto"
    "cancel" => "operator"
    "prompt" | "steer" => "user"
    _ => "none"
  }
}

///|
pub fn command_tool_hints(action : String) -> Array[String] {
  match action {
    "run_tests" => ["moon_check", "shell"]
    "run_eval" => ["eval_harness", "shell", "moon_check"]
    "package" => ["package_app_tool", "moon_check", "shell"]
    "commit" => ["read", "moon_check", "shell", "finish"]
    "accept" => ["finish", "package_app_tool"]
    "reject" => ["finish"]
    "approve_tool" | "reject_tool" =>
      ["read", "edit", "write", "shell", "moon_check"]
    "apply_patch" => ["apply_patch", "moon_check"]
    "revert_patch" => ["apply_patch", "moon_check"]
    "prompt" | "steer" =>
      ["read", "edit", "write", "shell", "moon_check", "finish"]
    "cancel" => []
    _ => []
  }
}

///|
pub fn command_expected_lanes(action : String) -> Array[String] {
  match action {
    "run_tests" => ["test", "tool", "runtime"]
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
    "run_tests" => "test"
    "run_eval" => "test"
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

///|
pub fn command_action(payload : Json) -> String {
  trimmed_or(json_string(payload, "action", default="note"), fallback="note")
}

///|
pub fn command_context_path(payload : Json) -> String {
  trimmed_or(json_string(payload, "context_path", default=""), fallback="")
}

///|
pub fn command_target_label(payload : Json) -> String {
  let context_path = command_context_path(payload)
  if context_path == "" {
    "this MoonBook code workspace"
  } else {
    "`\{context_path}`"
  }
}

///|
pub fn command_message(action : String, payload : Json) -> String {
  let explicit = trimmed_or(
    json_string(payload, "message", default=""),
    fallback="",
  )
  if explicit != "" {
    return explicit
  }
  let target = command_target_label(payload)
  match action {
    "run_tests" =>
      "Run the relevant tests or build checks for \{target}. Report the exact command, result, failures, and next fix."
    "run_eval" =>
      "Run the OpenSeek-style MoonCode eval harnesses for \{target}, especially tool_harness and file_edit. Publish the native eval report to `/v1/mooncode/sessions/<id>/eval-report?book_root=<path>` or POST equivalent proof to Moondesk's eval-report ingest endpoint, including harness ids, pass/fail counts, evidence, and failure details."
    "package" =>
      "Package the current accepted executable output for \{target} as a reusable tool, miniapp, generated site, or app-tool artifact. Preserve paths, emit a `package_verified` runtime proof event after bundle checks pass, and report the artifact location."
    "commit" =>
      "Commit the accepted and tested MoonBook code changes for \{target}. Keep the git operation inside the selected MoonBook workspace, use a concise review-ready commit message, emit a `commit_created` runtime proof event with the commit SHA after success, and report any uncommitted leftovers."
    "accept" =>
      "The operator accepts the current useful code changes and artifacts for \{target}. Finalize them into the MoonBook-owned output layout, leave a concise review note, and package any executable artifact that is ready."
    "reject" =>
      "The operator rejects the current proposed code changes or generated artifacts for \{target}. Do not promote them into accepted MoonBook output. Explain what should be discarded, what can be kept as notes, and what safer next step is recommended."
    "approve_tool" =>
      "Approve the selected MoonCode tool call for \{target}. Continue only within the selected MoonBook workspace, preserve tool output as stream events, and report any file, shell, or artifact effects."
    "reject_tool" =>
      "Reject the selected MoonCode tool call for \{target}. Do not execute or promote that tool result. Explain why it was rejected and propose a safer bounded alternative."
    "apply_patch" =>
      "Apply the selected reviewed patch for \{target}. Keep the change inside the MoonBook workspace, preserve a diff/test trail, emit a `patch_applied` runtime proof event, and report the exact file paths changed."
    "revert_patch" =>
      "Revert the selected patch for \{target}. Keep the revert inside the MoonBook workspace, preserve a diff/test trail, emit a `patch_reverted` runtime proof event, and report the exact file paths restored."
    "cancel" => "Cancel the current MoonCode/MoonClaw work for this session."
    "steer" =>
      "Continue the current MoonCode session with the selected MoonBook context. Focus on executable code changes, tests, diffs, and packaging readiness."
    "prompt" => "Continue the current MoonCode session for this MoonBook."
    _ => "MoonCode note recorded."
  }
}
