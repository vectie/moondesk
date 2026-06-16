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
  let pending_steer_count = pending_steer_count(
    steer_command_count, steer_settlement_count,
  )
  let accepted_count = count_review_command(events, "accept")
  let rejected_count = count_review_command(events, "reject")
  let session_id = json_string(session, "id", default="")
  {
    "protocol": "mooncode.v1",
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
pub fn session_eval_checks(session : Json, events : Array[Json]) -> Array[Json] {
  let task_id = json_string(session, "moonclaw_task_id", default="")
  let workspace_id = json_string(session, "workspace_id", default="")
  let transcript_count = count_lane(events, "transcript")
  let tool_count = count_lane(events, "tool")
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
      "task_attached",
      "MoonClaw task",
      task_id != "",
      if task_id == "" {
        "not attached"
      } else {
        task_id
      },
    ),
    eval_check(
      "transcript",
      "Conversation transcript",
      transcript_count > 0,
      "\{transcript_count} transcript event(s)",
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
        "\{runtime_command_log_count} OpenSeek-compatible runtime command(s)"
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
        "no .moontown/mooncode-sessions/<id>/session.json snapshot recorded yet"
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
        "\{runtime_handoff_manifest_count} extractable runtime handoff manifest(s)"
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

///|
pub fn eval_report_projection(session : Json) -> Json {
  let summary = summary_json_object_field_or_empty(session, "mooncode_summary")
  let checks = json_array_items(summary, "eval_checks")
  let session_id = json_string(session, "id", default="")
  let passed_count = eval_check_passed_count(checks)
  let missing_count = checks.length() - passed_count
  let native_eval = summary_json_object_field_or_empty(
    session, "mooncode_native_eval_report",
  )
  let native_ready = native_eval_report_ready(native_eval)
  let native_harnesses = native_eval_report_harnesses(native_eval)
  let native_passed_harness_count = native_eval_passed_harness_count(
    native_harnesses,
  )
  let bridge_score = summary_json_int(summary, "eval_score", default=0)
  let bridge_level = json_string(summary, "eval_level", default="empty")
  let status = if native_ready && missing_count == 0 {
    "production-ready"
  } else if native_ready {
    "native-partial"
  } else if missing_count == 0 {
    "bridge-ready"
  } else if passed_count > 0 {
    "bridge-partial"
  } else {
    "empty"
  }
  let manifest = summary_json_object_field_or_empty(
    session, "mooncode_last_eval_report_manifest",
  )
  {
    "kind": "mooncode-eval-report",
    "protocol": "mooncode.v1",
    "status": status,
    "session_id": session_id,
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "task_id": json_string(session, "moonclaw_task_id", default=""),
    "runtime_owner": "moonclaw",
    "ui_owner": "moondesk",
    "artifact_owner": "moonbook",
    "extractable_component": "mooncode",
    "bridge_score": bridge_score,
    "bridge_level": bridge_level,
    "passed_check_count": passed_count,
    "missing_check_count": missing_count,
    "check_count": checks.length(),
    "checks": Json::array(checks),
    "native_eval_evidence_ready": native_ready,
    "native_eval_report": native_eval,
    "native_eval_status": json_string(native_eval, "status", default="missing"),
    "native_eval_harness_count": native_harnesses.length(),
    "native_eval_passed_harness_count": native_passed_harness_count,
    "native_eval_failed_harness_count": native_harnesses.length() -
    native_passed_harness_count,
    "native_eval_harnesses": Json::array(native_harnesses),
    "native_eval_source": if native_ready {
      json_string(native_eval, "source", default="moonclaw-native-runtime")
    } else {
      "missing"
    },
    "native_eval_endpoint": json_string(
      native_eval,
      "endpoint",
      default="/v1/mooncode/sessions/<id>/eval-report?book_root=<path>",
    ),
    "native_eval_ingest_method": "POST",
    "native_eval_ingest_endpoint": if session_id == "" {
      "/api/mooncode/sessions/<id>/eval-report"
    } else {
      "/api/mooncode/sessions/\{session_id}/eval-report"
    },
    "recorded_at": json_string(manifest, "recorded_at", default=""),
    "manifest_path": json_string(manifest, "manifest_path", default=""),
    "absolute_manifest_path": json_string(
      manifest,
      "absolute_manifest_path",
      default="",
    ),
    "required_native_harnesses": string_array_json(["tool_harness", "file_edit"]),
    "minimum_native_evidence": string_array_json([
      "read/edit/write/shell/moon_check tool reliability", "file-edit task success/failure fixtures",
      "test/build execution with stdout/stderr", "package assembly proof for generated tools and miniapps",
    ]),
    "current_gap": if native_ready {
      "MoonClaw reported native eval evidence; remaining bridge/runtime gaps are reflected in the checks array."
    } else {
      "Bridge evidence is visible, but MoonClaw still needs OpenSeek-style tool_harness and file_edit eval results before Moondesk can claim production-grade coding-agent behavior."
    },
    "summary": summary,
  }
}

///|
pub fn normalize_native_eval_report(report : Json, endpoint : String) -> Json {
  let ok = native_eval_report_ready(report)
  eval_report_with_field(
    eval_report_with_field(
      eval_report_with_field(report, "ok", ok.to_json()),
      "source",
      "moonclaw-native-runtime".to_json(),
    ),
    "endpoint",
    endpoint.to_json(),
  )
}

///|
pub fn session_without_eval_report_projection(session : Json) -> Json {
  let object : Map[String, Json] = {}
  match session {
    Json::Object(fields) =>
      for key, value in fields {
        if key != "mooncode_last_eval_report_manifest" &&
          key != "mooncode_summary" {
          object[key] = value
        }
      }
    _ => ()
  }
  Json::object(object)
}

///|
fn native_eval_report_ready(report : Json) -> Bool {
  match summary_json_object_field(report, "ok") {
    Some(value) => return @json.from_json(value) catch { _ => false }
    None => ()
  }
  if json_bool(report, "native_eval_evidence_ready", default=false) {
    return true
  }
  let status = json_string(report, "status", default="")
  if status == "accepted" || status == "passed" || status == "production-ready" {
    return true
  }
  let native_eval = summary_json_object_field_or_empty(report, "native_eval")
  let nested_status = json_string(native_eval, "status", default="")
  if nested_status == "passed" || nested_status == "accepted" {
    return true
  }
  let harnesses = native_eval_report_harnesses(report)
  harnesses.length() > 0 &&
  native_eval_passed_harness_count(harnesses) == harnesses.length()
}

///|
fn native_eval_report_harnesses(report : Json) -> Array[Json] {
  let native_eval = summary_json_object_field_or_empty(report, "native_eval")
  let nested = json_array_items(native_eval, "harnesses")
  if nested.length() > 0 {
    return nested
  }
  json_array_items(report, "harnesses")
}

///|
fn native_eval_passed_harness_count(harnesses : Array[Json]) -> Int {
  let mut count = 0
  for harness in harnesses {
    let status = json_string(harness, "status", default="")
    if status == "passed" || status == "accepted" {
      count += 1
    }
  }
  count
}

///|
pub fn eval_check_passed_count(checks : Array[Json]) -> Int {
  let mut count = 0
  for check in checks {
    if json_bool(check, "ok", default=false) {
      count += 1
    }
  }
  count
}

///|
pub fn eval_check(
  id : String,
  label : String,
  ok : Bool,
  evidence : String,
) -> Json {
  { "id": id, "label": label, "ok": ok, "evidence": evidence }
}

///|
pub fn eval_score(checks : Array[Json]) -> Int {
  if checks.length() == 0 {
    return 0
  }
  let mut passed = 0
  for check in checks {
    if json_bool(check, "ok", default=false) {
      passed += 1
    }
  }
  passed * 100 / checks.length()
}

///|
pub fn eval_level(checks : Array[Json]) -> String {
  let score = eval_score(checks)
  if score >= 85 {
    "ready"
  } else if score >= 50 {
    "partial"
  } else if score > 0 {
    "early"
  } else {
    "empty"
  }
}

///|
pub fn count_lane(events : Array[Json], lane : String) -> Int {
  let mut count = 0
  for event in events {
    if json_string(event, "lane", default="") == lane {
      count += 1
    }
  }
  count
}

///|
pub fn count_review_command(events : Array[Json], command : String) -> Int {
  let mut count = 0
  for event in events {
    if json_string(event, "lane", default="") == "review" &&
      json_string(event, "command", default="") == command &&
      json_string(event, "status", default="") != "failed" {
      count += 1
    }
  }
  count
}

///|
pub fn count_command_events(events : Array[Json], command : String) -> Int {
  let seen : Map[String, Bool] = {}
  let mut count = 0
  for event in events {
    if json_string(event, "command", default="") == command &&
      json_string(event, "status", default="") != "failed" {
      let id = json_string(
        summary_json_object_field_or_empty(event, "command_packet"),
        "command_id",
        default=json_string(event, "id", default="event:\{count}"),
      )
      if !seen.get(id).unwrap_or(false) {
        seen[id] = true
        count += 1
      }
    }
  }
  count
}

///|
pub fn count_steer_settlements(events : Array[Json]) -> Int {
  let mut count = 0
  for event in events {
    let kind = json_string(event, "kind", default="")
    if kind == "steer_applied" || kind == "steer_dropped" {
      count += 1
    }
  }
  count
}

///|
pub fn pending_steer_count(
  steer_command_count : Int,
  steer_settlement_count : Int,
) -> Int {
  if steer_command_count > steer_settlement_count {
    steer_command_count - steer_settlement_count
  } else {
    0
  }
}

///|
pub fn count_command_packets(events : Array[Json]) -> Int {
  let seen : Map[String, Bool] = {}
  let mut count = 0
  for event in events {
    match summary_json_object_field(event, "command_packet") {
      Some(packet) =>
        if json_string(packet, "protocol", default="") == "mooncode.v1" {
          let command_id = json_string(
            packet,
            "command_id",
            default="packet:\{packet.stringify()}",
          )
          if !seen.get(command_id).unwrap_or(false) {
            seen[command_id] = true
            count += 1
          }
        }
      None => ()
    }
  }
  count
}

///|
pub fn count_review_receipts(events : Array[Json]) -> Int {
  let mut count = 0
  for event in events {
    if json_string(event, "lane", default="") == "review" &&
      json_string(event, "kind", default="").has_prefix("receipt.") {
      count += 1
    }
  }
  count
}

///|
pub fn count_package_manifests(events : Array[Json]) -> Int {
  count_kind(events, "package.manifest")
}

///|
pub fn count_package_index_manifests(events : Array[Json]) -> Int {
  count_kind(events, "package.index")
}

///|
pub fn count_change_set_manifests(events : Array[Json]) -> Int {
  count_kind(events, "change_set.manifest")
}

///|
pub fn count_patch_set_manifests(events : Array[Json]) -> Int {
  count_kind(events, "patch_set.manifest")
}

///|
pub fn count_tool_approvals_manifests(events : Array[Json]) -> Int {
  count_kind(events, "tool_approvals.manifest")
}

///|
pub fn count_test_runs_manifests(events : Array[Json]) -> Int {
  count_kind(events, "test_runs.manifest")
}

///|
pub fn count_eval_report_manifests(events : Array[Json]) -> Int {
  count_kind(events, "eval_report.manifest")
}

///|
pub fn count_runtime_evidence_manifests(events : Array[Json]) -> Int {
  count_kind(events, "runtime_evidence.manifest")
}

///|
pub fn count_runtime_handoff_manifests(events : Array[Json]) -> Int {
  count_kind(events, "runtime.handoff")
}

///|
pub fn count_runtime_commit_proofs(events : Array[Json]) -> Int {
  count_kind(events, "runtime.commit_created")
}

///|
pub fn count_verified_tests(events : Array[Json]) -> Int {
  let mut count = 0
  for event in events {
    if json_string(event, "lane", default="") == "test" &&
      test_event_is_completed(event) &&
      !test_event_failed(event) {
      count += 1
    }
  }
  count
}

///|
pub fn count_failed_tests(events : Array[Json]) -> Int {
  let mut count = 0
  for event in events {
    if json_string(event, "lane", default="") == "test" &&
      test_event_failed(event) {
      count += 1
    }
  }
  count
}

///|
pub fn test_event_is_completed(event : Json) -> Bool {
  let status = json_string(event, "status", default="")
  status == "done" || status == "completed" || status == "passed"
}

///|
pub fn test_event_failed(event : Json) -> Bool {
  json_string(event, "status", default="") == "failed" ||
  summary_json_int(event, "exit_code", default=0) > 0
}

///|
pub fn count_source_bound_packages(
  session : Json,
  package_manifest_count : Int,
) -> Int {
  if package_manifest_count == 0 {
    return 0
  }
  let manifest = summary_json_object_field_or_empty(
    session, "mooncode_last_package_manifest",
  )
  let index = summary_json_object_field_or_empty(
    session, "mooncode_last_package_index_manifest",
  )
  if json_string(index, "kind", default="") == "mooncode-package-index" {
    summary_json_int(index, "source_bound_package_count", default=0)
  } else if json_string(manifest, "source_inventory_status", default="") ==
    "source-bound" &&
    summary_json_int(manifest, "source_present_count", default=0) > 0 {
    1
  } else {
    0
  }
}

///|
pub fn pending_diff_count(
  diff_count : Int,
  accepted_count : Int,
  rejected_count : Int,
) -> Int {
  let reviewed = accepted_count + rejected_count
  if diff_count > reviewed {
    diff_count - reviewed
  } else {
    0
  }
}

///|
pub fn review_state(
  diff_count : Int,
  accepted_count : Int,
  rejected_count : Int,
) -> String {
  if rejected_count > 0 {
    "rejected"
  } else if accepted_count > 0 {
    "accepted"
  } else if diff_count > 0 {
    "pending"
  } else {
    "empty"
  }
}

///|
fn count_kind(events : Array[Json], kind : String) -> Int {
  let mut count = 0
  for event in events {
    if json_string(event, "kind", default="") == kind {
      count += 1
    }
  }
  count
}

///|
fn summary_json_object_field(json : Json, key : String) -> Json? {
  match json {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn summary_json_object_field_or_empty(json : Json, key : String) -> Json {
  match summary_json_object_field(json, key) {
    Some(value) => value
    None => Json::object({})
  }
}

///|
fn eval_report_with_field(base : Json, key : String, value : Json) -> Json {
  match base {
    Json::Object(fields) => {
      let next : Map[String, Json] = {}
      for item in fields {
        next[item.0] = item.1
      }
      next[key] = value
      Json::object(next)
    }
    _ => base
  }
}

///|
fn summary_json_int(json : Json, key : String, default~ : Int) -> Int {
  match summary_json_object_field(json, key) {
    Some(Json::Number(value, ..)) => value.to_int()
    Some(Json::String(value)) => @string.parse_int(value) catch { _ => default }
    _ => default
  }
}

///|
test "mooncode session summary counts reviewable code events" {
  let events : Array[Json] = [
    event_record(
      id="diff-1",
      lane="diff",
      kind="tool.write",
      title="Write file",
      status="done",
      created_at="1",
      detail="updated tool",
      path="tools/demo/main.mbt",
      diff="+fn main { println(\"ok\") }",
    ),
    event_record(
      id="test-1",
      lane="test",
      kind="tool.moon_check",
      title="Moon check",
      status="done",
      created_at="2",
      detail="passed",
      command="moon check",
    ),
    event_record(
      id="review-1",
      lane="review",
      kind="receipt.accept",
      title="Accepted",
      status="done",
      created_at="3",
      detail="accepted",
      path="tools/demo/main.mbt",
      command="accept",
    ),
  ]
  let summary = session_summary(
    {
      "id": "s1",
      "workspace_id": "book",
      "moonclaw_task_id": "task",
      "mooncode_append_log_count": 3,
      "mooncode_command_log_count": 1,
      "mooncode_runtime_command_log_count": 1,
      "mooncode_session_snapshot": {
        "kind": "mooncode-session-snapshot",
        "snapshot_path": ".moontown/mooncode-sessions/s1/session.json",
      },
    },
    events,
  )
  assert_eq(summary_json_int(summary, "diff_count", default=0), 1)
  assert_eq(summary_json_int(summary, "verified_test_count", default=0), 1)
  assert_eq(json_string(summary, "review_state", default=""), "accepted")
  assert_eq(summary_json_int(summary, "pending_diff_count", default=9), 0)
}

///|
test "mooncode session summary counts runtime patch execution proof" {
  let events : Array[Json] = [
    event_record(
      id="diff-1",
      lane="diff",
      kind="tool.edit",
      title="Edit file",
      status="done",
      created_at="1",
      detail="changed",
      path="tools/demo/main.mbt",
      diff="+new",
    ),
    event_record(
      id="patch-proof-1",
      lane="review",
      kind="runtime.patch_applied",
      title="Patch applied by runtime",
      status="done",
      created_at="2",
      detail="applied",
      path="tools/demo/main.mbt",
      command="apply_patch",
    ),
  ]
  let summary = session_summary({ "id": "s1", "workspace_id": "book" }, events)
  assert_eq(
    summary_json_int(summary, "runtime_patch_execution_proof_count", default=0),
    1,
  )
  let checks = json_array_items(summary, "eval_checks")
  let mut found = false
  for check in checks {
    if json_string(check, "id", default="") == "runtime_patch_execution_proof" {
      found = true
      assert_true(json_bool(check, "ok", default=false))
    }
  }
  assert_true(found)
}

///|
test "mooncode session summary counts runtime package proof" {
  let events : Array[Json] = [
    event_record(
      id="package-proof-1",
      lane="artifact",
      kind="runtime.package_verified",
      title="Package verified by runtime",
      status="done",
      created_at="1",
      detail="verified",
      path="portable/app-tool/mooncode/s1/index.json",
      command="package",
    ),
  ]
  let summary = session_summary(
    {
      "id": "s1",
      "workspace_id": "book",
      "mooncode_last_package_manifest": {
        "kind": "mooncode-package-manifest",
        "source_inventory_status": "source-bound",
        "source_present_count": 1,
      },
    },
    events,
  )
  assert_eq(
    summary_json_int(summary, "runtime_package_proof_count", default=0),
    1,
  )
  assert_eq(
    summary_json_int(summary, "runtime_verified_package_count", default=0),
    1,
  )
  let checks = json_array_items(summary, "eval_checks")
  let mut found = false
  for check in checks {
    if json_string(check, "id", default="") == "runtime_package_proof" {
      found = true
      assert_true(json_bool(check, "ok", default=false))
    }
  }
  assert_true(found)
}

///|
test "mooncode session summary counts runtime commit proof" {
  let events : Array[Json] = [
    event_record(
      id="commit-proof-1",
      lane="review",
      kind="runtime.commit_created",
      title="Commit created by runtime",
      status="done",
      created_at="1",
      detail="abc1234",
      command="commit",
    ),
  ]
  let summary = session_summary({ "id": "s1", "workspace_id": "book" }, events)
  assert_eq(
    summary_json_int(summary, "runtime_commit_proof_count", default=0),
    1,
  )
}

///|
test "mooncode session summary tracks pending steer acknowledgements" {
  let events : Array[Json] = [
    command_event(
      action="steer",
      status="queued",
      detail="add tests",
      created_at="1",
      path="tools/demo/main.mbt",
      command_packet={
        "protocol": "mooncode.v1",
        "command_id": "cmd-steer-1",
        "action": "steer",
      },
      event_id="cmd-steer-1",
    ),
    command_event(
      action="steer",
      status="queued",
      detail="tighten scope",
      created_at="2",
      path="tools/demo/main.mbt",
      command_packet={
        "protocol": "mooncode.v1",
        "command_id": "cmd-steer-2",
        "action": "steer",
      },
      event_id="cmd-steer-2",
    ),
    event_record(
      id="steer-proof-1",
      lane="runtime",
      kind="steer_applied",
      title="Steering applied",
      status="done",
      created_at="3",
      detail="add tests",
    ),
  ]
  let summary = session_summary({ "id": "s1", "workspace_id": "book" }, events)
  assert_eq(summary_json_int(summary, "steer_command_count", default=0), 2)
  assert_eq(summary_json_int(summary, "steer_settlement_count", default=0), 1)
  assert_eq(summary_json_int(summary, "pending_steer_count", default=0), 1)
  assert_eq(pending_steer_count(1, 2), 0)
}

///|
test "mooncode session summary tracks pending policy approval" {
  let events : Array[Json] = [
    event_record(
      id="tool-1",
      lane="tool",
      kind="tool.shell",
      title="Run shell",
      status="running",
      created_at="1",
      detail="execute_command",
      command="moon test",
    ),
  ]
  let summary = session_summary({ "id": "s1", "workspace_id": "book" }, events)
  assert_eq(
    summary_json_int(summary, "pending_tool_approval_count", default=0),
    1,
  )
  assert_eq(json_string(summary, "review_state", default=""), "empty")
}

///|
test "mooncode eval report projection stays extractable" {
  let checks = [
    eval_check("book_scope", "Book scope", true, "book"),
    eval_check("native_eval", "Native eval", false, "missing"),
  ]
  let summary : Json = {
    "eval_score": eval_score(checks),
    "eval_level": eval_level(checks),
    "eval_checks": Json::array(checks),
  }
  let report = eval_report_projection({
    "id": "s1",
    "workspace_id": "book",
    "moonclaw_task_id": "task",
    "mooncode_summary": summary,
  })
  assert_eq(json_string(report, "kind", default=""), "mooncode-eval-report")
  assert_eq(
    json_string(report, "extractable_component", default=""),
    "mooncode",
  )
  assert_eq(summary_json_int(report, "passed_check_count", default=0), 1)
}

///|
test "mooncode native eval report normalization accepts legacy readiness" {
  let native_eval = normalize_native_eval_report(
    {
      "native_eval_evidence_ready": true,
      "harnesses": ["tool_harness", "file_edit"],
    },
    "/v1/mooncode/sessions/s1/eval-report",
  )
  assert_true(json_bool(native_eval, "ok", default=false))
  assert_eq(
    json_string(native_eval, "source", default=""),
    "moonclaw-native-runtime",
  )
  assert_eq(
    json_string(native_eval, "endpoint", default=""),
    "/v1/mooncode/sessions/s1/eval-report",
  )
  assert_eq(json_array_items(native_eval, "harnesses").length(), 2)
}

///|
test "mooncode native eval report normalization accepts MoonClaw harness status" {
  let native_eval = normalize_native_eval_report(
    {
      "kind": "mooncode-native-eval-report",
      "protocol": "mooncode.v1",
      "status": "accepted",
      "native_eval": {
        "status": "passed",
        "harnesses": [
          { "id": "tool_harness", "status": "passed" },
          { "id": "file_edit", "status": "passed" },
        ],
      },
    },
    "/v1/mooncode/sessions/s1/eval-report?book_root=/tmp/book",
  )
  assert_true(json_bool(native_eval, "ok", default=false))
  let report = eval_report_projection({
    "id": "s1",
    "workspace_id": "book",
    "moonclaw_task_id": "task",
    "mooncode_native_eval_report": native_eval,
    "mooncode_summary": {
      "eval_score": 100,
      "eval_level": "ready",
      "eval_checks": [],
    },
  })
  assert_eq(json_string(report, "status", default=""), "production-ready")
  assert_eq(summary_json_int(report, "native_eval_harness_count", default=0), 2)
  assert_eq(
    summary_json_int(report, "native_eval_passed_harness_count", default=0),
    2,
  )
}

///|
test "mooncode native eval report normalization preserves explicit false" {
  let native_eval = normalize_native_eval_report(
    { "ok": false, "native_eval_evidence_ready": true },
    "/v1/mooncode/sessions/s2/eval-report",
  )
  assert_false(json_bool(native_eval, "ok", default=true))
  assert_eq(
    json_string(native_eval, "endpoint", default=""),
    "/v1/mooncode/sessions/s2/eval-report",
  )
}

///|
test "mooncode eval report projection cleanup is MoonCode-owned" {
  let cleaned = session_without_eval_report_projection({
    "id": "s1",
    "workspace_id": "book",
    "mooncode_summary": { "eval_score": 20 },
    "mooncode_last_eval_report_manifest": { "kind": "mooncode-eval-report" },
    "mooncode_native_eval_report": { "ok": true },
  })
  assert_eq(json_string(cleaned, "id", default=""), "s1")
  assert_eq(json_string(cleaned, "workspace_id", default=""), "book")
  assert_true(summary_json_object_field(cleaned, "mooncode_summary") is None)
  assert_true(
    summary_json_object_field(cleaned, "mooncode_last_eval_report_manifest")
    is None,
  )
  assert_true(
    summary_json_object_field(cleaned, "mooncode_native_eval_report") is Some(_),
  )
}
