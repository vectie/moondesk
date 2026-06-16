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
