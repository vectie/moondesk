///|
// MoonCode action-plan item-state gate helpers.

///|
fn action_plan_item_state_with_tool_harness(
  action : String,
  runtime_state : String,
  state : String,
  runtime_evidence : Json,
) -> String {
  if runtime_state != "delivered" ||
    !action_plan_action_requires_tool_harness(action) ||
    state == "blocked" ||
    state == "queued-for-runtime" ||
    state == "running" ||
    state == "runtime-retry" {
    return state
  }
  if runtime_json_int(
      runtime_evidence,
      "tool_harness_expected_tool_count",
      default=0,
    ) ==
    0 {
    return state
  }
  match json_string(runtime_evidence, "tool_harness_status", default="") {
    "proven" | "no-tools" => state
    "failed" => "runtime-retry"
    _ => "awaiting-proof"
  }
}

///|
fn action_plan_action_requires_tool_harness(action : String) -> Bool {
  match action {
    "prompt"
    | "steer"
    | "run_tests"
    | "run_eval"
    | "package"
    | "commit"
    | "accept"
    | "apply_patch"
    | "revert_patch" => true
    _ => false
  }
}

///|
pub fn action_plan_item_state(
  action : String,
  runtime_state : String,
  summary : Json,
) -> String {
  action_plan_item_state_for_command(action, "", runtime_state, summary, [])
}

///|
pub fn action_plan_item_state_for_command(
  action : String,
  command_id : String,
  runtime_state : String,
  summary : Json,
  proof_events : Array[Json],
) -> String {
  if runtime_state == "failed" || runtime_state == "expired-claim" {
    return "runtime-retry"
  }
  if runtime_state == "claimed" {
    return "running"
  }
  if runtime_state == "pending" || runtime_state == "not-recorded" {
    return "queued-for-runtime"
  }
  let verified_tests = runtime_json_int(
    summary,
    "verified_test_count",
    default=0,
  )
  let failed_tests = runtime_json_int(summary, "failed_test_count", default=0)
  let source_bound = runtime_json_int(
    summary,
    "source_bound_package_count",
    default=0,
  )
  let pending_diffs = runtime_json_int(summary, "pending_diff_count", default=0)
  let pending_approvals = runtime_json_int(
    summary,
    "pending_tool_approval_count",
    default=0,
  )
  let runtime_commit_proofs = runtime_json_int(
    summary,
    "runtime_commit_proof_count",
    default=0,
  )
  let command_verified_tests = command_proof_count(
    proof_events,
    command_id,
    action,
    proof_kind=event_test_result(),
  )
  let command_source_bound_packages = command_proof_count(
      proof_events,
      command_id,
      action,
      proof_kind="package.manifest",
    ) +
    command_proof_count(
      proof_events,
      command_id,
      action,
      proof_kind="runtime.package_verified",
    )
  let command_commit_proofs = command_proof_count(
    proof_events,
    command_id,
    action,
    proof_kind="runtime.commit_created",
  )
  match action {
    "run_tests" =>
      if failed_tests > 0 {
        "blocked"
      } else if command_proofs_are_scoped(proof_events, action) {
        if command_verified_tests > 0 {
          "completed"
        } else {
          "awaiting-proof"
        }
      } else if verified_tests > 0 {
        "completed"
      } else {
        "awaiting-proof"
      }
    "run_eval" => {
      let eval_report = runtime_json_object_field_or_empty(
        summary, "last_moonbook_eval_report_manifest",
      )
      if json_bool(eval_report, "native_eval_evidence_ready", default=false) {
        "completed"
      } else {
        "awaiting-proof"
      }
    }
    "package" =>
      if failed_tests > 0 {
        "blocked"
      } else if command_proofs_are_scoped(proof_events, action) {
        if command_source_bound_packages > 0 {
          "completed"
        } else {
          "ready-for-review"
        }
      } else if source_bound > 0 {
        "completed"
      } else {
        "ready-for-review"
      }
    "accept" =>
      if failed_tests > 0 ||
        pending_approvals > 0 ||
        (pending_diffs > 0 && verified_tests == 0) {
        "blocked"
      } else {
        "ready-for-review"
      }
    "commit" =>
      if failed_tests > 0 ||
        pending_approvals > 0 ||
        (pending_diffs > 0 && verified_tests == 0) {
        "blocked"
      } else if command_proofs_are_scoped(proof_events, action) {
        if command_commit_proofs > 0 {
          "completed"
        } else {
          "awaiting-proof"
        }
      } else if runtime_commit_proofs > 0 {
        "completed"
      } else {
        "awaiting-proof"
      }
    "reject"
    | "approve_tool"
    | "reject_tool"
    | "apply_patch"
    | "revert_patch" => "ready-for-review"
    "cancel" => "completed"
    _ => "completed"
  }
}
