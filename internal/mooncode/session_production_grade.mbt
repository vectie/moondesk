///|
// MoonCode product-grade scoring for the end-to-end workspace success criteria.

///|
pub fn production_grade_check(
  id : String,
  label : String,
  ok : Bool,
  evidence : String,
) -> Json {
  { "id": id, "label": label, "ok": ok, "evidence": evidence }
}

///|
pub fn session_production_checks(
  session : Json,
  events : Array[Json],
) -> Array[Json] {
  let workspace_id = json_string(session, "workspace_id", default="")
  let task_id = json_string(session, "moonclaw_task_id", default="")
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
  let runtime_handoff_manifest_count = count_runtime_handoff_manifests(events)
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
  [
    production_grade_check(
      "moonbook_selected",
      "MoonBook selected",
      workspace_id != "",
      if workspace_id == "" {
        "no selected workspace id"
      } else {
        workspace_id
      },
    ),
    production_grade_check(
      "moonclaw_attached",
      "MoonClaw session attached",
      task_id != "",
      if task_id == "" {
        "no MoonClaw task id"
      } else {
        task_id
      },
    ),
    production_grade_check(
      "durable_session",
      "Durable session",
      append_log_count > 0 && command_log_count > 0 && session_snapshot_ready,
      "\{append_log_count} event(s), \{command_log_count} command(s), snapshot \{if session_snapshot_ready { "ready" } else { "missing" }}",
    ),
    production_grade_check(
      "chat_transcript",
      "Chat transcript",
      transcript_count > 0,
      "\{transcript_count} transcript event(s)",
    ),
    production_grade_check(
      "typed_command_queue",
      "Typed command queue",
      command_packet_count > 0 && runtime_command_log_count > 0,
      "\{command_packet_count} command packet(s), \{runtime_command_log_count} runtime command(s)",
    ),
    production_grade_check(
      "live_runtime_stream",
      "Live runtime stream",
      runtime_count > 0 && runtime_dispatch_log_count > 0,
      "\{runtime_count} runtime event(s), \{runtime_dispatch_log_count} dispatch receipt(s)",
    ),
    production_grade_check(
      "tool_execution",
      "Tool execution",
      tool_count > 0,
      "\{tool_count} tool event(s)",
    ),
    production_grade_check(
      "diff_review",
      "Diff review",
      diff_count > 0 &&
      change_set_manifest_count > 0 &&
      patch_set_manifest_count > 0,
      "\{diff_count} diff event(s), \{change_set_manifest_count} change-set manifest(s), \{patch_set_manifest_count} patch-set manifest(s)",
    ),
    production_grade_check(
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
    production_grade_check(
      "review_receipts",
      "Review receipts",
      review_count > 0 && review_receipt_count > 0,
      "\{review_count} review event(s), \{review_receipt_count} MoonBook receipt(s)",
    ),
    production_grade_check(
      "package_result",
      "Package result",
      artifact_count > 0 &&
      source_bound_package_count > 0 &&
      package_index_manifest_count > 0 &&
      runtime_verified_package_count > 0,
      "\{artifact_count} artifact event(s), \{source_bound_package_count} source-bound package(s), \{package_index_manifest_count} package index manifest(s), \{runtime_verified_package_count}/\{runtime_package_proof_count} verified runtime package proof",
    ),
    production_grade_check(
      "extractable_boundary",
      "Extractable MoonCode boundary",
      runtime_handoff_manifest_count > 0,
      "\{runtime_handoff_manifest_count} runtime handoff manifest(s); MoonCode owns protocol/projection while MoonClaw owns execution",
    ),
  ]
}

///|
pub fn production_grade_score(checks : Array[Json]) -> Int {
  if checks.length() == 0 {
    return 0
  }
  production_grade_passed_count(checks) * 100 / checks.length()
}

///|
pub fn production_grade_level(checks : Array[Json]) -> String {
  let score = production_grade_score(checks)
  if score >= 95 {
    "production-grade"
  } else if score >= 80 {
    "near-production"
  } else if score >= 60 {
    "working-slice"
  } else if score > 0 {
    "prototype"
  } else {
    "empty"
  }
}

///|
pub fn production_grade_passed_count(checks : Array[Json]) -> Int {
  let mut passed = 0
  for check in checks {
    if json_bool(check, "ok", default=false) {
      passed += 1
    }
  }
  passed
}
