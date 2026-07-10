///|
pub fn session_eval_checks(session : Json, events : Array[Json]) -> Array[Json] {
  let runtime_session_id = json_string(
    session,
    "mooncode_runtime_session_id",
    default=json_string(session, "id", default=""),
  )
  let workspace_id = json_string(session, "workspace_id", default="")
  let canonical_conversation = session_canonical_conversation(session)
  let canonical_turn_count = summary_json_int(
    canonical_conversation,
    "turn_count",
    default=0,
  )
  let tool_count = count_lane(events, event_lane_tool())
  let diff_count = count_lane(events, event_lane_diff())
  let test_count = count_lane(events, event_lane_test())
  let artifact_count = count_lane(events, event_lane_artifact())
  let review_count = count_lane(events, event_lane_review())
  let command_packet_count = count_command_packets(events)
  let review_receipt_count = count_review_receipts(events)
  let package_manifest_count = count_package_manifests(events)
  let package_index_manifest_count = count_package_index_manifests(events)
  let change_set_manifest_count = count_change_set_manifests(events)
  let patch_set_manifest_count = count_patch_set_manifests(events)
  let patch_execution_proof_count = count_patch_execution_proofs(events)
  let tool_approvals_manifest_count = count_tool_approvals_manifests(events)
  let test_runs_manifest_count = count_test_runs_manifests(events)
  let runtime_handoff_manifest_count = count_runtime_handoff_manifests(events)
  let pending_tool_approval_count = count_tool_approval_state(
    tool_approval_entries(events),
    "pending",
  )
  let verified_test_count = count_verified_tests(events)
  let failed_test_count = count_failed_tests(events)
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
  let snapshot = summary_json_object_field_or_empty(
    session, "mooncode_session_snapshot",
  )
  let session_snapshot_ready = json_string(snapshot, "kind", default="") ==
    "mooncode-session-snapshot"
  [
    eval_check(
      "book_scope",
      "Book scope",
      workspace_id != "",
      if workspace_id == "" {
        "session has no workspace id"
      } else {
        workspace_id
      },
    ),
    eval_check(
      "runtime_session_attached",
      "MoonCode runtime session",
      runtime_session_id != "",
      if runtime_session_id == "" {
        "not attached"
      } else {
        runtime_session_id
      },
    ),
    eval_check(
      "canonical_conversation",
      "Canonical conversation",
      canonical_turn_count > 0,
      "\{canonical_turn_count} canonical turn(s)",
    ),
    eval_check(
      "tool_events",
      "Tool events",
      tool_count > 0,
      "\{tool_count} tool event(s)",
    ),
    eval_check(
      "diff_events",
      "File diff events",
      diff_count > 0,
      "\{diff_count} diff event(s)",
    ),
    eval_check(
      "test_events",
      "Test/build events",
      test_count > 0,
      "\{test_count} test event(s)",
    ),
    eval_check(
      "verified_test_results",
      "Verified test results",
      verified_test_count > 0 && failed_test_count == 0,
      if verified_test_count > 0 && failed_test_count == 0 {
        "\{verified_test_count} verified passing test/build result(s)"
      } else if failed_test_count > 0 {
        "\{failed_test_count} failing test/build result(s)"
      } else {
        "test commands may be queued, but no MoonClaw test/build result has completed yet"
      },
    ),
    eval_check(
      "artifact_events",
      "Artifact events",
      artifact_count > 0,
      "\{artifact_count} artifact event(s)",
    ),
    eval_check(
      "review_events",
      "Review decisions",
      review_count > 0,
      "\{review_count} review event(s)",
    ),
    eval_check(
      "append_only_log",
      "Append-only event log",
      append_log_count > 0,
      if append_log_count > 0 {
        "\{append_log_count} durable event(s)"
      } else {
        "no durable MoonCode event log entries yet"
      },
    ),
    eval_check(
      "typed_command_packets",
      "Typed command packets",
      command_packet_count > 0,
      if command_packet_count > 0 {
        "\{command_packet_count} mooncode.v1 command packet(s)"
      } else {
        "no typed MoonCode command packet recorded yet"
      },
    ),
    eval_check(
      "ordered_command_queue",
      "Ordered command queue",
      command_log_count > 0,
      if command_log_count > 0 {
        "\{command_log_count} durable command packet(s)"
      } else {
        "no durable commands.jsonl entries yet"
      },
    ),
    eval_check(
      "runtime_command_feed",
      "Runtime command feed",
      runtime_command_log_count > 0,
      if runtime_command_log_count > 0 {
        "\{runtime_command_log_count} MoonCode runtime command(s)"
      } else {
        "no durable runtime-commands.jsonl entries yet"
      },
    ),
    eval_check(
      "typed_session_snapshot",
      "Typed session snapshot",
      session_snapshot_ready,
      if session_snapshot_ready {
        json_string(snapshot, "snapshot_path", default="")
      } else {
        "no \{@moonsuite.product_display_artifact("mooncode", "sessions/<id>/session.json")} snapshot recorded yet"
      },
    ),
    eval_check(
      "moonbook_review_receipts",
      "MoonBook review receipts",
      review_receipt_count > 0,
      if review_receipt_count > 0 {
        "\{review_receipt_count} MoonBook-owned receipt(s)"
      } else {
        "no MoonBook-owned accept/reject/package receipt recorded yet"
      },
    ),
    eval_check(
      "moonbook_package_manifest",
      "MoonBook package manifest",
      package_manifest_count > 0,
      if package_manifest_count > 0 {
        "\{package_manifest_count} MoonBook-owned package manifest(s)"
      } else {
        "no MoonBook-owned package manifest recorded yet"
      },
    ),
    eval_check(
      "moonbook_package_index",
      "MoonBook package index",
      package_index_manifest_count > 0,
      if package_index_manifest_count > 0 {
        "\{package_index_manifest_count} MoonBook-owned package index manifest(s)"
      } else {
        "no MoonBook-owned package index recorded yet"
      },
    ),
    eval_check(
      "moonbook_change_set_manifest",
      "MoonBook change-set manifest",
      change_set_manifest_count > 0,
      if change_set_manifest_count > 0 {
        "\{change_set_manifest_count} MoonBook-owned change-set manifest(s)"
      } else {
        "no MoonBook-owned change-set manifest recorded yet"
      },
    ),
    eval_check(
      "moonbook_patch_set_manifest",
      "MoonBook patch-set manifest",
      patch_set_manifest_count > 0,
      if patch_set_manifest_count > 0 {
        "\{patch_set_manifest_count} MoonBook-owned patch-set manifest(s)"
      } else {
        "no MoonBook-owned patch-set manifest recorded yet"
      },
    ),
    eval_check(
      "runtime_patch_execution_proof",
      "Runtime patch execution proof",
      patch_execution_proof_count > 0,
      if patch_execution_proof_count > 0 {
        "\{patch_execution_proof_count} runtime patch apply/revert proof event(s)"
      } else if patch_set_manifest_count > 0 {
        "patch-set exists, but no MoonClaw runtime patch_applied or patch_reverted proof has been recorded"
      } else {
        "no patch-set available for runtime execution proof"
      },
    ),
    eval_check(
      "moonbook_tool_approvals_manifest",
      "MoonBook tool-approval manifest",
      tool_approvals_manifest_count > 0,
      if tool_approvals_manifest_count > 0 {
        "\{tool_approvals_manifest_count} MoonBook-owned tool-approval manifest(s)"
      } else {
        "no MoonBook-owned tool-approval manifest recorded yet"
      },
    ),
    eval_check(
      "moonbook_test_runs_manifest",
      "MoonBook test-run manifest",
      test_runs_manifest_count > 0,
      if test_runs_manifest_count > 0 {
        "\{test_runs_manifest_count} MoonBook-owned test-run manifest(s)"
      } else {
        "no MoonBook-owned test-run manifest recorded yet"
      },
    ),
    eval_check(
      "mooncode_runtime_handoff",
      "MoonCode runtime handoff",
      runtime_handoff_manifest_count > 0,
      if runtime_handoff_manifest_count > 0 {
        "\{runtime_handoff_manifest_count} standalone runtime handoff manifest(s)"
      } else {
        "no runtime handoff manifest recorded yet"
      },
    ),
    eval_check(
      "tool_approval_queue",
      "Tool approval queue",
      pending_tool_approval_count == 0,
      if pending_tool_approval_count == 0 {
        "no pending policy/review-gated tool approval"
      } else {
        "\{pending_tool_approval_count} tool approval(s) pending"
      },
    ),
    eval_check(
      "source_bound_package",
      "Source-bound package evidence",
      source_bound_package_count > 0,
      if source_bound_package_count > 0 {
        "\{source_bound_package_count} package manifest(s) include source inventory evidence"
      } else if package_manifest_count > 0 {
        "package manifest exists, but no source-bound inventory has been recorded"
      } else {
        "no package manifest to inspect for source evidence"
      },
    ),
    eval_check(
      "runtime_package_proof",
      "Runtime package proof",
      runtime_package_proof_count > 0 && runtime_verified_package_count > 0,
      if runtime_verified_package_count > 0 {
        "\{runtime_verified_package_count} verified package proof event(s)"
      } else if runtime_package_proof_count > 0 {
        "\{runtime_package_proof_count} package build proof event(s), but no package_verified event"
      } else if source_bound_package_count > 0 {
        "source-bound package candidate exists, but MoonClaw has not emitted package_built or package_verified proof"
      } else {
        "no package candidate available for runtime package proof"
      },
    ),
    eval_check(
      "incremental_append_stream", "Incremental append stream", true, "stream accepts ?since=<sequence> and returns only later records",
    ),
    eval_check(
      "live_append_only_stream", "Live append-only stream", true, "stream supports bounded live tail with ?live=true over JSONL/SSE and falls back to MoonClaw native streaming when available",
    ),
  ]
}
