///|
test "mooncode command runtime evidence requires command scoped proof" {
  let command : Json = { "command_id": "cmd-test", "action": "run_tests" }
  let runtime_command : Json = {
    "command_id": "cmd-test",
    "execution_summary": {
      "required_events": [
        "tool_call", "tool_result", "test_result", "runtime_finished",
      ],
      "required_outputs": ["exit code"],
    },
  }
  let scoped_packet : Json = { "command_id": "cmd-test", "action": "run_tests" }
  let evidence = command_runtime_evidence(command, runtime_command, [
    event_record(
      id="tool-start",
      lane="test",
      kind="moon_check",
      title="Tool started",
      status="running",
      created_at="2026-06-15T00:00:00Z",
      detail="moon check",
      command_packet=scoped_packet,
    )
    |> runtime_with_field("tool_call_id", "call-1".to_json()),
    event_record(
      id="tool-result",
      lane="test",
      kind="moon_check",
      title="Tool finished",
      status="done",
      created_at="2026-06-15T00:00:01Z",
      detail="ok",
      command_packet=scoped_packet,
    )
    |> runtime_with_field("tool_call_id", "call-1".to_json()),
    event_record(
      id="test-result",
      lane="test",
      kind=event_test_result(),
      title="Test result",
      status="done",
      created_at="2026-06-15T00:00:02Z",
      detail="ok",
      command_packet=scoped_packet,
    ),
    event_record(
      id="finish",
      lane="review",
      kind="finish",
      title="Runtime finished",
      status="done",
      created_at="2026-06-15T00:00:03Z",
      detail="done",
      command_packet=scoped_packet,
    ),
    event_record(
      id="unscoped-test",
      lane="test",
      kind=event_test_result(),
      title="Ignored",
      status="done",
      created_at="2026-06-15T00:00:04Z",
      detail="unscoped",
    ),
  ])
  assert_eq(json_string(evidence, "status", default=""), "proven")
  assert_true(json_bool(evidence, "proven", default=false))
  assert_eq(
    runtime_json_int(evidence, "proven_required_event_count", default=0),
    4,
  )
  assert_eq(
    runtime_json_int(evidence, "missing_required_event_count", default=-1),
    0,
  )
}

///|
test "mooncode runtime evidence accepts command-scoped replay ack events" {
  let command : Json = { "command_id": "cmd-tests", "action": "run_tests" }
  let runtime_command : Json = {
    "protocol": protocol_version(),
    "kind": "mooncode.runtime-command",
    "command_id": "cmd-tests",
    "session_id": "session-demo",
    "action": "run_tests",
    "control": "command",
    "execution_summary": {
      "required_events": [
        "tool_call", "tool_result", "test_result", "runtime_finished",
      ],
    },
    "mooncode_command": { "command": "prompt", "text": "run tests" },
  }
  let receipts = runtime_replay_ack_receipts(
    { "id": "session-demo", "workspace_id": "book-demo" },
    [runtime_command],
    {
      "consumer_id": "moonclaw-runtime",
      "command_id": "cmd-tests",
      "status": "runtime-completed",
      "acknowledged_at": "2026-06-15T00:00:00Z",
      "events": [
        {
          "event": event_tool_call(),
          "id": "evt-tool-start",
          "tool_name": "moon_check",
          "tool_call_id": "call-check",
          "arguments": "{\"command\":\"moon check\"}",
        },
        {
          "event": event_tool_result(),
          "id": "evt-tool-result",
          "tool_name": "moon_check",
          "tool_call_id": "call-check",
          "content": "moon check passed",
        },
        {
          "event": event_test_result(),
          "id": "evt-test",
          "command": "moon test",
          "status": "passed",
          "exit_code": 0,
        },
        { "event": "runtime_finished", "id": "evt-finish", "answer": "done" },
      ],
    },
  )
  let events = runtime_replay_ack_normalized_events(receipts)
  let evidence = command_runtime_evidence(command, runtime_command, events)
  assert_eq(json_string(evidence, "status", default=""), "proven")
  assert_eq(
    runtime_json_int(evidence, "proven_required_event_count", default=0),
    4,
  )
  let packet = evidence_json_object_field_or_empty(events[0], "command_packet")
  assert_eq(json_string(packet, "command_id", default=""), "cmd-tests")
  assert_eq(json_string(packet, "action", default=""), "run_tests")
}

///|
test "mooncode session runtime evidence aggregates command proof" {
  let run_tests : Json = {
    "command_id": "cmd-tests",
    "action": "run_tests",
    "created_at": "2026-06-15T00:00:00Z",
  }
  let commit : Json = {
    "command_id": "cmd-commit",
    "action": "commit",
    "created_at": "2026-06-15T00:00:10Z",
  }
  let runtime_command : Json = {
    "command_id": "cmd-tests",
    "execution_summary": {
      "required_events": ["tool_call", "tool_result", "test_result"],
    },
  }
  let packet : Json = { "command_id": "cmd-tests", "action": "run_tests" }
  let projection = session_runtime_evidence(
    { "id": "session-demo", "workspace_id": "book-demo" },
    [run_tests, commit],
    [runtime_command],
    [
      event_record(
        id="tool-start",
        lane="test",
        kind="moon_check",
        title="Tool started",
        status="running",
        created_at="2026-06-15T00:00:01Z",
        detail="moon check",
        command_packet=packet,
      )
      |> runtime_with_field("tool_call_id", "call-1".to_json()),
      event_record(
        id="tool-result",
        lane="test",
        kind="moon_check",
        title="Tool finished",
        status="done",
        created_at="2026-06-15T00:00:02Z",
        detail="ok",
        command_packet=packet,
      )
      |> runtime_with_field("tool_call_id", "call-1".to_json()),
      event_record(
        id="test-result",
        lane="test",
        kind=event_test_result(),
        title="Tests passed",
        status="done",
        created_at="2026-06-15T00:00:03Z",
        detail="ok",
        command_packet=packet,
      ),
    ],
    recorded_at="2026-06-15T00:01:00Z",
  )
  assert_eq(
    json_string(projection, "kind", default=""),
    "mooncode-session-runtime-evidence",
  )
  assert_eq(json_string(projection, "status", default=""), "missing-evidence")
  assert_eq(runtime_json_int(projection, "command_count", default=0), 2)
  assert_eq(runtime_json_int(projection, "proven_command_count", default=0), 1)
  assert_eq(
    runtime_json_int(projection, "missing_runtime_command_count", default=0),
    1,
  )
}

///|
test "mooncode session runtime evidence wrappers stamp manifest and log paths" {
  let evidence : Json = {
    "kind": "mooncode-session-runtime-evidence",
    "protocol": protocol_version(),
    "session_id": "session-demo",
    "status": "proven",
  }
  let manifest = session_runtime_evidence_manifest_response(
    evidence, "wiki/reviews/mooncode/session-demo/runtime-evidence.json", "/tmp/book/wiki/reviews/mooncode/session-demo/runtime-evidence.json",
  )
  assert_eq(
    json_string(manifest, "manifest_path", default=""),
    "wiki/reviews/mooncode/session-demo/runtime-evidence.json",
  )
  assert_eq(
    json_string(manifest, "absolute_manifest_path", default=""),
    "/tmp/book/wiki/reviews/mooncode/session-demo/runtime-evidence.json",
  )
  assert_eq(json_string(manifest, "status", default=""), "proven")
  let response = session_runtime_evidence_response(
    evidence, "wiki/reviews/mooncode/session-demo/runtime-evidence.json", "/tmp/book/wiki/reviews/mooncode/session-demo/runtime-evidence.json",
    "/tmp/mooncode/session-demo/commands.jsonl", "/tmp/mooncode/session-demo/runtime-commands.jsonl",
    "/tmp/mooncode/session-demo/events.jsonl",
  )
  assert_eq(
    json_string(response, "command_log_path", default=""),
    "/tmp/mooncode/session-demo/commands.jsonl",
  )
  assert_eq(
    json_string(response, "runtime_command_log_path", default=""),
    "/tmp/mooncode/session-demo/runtime-commands.jsonl",
  )
  assert_eq(
    json_string(response, "event_log_path", default=""),
    "/tmp/mooncode/session-demo/events.jsonl",
  )
  let native = session_runtime_evidence_response_with_native(
    evidence,
    "wiki/reviews/mooncode/session-demo/runtime-evidence.json",
    "/tmp/book/wiki/reviews/mooncode/session-demo/runtime-evidence.json",
    "/tmp/mooncode/session-demo/commands.jsonl",
    "/tmp/mooncode/session-demo/runtime-commands.jsonl",
    "/tmp/mooncode/session-demo/events.jsonl",
    local_event_count=1,
    native_state={
      "native_runtime_ready": true,
      "endpoint": "/v1/code/sessions/session-demo/runtime-events?book_root=%2Ftmp%2Fbook",
      "error": "",
    },
    native_report={
      "submitted_count": 3,
      "accepted_count": 2,
      "rejected_count": 1,
      "events": [{ "id": "native-1" }, { "id": "native-2" }],
    },
  )
  assert_eq(runtime_json_int(native, "local_event_count", default=0), 1)
  assert_eq(runtime_json_int(native, "native_event_count", default=0), 2)
  assert_eq(
    runtime_json_int(native, "native_runtime_events_submitted_count", default=0),
    3,
  )
  assert_eq(
    runtime_json_int(native, "native_runtime_events_accepted_count", default=0),
    2,
  )
  assert_eq(
    runtime_json_int(native, "native_runtime_events_rejected_count", default=0),
    1,
  )
  assert_true(json_bool(native, "native_runtime_ready", default=false))
  assert_eq(
    json_string(native, "native_runtime_events_endpoint", default=""),
    "/v1/code/sessions/session-demo/runtime-events?book_root=%2Ftmp%2Fbook",
  )
  assert_true(
    runtime_json_object_field(native, "native_runtime_events_report")
    is Some(Object(_)),
  )
}

///|
test "mooncode command runtime evidence reports missing and failed requirements" {
  let command : Json = { "command_id": "cmd-commit", "action": "commit" }
  let runtime_command : Json = {
    "command_id": "cmd-commit",
    "execution_summary": {
      "required_events": [
        "tool_call", "tool_result", "commit_created", "runtime_finished",
      ],
    },
  }
  let packet : Json = { "command_id": "cmd-commit", "action": "commit" }
  let evidence = command_runtime_evidence(command, runtime_command, [
    event_record(
      id="commit-failed",
      lane="review",
      kind="runtime.commit_created",
      title="Commit failed",
      status="failed",
      created_at="2026-06-15T00:00:00Z",
      detail="git failed",
      command_packet=packet,
    ),
  ])
  assert_eq(json_string(evidence, "status", default=""), "failed")
  assert_eq(
    runtime_json_int(evidence, "failed_required_event_count", default=0),
    1,
  )
  assert_true(
    evidence_json_string_array_items(evidence, "missing_required_events").contains(
      "runtime_finished",
    ),
  )
  assert_true(
    evidence_json_string_array_items(evidence, "failed_required_events").contains(
      "commit_created",
    ),
  )
}

///|
test "mooncode command runtime evidence fails command scoped tool decode errors" {
  let command : Json = { "command_id": "cmd-prompt", "action": "prompt" }
  let runtime_command : Json = {
    "command_id": "cmd-prompt",
    "execution_summary": {
      "required_events": ["tool_call", "tool_result", "runtime_finished"],
    },
  }
  let packet : Json = { "command_id": "cmd-prompt", "action": "prompt" }
  let evidence = command_runtime_evidence(command, runtime_command, [
    event_record(
      id="tool-decode-failed",
      lane="tool",
      kind=event_tool_call_decode_error(),
      title="Tool decode failed",
      status="failed",
      created_at="2026-06-15T00:00:00Z",
      detail="unknown tool: delete_everything",
      command_packet=packet,
    )
    |> runtime_with_field("tool_call_id", "call-danger".to_json())
    |> runtime_with_field("source_event", "tool_call".to_json()),
  ])
  assert_eq(json_string(evidence, "status", default=""), "failed")
  assert_eq(
    runtime_json_int(evidence, "failed_required_event_count", default=0),
    1,
  )
  assert_true(
    evidence_json_string_array_items(evidence, "failed_required_events").contains(
      "tool_call",
    ),
  )
  assert_true(
    evidence_json_string_array_items(evidence, "missing_required_events").contains(
      "tool_result",
    ),
  )
}
