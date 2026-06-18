///|
test "mooncode summary exposes eval readiness gates" {
  let base_session : Json = {
    "id": "s1",
    "workspace_id": "book",
    "moonclaw_task_id": "task-1",
    "mooncode_event_log_path": "/tmp/mooncode/events.jsonl",
    "mooncode_append_log_count": 1,
    "mooncode_command_log_path": "/tmp/mooncode/commands.jsonl",
    "mooncode_command_log_count": 1,
    "mooncode_last_package_manifest": {
      "kind": "mooncode-package-manifest",
      "source_inventory_status": "source-bound",
      "source_present_count": 1,
    },
    "mooncode_last_package_index_manifest": {
      "kind": "mooncode-package-index",
      "manifest_path": "portable/app-tool/mooncode/s1/index.json",
      "source_bound_package_count": 1,
    },
    "mooncode_last_change_set_manifest": {
      "kind": "mooncode-change-set",
      "manifest_path": "wiki/reviews/mooncode/s1/change-set.json",
    },
    "mooncode_last_patch_set_manifest": {
      "kind": "mooncode-patch-set",
      "manifest_path": "wiki/reviews/mooncode/s1/patch-set.json",
    },
    "mooncode_last_tool_approvals_manifest": {
      "kind": "mooncode-tool-approvals",
      "manifest_path": "wiki/reviews/mooncode/s1/tool-approvals.json",
    },
    "mooncode_last_test_runs_manifest": {
      "kind": "mooncode-test-runs",
      "manifest_path": "wiki/reviews/mooncode/s1/test-runs.json",
    },
    "mooncode_last_runtime_handoff_manifest": {
      "kind": "mooncode-runtime-handoff",
      "manifest_path": "wiki/reviews/mooncode/s1/runtime-handoff.json",
    },
  }
  let command_packet = @mooncode.projected_command_packet(
    base_session,
    { "context_path": "tools/demo/main.mbt" },
    "accept",
    "Accept the proposed file.",
    "7",
    "tools/demo/main.mbt",
  )
  let events = [
    @mooncode.event_record(
      id="transcript",
      lane="transcript",
      kind="message.user",
      title="User",
      status="recorded",
      created_at="1",
      detail="Please edit this book tool.",
    ),
    @mooncode.event_record(
      id="tool",
      lane="tool",
      kind="tool.read",
      title="Read",
      status="completed",
      created_at="2",
      detail="read source",
    ),
    @mooncode.event_record(
      id="diff",
      lane="diff",
      kind="file.write",
      title="Write",
      status="completed",
      created_at="3",
      detail="wrote file",
      path="tools/demo/main.mbt",
      diff="+fn main { println(\"ok\") }",
    ),
    @mooncode.event_record(
      id="test",
      lane="test",
      kind="tool.moon_check",
      title="Moon check",
      status="passed",
      created_at="4",
      detail="passed",
      command="moon test",
    ),
    @mooncode.event_record(
      id="artifact",
      lane="artifact",
      kind="artifact.package",
      title="Package",
      status="completed",
      created_at="5",
      detail="packaged",
    ),
    @mooncode.event_record(
      id="review",
      lane="review",
      kind="review.accept",
      title="Accept",
      status="accepted",
      created_at="6",
      detail="accepted",
      command_packet~,
    ),
    @mooncode.event_record(
      id="approve-tool",
      lane="review",
      kind="command.approve_tool",
      title="Approve tool",
      status="approved",
      created_at="6",
      detail="approved file write",
      path="tools/demo/main.mbt",
      command="approve_tool",
      command_packet~,
    ),
    @mooncode.event_record(
      id="approve-artifact",
      lane="review",
      kind="command.approve_tool",
      title="Approve artifact",
      status="approved",
      created_at="6",
      detail="approved package artifact",
      path="artifact",
      command="approve_tool",
      command_packet~,
    ),
    @mooncode.event_record(
      id="receipt",
      lane="review",
      kind="receipt.accept",
      title="MoonBook review receipt",
      status="recorded",
      created_at="7",
      detail="MoonBook review receipt recorded",
      path="wiki/reviews/mooncode/s1/accept-command.json",
      command_packet~,
    ),
    @mooncode.event_record(
      id="manifest",
      lane="artifact",
      kind="package.manifest",
      title="MoonBook package manifest",
      status="candidate",
      created_at="8",
      detail="MoonBook package manifest recorded",
      path="portable/app-tool/mooncode/s1/package-command.json",
      command_packet~,
    ),
    @mooncode.event_record(
      id="package-index",
      lane="artifact",
      kind="package.index",
      title="MoonBook package index",
      status="source-bound",
      created_at="8",
      detail="MoonBook package index recorded",
      path="portable/app-tool/mooncode/s1/index.json",
      command_packet~,
    ),
    @mooncode.event_record(
      id="change-set",
      lane="review",
      kind="change_set.manifest",
      title="MoonCode change set",
      status="pending",
      created_at="9",
      detail="MoonBook change-set manifest recorded",
      path="wiki/reviews/mooncode/s1/change-set.json",
      command_packet~,
    ),
    @mooncode.event_record(
      id="patch-set",
      lane="review",
      kind="patch_set.manifest",
      title="MoonCode patch set",
      status="accepted",
      created_at="10",
      detail="MoonBook patch-set manifest recorded",
      path="wiki/reviews/mooncode/s1/patch-set.json",
      command_packet~,
    ),
    @mooncode.event_record(
      id="tool-approvals",
      lane="review",
      kind="tool_approvals.manifest",
      title="MoonCode tool approvals",
      status="approved",
      created_at="11",
      detail="MoonBook tool-approval manifest recorded",
      path="wiki/reviews/mooncode/s1/tool-approvals.json",
      command_packet~,
    ),
    @mooncode.event_record(
      id="test-runs",
      lane="review",
      kind="test_runs.manifest",
      title="MoonCode test runs",
      status="passed",
      created_at="12",
      detail="MoonBook test-run manifest recorded",
      path="wiki/reviews/mooncode/s1/test-runs.json",
      command_packet~,
    ),
    @mooncode.event_record(
      id="runtime-evidence",
      lane="runtime",
      kind="runtime_evidence.manifest",
      title="MoonCode runtime evidence",
      status="proven",
      created_at="12",
      detail="MoonCode runtime evidence recorded",
      path="wiki/reviews/mooncode/s1/runtime-evidence.json",
      command_packet~,
    ),
    @mooncode.event_record(
      id="runtime-handoff",
      lane="runtime",
      kind="runtime.handoff",
      title="MoonCode runtime handoff",
      status="bridge-resumable",
      created_at="14",
      detail="MoonCode runtime handoff recorded",
      path="wiki/reviews/mooncode/s1/runtime-handoff.json",
      command_packet~,
    ),
  ]
  let summary = @mooncode.session_summary(base_session, events)
  assert_eq(
    json_string(summary, "stream_mode", default=""),
    "append-log-incremental",
  )
  assert_eq(
    json_string(summary, "stream_source", default=""),
    "moondesk-append-log-projection",
  )
  assert_true(json_bool(summary, "live_stream_ready", default=false))
  assert_true(
    json_string(summary, "live_stream_url", default="").contains("live=true"),
  )
  assert_true(
    json_string(summary, "live_stream_url", default="").contains(
      "timeout_ms=8000",
    ),
  )
  assert_true(json_bool(summary, "incremental_stream_ready", default=false))
  assert_true(
    json_string(summary, "incremental_stream_url", default="").contains(
      "since=<sequence>",
    ),
  )
  assert_eq(
    json_string(summary, "event_log_path", default=""),
    "/tmp/mooncode/events.jsonl",
  )
  assert_true(json_bool(summary, "append_log_ready", default=false))
  assert_eq(json_int(summary, "append_log_count", default=0), 1)
  assert_eq(
    json_string(summary, "command_log_path", default=""),
    "/tmp/mooncode/commands.jsonl",
  )
  assert_true(json_bool(summary, "command_log_ready", default=false))
  assert_eq(json_int(summary, "command_log_count", default=0), 1)
  assert_eq(json_int(summary, "command_packet_count", default=0), 1)
  assert_eq(json_int(summary, "moonbook_review_receipt_count", default=0), 1)
  assert_eq(json_int(summary, "moonbook_package_manifest_count", default=0), 1)
  assert_eq(
    json_int(summary, "moonbook_package_index_manifest_count", default=0),
    1,
  )
  assert_eq(
    json_int(summary, "moonbook_change_set_manifest_count", default=0),
    1,
  )
  assert_eq(
    json_int(summary, "moonbook_patch_set_manifest_count", default=0),
    1,
  )
  assert_eq(
    json_int(summary, "moonbook_tool_approvals_manifest_count", default=0),
    1,
  )
  assert_eq(
    json_int(summary, "moonbook_test_runs_manifest_count", default=0),
    1,
  )
  assert_eq(
    json_int(summary, "mooncode_runtime_evidence_manifest_count", default=0),
    1,
  )
  assert_eq(
    json_int(summary, "mooncode_runtime_handoff_manifest_count", default=0),
    1,
  )
  assert_false(json_bool(summary, "session_snapshot_ready", default=true))
  assert_eq(json_string(summary, "session_snapshot_path", default="x"), "")
  assert_eq(json_int(summary, "pending_tool_approval_count", default=-1), 0)
  assert_eq(json_int(summary, "verified_test_count", default=0), 1)
  assert_eq(json_int(summary, "failed_test_count", default=0), 0)
  assert_eq(json_int(summary, "source_bound_package_count", default=0), 1)
  assert_eq(json_int(summary, "runtime_package_proof_count", default=-1), 0)
  assert_eq(json_int(summary, "runtime_verified_package_count", default=-1), 0)
  assert_eq(
    json_int(summary, "runtime_patch_execution_proof_count", default=-1),
    0,
  )
  assert_eq(json_int(summary, "eval_score", default=0), 85)
  assert_eq(json_string(summary, "eval_level", default=""), "ready")
  assert_eq(json_int(summary, "pending_diff_count", default=0), 1)
  assert_eq(json_int(summary, "accepted_review_count", default=0), 0)
  assert_eq(json_string(summary, "review_state", default=""), "pending")
  let checks = json_array_items(summary, "eval_checks")
  assert_eq(checks.length(), 28)
  let eval_report = @mooncode.eval_report_projection(
    agent_session_with_field(base_session, "mooncode_summary", summary),
  )
  assert_eq(
    json_string(eval_report, "kind", default=""),
    "mooncode-eval-report",
  )
  assert_eq(json_string(eval_report, "status", default=""), "bridge-partial")
  assert_eq(json_int(eval_report, "bridge_score", default=0), 85)
  assert_eq(json_int(eval_report, "check_count", default=0), 28)
  assert_eq(json_int(eval_report, "missing_check_count", default=0), 4)
  assert_false(
    json_bool(eval_report, "native_eval_evidence_ready", default=true),
  )
  assert_eq(
    json_string(eval_report, "native_eval_source", default=""),
    "missing",
  )
  assert_eq(
    json_string(eval_report, "native_eval_endpoint", default=""),
    "/v1/mooncode/sessions/<id>/eval-report?book_root=<path>",
  )
  assert_eq(
    json_string(eval_report, "native_eval_ingest_method", default=""),
    "POST",
  )
  assert_eq(
    json_string(eval_report, "native_eval_ingest_endpoint", default=""),
    "/api/mooncode/sessions/s1/eval-report",
  )
  assert_true(
    json_string(eval_report, "current_gap", default="").contains("MoonClaw"),
  )
  let native_eval = @mooncode.normalize_native_eval_report(
    {
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
  let native_eval_report = @mooncode.eval_report_projection(
    agent_session_with_field(
      agent_session_with_field(base_session, "mooncode_summary", summary),
      "mooncode_native_eval_report",
      native_eval,
    ),
  )
  assert_eq(
    json_string(native_eval_report, "status", default=""),
    "native-partial",
  )
  assert_true(
    json_bool(native_eval_report, "native_eval_evidence_ready", default=false),
  )
  assert_eq(
    json_string(native_eval_report, "native_eval_source", default=""),
    "moonclaw-native-runtime",
  )
  assert_eq(json_string(checks[6], "id", default=""), "verified_test_results")
  assert_true(json_bool(checks[6], "ok", default=false))
  let check_payload = Json::array(checks).stringify()
  assert_true(check_payload.contains("typed_command_packets"))
  assert_true(check_payload.contains("ordered_command_queue"))
  assert_true(check_payload.contains("moonbook_review_receipts"))
  assert_true(check_payload.contains("moonbook_package_manifest"))
  assert_true(check_payload.contains("moonbook_package_index"))
  assert_true(check_payload.contains("moonbook_change_set_manifest"))
  assert_true(check_payload.contains("moonbook_patch_set_manifest"))
  assert_true(check_payload.contains("runtime_patch_execution_proof"))
  assert_true(check_payload.contains("runtime_package_proof"))
  assert_true(check_payload.contains("moonbook_tool_approvals_manifest"))
  assert_true(check_payload.contains("moonbook_test_runs_manifest"))
  assert_true(check_payload.contains("tool_approval_queue"))
  assert_eq(
    json_string(checks[checks.length() - 4], "id", default=""),
    "source_bound_package",
  )
  assert_true(json_bool(checks[checks.length() - 4], "ok", default=false))
  assert_eq(
    json_string(checks[checks.length() - 3], "id", default=""),
    "runtime_package_proof",
  )
  assert_false(json_bool(checks[checks.length() - 3], "ok", default=true))
  assert_eq(
    json_string(checks[checks.length() - 2], "id", default=""),
    "incremental_append_stream",
  )
  assert_true(json_bool(checks[checks.length() - 2], "ok", default=false))
  assert_eq(
    json_string(checks[checks.length() - 1], "id", default=""),
    "live_append_only_stream",
  )
  assert_true(json_bool(checks[checks.length() - 1], "ok", default=false))
  assert_true(
    json_string(checks[checks.length() - 1], "evidence", default="").contains(
      "?live=true",
    ),
  )
}

///|
async test "mooncode native eval report ingress persists moonbook proof" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-mooncode-native-eval-wbtest-" +
    @desk.stable_id("mooncode-native-eval", @async.now().to_string()),
  )
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let session : Json = {
    "id": "agent-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "workspace_root": root,
    "moonclaw_task_id": "task-demo",
    "mooncode_dispatch_mode": "moonclaw-mooncode-runtime",
  }
  let eval_payload : Json = { "context_path": "tools/demo/main.mbt" }
  let eval_message = @mooncode.command_message("run_eval", eval_payload)
  let eval_packet = @mooncode.projected_command_packet(
    session, eval_payload, "run_eval", eval_message, "2026-06-14T00:00:00Z", "tools/demo/main.mbt",
  )
  let eval_runtime_command = @mooncode.runtime_command_record(
    session, eval_payload, eval_message, eval_packet,
  )
  append_mooncode_command_log(root, "agent-demo", eval_packet)
  append_mooncode_runtime_command_log(root, "agent-demo", eval_runtime_command)
  append_mooncode_runtime_dispatch_log(
    root,
    "agent-demo",
    @mooncode.projected_runtime_dispatch_receipt(
      session, eval_runtime_command, "2026-06-14T00:01:00Z",
    ),
  )
  let before_plan = mooncode_action_plan_projection(root, session)
  let before_actions = json_array_items(before_plan, "actions")
  assert_eq(json_string(before_actions[0], "action", default=""), "run_eval")
  assert_eq(
    json_string(before_actions[0], "state", default=""),
    "awaiting-proof",
  )
  let command_id = json_string(eval_packet, "command_id", default="")
  for
    event in @mooncode.runtime_ingest_events(
      {
        "events": [
          {
            "event": "tool_call",
            "id": "eval-tool-call-read",
            "created_at": "2026-06-14T00:00:30Z",
            "tool_name": "read",
            "tool_call_id": "eval-call-read",
            "arguments": "{\"path\":\"tools/demo/main.mbt\"}",
            "command_id": command_id,
            "action": "run_eval",
          },
          {
            "event": "tool_result",
            "id": "eval-tool-result-read",
            "created_at": "2026-06-14T00:00:45Z",
            "tool_name": "read",
            "tool_call_id": "eval-call-read",
            "content": "fn main { println(\"demo\") }",
            "command_id": command_id,
            "action": "run_eval",
          },
          {
            "event": "tool_call",
            "id": "eval-tool-call-ide",
            "created_at": "2026-06-14T00:00:50Z",
            "tool_name": "moon_ide",
            "tool_call_id": "eval-call-ide",
            "arguments": "{\"action\":\"outline\",\"path\":\"tools/demo/main.mbt\"}",
            "command_id": command_id,
            "action": "run_eval",
          },
          {
            "event": "tool_result",
            "id": "eval-tool-result-ide",
            "created_at": "2026-06-14T00:00:55Z",
            "tool_name": "moon_ide",
            "tool_call_id": "eval-call-ide",
            "content": "main : () -> Unit",
            "command_id": command_id,
            "action": "run_eval",
          },
          {
            "event": "tool_call",
            "id": "eval-tool-call-cmd",
            "created_at": "2026-06-14T00:00:56Z",
            "tool_name": "moon_cmd",
            "tool_call_id": "eval-call-cmd",
            "arguments": "{\"command\":\"moon info\"}",
            "command_id": command_id,
            "action": "run_eval",
          },
          {
            "event": "tool_result",
            "id": "eval-tool-result-cmd",
            "created_at": "2026-06-14T00:00:57Z",
            "tool_name": "moon_cmd",
            "tool_call_id": "eval-call-cmd",
            "content": "moon info passed",
            "command_id": command_id,
            "action": "run_eval",
          },
          {
            "event": "tool_call",
            "id": "eval-tool-call-check",
            "created_at": "2026-06-14T00:01:00Z",
            "tool_name": "moon_check",
            "tool_call_id": "eval-call-check",
            "arguments": "{\"command\":\"moon check\"}",
            "command_id": command_id,
            "action": "run_eval",
          },
          {
            "event": "tool_result",
            "id": "eval-tool-result-check",
            "created_at": "2026-06-14T00:01:20Z",
            "tool_name": "moon_check",
            "tool_call_id": "eval-call-check",
            "content": "moon check passed",
            "command_id": command_id,
            "action": "run_eval",
          },
          {
            "event": "tool_call",
            "id": "eval-tool-call-shell",
            "created_at": "2026-06-14T00:01:40Z",
            "tool_name": "shell",
            "tool_call_id": "eval-call-shell",
            "arguments": "{\"command\":\"moon test\"}",
            "command_id": command_id,
            "action": "run_eval",
          },
          {
            "event": "tool_result",
            "id": "eval-tool-result-shell",
            "created_at": "2026-06-14T00:01:55Z",
            "tool_name": "shell",
            "tool_call_id": "eval-call-shell",
            "content": "moon test passed",
            "command_id": command_id,
            "action": "run_eval",
          },
          {
            "event": "test_result",
            "id": "eval-test-result",
            "created_at": "2026-06-14T00:02:10Z",
            "status": "done",
            "command": "moon test",
            "exit_code": 0,
            "detail": "Total tests: 1, passed: 1",
            "command_id": command_id,
            "action": "run_eval",
          },
          {
            "event": "agent_finished",
            "id": "eval-finish",
            "created_at": "2026-06-14T00:02:30Z",
            "answer": "eval passed",
            "command_id": command_id,
            "action": "run_eval",
          },
        ],
      },
      ingested_at="2026-06-15T00:00:00Z",
    ) {
    append_mooncode_event_log(root, "agent-demo", event)
  }
  let native_payload : Json = {
    "ok": true,
    "required_harnesses": [
      "tool_harness", "file_edit", "patch_review", "command_execution", "package_output",
    ],
    "harnesses": [
      { "id": "tool_harness", "status": "passed" },
      { "id": "file_edit", "status": "passed" },
      { "id": "patch_review", "status": "passed" },
      { "id": "command_execution", "status": "passed" },
      { "id": "package_output", "status": "passed" },
    ],
    "tool_harness": { "status": "passed", "passed_count": 8 },
    "file_edit": { "status": "passed", "passed_count": 5 },
    "patch_review": { "status": "passed", "passed_count": 4 },
    "command_execution": { "status": "passed", "passed_count": 9 },
    "package_output": { "status": "passed", "passed_count": 3 },
    "passed_count": 29,
    "failed_count": 0,
    "evidence": ["OpenSeek-style harnesses passed"],
  }
  let with_report = persist_mooncode_native_eval_report(
    root,
    session,
    native_payload,
    "/v1/mooncode/sessions/agent-demo/eval-report?book_root=" +
    encode_query_value(root),
  )
  let after_plan = mooncode_action_plan_projection(root, with_report)
  let after_actions = json_array_items(after_plan, "actions")
  assert_eq(json_string(after_actions[0], "action", default=""), "run_eval")
  assert_eq(json_string(after_actions[0], "state", default=""), "completed")
  let native_report = json_object_field_or_empty(
    with_report, "mooncode_native_eval_report",
  )
  assert_true(json_bool(native_report, "ok", default=false))
  assert_eq(
    json_string(native_report, "source", default=""),
    "moonclaw-native-runtime",
  )
  assert_eq(
    json_string(native_report, "endpoint", default=""),
    "/v1/mooncode/sessions/agent-demo/eval-report?book_root=" +
    encode_query_value(root),
  )
  let manifest = json_object_field_or_empty(
    with_report, "mooncode_last_eval_report_manifest",
  )
  assert_eq(json_string(manifest, "kind", default=""), "mooncode-eval-report")
  assert_true(json_bool(manifest, "native_eval_evidence_ready", default=false))
  assert_eq(json_string(manifest, "status", default=""), "native-partial")
  assert_eq(
    json_string(manifest, "native_eval_ingest_endpoint", default=""),
    "/api/mooncode/sessions/agent-demo/eval-report",
  )
  let relative = json_string(manifest, "manifest_path", default="")
  assert_eq(relative, "wiki/reviews/mooncode/agent-demo/eval-report.json")
  assert_true(@fs.exists(@pathx.join(root, relative)))
  let snapshot = json_object_field_or_empty(
    with_report, "mooncode_session_snapshot",
  )
  assert_eq(
    json_string(snapshot, "kind", default=""),
    "mooncode-session-snapshot",
  )
  assert_true(@fs.exists(json_string(snapshot, "snapshot_path", default="")))
  let runtime_handoff = json_object_field_or_empty(
    with_report, "mooncode_last_runtime_handoff_manifest",
  )
  assert_eq(
    json_string(runtime_handoff, "kind", default=""),
    "mooncode-runtime-handoff",
  )
  assert_true(
    @fs.exists(
      json_string(runtime_handoff, "absolute_manifest_path", default=""),
    ),
  )
  let durable_events = read_mooncode_event_log(root, "agent-demo")
  let mut saw_eval_report_event = false
  for event in durable_events {
    match json_string(event, "kind", default="") {
      "eval_report.manifest" =>
        if json_string(event, "path", default="") == relative {
          saw_eval_report_event = true
        }
      _ => ()
    }
  }
  assert_true(saw_eval_report_event)
  assert_false(manifest.stringify().contains("stale-eval-report"))
  let response_projection = @mooncode.eval_report_projection(with_report)
  let response_summary = json_object_field_or_empty(
    response_projection, "summary",
  )
  assert_eq(
    json_string(
      json_object_field_or_empty(
        response_summary, "last_moonbook_eval_report_manifest",
      ),
      "manifest_path",
      default="",
    ),
    relative,
  )
  assert_true(
    json_bool(response_summary, "session_snapshot_ready", default=false),
  )
  assert_eq(
    json_int(
      response_summary,
      "mooncode_runtime_handoff_manifest_count",
      default=0,
    ),
    1,
  )
  match read_agent_session_record(root, "agent-demo") {
    Some(saved) => {
      let saved_native = json_object_field_or_empty(
        saved, "mooncode_native_eval_report",
      )
      assert_true(json_bool(saved_native, "ok", default=false))
      assert_eq(
        json_string(
          json_object_field_or_empty(
            saved, "mooncode_last_eval_report_manifest",
          ),
          "manifest_path",
          default="",
        ),
        relative,
      )
      assert_true(
        json_bool(
          json_object_field_or_empty(saved, "mooncode_summary"),
          "session_snapshot_ready",
          default=false,
        ),
      )
    }
    None => fail("native eval ingress should persist the session record")
  }
}
