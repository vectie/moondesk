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
      "mooncode_runtime_session_id": "runtime",
      "mooncode_append_log_count": 3,
      "mooncode_command_log_count": 1,
      "mooncode_runtime_command_log_count": 1,
      "mooncode_session_snapshot": {
        "kind": "mooncode-session-snapshot",
        "snapshot_path": ".moonsuite/products/mooncode/sessions/s1/session.json",
      },
    },
    events,
  )
  assert_eq(summary_json_int(summary, "diff_count", default=0), 1)
  assert_true(json_bool(summary, "live_stream_ready", default=false))
  assert_true(
    json_string(summary, "live_stream_url", default="").contains("format=sse"),
  )
  assert_true(
    json_string(summary, "live_stream_url", default="").contains("live=true"),
  )
  assert_true(
    json_string(summary, "stream_state_url", default="").contains(
      "stream-state",
    ),
  )
  assert_true(
    json_string(summary, "stream_state_url", default="").contains(
      "consumer=moondesk-ui",
    ),
  )
  assert_eq(summary_json_int(summary, "verified_test_count", default=0), 1)
  assert_eq(json_string(summary, "review_state", default=""), "accepted")
  assert_eq(summary_json_int(summary, "pending_diff_count", default=9), 0)
  assert_eq(summary_json_int(summary, "readiness_check_count", default=0), 18)
  assert_true(
    summary_json_int(summary, "readiness_blocked_count", default=0) > 0,
  )
  assert_eq(json_array_items(summary, "readiness_checks").length(), 18)
}

///|
fn complete_native_eval_report_fixture() -> Json {
  normalize_native_eval_report(
    {
      "status": "accepted",
      "native_eval": {
        "harnesses": [
          { "id": "tool_harness", "status": "passed" },
          { "id": "file_edit", "status": "passed" },
          { "id": "patch_review", "status": "passed" },
          { "id": "command_execution", "status": "passed" },
          { "id": "package_output", "status": "passed" },
        ],
      },
    },
    "/v1/code/sessions/s1/eval-report?book_root=<path>",
  )
}

///|
fn complete_runtime_supervisor_fixture() -> Json {
  let turn_packet : Json = {
    "kind": "mooncode-runtime-turn-packet",
    "protocol": protocol_version(),
    "session_id": "s1",
    "command_id": "cmd-1",
    "status": "ready",
    "operation": "claim-command",
    "action": "prompt",
    "runtime_control_effect": "start-turn",
    "runtime_control_allows_turn": true,
    "ready_to_execute": true,
    "endpoints": {
      "claim": "/api/mooncode/sessions/s1/runtime-claim",
      "ack": "/api/mooncode/sessions/s1/runtime-replay",
      "runtime_events": "/api/mooncode/sessions/s1/runtime-events",
      "stream": "/api/mooncode/sessions/s1/stream?format=sse",
      "native_session_listing": "/v1/code/sessions?book_root=<path>&format=json",
      "native_commands": "/v1/code/sessions/s1/commands?book_root=<path>",
      "native_runtime_control": "/v1/code/sessions/s1/runtime-control?book_root=<path>",
      "native_eval_report": "/v1/code/sessions/s1/eval-report?book_root=<path>",
    },
    "claim_request_template": { "command_id": "cmd-1", "lease_id": "lease-1" },
    "ack_request_template": {
      "command_id": "cmd-1",
      "status": "runtime-completed",
    },
    "failure_ack_template": { "command_id": "cmd-1", "status": "failed" },
    "mooncode_command": { "command": "prompt", "text": "build tool" },
    "native_mooncode_body": {
      "protocol": protocol_version(),
      "command": "prompt",
      "session_id": "s1",
    },
    "required_events": ["assistant_delta", "tool_result"],
    "required_outputs": ["diff", "test_result"],
  }
  runtime_supervisor_launch_packet(
    "s1",
    turn_packet,
    { "kind": "mooncode-runtime-consumer", "status": "claim-ready" },
    workspace_root="/tmp/book",
    moonclaw_root="/opt/moonclaw",
    host_base_url="",
    false,
  )
}

///|
test "mooncode session summary reports readiness coding flow" {
  let command_packet : Json = {
    "protocol": protocol_version(),
    "command_id": "cmd-1",
    "action": "prompt",
  }
  let events : Array[Json] = [
    event_record(
      id="prompt-1",
      lane="transcript",
      kind="user",
      title="User prompt",
      status="done",
      created_at="1",
      detail="Build the tool.",
      command="prompt",
      command_packet~,
    ),
    event_record(
      id="transcript-1",
      lane="transcript",
      kind="assistant",
      title="Assistant",
      status="done",
      created_at="2",
      detail="I will edit the tool.",
      command_packet~,
    ),
    event_record(
      id="runtime-1",
      lane="runtime",
      kind="runtime_update",
      title="Runtime update",
      status="running",
      created_at="3",
      detail="running",
      command_packet~,
    ),
    event_record(
      id="tool-1",
      lane="tool",
      kind="tool.read",
      title="Read",
      status="done",
      created_at="4",
      detail="read source",
      command_packet~,
    ),
    event_record(
      id="diff-1",
      lane="diff",
      kind="tool.write",
      title="Write file",
      status="done",
      created_at="5",
      detail="updated tool",
      path="tools/demo/main.mbt",
      diff="+fn main { println(\"ok\") }",
      command_packet~,
    ),
    event_record(
      id="test-1",
      lane="test",
      kind="tool.moon_check",
      title="Moon check",
      status="passed",
      created_at="6",
      detail="passed",
      command="moon check",
      command_packet~,
    ),
    event_record(
      id="artifact-1",
      lane="artifact",
      kind="artifact",
      title="Tool artifact",
      status="done",
      created_at="7",
      detail="artifact ready",
      path="portable/app-tool/mooncode/s1/index.json",
      command_packet~,
    ),
    event_record(
      id="review-1",
      lane="review",
      kind="receipt.accept",
      title="Accepted",
      status="done",
      created_at="8",
      detail="accepted",
      path="tools/demo/main.mbt",
      command="accept",
      command_packet~,
    ),
    event_record(
      id="package-manifest",
      lane="artifact",
      kind="package.manifest",
      title="Package manifest",
      status="source-bound",
      created_at="9",
      detail="manifest",
      path="portable/app-tool/mooncode/s1/package.json",
      command_packet~,
    ),
    event_record(
      id="package-index",
      lane="artifact",
      kind="package.index",
      title="Package index",
      status="source-bound",
      created_at="10",
      detail="index",
      path="portable/app-tool/mooncode/s1/index.json",
      command_packet~,
    ),
    event_record(
      id="change-set",
      lane="review",
      kind="change_set.manifest",
      title="Change set",
      status="done",
      created_at="11",
      detail="change set",
      path="wiki/reviews/mooncode/s1/change-set.json",
      command_packet~,
    ),
    event_record(
      id="patch-set",
      lane="review",
      kind="patch_set.manifest",
      title="Patch set",
      status="done",
      created_at="12",
      detail="patch set",
      path="wiki/reviews/mooncode/s1/patch-set.json",
      command_packet~,
    ),
    event_record(
      id="test-runs",
      lane="review",
      kind="test_runs.manifest",
      title="Test runs",
      status="passed",
      created_at="13",
      detail="test runs",
      path="wiki/reviews/mooncode/s1/test-runs.json",
      command_packet~,
    ),
    event_record(
      id="runtime-package-verified",
      lane="artifact",
      kind="runtime.package_verified",
      title="Package verified",
      status="verified",
      created_at="14",
      detail="verified",
      path="portable/app-tool/mooncode/s1/index.json",
      command="package",
      command_packet~,
    ),
    event_record(
      id="runtime-handoff",
      lane="runtime",
      kind="runtime.handoff",
      title="Runtime handoff",
      status="ready",
      created_at="15",
      detail="handoff",
      path="wiki/reviews/mooncode/s1/runtime-handoff.json",
      command_packet~,
    ),
    event_record(
      id="eval-report",
      lane="review",
      kind="eval_report.manifest",
      title="Eval report",
      status="accepted",
      created_at="16",
      detail="native eval report",
      path="wiki/reviews/mooncode/s1/eval-report.json",
      command_packet~,
    ),
  ]
  let summary = session_summary(
    {
      "id": "s1",
      "workspace_id": "book",
      "mooncode_runtime_session_id": "runtime",
      "mooncode_append_log_count": events.length(),
      "mooncode_command_log_count": 1,
      "mooncode_runtime_command_log_count": 1,
      "mooncode_runtime_receipt_log_count": 1,
      "mooncode_session_snapshot": {
        "kind": "mooncode-session-snapshot",
        "snapshot_path": ".moonsuite/products/mooncode/sessions/s1/session.json",
      },
      "mooncode_last_package_manifest": {
        "kind": "mooncode-package-manifest",
        "source_inventory_status": "source-bound",
        "source_present_count": 1,
      },
      "mooncode_last_package_index_manifest": {
        "kind": "mooncode-package-index",
        "source_bound_package_count": 1,
      },
      "mooncode_last_action_plan_manifest": {
        "kind": "mooncode-action-plan",
        "status": "complete",
        "next_required_action": "completed",
        "blocked_count": 0,
        "pending_runtime_count": 0,
        "running_count": 0,
        "pending_diff_count": 0,
        "pending_tool_approval_count": 0,
        "pending_steer_count": 0,
        "failed_test_count": 0,
      },
      "mooncode_last_runtime_handoff_manifest": {
        "kind": "mooncode-runtime-handoff",
        "runtime_supervisor": complete_runtime_supervisor_fixture(),
      },
      "mooncode_native_eval_report": complete_native_eval_report_fixture(),
    },
    events,
  )
  assert_eq(
    summary_json_int(summary, "readiness_passed_check_count", default=0),
    18,
  )
  assert_eq(summary_json_int(summary, "readiness_check_count", default=0), 18)
  assert_eq(summary_json_int(summary, "readiness_blocked_count", default=9), 0)
  assert_eq(
    summary_json_int(summary, "canonical_conversation_turn_count", default=0),
    1,
  )
  assert_true(json_bool(summary, "canonical_conversation_ready", default=false))
  let readiness = summary_json_object_field_or_empty(summary, "readiness")
  assert_eq(json_string(readiness, "kind", default=""), "mooncode-readiness")
  assert_true(json_bool(readiness, "ready", default=false))
  assert_eq(json_string(readiness, "next_action", default=""), "completed")
  assert_eq(json_string(readiness, "next_owner", default=""), "none")
  assert_eq(summary_json_int(readiness, "blocked_count", default=9), 0)
  let checks = json_array_items(summary, "readiness_checks")
  assert_eq(json_string(checks[0], "id", default=""), "moonbook_selected")
  let mut found_resume_lifecycle = false
  let mut found_runtime_supervisor = false
  let mut found_canonical_conversation = false
  let mut found_native_eval = false
  let mut found_package_lifecycle = false
  for check in checks {
    if json_string(check, "id", default="") == "resume_lifecycle" {
      found_resume_lifecycle = true
      assert_true(json_bool(check, "ok", default=false))
    }
    if json_string(check, "id", default="") == "runtime_supervisor_ready" {
      found_runtime_supervisor = true
      assert_true(json_bool(check, "ok", default=false))
    }
    if json_string(check, "id", default="") == "canonical_conversation" {
      found_canonical_conversation = true
      assert_true(json_bool(check, "ok", default=false))
      assert_eq(
        json_string(check, "evidence", default=""),
        "1 canonical turn(s)",
      )
    }
    if json_string(check, "id", default="") == "native_eval_ready" {
      found_native_eval = true
      assert_true(json_bool(check, "ok", default=false))
    }
    if json_string(check, "id", default="") == "package_lifecycle" {
      found_package_lifecycle = true
      assert_true(json_bool(check, "ok", default=false))
    }
  }
  assert_true(found_resume_lifecycle)
  assert_true(found_runtime_supervisor)
  assert_true(found_canonical_conversation)
  assert_true(found_native_eval)
  assert_true(found_package_lifecycle)
  assert_eq(
    json_string(checks[checks.length() - 1], "id", default=""),
    "standalone_boundary",
  )
}

///|
test "mooncode session summary reports live action blockers in readiness checks" {
  let summary = session_summary(
    {
      "id": "s1",
      "workspace_id": "book",
      "mooncode_runtime_session_id": "runtime",
      "mooncode_last_action_plan_manifest": {
        "kind": "mooncode-action-plan",
        "status": "blocked",
        "next_required_action": "resolve_tool_approvals",
        "blocked_count": 1,
        "pending_runtime_count": 1,
        "running_count": 0,
        "pending_diff_count": 1,
        "pending_tool_approval_count": 1,
        "pending_steer_count": 0,
        "failed_test_count": 0,
      },
    },
    [],
  )
  let checks = json_array_items(summary, "readiness_checks")
  let readiness = summary_json_object_field_or_empty(summary, "readiness")
  assert_eq(json_string(readiness, "kind", default=""), "mooncode-readiness")
  assert_false(json_bool(readiness, "ready", default=true))
  assert_eq(
    json_string(readiness, "first_blocker_id", default=""),
    "durable_session",
  )
  assert_eq(
    json_string(readiness, "next_action", default=""),
    "persist_session_snapshot",
  )
  assert_eq(
    json_string(readiness, "next_owner", default=""),
    "mooncode-moonbook",
  )
  assert_true(
    json_array_items(readiness, "blocking_check_ids")
    .map(item => item.stringify())
    .contains("\"live_blockers_clear\""),
  )
  let mut found_action_plan = false
  let mut found_blockers = false
  for check in checks {
    match json_string(check, "id", default="") {
      "action_plan_current" => {
        found_action_plan = true
        assert_true(json_bool(check, "ok", default=false))
      }
      "live_blockers_clear" => {
        found_blockers = true
        assert_false(json_bool(check, "ok", default=true))
        assert_true(
          json_string(check, "evidence", default="").contains("pending tools 1"),
        )
      }
      _ => ()
    }
  }
  assert_true(found_action_plan)
  assert_true(found_blockers)
}

///|
test "mooncode readiness blocks partial patch lifecycle" {
  let summary = session_summary(
    {
      "id": "s1",
      "workspace_id": "book",
      "mooncode_runtime_session_id": "runtime",
      "mooncode_last_action_plan_manifest": {
        "kind": "mooncode-action-plan",
        "status": "review-ready",
        "next_required_action": "accept_or_reject_changes",
        "blocked_count": 0,
        "pending_runtime_count": 0,
        "running_count": 0,
        "pending_diff_count": 0,
        "patch_needs_review_count": 0,
        "patch_runtime_needed_count": 0,
        "partial_patch_count": 1,
        "runtime_partial_patch_count": 1,
        "pending_tool_approval_count": 0,
        "pending_steer_count": 0,
        "failed_test_count": 0,
      },
    },
    [],
  )
  let checks = json_array_items(summary, "readiness_checks")
  let mut found_blockers = false
  for check in checks {
    if json_string(check, "id", default="") == "live_blockers_clear" {
      found_blockers = true
      assert_false(json_bool(check, "ok", default=true))
      let evidence = json_string(check, "evidence", default="")
      assert_true(evidence.contains("partial patches 1"))
      assert_true(evidence.contains("runtime partial patches 1"))
    }
  }
  assert_true(found_blockers)
}

///|
test "mooncode session projection response attaches events and summary without leaking host fields" {
  let event = event_record(
    id="evt-1",
    lane="tool",
    kind="tool.read",
    title="Read file",
    status="done",
    created_at="1",
    detail="read source",
    path="tools/demo/main.mbt",
  )
  let projected = session_projection_response(
    { "id": "s1", "workspace_id": "book" },
    [event],
    event_log_path="/tmp/mooncode/events.jsonl",
    append_log_count=2,
    command_log_path="/tmp/mooncode/commands.jsonl",
    command_log_count=3,
    runtime_command_log_path="/tmp/mooncode/runtime-commands.jsonl",
    runtime_command_log_count=4,
    runtime_receipt_log_path="/tmp/mooncode/runtime-receipt.jsonl",
    runtime_receipt_log_count=5,
  )
  assert_eq(json_array_items(projected, "mooncode_events").length(), 1)
  assert_true(
    summary_json_object_field(projected, "mooncode_event_log_path") is None,
  )
  let summary = summary_json_object_field_or_empty(
    projected, "mooncode_summary",
  )
  assert_eq(
    json_string(summary, "event_log_path", default=""),
    "/tmp/mooncode/events.jsonl",
  )
  assert_eq(summary_json_int(summary, "append_log_count", default=0), 2)
  assert_eq(summary_json_int(summary, "command_log_count", default=0), 3)
  assert_eq(summary_json_int(summary, "runtime_command_count", default=0), 4)
  assert_eq(summary_json_int(summary, "runtime_receipt_count", default=0), 5)
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
test "mooncode session summary exposes package lifecycle" {
  let events : Array[Json] = [
    event_record(
      id="package-proof-1",
      lane="artifact",
      kind="runtime.package_verified",
      title="Package verified by runtime",
      status="done",
      created_at="1",
      detail="verified",
      path="tools/demo/main.mbt",
      command="package",
    ),
  ]
  let session_base : Json = {
    "id": "s1",
    "workspace_id": "book",
    "mooncode_runtime_session_id": "runtime",
    "mooncode_command_events": events,
  }
  let manifest = package_manifest(
    session_base,
    { "receipt_path": "wiki/reviews/mooncode/s1/package-cmd-1.json" },
    { "command_id": "cmd-1" },
    "tools/demo/main.mbt",
    "Package tool",
    "2026-06-15T00:00:00Z",
    "2026-06-15T00:01:00Z",
    "portable/app-tool/mooncode/s1/package-cmd-1.json",
    "/tmp/book/portable/app-tool/mooncode/s1/package-cmd-1.json",
    [
      {
        "path": "tools/demo/main.mbt",
        "exists": true,
        "kind": "file",
        "package_ready": true,
      },
    ],
  )
  let index = package_index_manifest(
    session_base,
    "s1",
    manifest,
    [manifest],
    "2026-06-15T00:02:00Z",
    "portable/app-tool/mooncode/s1/index.json",
    "/tmp/book/portable/app-tool/mooncode/s1/index.json",
    "portable/app-tool/mooncode/s1",
  )
  let summary = session_summary(
    {
      "id": "s1",
      "workspace_id": "book",
      "mooncode_runtime_session_id": "runtime",
      "mooncode_last_package_manifest": manifest,
      "mooncode_last_package_index_manifest": index,
    },
    events,
  )
  let lifecycle = summary_json_object_field_or_empty(
    summary, "package_lifecycle",
  )
  assert_eq(
    json_string(lifecycle, "kind", default=""),
    "mooncode-package-lifecycle",
  )
  assert_eq(json_string(lifecycle, "latest_status", default=""), "verified")
  assert_eq(summary_json_int(lifecycle, "package_count", default=0), 1)
  assert_eq(
    summary_json_int(lifecycle, "source_bound_package_count", default=0),
    1,
  )
  assert_eq(summary_json_int(lifecycle, "executable_ready_count", default=0), 1)
  assert_eq(
    summary_json_int(lifecycle, "runtime_verified_package_count", default=0),
    1,
  )
  let rows = json_array_items(lifecycle, "rows")
  assert_eq(rows.length(), 1)
  assert_eq(json_string(rows[0], "execution_state", default=""), "verified")
  assert_true(
    json_string(lifecycle, "next_step", default="").contains(
      "Verified package proof",
    ),
  )
}

///|
test "mooncode session summary exposes resume lifecycle" {
  let command : Json = {
    "protocol": protocol_version(),
    "kind": kind_runtime_command(),
    "command_id": "cmd-resume",
    "session_id": "s1",
    "action": "prompt",
    "control": "prompt",
    "code_command": "prompt",
    "mooncode_command": { "command": "prompt", "text": "continue work" },
    "tool_authorization": {
      "enforcement_state": "approved",
      "runtime_may_execute": true,
    },
  }
  let summary = session_summary(
    {
      "id": "s1",
      "workspace_id": "book",
      "mooncode_runtime_session_id": "runtime",
      "mooncode_session_snapshot": session_snapshot(
        {
          "id": "s1",
          "workspace_id": "book",
          "mooncode_runtime_session_id": "runtime",
          "transcript": [],
        },
        [],
        [],
        [command],
        [],
        recorded_at="2026-06-18T00:00:00Z",
        snapshot_path=".moonsuite/products/mooncode/sessions/s1/session.json",
        command_log_path=".moonsuite/products/mooncode/sessions/s1/commands.jsonl",
        runtime_command_log_path=".moonsuite/products/mooncode/sessions/s1/runtime-commands.jsonl",
        runtime_receipt_log_path=".moonsuite/products/mooncode/sessions/s1/runtime-receipts.jsonl",
        event_log_path=".moonsuite/products/mooncode/sessions/s1/events.jsonl",
      ),
    },
    [],
  )
  let lifecycle = summary_json_object_field_or_empty(
    summary, "resume_lifecycle",
  )
  assert_eq(
    json_string(lifecycle, "kind", default=""),
    "mooncode-resume-lifecycle",
  )
  assert_eq(json_string(lifecycle, "latest_status", default=""), "resumable")
  assert_true(json_bool(lifecycle, "snapshot_ready", default=false))
  assert_eq(summary_json_int(lifecycle, "runtime_command_count", default=0), 1)
  assert_eq(summary_json_int(lifecycle, "pending_count", default=0), 1)
  assert_eq(json_string(lifecycle, "next_command_id", default=""), "cmd-resume")
  let rows = json_array_items(lifecycle, "rows")
  assert_eq(rows.length(), 1)
  assert_eq(json_string(rows[0], "status", default=""), "pending")
  assert_true(
    json_string(lifecycle, "next_step", default="").contains("native loop"),
  )
}

///|
test "mooncode session summary exposes patch lifecycle" {
  let events : Array[Json] = [
    event_record(
      id="diff-1",
      lane="diff",
      kind="tool.edit",
      title="Edit file",
      status="done",
      created_at="1",
      detail="edited",
      path="tools/demo/main.mbt",
      diff="@@ -1 +1 @@\n-old\n+new",
    ),
  ]
  let summary = session_summary({ "id": "s1", "workspace_id": "book" }, events)
  let lifecycle = summary_json_object_field_or_empty(summary, "patch_lifecycle")
  assert_eq(
    json_string(lifecycle, "kind", default=""),
    "mooncode-patch-lifecycle",
  )
  assert_eq(summary_json_int(lifecycle, "patch_count", default=0), 1)
  assert_eq(summary_json_int(lifecycle, "needs_review_count", default=0), 1)
  assert_eq(
    json_string(lifecycle, "next_step", default=""),
    "Accept or reject pending patch targets before packaging or committing.",
  )
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
        "protocol": protocol_version(),
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
        "protocol": protocol_version(),
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
      command_packet={
        "protocol": protocol_version(),
        "command_id": "cmd-steer-1",
        "action": "steer",
      },
    ),
    event_record(
      id="steer-deferred-1",
      lane="runtime",
      kind=event_steer_deferred(),
      title="Steering deferred",
      status="queued",
      created_at="4",
      detail="tighten scope",
      command_packet={
        "protocol": protocol_version(),
        "command_id": "cmd-steer-2",
        "action": "steer",
      },
    ),
  ]
  let summary = session_summary({ "id": "s1", "workspace_id": "book" }, events)
  assert_eq(summary_json_int(summary, "steer_command_count", default=0), 2)
  assert_eq(summary_json_int(summary, "steer_settlement_count", default=0), 1)
  assert_eq(summary_json_int(summary, "deferred_steer_count", default=0), 1)
  assert_eq(summary_json_int(summary, "pending_steer_count", default=0), 1)
  let lifecycle = summary_json_object_field_or_empty(
    summary, "steering_lifecycle",
  )
  assert_eq(
    json_string(lifecycle, "kind", default=""),
    "mooncode-steering-lifecycle",
  )
  assert_eq(summary_json_int(lifecycle, "steer_command_count", default=0), 2)
  assert_eq(summary_json_int(lifecycle, "applied_count", default=0), 1)
  assert_eq(summary_json_int(lifecycle, "deferred_count", default=0), 1)
  assert_eq(summary_json_int(lifecycle, "pending_count", default=0), 0)
  let rows = json_array_items(lifecycle, "rows")
  assert_eq(rows.length(), 2)
  assert_eq(json_string(rows[0], "command_id", default=""), "cmd-steer-1")
  assert_eq(json_string(rows[0], "status", default=""), "applied")
  assert_eq(json_string(rows[1], "command_id", default=""), "cmd-steer-2")
  assert_eq(json_string(rows[1], "status", default=""), "deferred")
  assert_eq(pending_steer_count(1, 2), 0)
}

///|
test "mooncode session summary tracks cancel lifecycle evidence" {
  let events : Array[Json] = [
    command_event(
      action="cancel",
      status="queued",
      detail="stop active run",
      created_at="1",
      path="tools/demo/main.mbt",
      command_packet={
        "protocol": protocol_version(),
        "command_id": "cmd-cancel-1",
        "action": "cancel",
      },
      event_id="cmd-cancel-1",
    ),
    command_event(
      action="cancel",
      status="queued",
      detail="cancel idle",
      created_at="2",
      path="tools/demo/main.mbt",
      command_packet={
        "protocol": protocol_version(),
        "command_id": "cmd-cancel-2",
        "action": "cancel",
      },
      event_id="cmd-cancel-2",
    ),
    command_event(
      action="cancel",
      status="queued",
      detail="still pending",
      created_at="3",
      path="tools/demo/main.mbt",
      command_packet={
        "protocol": protocol_version(),
        "command_id": "cmd-cancel-3",
        "action": "cancel",
      },
      event_id="cmd-cancel-3",
    ),
    event_record(
      id="cancel-proof-1",
      lane="runtime",
      kind="runtime_aborted",
      title="Runtime interrupted",
      status="cancelled",
      created_at="4",
      detail="active run cancelled",
      command_packet={
        "protocol": protocol_version(),
        "command_id": "cmd-cancel-1",
        "action": "cancel",
      },
    ),
    event_record(
      id="cancel-proof-2",
      lane="runtime",
      kind=event_cancel_dropped(),
      title="Cancel dropped",
      status="done",
      created_at="5",
      detail="no active turn",
      command_packet={
        "protocol": protocol_version(),
        "command_id": "cmd-cancel-2",
        "action": "cancel",
      },
    ),
  ]
  let summary = session_summary({ "id": "s1", "workspace_id": "book" }, events)
  assert_eq(summary_json_int(summary, "cancel_command_count", default=0), 3)
  assert_eq(summary_json_int(summary, "cancel_dropped_count", default=0), 1)
  assert_eq(summary_json_int(summary, "cancel_settlement_count", default=0), 2)
  assert_eq(summary_json_int(summary, "pending_cancel_count", default=0), 1)
  let lifecycle = summary_json_object_field_or_empty(
    summary, "cancel_lifecycle",
  )
  assert_eq(
    json_string(lifecycle, "kind", default=""),
    "mooncode-cancel-lifecycle",
  )
  assert_eq(summary_json_int(lifecycle, "cancel_command_count", default=0), 3)
  assert_eq(summary_json_int(lifecycle, "cancelled_count", default=0), 1)
  assert_eq(summary_json_int(lifecycle, "dropped_count", default=0), 1)
  assert_eq(summary_json_int(lifecycle, "pending_count", default=0), 1)
  let rows = json_array_items(lifecycle, "rows")
  assert_eq(rows.length(), 3)
  assert_eq(json_string(rows[0], "command_id", default=""), "cmd-cancel-1")
  assert_eq(json_string(rows[0], "status", default=""), "cancelled")
  assert_eq(json_string(rows[1], "command_id", default=""), "cmd-cancel-2")
  assert_eq(json_string(rows[1], "status", default=""), "dropped")
  assert_eq(json_string(rows[2], "command_id", default=""), "cmd-cancel-3")
  assert_eq(json_string(rows[2], "status", default=""), "pending")
  assert_eq(pending_cancel_count(1, 2), 0)
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
