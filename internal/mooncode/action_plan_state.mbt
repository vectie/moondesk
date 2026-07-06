///|
// MoonCode action-plan item-state gate helpers.

///|
fn action_plan_item_state_with_tool_harness(
  action : String,
  runtime_state : String,
  state : String,
  runtime_evidence : Json,
) -> String {
  if runtime_state != @mooncode_core.runtime_claim_status_delivered() ||
    !action_plan_action_requires_tool_harness(action) ||
    state == @mooncode_core.action_plan_state_blocked() ||
    state == @mooncode_core.action_plan_state_queued_for_runtime() ||
    state == @mooncode_core.action_plan_state_running() ||
    state == @mooncode_core.action_plan_state_runtime_retry() {
    return state
  }
  @mooncode_core.action_plan_state_with_tool_harness(
    action,
    runtime_state,
    state,
    runtime_json_int(
      runtime_evidence,
      "tool_harness_expected_tool_count",
      default=0,
    ),
    json_string(runtime_evidence, "tool_harness_status", default=""),
  )
}

///|
fn action_plan_action_requires_tool_harness(action : String) -> Bool {
  @mooncode_core.command_action_requires_tool_harness(action)
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
  let precondition = @mooncode_core.action_plan_runtime_state_precondition_state(
    runtime_state,
  )
  if precondition != "" {
    return precondition
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
  if action == command_run_tests() {
    if failed_tests > 0 {
      @mooncode_core.action_plan_state_blocked()
    } else if command_proofs_are_scoped(proof_events, action) {
      if command_verified_tests > 0 {
        @mooncode_core.action_plan_state_completed()
      } else {
        @mooncode_core.action_plan_state_awaiting_proof()
      }
    } else if verified_tests > 0 {
      @mooncode_core.action_plan_state_completed()
    } else {
      @mooncode_core.action_plan_state_awaiting_proof()
    }
  } else if action == command_run_eval() {
    let eval_report = runtime_json_object_field_or_empty(
      summary, "last_moonbook_eval_report_manifest",
    )
    if json_bool(eval_report, "native_eval_ready", default=false) {
      @mooncode_core.action_plan_state_completed()
    } else {
      @mooncode_core.action_plan_state_awaiting_proof()
    }
  } else if action == command_package() {
    if failed_tests > 0 {
      @mooncode_core.action_plan_state_blocked()
    } else if command_proofs_are_scoped(proof_events, action) {
      if command_source_bound_packages > 0 {
        @mooncode_core.action_plan_state_completed()
      } else {
        @mooncode_core.action_plan_state_ready_for_review()
      }
    } else if source_bound > 0 {
      @mooncode_core.action_plan_state_completed()
    } else {
      @mooncode_core.action_plan_state_ready_for_review()
    }
  } else if action == command_accept() {
    if failed_tests > 0 ||
      pending_approvals > 0 ||
      (pending_diffs > 0 && verified_tests == 0) {
      @mooncode_core.action_plan_state_blocked()
    } else {
      @mooncode_core.action_plan_state_ready_for_review()
    }
  } else if action == command_commit() {
    if failed_tests > 0 ||
      pending_approvals > 0 ||
      (pending_diffs > 0 && verified_tests == 0) {
      @mooncode_core.action_plan_state_blocked()
    } else if command_proofs_are_scoped(proof_events, action) {
      if command_commit_proofs > 0 {
        @mooncode_core.action_plan_state_completed()
      } else {
        @mooncode_core.action_plan_state_awaiting_proof()
      }
    } else if runtime_commit_proofs > 0 {
      @mooncode_core.action_plan_state_completed()
    } else {
      @mooncode_core.action_plan_state_awaiting_proof()
    }
  } else if action == command_reject() ||
    @mooncode_core.command_action_is_tool_approval(action) ||
    @mooncode_core.command_action_is_patch(action) {
    @mooncode_core.action_plan_state_ready_for_review()
  } else if action == command_cancel() {
    @mooncode_core.action_plan_state_completed()
  } else {
    @mooncode_core.action_plan_state_completed()
  }
}
