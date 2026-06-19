///|
test "mooncode runtime consumer ack completes run_tests with typed tool proof" {
  let session : Json = { "id": "session-demo", "workspace_id": "book-demo" }
  let runtime_command : Json = {
    "protocol": protocol_version(),
    "kind": "mooncode.runtime-command",
    "command_id": "cmd-tests",
    "session_id": "session-demo",
    "action": "run_tests",
    "control": "command",
    "code_command": "prompt",
    "mooncode_command": { "command": "prompt", "text": "run tests" },
    "execution_summary": {
      "tool_sequence": ["read", "moon_check", "shell", "finish"],
      "required_events": [
        "tool_call", "tool_result", "test_result", "runtime_finished",
      ],
    },
  }
  let ack = runtime_consumer_completion_ack(
    runtime_command,
    [
      runtime_consumer_tool_outcome(
        "read",
        call_id="call-read",
        arguments="{\"path\":\"tools/demo/main.mbt\"}",
        content="fn main { println(\"demo\") }",
        path="tools/demo/main.mbt",
      ),
      runtime_consumer_tool_outcome(
        "moon_check",
        call_id="call-check",
        arguments="{\"command\":\"moon check\"}",
        content="moon check passed",
        command="moon check",
      ),
      runtime_consumer_tool_outcome(
        "shell",
        call_id="call-shell",
        arguments="{\"command\":\"moon test\"}",
        content="Total tests: 1, passed: 1",
        command="moon test",
      ),
      runtime_consumer_tool_outcome("finish", content="tests passed"),
    ],
    [
      runtime_consumer_test_result_event(
        command="moon test",
        exit_code=0,
        detail="Total tests: 1, passed: 1",
      ),
    ],
    consumer_id="mooncode-local",
    acknowledged_at="2026-06-15T00:00:00Z",
  )
  let receipts = runtime_replay_ack_receipts(session, [runtime_command], ack)
  assert_eq(receipts.length(), 1)
  assert_eq(
    rq_json_string(receipts[0], "status", default=""),
    "runtime-completed",
  )
  let gate = rq_json_object_field_or_empty(receipts[0], "proof_gate")
  assert_eq(rq_json_string(gate, "status", default=""), "passed")
  assert_eq(rq_json_string(gate, "tool_harness_status", default=""), "proven")
  assert_eq(rq_json_int(gate, "tool_harness_expected_tool_count", default=0), 4)
  assert_eq(rq_json_int(gate, "tool_harness_proven_tool_count", default=0), 4)
}

///|
test "mooncode runtime consumer ack is proof-missing when an expected tool outcome is absent" {
  let session : Json = { "id": "session-demo", "workspace_id": "book-demo" }
  let runtime_command : Json = {
    "protocol": protocol_version(),
    "kind": "mooncode.runtime-command",
    "command_id": "cmd-tests",
    "session_id": "session-demo",
    "action": "run_tests",
    "control": "command",
    "code_command": "prompt",
    "mooncode_command": { "command": "prompt", "text": "run tests" },
    "execution_summary": {
      "tool_sequence": ["read", "moon_check", "shell", "finish"],
      "required_events": [
        "tool_call", "tool_result", "test_result", "runtime_finished",
      ],
    },
  }
  let ack = runtime_consumer_completion_ack(
    runtime_command,
    [
      runtime_consumer_tool_outcome("read", call_id="call-read", content="ok"),
      runtime_consumer_tool_outcome(
        "moon_check",
        call_id="call-check",
        content="moon check passed",
      ),
      runtime_consumer_tool_outcome("finish", content="done"),
    ],
    [runtime_consumer_test_result_event(command="moon test", exit_code=0)],
    consumer_id="mooncode-local",
    acknowledged_at="2026-06-15T00:00:00Z",
  )
  let receipts = runtime_replay_ack_receipts(session, [runtime_command], ack)
  assert_eq(receipts.length(), 1)
  assert_eq(rq_json_string(receipts[0], "status", default=""), "proof-missing")
  let gate = rq_json_object_field_or_empty(receipts[0], "proof_gate")
  assert_true(rq_json_bool(gate, "completion_blocked", default=false))
  assert_true(
    rq_json_bool(gate, "tool_harness_completion_blocked", default=false),
  )
  assert_eq(rq_json_string(gate, "tool_harness_status", default=""), "failed")
  assert_eq(rq_json_int(gate, "tool_harness_failed_tool_count", default=0), 1)
}

///|
test "mooncode runtime consumer package output ack proves executable package completion" {
  let session : Json = { "id": "session-demo", "workspace_id": "book-demo" }
  let runtime_command : Json = {
    "protocol": protocol_version(),
    "kind": "mooncode.runtime-command",
    "command_id": "cmd-package",
    "session_id": "session-demo",
    "action": "package",
    "control": "command",
    "code_command": "prompt",
    "mooncode_command": { "command": "prompt", "text": "package output" },
    "execution_summary": {
      "tool_sequence": [
        "read", "moon_check", "shell", "package_app_tool", "finish",
      ],
      "required_events": [
        "tool_call", "tool_result", "artifact", "package.manifest", "package.index",
        "package_verified", "runtime_finished",
      ],
    },
  }
  let ack = runtime_consumer_package_output_ack(
    runtime_command,
    "tools/demo/main.mbt",
    "portable/app-tool/demo",
    "wiki/reviews/mooncode/session-demo/package-cmd-package.json",
    "portable/app-tool/mooncode/session-demo/index.json",
    package_kind="app-tool",
    consumer_id="mooncode-local",
    acknowledged_at="2026-06-15T00:00:00Z",
  )
  let receipts = runtime_replay_ack_receipts(session, [runtime_command], ack)
  assert_eq(receipts.length(), 1)
  assert_eq(
    rq_json_string(receipts[0], "status", default=""),
    "runtime-completed",
  )
  let gate = rq_json_object_field_or_empty(receipts[0], "proof_gate")
  assert_eq(rq_json_string(gate, "status", default=""), "passed")
  assert_eq(rq_json_string(gate, "tool_harness_status", default=""), "proven")
  assert_eq(rq_json_int(gate, "tool_harness_expected_tool_count", default=0), 5)
  assert_eq(rq_json_int(gate, "tool_harness_proven_tool_count", default=0), 5)
  assert_eq(rq_json_int(gate, "missing_required_event_count", default=-1), 0)
  let summary = rq_json_object_field_or_empty(
    receipts[0],
    "runtime_event_summary",
  )
  assert_true(rq_json_int(summary, "artifact_event_count", default=0) >= 4)
  let events = runtime_replay_ack_normalized_events(receipts)
  let mut saw_manifest = false
  let mut saw_index = false
  let mut saw_verified = false
  for event in events {
    match rq_json_string(event, "kind", default="") {
      "package.manifest" => saw_manifest = true
      "package.index" => saw_index = true
      "runtime.package_verified" => saw_verified = true
      _ => ()
    }
  }
  assert_true(saw_manifest)
  assert_true(saw_index)
  assert_true(saw_verified)
}
