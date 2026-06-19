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
    "run_build" =>
      "Run the relevant build checks for \{target}. Prefer the structured MoonBit build command when available, report the exact command, result, failures, and next fix."
    "run_eval" =>
      "Run the MoonCode-style MoonCode eval harnesses for \{target}, especially tool_harness and file_edit. Publish the native eval report to `/v1/code/sessions/<id>/eval-report?book_root=<path>` or POST equivalent proof to Moondesk's eval-report ingest endpoint, including harness ids, pass/fail counts, evidence, and failure details."
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
