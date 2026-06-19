///|
// MoonCode readiness telemetry for the end-to-end workspace success criteria.

///|
pub fn readiness_check(
  id : String,
  label : String,
  ok : Bool,
  evidence : String,
) -> Json {
  { "id": id, "label": label, "ok": ok, "evidence": evidence }
}

///|
pub fn session_readiness_checks(
  session : Json,
  events : Array[Json],
) -> Array[Json] {
  let workspace_id = json_string(session, "workspace_id", default="")
  let runtime_session_id = json_string(
    session,
    "mooncode_runtime_session_id",
    default=json_string(session, "id", default=""),
  )
  let transcript_count = count_lane(events, "transcript")
  let runtime_count = count_lane(events, "runtime")
  let tool_count = count_lane(events, "tool")
  let diff_count = count_lane(events, "diff")
  let test_count = count_lane(events, "test")
  let artifact_count = count_lane(events, "artifact")
  let review_count = count_lane(events, "review")
  let verified_test_count = count_verified_tests(events)
  let failed_test_count = count_failed_tests(events)
  let command_packet_count = count_command_packets(events)
  let review_receipt_count = count_review_receipts(events)
  let package_manifest_count = count_package_manifests(events)
  let package_index_manifest_count = count_package_index_manifests(events)
  let change_set_manifest_count = count_change_set_manifests(events)
  let patch_set_manifest_count = count_patch_set_manifests(events)
  let test_runs_manifest_count = count_test_runs_manifests(events)
  let eval_report_manifest_count = count_eval_report_manifests(events)
  let runtime_handoff_manifest_count = count_runtime_handoff_manifests(events)
  let runtime_supervisor_readiness = session_runtime_supervisor_readiness(
    session,
  )
  let runtime_supervisor_status = json_string(
    runtime_supervisor_readiness,
    "status",
    default="",
  )
  let runtime_supervisor_missing_count = summary_json_int(
    runtime_supervisor_readiness,
    "missing_requirement_count",
    default=0,
  )
  let native_eval_report = summary_json_object_field_or_empty(
    session, "mooncode_native_eval_report",
  )
  let native_eval_harness_count = native_eval_report_harnesses(
    native_eval_report,
  ).length()
  let native_eval_passed_harness_count = native_eval_passed_harness_count(
    native_eval_report_harnesses(native_eval_report),
  )
  let native_eval_missing_count = native_eval_missing_required_harnesses(
    native_eval_report,
  ).length()
  let native_eval_ready = native_eval_report_ready(native_eval_report) &&
    eval_report_manifest_count > 0
  let action_plan = summary_json_object_field_or_empty(
    session, "mooncode_last_action_plan_manifest",
  )
  let action_plan_ready = json_string(action_plan, "kind", default="") ==
    "mooncode-action-plan"
  let action_plan_status = json_string(action_plan, "status", default="")
  let next_required_action = json_string(
    action_plan,
    "next_required_action",
    default="",
  )
  let blocked_action_count = summary_json_int(
    action_plan,
    "blocked_count",
    default=0,
  )
  let pending_runtime_count = summary_json_int(
    action_plan,
    "pending_runtime_count",
    default=0,
  )
  let running_count = summary_json_int(action_plan, "running_count", default=0)
  let pending_action_diff_count = summary_json_int(
    action_plan,
    "pending_diff_count",
    default=0,
  )
  let patch_needs_review_count = summary_json_int(
    action_plan,
    "patch_needs_review_count",
    default=0,
  )
  let patch_runtime_needed_count = summary_json_int(
    action_plan,
    "patch_runtime_needed_count",
    default=0,
  )
  let partial_patch_count = summary_json_int(
    action_plan,
    "partial_patch_count",
    default=0,
  )
  let runtime_partial_patch_count = summary_json_int(
    action_plan,
    "runtime_partial_patch_count",
    default=0,
  )
  let pending_action_tool_approval_count = summary_json_int(
    action_plan,
    "pending_tool_approval_count",
    default=0,
  )
  let pending_action_steer_count = summary_json_int(
    action_plan,
    "pending_steer_count",
    default=0,
  )
  let failed_action_test_count = summary_json_int(
    action_plan,
    "failed_test_count",
    default=failed_test_count,
  )
  let source_bound_package_count = count_source_bound_packages(
    session, package_manifest_count,
  )
  let runtime_package_proof_count = count_package_runtime_proofs(events)
  let runtime_verified_package_count = count_package_runtime_state(
    events, "verified",
  )
  let append_log_count = summary_json_int(
    session,
    "mooncode_append_log_count",
    default=0,
  )
  let command_log_count = summary_json_int(
    session,
    "mooncode_command_log_count",
    default=0,
  )
  let runtime_command_log_count = summary_json_int(
    session,
    "mooncode_runtime_command_log_count",
    default=0,
  )
  let runtime_dispatch_log_count = summary_json_int(
    session,
    "mooncode_runtime_dispatch_log_count",
    default=0,
  )
  let snapshot = summary_json_object_field_or_empty(
    session, "mooncode_session_snapshot",
  )
  let session_snapshot_ready = json_string(snapshot, "kind", default="") ==
    "mooncode-session-snapshot"
  let resume_lifecycle = session_resume_lifecycle(session, events)
  let resume_status = json_string(resume_lifecycle, "latest_status", default="")
  let resume_ok = json_bool(resume_lifecycle, "snapshot_ready", default=false) &&
    resume_status != "missing-snapshot" &&
    resume_status != "blocked"
  let package_lifecycle = session_package_lifecycle(session, events)
  let package_lifecycle_status = json_string(
    package_lifecycle,
    "latest_status",
    default="",
  )
  let package_lifecycle_verified = package_lifecycle_status == "verified" &&
    summary_json_int(
      package_lifecycle,
      "runtime_verified_package_count",
      default=0,
    ) >
    0 &&
    summary_json_int(package_lifecycle, "executable_ready_count", default=0) > 0
  [
    readiness_check(
      "moonbook_selected",
      "MoonBook selected",
      workspace_id != "",
      if workspace_id == "" {
        "no selected workspace id"
      } else {
        workspace_id
      },
    ),
    readiness_check(
      "runtime_session_attached",
      "MoonCode runtime session attached",
      runtime_session_id != "",
      if runtime_session_id == "" {
        "no MoonCode runtime session id"
      } else {
        runtime_session_id
      },
    ),
    readiness_check(
      "durable_session",
      "Durable session",
      append_log_count > 0 && command_log_count > 0 && session_snapshot_ready,
      "\{append_log_count} event(s), \{command_log_count} command(s), snapshot \{if session_snapshot_ready { "ready" } else { "missing" }}",
    ),
    readiness_check(
      "resume_lifecycle",
      "Resume lifecycle",
      resume_ok,
      "status \{empty_readiness_label(resume_status)}, pending \{summary_json_int(resume_lifecycle, "pending_count", default=0)}, running \{summary_json_int(resume_lifecycle, "running_count", default=0)}, blocked \{summary_json_int(resume_lifecycle, "blocked_count", default=0)}",
    ),
    readiness_check(
      "runtime_supervisor_ready",
      "Runtime supervisor ready",
      json_bool(runtime_supervisor_readiness, "ok", default=false),
      "status \{empty_readiness_label(runtime_supervisor_status)}, missing requirements \{runtime_supervisor_missing_count}",
    ),
    readiness_check(
      "native_eval_ready",
      "Native eval ready",
      native_eval_ready,
      "status \{empty_readiness_label(json_string(native_eval_report, "status", default=""))}, manifest \{eval_report_manifest_count}, harnesses \{native_eval_passed_harness_count}/\{required_native_eval_harness_ids().length()} passed, missing required \{native_eval_missing_count}, total \{native_eval_harness_count}",
    ),
    readiness_check(
      "chat_transcript",
      "Chat transcript",
      transcript_count > 0,
      "\{transcript_count} transcript event(s)",
    ),
    readiness_check(
      "typed_command_queue",
      "Typed command queue",
      command_packet_count > 0 && runtime_command_log_count > 0,
      "\{command_packet_count} command packet(s), \{runtime_command_log_count} runtime command(s)",
    ),
    readiness_check(
      "live_runtime_stream",
      "Live runtime stream",
      runtime_count > 0 && runtime_dispatch_log_count > 0,
      "\{runtime_count} runtime event(s), \{runtime_dispatch_log_count} dispatch receipt(s)",
    ),
    readiness_check(
      "tool_execution",
      "Tool execution",
      tool_count > 0,
      "\{tool_count} tool event(s)",
    ),
    readiness_check(
      "diff_review",
      "Diff review",
      diff_count > 0 &&
      change_set_manifest_count > 0 &&
      patch_set_manifest_count > 0,
      "\{diff_count} diff event(s), \{change_set_manifest_count} change-set manifest(s), \{patch_set_manifest_count} patch-set manifest(s)",
    ),
    readiness_check(
      "test_build_execution",
      "Test/build execution",
      test_count > 0 &&
      verified_test_count > 0 &&
      failed_test_count == 0 &&
      test_runs_manifest_count > 0,
      if failed_test_count > 0 {
        "\{failed_test_count} failing test/build result(s)"
      } else {
        "\{verified_test_count} verified result(s), \{test_runs_manifest_count} test-run manifest(s)"
      },
    ),
    readiness_check(
      "review_receipts",
      "Review receipts",
      review_count > 0 && review_receipt_count > 0,
      "\{review_count} review event(s), \{review_receipt_count} MoonBook receipt(s)",
    ),
    readiness_check(
      "package_result",
      "Package result",
      artifact_count > 0 &&
      source_bound_package_count > 0 &&
      package_index_manifest_count > 0 &&
      runtime_verified_package_count > 0,
      "\{artifact_count} artifact event(s), \{source_bound_package_count} source-bound package(s), \{package_index_manifest_count} package index manifest(s), \{runtime_verified_package_count}/\{runtime_package_proof_count} verified runtime package proof",
    ),
    readiness_check(
      "package_lifecycle",
      "Package lifecycle",
      package_lifecycle_verified,
      "status \{empty_readiness_label(package_lifecycle_status)}, executable-ready \{summary_json_int(package_lifecycle, "executable_ready_count", default=0)}, verified \{summary_json_int(package_lifecycle, "runtime_verified_package_count", default=0)}",
    ),
    readiness_check(
      "action_plan_current",
      "Current action plan",
      action_plan_ready,
      if action_plan_ready {
        "status \{empty_readiness_label(action_plan_status)}, next \{empty_readiness_label(next_required_action)}"
      } else {
        "no MoonBook action-plan manifest"
      },
    ),
    readiness_check(
      "live_blockers_clear",
      "Live blockers clear",
      action_plan_ready &&
      blocked_action_count == 0 &&
      pending_action_diff_count == 0 &&
      patch_needs_review_count == 0 &&
      patch_runtime_needed_count == 0 &&
      partial_patch_count == 0 &&
      runtime_partial_patch_count == 0 &&
      pending_action_tool_approval_count == 0 &&
      pending_action_steer_count == 0 &&
      failed_action_test_count == 0,
      "blocked \{blocked_action_count}, pending runtime \{pending_runtime_count}, running \{running_count}, pending diffs \{pending_action_diff_count}, patch needs-review \{patch_needs_review_count}, patch runtime-needed \{patch_runtime_needed_count}, partial patches \{partial_patch_count}, runtime partial patches \{runtime_partial_patch_count}, pending tools \{pending_action_tool_approval_count}, pending steers \{pending_action_steer_count}, failing tests \{failed_action_test_count}",
    ),
    readiness_check(
      "standalone_boundary",
      "Standalone MoonCode boundary",
      runtime_handoff_manifest_count > 0,
      "\{runtime_handoff_manifest_count} runtime handoff manifest(s); MoonCode owns protocol/projection while MoonClaw owns execution",
    ),
  ]
}

///|
fn empty_readiness_label(value : String) -> String {
  if value == "" {
    "empty"
  } else {
    value
  }
}

///|
fn session_runtime_supervisor_readiness(session : Json) -> Json {
  let handoff = summary_json_object_field_or_empty(
    session, "mooncode_last_runtime_handoff_manifest",
  )
  let supervisor = summary_json_object_field_or_empty(
    handoff, "runtime_supervisor",
  )
  runtime_supervisor_readiness_report(supervisor)
}
