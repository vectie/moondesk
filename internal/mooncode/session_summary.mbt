///|
pub fn session_summary(session : Json, events : Array[Json]) -> Json {
  let event_log_path = json_string(
    session,
    "mooncode_event_log_path",
    default="",
  )
  let append_log_count = summary_json_int(
    session,
    "mooncode_append_log_count",
    default=0,
  )
  let command_log_path = json_string(
    session,
    "mooncode_command_log_path",
    default="",
  )
  let command_log_count = summary_json_int(
    session,
    "mooncode_command_log_count",
    default=0,
  )
  let runtime_command_log_path = json_string(
    session,
    "mooncode_runtime_command_log_path",
    default="",
  )
  let runtime_command_log_count = summary_json_int(
    session,
    "mooncode_runtime_command_log_count",
    default=0,
  )
  let runtime_dispatch_log_path = json_string(
    session,
    "mooncode_runtime_dispatch_log_path",
    default="",
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
  let eval_checks = session_eval_checks(session, events)
  let diff_count = count_lane(events, "diff")
  let test_count = count_lane(events, "test")
  let artifact_count = count_lane(events, "artifact")
  let review_count = count_lane(events, "review")
  let command_packet_count = count_command_packets(events)
  let review_receipt_count = count_review_receipts(events)
  let package_manifest_count = count_package_manifests(events)
  let package_index_manifest_count = count_package_index_manifests(events)
  let change_set_manifest_count = count_change_set_manifests(events)
  let patch_set_manifest_count = count_patch_set_manifests(events)
  let patch_execution_proof_count = count_patch_execution_proofs(events)
  let tool_approvals_manifest_count = count_tool_approvals_manifests(events)
  let test_runs_manifest_count = count_test_runs_manifests(events)
  let eval_report_manifest_count = count_eval_report_manifests(events)
  let runtime_evidence_manifest_count = count_runtime_evidence_manifests(events)
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
  let runtime_commit_proof_count = count_runtime_commit_proofs(events)
  let steer_command_count = count_command_events(events, "steer")
  let steer_settlement_count = count_steer_settlements(events)
  let deferred_steer_count = count_deferred_steers(events)
  let pending_steer_count = pending_steer_count(
    steer_command_count, steer_settlement_count,
  )
  let accepted_count = count_review_command(events, "accept")
  let rejected_count = count_review_command(events, "reject")
  let session_id = json_string(session, "id", default="")
  {
    "protocol": protocol_version(),
    "session_id": session_id,
    "workspace_id": json_string(session, "workspace_id", default=""),
    "task_id": json_string(session, "moonclaw_task_id", default=""),
    "stream_url": "/api/mooncode/sessions/\{session_id}/stream",
    "stream_mode": "append-log-incremental",
    "stream_source": stream_source(),
    "dispatch_mode": json_string(
      session,
      "mooncode_dispatch_mode",
      default="moonclaw-task-bridge",
    ),
    "live_stream_ready": false,
    "incremental_stream_ready": true,
    "incremental_stream_url": "/api/mooncode/sessions/\{session_id}/stream?format=jsonl&since=<sequence>",
    "stream_state_url": "/api/mooncode/sessions/\{session_id}/stream-state?consumer=moondesk-ui&since=<sequence>",
    "event_log_path": event_log_path,
    "append_log_ready": append_log_count > 0,
    "append_log_count": append_log_count,
    "command_log_path": command_log_path,
    "command_log_ready": command_log_count > 0,
    "command_log_count": command_log_count,
    "runtime_command_log_path": runtime_command_log_path,
    "runtime_command_feed_ready": runtime_command_log_count > 0,
    "runtime_command_count": runtime_command_log_count,
    "runtime_dispatch_log_path": runtime_dispatch_log_path,
    "runtime_dispatch_ready": runtime_dispatch_log_count > 0,
    "runtime_dispatch_count": runtime_dispatch_log_count,
    "session_snapshot_path": if session_snapshot_ready {
      json_string(snapshot, "snapshot_path", default="")
    } else {
      ""
    },
    "session_snapshot_ready": session_snapshot_ready,
    "command_packet_count": command_packet_count,
    "last_command_packet": summary_json_object_field_or_empty(
      session, "mooncode_last_command_packet",
    ),
    "moonbook_review_receipt_count": review_receipt_count,
    "last_moonbook_review_receipt": summary_json_object_field_or_empty(
      session, "mooncode_last_review_receipt",
    ),
    "moonbook_package_manifest_count": package_manifest_count,
    "last_moonbook_package_manifest": summary_json_object_field_or_empty(
      session, "mooncode_last_package_manifest",
    ),
    "moonbook_package_index_manifest_count": package_index_manifest_count,
    "last_moonbook_package_index_manifest": summary_json_object_field_or_empty(
      session, "mooncode_last_package_index_manifest",
    ),
    "moonbook_change_set_manifest_count": change_set_manifest_count,
    "last_moonbook_change_set_manifest": summary_json_object_field_or_empty(
      session, "mooncode_last_change_set_manifest",
    ),
    "moonbook_patch_set_manifest_count": patch_set_manifest_count,
    "runtime_patch_execution_proof_count": patch_execution_proof_count,
    "last_moonbook_patch_set_manifest": summary_json_object_field_or_empty(
      session, "mooncode_last_patch_set_manifest",
    ),
    "moonbook_tool_approvals_manifest_count": tool_approvals_manifest_count,
    "last_moonbook_tool_approvals_manifest": summary_json_object_field_or_empty(
      session, "mooncode_last_tool_approvals_manifest",
    ),
    "moonbook_test_runs_manifest_count": test_runs_manifest_count,
    "last_moonbook_test_runs_manifest": summary_json_object_field_or_empty(
      session, "mooncode_last_test_runs_manifest",
    ),
    "moonbook_eval_report_manifest_count": eval_report_manifest_count,
    "last_moonbook_eval_report_manifest": summary_json_object_field_or_empty(
      session, "mooncode_last_eval_report_manifest",
    ),
    "mooncode_runtime_evidence_manifest_count": runtime_evidence_manifest_count,
    "last_mooncode_runtime_evidence_manifest": summary_json_object_field_or_empty(
      session, "mooncode_last_runtime_evidence_manifest",
    ),
    "mooncode_runtime_handoff_manifest_count": runtime_handoff_manifest_count,
    "last_mooncode_runtime_handoff_manifest": summary_json_object_field_or_empty(
      session, "mooncode_last_runtime_handoff_manifest",
    ),
    "pending_tool_approval_count": pending_tool_approval_count,
    "event_count": events.length(),
    "tool_count": count_lane(events, "tool"),
    "diff_count": diff_count,
    "test_count": test_count,
    "verified_test_count": verified_test_count,
    "failed_test_count": failed_test_count,
    "artifact_count": artifact_count,
    "source_bound_package_count": source_bound_package_count,
    "runtime_package_proof_count": runtime_package_proof_count,
    "runtime_verified_package_count": runtime_verified_package_count,
    "runtime_commit_proof_count": runtime_commit_proof_count,
    "steer_command_count": steer_command_count,
    "steer_settlement_count": steer_settlement_count,
    "deferred_steer_count": deferred_steer_count,
    "pending_steer_count": pending_steer_count,
    "review_count": review_count,
    "pending_diff_count": pending_diff_count(
      diff_count, accepted_count, rejected_count,
    ),
    "accepted_review_count": accepted_count,
    "rejected_review_count": rejected_count,
    "review_state": review_state(diff_count, accepted_count, rejected_count),
    "runtime_count": count_lane(events, "runtime"),
    "transcript_count": count_lane(events, "transcript"),
    "has_packaging_candidate": artifact_count > 0,
    "extractable_component": "mooncode",
    "eval_score": eval_score(eval_checks),
    "eval_level": eval_level(eval_checks),
    "eval_checks": Json::array(eval_checks),
  }
}

///|
pub fn session_projection_response(
  session : Json,
  events : Array[Json],
  event_log_path~ : String,
  append_log_count~ : Int,
  command_log_path~ : String,
  command_log_count~ : Int,
  runtime_command_log_path~ : String,
  runtime_command_log_count~ : Int,
  runtime_dispatch_log_path~ : String,
  runtime_dispatch_log_count~ : Int,
) -> Json {
  let summary_session = session
    |> runtime_with_field("mooncode_event_log_path", event_log_path.to_json())
    |> runtime_with_field(
      "mooncode_append_log_count",
      append_log_count.to_json(),
    )
    |> runtime_with_field(
      "mooncode_command_log_path",
      command_log_path.to_json(),
    )
    |> runtime_with_field(
      "mooncode_command_log_count",
      command_log_count.to_json(),
    )
    |> runtime_with_field(
      "mooncode_runtime_command_log_path",
      runtime_command_log_path.to_json(),
    )
    |> runtime_with_field(
      "mooncode_runtime_command_log_count",
      runtime_command_log_count.to_json(),
    )
    |> runtime_with_field(
      "mooncode_runtime_dispatch_log_path",
      runtime_dispatch_log_path.to_json(),
    )
    |> runtime_with_field(
      "mooncode_runtime_dispatch_log_count",
      runtime_dispatch_log_count.to_json(),
    )
  let summary = session_summary(summary_session, events)
  session
  |> runtime_with_field("mooncode_events", Json::array(events))
  |> runtime_with_field("mooncode_summary", summary)
}
