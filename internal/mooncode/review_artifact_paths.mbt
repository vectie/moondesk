///|
pub fn change_set_manifest_relative_path(session_id : String) -> String {
  let safe_session = artifact_safe_id(session_id, fallback="session")
  "wiki/reviews/mooncode/\{safe_session}/change-set.json"
}

///|
pub fn patch_set_manifest_relative_path(session_id : String) -> String {
  let safe_session = artifact_safe_id(session_id, fallback="session")
  "wiki/reviews/mooncode/\{safe_session}/patch-set.json"
}

///|
pub fn tool_approvals_manifest_relative_path(session_id : String) -> String {
  let safe_session = artifact_safe_id(session_id, fallback="session")
  "wiki/reviews/mooncode/\{safe_session}/tool-approvals.json"
}

///|
pub fn test_runs_manifest_relative_path(session_id : String) -> String {
  let safe_session = artifact_safe_id(session_id, fallback="session")
  "wiki/reviews/mooncode/\{safe_session}/test-runs.json"
}

///|
pub fn action_plan_manifest_relative_path(session_id : String) -> String {
  let safe_session = artifact_safe_id(session_id, fallback="session")
  "wiki/reviews/mooncode/\{safe_session}/action-plan.json"
}

///|
pub fn runtime_evidence_manifest_relative_path(session_id : String) -> String {
  let safe_session = artifact_safe_id(session_id, fallback="session")
  "wiki/reviews/mooncode/\{safe_session}/runtime-evidence.json"
}

///|
pub fn eval_report_manifest_relative_path(session_id : String) -> String {
  let safe_session = artifact_safe_id(session_id, fallback="session")
  "wiki/reviews/mooncode/\{safe_session}/eval-report.json"
}

///|
pub fn runtime_handoff_manifest_relative_path(session_id : String) -> String {
  let safe_session = artifact_safe_id(session_id, fallback="session")
  "wiki/reviews/mooncode/\{safe_session}/runtime-handoff.json"
}

///|
pub fn review_receipt_relative_path(
  session_id : String,
  command_id : String,
  action : String,
) -> String {
  let safe_session = artifact_safe_id(session_id, fallback="session")
  let safe_command = artifact_safe_id(command_id, fallback="command")
  let safe_action = match action {
    "accept" => "accept"
    "reject" => "reject"
    "approve_tool" => "approve-tool"
    "reject_tool" => "reject-tool"
    "package" => "package"
    "apply_patch" => "apply-patch"
    "revert_patch" => "revert-patch"
    _ => "command"
  }
  "wiki/reviews/mooncode/\{safe_session}/\{safe_action}-\{safe_command}.json"
}

///|
pub fn command_writes_review_receipt(action : String) -> Bool {
  action == "accept" ||
  action == "reject" ||
  action == "package" ||
  action == "commit" ||
  action == "approve_tool" ||
  action == "reject_tool" ||
  action == "apply_patch" ||
  action == "revert_patch"
}

///|
pub fn package_manifest_relative_path(
  session_id : String,
  command_id : String,
) -> String {
  let safe_session = artifact_safe_id(session_id, fallback="session")
  let safe_command = artifact_safe_id(command_id, fallback="command")
  "portable/app-tool/mooncode/\{safe_session}/package-\{safe_command}.json"
}

///|
pub fn package_session_root_relative_path(session_id : String) -> String {
  let safe_session = artifact_safe_id(session_id, fallback="session")
  "portable/app-tool/mooncode/\{safe_session}"
}

///|
pub fn package_index_manifest_relative_path(session_id : String) -> String {
  "\{package_session_root_relative_path(session_id)}/index.json"
}

///|
pub fn artifact_safe_id(value : String, fallback~ : String) -> String {
  let trimmed = value.trim().to_owned()
  if trimmed == "" ||
    trimmed == "." ||
    trimmed == ".." ||
    trimmed.contains("/") ||
    trimmed.contains("\\") ||
    trimmed.contains(":") {
    fallback
  } else if trimmed.length() > 72 {
    fallback + "-" + artifact_id_digest(trimmed)
  } else {
    trimmed
  }
}

///|
fn artifact_id_digest(value : String) -> String {
  let digest = @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding/utf8.encode(value).to_fixedarray()),
  )
  digest[:16].to_owned()
}
