///|
async test "mooncode durable runtime event satisfies action plan test proof" {
  let root = "/tmp/moondesk-mooncode-runtime-events-" +
    @desk.stable_id("runtime-event-test", @async.now().to_string())
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let session : Json = {
    "id": "agent-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "workspace_root": root,
    "moonclaw_task_id": "task-demo",
    "mooncode_dispatch_mode": "moonclaw-mooncode-runtime",
  }
  let payload : Json = { "context_path": "tools/demo/main.mbt" }
  let message = @mooncode.command_message("run_tests", payload)
  let packet = mooncode_command_packet(
    session, payload, "run_tests", message, "2026-06-14T00:00:00Z", "tools/demo/main.mbt",
  )
  let runtime_command = @mooncode.runtime_command_record(
    session, payload, message, packet,
  )
  append_mooncode_command_log(root, "agent-demo", packet)
  append_mooncode_runtime_command_log(root, "agent-demo", runtime_command)
  append_mooncode_runtime_dispatch_log(
    root,
    "agent-demo",
    mooncode_runtime_dispatch_receipt(session, runtime_command),
  )
  let before = mooncode_action_plan_projection(root, session)
  let before_actions = json_array_items(before, "actions")
  assert_eq(
    json_string(before_actions[0], "state", default=""),
    "awaiting-proof",
  )
  let command_id = json_string(packet, "command_id", default="")
  for
    event in @mooncode.runtime_ingest_events(
      {
        "events": [
          {
            "event": "tool_call",
            "id": "tool-call-read",
            "created_at": "2026-06-14T00:00:30Z",
            "tool_name": "read",
            "tool_call_id": "call-read",
            "arguments": "{\"path\":\"tools/demo/main.mbt\"}",
            "command_id": command_id,
            "action": "run_tests",
          },
          {
            "event": "tool_result",
            "id": "tool-result-read",
            "created_at": "2026-06-14T00:00:45Z",
            "tool_name": "read",
            "tool_call_id": "call-read",
            "content": "fn main { println(\"demo\") }",
            "command_id": command_id,
            "action": "run_tests",
          },
          {
            "event": "tool_call",
            "id": "tool-call-1",
            "created_at": "2026-06-14T00:01:00Z",
            "tool_name": "moon_check",
            "tool_call_id": "call-check",
            "arguments": "{\"command\":\"moon check\"}",
            "command_id": command_id,
            "action": "run_tests",
          },
          {
            "event": "tool_result",
            "id": "tool-result-1",
            "created_at": "2026-06-14T00:01:30Z",
            "tool_name": "moon_check",
            "tool_call_id": "call-check",
            "content": "moon check passed",
            "command_id": command_id,
            "action": "run_tests",
          },
          {
            "event": "tool_call",
            "id": "tool-call-shell",
            "created_at": "2026-06-14T00:01:40Z",
            "tool_name": "shell",
            "tool_call_id": "call-shell",
            "arguments": "{\"command\":\"moon test\"}",
            "command_id": command_id,
            "action": "run_tests",
          },
          {
            "event": "tool_result",
            "id": "tool-result-shell",
            "created_at": "2026-06-14T00:01:50Z",
            "tool_name": "shell",
            "tool_call_id": "call-shell",
            "content": "moon test passed",
            "command_id": command_id,
            "action": "run_tests",
          },
          {
            "event": "test_result",
            "id": "test-result-1",
            "created_at": "2026-06-14T00:02:00Z",
            "status": "done",
            "command": "moon test",
            "exit_code": 0,
            "detail": "Total tests: 1, passed: 1",
            "command_id": command_id,
          },
          {
            "event": "agent_finished",
            "id": "finish-1",
            "created_at": "2026-06-14T00:03:00Z",
            "answer": "done",
            "command_id": command_id,
            "action": "run_tests",
          },
        ],
      },
      ingested_at="2026-06-15T00:00:00Z",
    ) {
    append_mooncode_event_log(root, "agent-demo", event)
  }
  let after = mooncode_action_plan_projection(root, session)
  let after_actions = json_array_items(after, "actions")
  assert_eq(json_int(after, "verified_test_count", default=0), 3)
  assert_eq(json_string(after_actions[0], "state", default=""), "completed")
  let gates = json_object_field_or_empty(after, "acceptance_gates")
  assert_true(json_bool(gates, "has_verified_tests", default=false))
  let refreshed = refresh_mooncode_runtime_review_artifacts(
    root,
    attach_mooncode_session_projection(root, session),
  )
  let runtime_evidence = json_object_field_or_empty(
    refreshed, "mooncode_last_runtime_evidence_manifest",
  )
  assert_eq(
    json_string(runtime_evidence, "kind", default=""),
    "mooncode-session-runtime-evidence",
  )
  assert_eq(json_string(runtime_evidence, "status", default=""), "proven")
  assert_eq(
    json_int(runtime_evidence, "proven_required_event_count", default=0),
    4,
  )
  assert_true(
    @fs.exists(
      json_string(runtime_evidence, "absolute_manifest_path", default=""),
    ),
  )
  let manifest_events = json_array_items(refreshed, "mooncode_command_events")
  let mut has_runtime_evidence_manifest_event = false
  for event in manifest_events {
    if json_string(event, "kind", default="") == "runtime_evidence.manifest" {
      has_runtime_evidence_manifest_event = true
    }
  }
  assert_true(has_runtime_evidence_manifest_event)
}

///|
async test "mooncode runtime replay ack events persist as session evidence" {
  let root = "/tmp/moondesk-mooncode-replay-proof-" +
    @desk.stable_id("runtime-replay-proof-test", @async.now().to_string())
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let session : Json = {
    "id": "agent-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "workspace_root": root,
    "moonclaw_task_id": "task-demo",
    "mooncode_dispatch_mode": "moonclaw-mooncode-runtime",
  }
  let payload : Json = { "context_path": "tools/demo/main.mbt" }
  let message = @mooncode.command_message("run_tests", payload)
  let packet = mooncode_command_packet(
    session, payload, "run_tests", message, "2026-06-15T00:00:00Z", "tools/demo/main.mbt",
  )
  let runtime_command = @mooncode.runtime_command_record(
    session, payload, message, packet,
  )
  append_mooncode_command_log(root, "agent-demo", packet)
  append_mooncode_runtime_command_log(root, "agent-demo", runtime_command)
  let command_id = json_string(packet, "command_id", default="")
  let ack_receipts = mooncode_runtime_replay_ack_receipts(
    session,
    [runtime_command],
    {
      "consumer_id": "moonclaw-runtime",
      "command_id": command_id,
      "status": "runtime-completed",
      "acknowledged_at": "2026-06-15T00:01:00Z",
      "events": [
        {
          "event": "tool_call",
          "id": "evt-tool-start",
          "tool_name": "moon_check",
          "tool_call_id": "call-check",
          "arguments": "{\"command\":\"moon check\"}",
        },
        {
          "event": "tool_result",
          "id": "evt-tool-result",
          "tool_name": "moon_check",
          "tool_call_id": "call-check",
          "content": "moon check passed",
        },
        {
          "event": "test_result",
          "id": "evt-test",
          "command": "moon test",
          "status": "passed",
          "exit_code": 0,
        },
        { "event": "agent_finished", "id": "evt-finish", "answer": "done" },
      ],
    },
  )
  assert_eq(ack_receipts.length(), 1)
  append_mooncode_runtime_dispatch_log(root, "agent-demo", ack_receipts[0])
  let ack_events = @mooncode.runtime_replay_ack_normalized_events(ack_receipts)
  assert_eq(ack_events.length(), 4)
  for event in ack_events {
    append_mooncode_event_log(root, "agent-demo", event)
  }
  let stored_events = read_mooncode_event_log(root, "agent-demo")
  assert_eq(stored_events.length(), 4)
  let stored_packet = json_object_field_or_empty(
    stored_events[0],
    "command_packet",
  )
  assert_eq(
    json_string(stored_packet, "kind", default=""),
    "mooncode.command-ref",
  )
  assert_eq(json_string(stored_packet, "command_id", default=""), command_id)
  assert_eq(json_string(stored_packet, "action", default=""), "run_tests")
  assert_true(json_bool(stored_packet, "runtime_proof", default=false))
  let projection = mooncode_session_runtime_evidence_projection(root, session)
  assert_eq(json_string(projection, "status", default=""), "proven")
  assert_eq(json_int(projection, "command_count", default=0), 1)
  assert_eq(json_int(projection, "runtime_command_count", default=0), 1)
  assert_eq(json_int(projection, "proof_event_count", default=0), 4)
  assert_eq(json_int(projection, "proven_command_count", default=0), 1)
  assert_eq(json_int(projection, "missing_required_event_count", default=-1), 0)
  assert_eq(
    json_string(projection, "manifest_path", default=""),
    @mooncode.runtime_evidence_manifest_relative_path("agent-demo"),
  )
  assert_eq(
    json_string(projection, "absolute_manifest_path", default=""),
    @pathx.join(
      root,
      @mooncode.runtime_evidence_manifest_relative_path("agent-demo"),
    ),
  )
  let with_manifest = write_mooncode_runtime_evidence_if_possible(root, session)
  let manifest = json_object_field_or_empty(
    with_manifest, "mooncode_last_runtime_evidence_manifest",
  )
  assert_eq(
    json_string(manifest, "kind", default=""),
    "mooncode-session-runtime-evidence",
  )
  assert_eq(json_string(manifest, "status", default=""), "proven")
  assert_eq(
    json_string(manifest, "manifest_path", default=""),
    @mooncode.runtime_evidence_manifest_relative_path("agent-demo"),
  )
  assert_true(
    @fs.exists(json_string(manifest, "absolute_manifest_path", default="")),
  )
  let manifest_events = json_array_items(
    with_manifest, "mooncode_command_events",
  )
  assert_eq(
    json_string(manifest_events[0], "kind", default=""),
    "runtime_evidence.manifest",
  )
}
