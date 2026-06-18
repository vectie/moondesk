///|
// White-box tests for MoonCode runtime event normalization and ingest surfaces.

///|
fn runtime_json_string_array_items(json : Json, key : String) -> Array[String] {
  match runtime_json_object_field(json, key) {
    Some(Json::Array(values)) => {
      let result : Array[String] = []
      for value in values {
        match value {
          Json::String(text) => result.push(text)
          _ => ()
        }
      }
      result
    }
    _ => []
  }
}

///|
test "mooncode normalizes OpenSeek runtime events into lanes" {
  let fallback_a = runtime_event_fallback_id({
    "event": "assistant_delta",
    "content": "hello",
  })
  let fallback_b = runtime_event_fallback_id({
    "event": "assistant_delta",
    "content": "hello",
  })
  assert_eq(fallback_a, fallback_b)
  assert_true(fallback_a.has_prefix("mooncode-runtime-event-"))
  guard normalize_runtime_event_with_defaults(
      { "event": "assistant_delta", "content": "hello" },
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(defaulted_event) else {
    fail("defaulted assistant_delta was not normalized")
  }
  assert_eq(json_string(defaulted_event, "id", default=""), fallback_a)
  assert_eq(
    json_string(defaulted_event, "created_at", default=""),
    "2026-06-15T00:00:00Z",
  )
  guard normalize_runtime_event(
      {
        "event": event_tool_call(),
        "tool_call_id": "call-shell",
        "tool_name": "shell",
        "command_id": "cmd-test-call",
        "arguments": "{\"cmd\":[\"moon\",\"test\",\"tools/demo\"],\"cwd\":\"tools/demo\"}",
      },
      fallback_id="runtime-1",
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(tool_call_event) else {
    fail("tool_call was not normalized")
  }
  assert_eq(json_string(tool_call_event, "lane", default=""), "test")
  assert_eq(json_string(tool_call_event, "kind", default=""), "shell")
  assert_eq(
    json_string(tool_call_event, "command", default=""),
    "moon test tools/demo",
  )
  assert_eq(json_string(tool_call_event, "status", default=""), "running")
  let tool_call_packet = runtime_json_object_field_or_empty(
    tool_call_event, "command_packet",
  )
  assert_eq(
    json_string(tool_call_packet, "command_id", default=""),
    "cmd-test-call",
  )
  assert_eq(json_string(tool_call_packet, "action", default=""), "run_tests")
  guard normalize_runtime_event(
      {
        "event": event_tool_result(),
        "tool_call_id": "call-check",
        "tool_name": "moon_check",
        "arguments": "{\"cmd\":[\"moon\",\"test\",\"tools/demo\"],\"cwd\":\"tools/demo\"}",
        "command_id": "cmd-test-1",
        "content": "Total tests: 3, passed: 3",
        "is_error": false,
      },
      fallback_id="runtime-2",
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(test_event) else {
    fail("tool_result was not normalized")
  }
  assert_eq(json_string(test_event, "lane", default=""), "test")
  assert_eq(json_string(test_event, "status", default=""), "done")
  assert_eq(
    json_string(test_event, "command", default=""),
    "moon test tools/demo",
  )
  assert_eq(json_string(test_event, "path", default=""), "")
  assert_eq(json_string(test_event, "tool_call_id", default=""), "call-check")
  let test_packet = runtime_json_object_field_or_empty(
    test_event, "command_packet",
  )
  assert_eq(json_string(test_packet, "command_id", default=""), "cmd-test-1")
  assert_eq(json_string(test_packet, "action", default=""), "run_tests")
  guard normalize_runtime_event(
      { "event": "agent_finished", "answer": "done" },
      fallback_id="runtime-3",
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(review_event) else {
    fail("agent_finished was not normalized")
  }
  assert_eq(json_string(review_event, "lane", default=""), "review")
  assert_eq(json_string(review_event, "kind", default=""), "finish")
  guard normalize_runtime_event(
      { "event": "steer_applied", "content": "focus the tests" },
      fallback_id="runtime-4",
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(steer_applied_event) else {
    fail("steer_applied was not normalized")
  }
  assert_eq(json_string(steer_applied_event, "lane", default=""), "runtime")
  assert_eq(
    json_string(steer_applied_event, "kind", default=""),
    "steer_applied",
  )
  assert_eq(json_string(steer_applied_event, "status", default=""), "done")
  assert_eq(
    json_string(steer_applied_event, "detail", default=""),
    "focus the tests",
  )
  guard normalize_runtime_event(
      { "event": "steer_dropped", "content": "too late" },
      fallback_id="runtime-5",
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(steer_dropped_event) else {
    fail("steer_dropped was not normalized")
  }
  assert_eq(
    json_string(steer_dropped_event, "kind", default=""),
    "steer_dropped",
  )
  assert_eq(json_string(steer_dropped_event, "status", default=""), "failed")
  guard normalize_runtime_event(
      { "event": "steer_deferred", "content": "next turn" },
      fallback_id="runtime-6",
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(steer_deferred_event) else {
    fail("steer_deferred was not normalized")
  }
  assert_eq(
    json_string(steer_deferred_event, "kind", default=""),
    "steer_deferred",
  )
  assert_eq(json_string(steer_deferred_event, "status", default=""), "queued")
  guard normalize_runtime_event(
      {
        "event": event_cancel_dropped(),
        "command_id": "cmd-cancel-1",
        "content": "nothing active",
      },
      fallback_id="runtime-7",
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(cancel_dropped_event) else {
    fail("cancel_dropped was not normalized")
  }
  assert_eq(
    json_string(cancel_dropped_event, "kind", default=""),
    event_cancel_dropped(),
  )
  assert_eq(json_string(cancel_dropped_event, "status", default=""), "done")
  let cancel_packet = runtime_json_object_field_or_empty(
    cancel_dropped_event, "command_packet",
  )
  assert_eq(
    json_string(cancel_packet, "command_id", default=""),
    "cmd-cancel-1",
  )
  assert_eq(json_string(cancel_packet, "action", default=""), "cancel")
}

///|
test "mooncode runtime event ingest report accepts canonical and openseek events" {
  let report = runtime_event_ingest_report(
    {
      "events": [
        {
          "lane": "diff",
          "kind": "write",
          "path": "tools/demo/main.mbt",
          "detail": "changed",
        },
        {
          "event": event_tool_result(),
          "tool_name": "moon_check",
          "content": "moon check passed",
          "command_id": "cmd-tests",
          "action": "run_tests",
        },
        { "event": "unknown_runtime_event" },
      ],
    },
    session_id="agent-demo",
    ingested_at="2026-06-15T00:00:00Z",
  )
  assert_eq(json_string(report, "status", default=""), "accepted")
  assert_eq(runtime_json_int(report, "submitted_count", default=0), 3)
  assert_eq(runtime_json_int(report, "accepted_count", default=0), 2)
  assert_eq(runtime_json_int(report, "rejected_count", default=0), 1)
  let events = runtime_json_array_items(report, "events")
  assert_eq(events.length(), 2)
  assert_eq(json_string(events[0], "lane", default=""), "diff")
  assert_eq(json_string(events[0], "path", default=""), "tools/demo/main.mbt")
  assert_eq(json_string(events[1], "lane", default=""), "test")
  assert_eq(
    json_string(events[1], "created_at", default=""),
    "2026-06-15T00:00:00Z",
  )
  let progress = runtime_json_object_field_or_empty(report, "command_progress")
  assert_eq(
    json_string(progress, "kind", default=""),
    "mooncode-runtime-event-command-progress",
  )
}

///|
test "mooncode native runtime event report normalizes openseek events before merge" {
  let report = runtime_native_event_report(
    {
      "kind": "mooncode-runtime-events-state",
      "events": [
        {
          "event": event_tool_result(),
          "tool_name": "moon_check",
          "command_id": "cmd-native-tests",
          "content": "Total tests: 2, passed: 2",
          "is_error": false,
        },
        { "event": "unsupported-native-event" },
      ],
    },
    session_id="session-native",
    observed_at="2026-06-17T00:00:00Z",
  )
  assert_eq(
    json_string(report, "kind", default=""),
    "mooncode-native-runtime-event-report",
  )
  assert_eq(
    json_string(report, "native_payload_kind", default=""),
    "mooncode-runtime-events-state",
  )
  assert_eq(
    runtime_json_int(report, "native_payload_event_count", default=0),
    2,
  )
  assert_eq(runtime_json_int(report, "submitted_count", default=0), 2)
  assert_eq(runtime_json_int(report, "accepted_count", default=0), 1)
  assert_eq(runtime_json_int(report, "rejected_count", default=0), 1)
  let events = runtime_json_array_items(report, "events")
  assert_eq(events.length(), 1)
  assert_true(
    json_string(events[0], "id", default="").has_prefix(
      "mooncode-runtime-event-",
    ),
  )
  assert_eq(json_string(events[0], "lane", default=""), "test")
  assert_eq(json_string(events[0], "status", default=""), "done")
  let packet = runtime_json_object_field_or_empty(events[0], "command_packet")
  assert_eq(json_string(packet, "command_id", default=""), "cmd-native-tests")
}

///|
test "mooncode owns native runtime events projection extraction" {
  let report = runtime_native_event_report(
    {
      "kind": "mooncode-runtime-events-state",
      "events": [
        {
          "event": event_tool_result(),
          "tool_name": "moon_check",
          "command_id": "cmd-native-tests",
          "content": "Total tests: 1, passed: 1",
          "is_error": false,
        },
      ],
    },
    session_id="session-native",
    observed_at="2026-06-17T00:00:00Z",
  )
  let events = native_runtime_events_for_projection(report)
  assert_eq(events.length(), 1)
  assert_eq(json_string(events[0], "lane", default=""), "test")
  assert_eq(json_string(events[0], "status", default=""), "done")
}

///|
test "mooncode native runtime event report preserves moonclaw command scope" {
  let report = runtime_native_event_report(
    {
      "kind": "mooncode-runtime-events-state",
      "events": [
        {
          "id": "native-tool-result",
          "protocol": protocol_version(),
          "session_id": "session-native",
          "command_id": "cmd-native-tool",
          "lane": "tool",
          "kind": "runtime.tool_result",
          "title": "Native tool finished",
          "status": "done",
          "detail": "native result",
          "raw_event": {
            "command_packet": {
              "command_id": "cmd-native-tool",
              "action": "prompt",
            },
          },
        },
      ],
    },
    session_id="session-native",
    observed_at="2026-06-17T00:00:00Z",
  )
  assert_eq(runtime_json_int(report, "accepted_count", default=0), 1)
  let events = runtime_json_array_items(report, "events")
  assert_eq(events.length(), 1)
  let packet = runtime_json_object_field_or_empty(events[0], "command_packet")
  assert_eq(json_string(packet, "command_id", default=""), "cmd-native-tool")
  assert_eq(json_string(packet, "action", default=""), "prompt")
  let progress = runtime_json_object_field_or_empty(report, "command_progress")
  assert_eq(runtime_json_int(progress, "command_count", default=0), 1)
  assert_eq(runtime_json_int(progress, "completed_command_count", default=0), 1)
}

///|
test "mooncode derives runtime command rows from canonical event progress" {
  let packet_a : Json = { "command_id": "cmd-a", "action": "prompt" }
  let packet_b : Json = { "command_id": "cmd-b", "action": "run_tests" }
  let rows = runtime_event_command_rows(
    [
      event_record(
        id="evt-a-1",
        lane="runtime",
        kind="agent_update",
        title="Started",
        status="done",
        created_at="2026-06-17T00:00:00Z",
        detail="first",
        command_packet=packet_a,
      ),
      event_record(
        id="evt-a-2",
        lane="tool",
        kind="tool_result",
        title="Tool finished",
        status="done",
        created_at="2026-06-17T00:00:01Z",
        detail="done",
        command_packet=packet_a,
      ),
      event_record(
        id="evt-b-1",
        lane="test",
        kind=event_test_result(),
        title="Tests failed",
        status="failed",
        created_at="2026-06-17T00:00:02Z",
        detail="failed",
        command_packet=packet_b,
      ),
      event_record(
        id="unscoped",
        lane="runtime",
        kind="agent_update",
        title="Unscoped",
        status="done",
        created_at="2026-06-17T00:00:03Z",
        detail="ignored",
      ),
    ],
    source="moonclaw-native-runtime-events",
  )
  assert_eq(rows.length(), 2)
  assert_eq(json_string(rows[0], "command_id", default=""), "cmd-a")
  assert_eq(json_string(rows[0], "action", default=""), "prompt")
  assert_eq(json_string(rows[0], "status", default=""), "done")
  assert_eq(
    json_string(rows[0], "created_at", default=""),
    "2026-06-17T00:00:01Z",
  )
  assert_eq(json_string(rows[0], "message", default=""), "Tool finished")
  assert_eq(runtime_json_int(rows[0], "event_count", default=0), 2)
  assert_eq(json_string(rows[1], "command_id", default=""), "cmd-b")
  assert_eq(json_string(rows[1], "status", default=""), "failed")
  assert_eq(
    json_string(rows[1], "source", default=""),
    "moonclaw-native-runtime-events",
  )
}

///|
test "mooncode runtime event ingest accepts moonclaw run_tests proof events" {
  let events = runtime_ingest_events(
    {
      "events": [
        {
          "protocol": protocol_version(),
          "session_id": "session-tests",
          "command_id": "cmd-tests",
          "command_packet": { "command_id": "cmd-tests", "action": "run_tests" },
          "lane": "test",
          "kind": "test_result",
          "event": event_test_result(),
          "title": "MoonCode tests failed",
          "status": "failed",
          "test_status": "failed",
          "detail": "moon check failed with status 7",
          "content": "failure output",
          "output": "failure output",
          "tool": "moon_check",
          "target": "cmd/daemon",
          "exit_status": 7,
          "created_at": "2026-06-15T00:00:00Z",
          "source": "moonclaw-native-runtime-turn",
        },
      ],
    },
    ingested_at="2026-06-15T00:00:01Z",
  )
  assert_eq(events.length(), 1)
  assert_eq(json_string(events[0], "lane", default=""), "test")
  assert_eq(json_string(events[0], "kind", default=""), "test_result")
  assert_eq(json_string(events[0], "status", default=""), "failed")
  assert_eq(json_string(events[0], "command", default=""), "cmd/daemon")
  assert_eq(runtime_json_int(events[0], "exit_code", default=0), 7)
  let packet = runtime_json_object_field_or_empty(events[0], "command_packet")
  assert_eq(json_string(packet, "command_id", default=""), "cmd-tests")
  assert_eq(json_string(packet, "action", default=""), "run_tests")
}

///|
test "mooncode runtime event ingest accepts moonclaw tool events" {
  let report = runtime_event_ingest_report(
    {
      "id": "evt-moonclaw-tool",
      "created": 0,
      "desc": {
        "msg": "PostToolCall",
        "tool_call": {
          "id": "call-1",
          "function": {
            "name": "execute_command",
            "arguments": "{\"command\":\"moon test\"}",
          },
          "type": "function",
        },
        "name": "execute_command",
        "result": { "ok": true },
        "text": "Total tests: 1, passed: 1",
      },
    },
    session_id="s1",
    ingested_at="2026-06-15T00:00:00Z",
  )
  assert_eq(json_string(report, "status", default=""), "accepted")
  let events = runtime_json_array_items(report, "events")
  assert_eq(events.length(), 1)
  assert_eq(json_string(events[0], "lane", default=""), "test")
  assert_eq(json_string(events[0], "kind", default=""), "shell")
  assert_eq(json_string(events[0], "kind", default=""), "shell")
  assert_true(
    json_string(events[0], "detail", default="").contains("Total tests"),
  )
}

///|
test "mooncode runtime event ingest report owns moonclaw descriptor fallback" {
  let report = runtime_event_ingest_report_with_moonclaw_adapter(
    {
      "events": [
        {
          "created": "2026-06-16T00:00:00Z",
          "desc": { "msg": "UserMessage", "content": "Create a MoonBook tool" },
        },
      ],
    },
    session_id="agent-demo",
    ingested_at="2026-06-16T00:00:01Z",
  )
  assert_eq(
    json_string(report, "status", default=""),
    "accepted-legacy-moonclaw",
  )
  assert_eq(runtime_json_int(report, "accepted_count", default=0), 1)
  assert_eq(
    json_string(report, "legacy_adapter", default=""),
    "mooncode.moonclaw.desc",
  )
  let events = runtime_json_array_items(report, "events")
  assert_eq(events.length(), 1)
  assert_true(
    json_string(events[0], "id", default="").has_prefix("mooncode-event-"),
  )
  assert_eq(json_string(events[0], "lane", default=""), "transcript")
  assert_eq(json_string(events[0], "kind", default=""), "user")
  assert_eq(
    json_string(events[0], "detail", default=""),
    "Create a MoonBook tool",
  )
}

///|
test "mooncode normalizes native runtime loop responses" {
  guard normalize_runtime_loop_response_event(
      {
        "kind": "mooncode-runtime-loop",
        "protocol": protocol_version(),
        "session_id": "agent-demo",
        "book_root": "/tmp/demo-book",
        "consumer_id": "moonclaw-native-runtime-loop",
        "ran_turn_count": 0,
        "failed_turn_count": 0,
        "stopped_by": "idle",
        "message": "MoonClaw native runtime loop found no claimable MoonCode commands.",
      },
      fallback_id="loop-idle",
      fallback_created_at="2026-06-16T00:00:00Z",
    )
    is Some(idle_event) else {
    fail("idle runtime loop was not normalized")
  }
  assert_eq(json_string(idle_event, "id", default=""), "loop-idle")
  assert_eq(json_string(idle_event, "lane", default=""), "runtime")
  assert_eq(json_string(idle_event, "kind", default=""), "runtime_loop")
  assert_eq(json_string(idle_event, "status", default=""), "done")
  assert_eq(
    json_string(idle_event, "created_at", default=""),
    "2026-06-16T00:00:00Z",
  )
  assert_eq(json_string(idle_event, "path", default=""), "/tmp/demo-book")
  assert_eq(json_string(idle_event, "command", default=""), "runtime-loop")
  assert_true(
    json_string(idle_event, "detail", default="").contains("no claimable"),
  )
  guard normalize_runtime_loop_response_event(
      {
        "kind": "mooncode-runtime-loop",
        "stopped_by": "failed",
        "message": "failed",
      },
      fallback_id="loop-failed",
      fallback_created_at="2026-06-16T00:00:01Z",
    )
    is Some(failed_event) else {
    fail("failed runtime loop was not normalized")
  }
  assert_eq(json_string(failed_event, "status", default=""), "failed")
  guard normalize_runtime_loop_response_event(
      {
        "kind": "mooncode-runtime-loop",
        "stopped_by": "cancelled",
        "message": "cancelled",
      },
      fallback_id="loop-cancelled",
      fallback_created_at="2026-06-16T00:00:02Z",
    )
    is Some(cancelled_event) else {
    fail("cancelled runtime loop was not normalized")
  }
  assert_eq(json_string(cancelled_event, "status", default=""), "cancelled")
  guard normalize_runtime_loop_response_event(
      { "kind": "mooncode-runtime-turn" },
      fallback_id="turn",
      fallback_created_at="2026-06-16T00:00:03Z",
    )
    is None else {
    fail("runtime turn response normalized as a loop")
  }
}

///|
test "mooncode extracts native response events from loop payloads" {
  let event = event_record(
    id="native-event",
    lane="runtime",
    kind="runtime_update",
    title="Runtime update",
    status="running",
    created_at="1",
    detail="native",
  )
  let execution_event = event_record(
    id="execution-event",
    lane="tool",
    kind="tool_result",
    title="Tool result",
    status="done",
    created_at="2",
    detail="execution",
  )
  let package_event = event_record(
    id="package-event",
    lane="artifact",
    kind="runtime.package_verified",
    title="Package verified",
    status="verified",
    created_at="3",
    detail="package",
  )
  let receipt_event = event_record(
    id="receipt-event",
    lane="runtime",
    kind="runtime_acknowledged",
    title="Runtime acknowledged",
    status="done",
    created_at="4",
    detail="receipt",
  )
  let nested_event = event_record(
    id="nested-event",
    lane="review",
    kind="finish",
    title="Finished",
    status="done",
    created_at="5",
    detail="nested",
  )
  let events = native_response_event_items(
    {
      "kind": "mooncode-runtime-loop",
      "protocol": protocol_version(),
      "session_id": "agent-demo",
      "book_root": "/tmp/demo-book",
      "stopped_by": "idle",
      "message": "MoonClaw native runtime loop reached idle.",
      "events": [event],
      "execution": { "events": [execution_event] },
      "package_events": [package_event],
      "turn_receipt": { "events": [receipt_event] },
      "turns": [{ "events": [nested_event] }],
    },
    loop_fallback_id="loop-event",
    loop_fallback_created_at="2026-06-16T00:00:00Z",
  )
  assert_eq(events.length(), 6)
  assert_eq(json_string(events[0], "id", default=""), "native-event")
  assert_eq(json_string(events[1], "id", default=""), "execution-event")
  assert_eq(json_string(events[2], "id", default=""), "loop-event")
  assert_eq(json_string(events[2], "kind", default=""), "runtime_loop")
  assert_eq(json_string(events[3], "id", default=""), "package-event")
  assert_eq(json_string(events[4], "id", default=""), "receipt-event")
  assert_eq(json_string(events[5], "id", default=""), "nested-event")
}

///|
test "mooncode appends native response events with durable id dedupe" {
  let existing_event = event_record(
    id="native-event",
    lane="runtime",
    kind="tool_call",
    title="Tool call",
    status="running",
    created_at="1",
    detail="existing",
  )
  let new_event = event_record(
    id="execution-event",
    lane="runtime",
    kind="tool_result",
    title="Tool result",
    status="done",
    created_at="2",
    detail="execution",
  )
  let package_event = event_record(
    id="package-event",
    lane="artifact",
    kind="runtime.package_verified",
    title="Package verified",
    status="verified",
    created_at="3",
    detail="package",
  )
  let service_started_event = event_record(
    id="service-started",
    lane="runtime",
    kind="runtime.service_started",
    title="Runtime service started",
    status="running",
    created_at="2026-06-16T00:00:04Z",
    detail="service started",
  )
  let service_finished_event = event_record(
    id="service-finished",
    lane="runtime",
    kind="runtime.service_finished",
    title="Runtime service finished",
    status="done",
    created_at="2026-06-16T00:00:05Z",
    detail="service finished",
  )
  let session = append_native_response_events(
    { "mooncode_command_events": [existing_event] },
    {
      "kind": "mooncode-runtime-loop",
      "protocol": protocol_version(),
      "session_id": "agent-demo",
      "stopped_by": "idle",
      "events": [existing_event],
      "execution": { "events": [new_event] },
      "started_event": service_started_event,
      "finished_event": service_finished_event,
      "package_events": [package_event],
    },
    loop_fallback_id="loop-event",
    loop_fallback_created_at="2026-06-16T00:00:00Z",
  )
  let events = runtime_json_array_items(session, "mooncode_command_events")
  assert_eq(events.length(), 6)
  assert_eq(json_string(events[0], "id", default=""), "native-event")
  assert_eq(json_string(events[1], "id", default=""), "execution-event")
  assert_eq(json_string(events[2], "id", default=""), "service-started")
  assert_eq(json_string(events[3], "id", default=""), "service-finished")
  assert_eq(json_string(events[4], "id", default=""), "loop-event")
  assert_eq(json_string(events[5], "id", default=""), "package-event")
}

///|
test "mooncode projected native response events own loop fallback id" {
  let response : Json = {
    "kind": "mooncode-runtime-loop",
    "protocol": protocol_version(),
    "session_id": "agent-demo",
    "consumer_id": "moondesk-native-runtime-loop",
    "ran_turn_count": 2,
    "failed_turn_count": 1,
    "stopped_by": "failed",
    "message": "MoonClaw native runtime loop stopped after a failed turn.",
  }
  let session_a = append_projected_native_response_events(
    {},
    response,
    loop_fallback_created_at="2026-06-17T00:00:00Z",
  )
  let session_b = append_projected_native_response_events(
    {},
    response,
    loop_fallback_created_at="2026-06-17T00:00:00Z",
  )
  let events_a = runtime_json_array_items(session_a, "mooncode_command_events")
  let events_b = runtime_json_array_items(session_b, "mooncode_command_events")
  assert_eq(events_a.length(), 1)
  assert_eq(events_b.length(), 1)
  let id_a = json_string(events_a[0], "id", default="")
  let id_b = json_string(events_b[0], "id", default="")
  assert_eq(id_a, id_b)
  assert_true(id_a.has_prefix("mooncode-runtime-loop-"))
  assert_eq(json_string(events_a[0], "kind", default=""), "runtime_loop")
  assert_eq(json_string(events_a[0], "status", default=""), "failed")
  assert_eq(
    json_string(events_a[0], "created_at", default=""),
    "2026-06-17T00:00:00Z",
  )
}

///|
test "mooncode normalizes runtime patch execution proof events" {
  guard normalize_runtime_event(
      {
        "event": "patch_applied",
        "path": "tools/demo/main.mbt#hunk-1",
        "detail": "applied cleanly",
      },
      fallback_id="patch-proof-1",
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(applied) else {
    fail("patch_applied was not normalized")
  }
  assert_eq(json_string(applied, "lane", default=""), "review")
  assert_eq(json_string(applied, "kind", default=""), "runtime.patch_applied")
  assert_eq(json_string(applied, "command", default=""), "apply_patch")
  assert_eq(
    json_string(applied, "path", default=""),
    "tools/demo/main.mbt#hunk-1",
  )
  guard normalize_runtime_event(
      { "event": "patch_reverted", "path": "tools/demo/main.mbt" },
      fallback_id="patch-proof-2",
      fallback_created_at="2026-06-15T00:00:01Z",
    )
    is Some(reverted) else {
    fail("patch_reverted was not normalized")
  }
  assert_eq(json_string(reverted, "kind", default=""), "runtime.patch_reverted")
  assert_eq(json_string(reverted, "command", default=""), "revert_patch")
}

///|
test "mooncode normalizes runtime package proof events" {
  guard normalize_runtime_event(
      {
        "event": event_package_verified(),
        "command_id": "cmd-package-1",
        "path": "portable/app-tool/mooncode/s1/index.json",
        "detail": "bundle verified",
      },
      fallback_id="package-proof-1",
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(proof) else {
    fail("package_verified was not normalized")
  }
  assert_eq(json_string(proof, "lane", default=""), "artifact")
  assert_eq(json_string(proof, "kind", default=""), "runtime.package_verified")
  assert_eq(json_string(proof, "command", default=""), "package")
  let packet = runtime_json_object_field_or_empty(proof, "command_packet")
  assert_eq(json_string(packet, "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(packet, "command_id", default=""), "cmd-package-1")
  assert_eq(json_string(packet, "action", default=""), "package")
  assert_eq(
    json_string(proof, "path", default=""),
    "portable/app-tool/mooncode/s1/index.json",
  )
}

///|
test "mooncode normalizes runtime commit proof events" {
  guard normalize_runtime_event(
      {
        "event": "commit_created",
        "command_id": "cmd-commit-1",
        "sha": "abc1234",
        "detail": "Committed reviewed MoonBook changes",
      },
      fallback_id="commit-proof-1",
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(proof) else {
    fail("commit_created was not normalized")
  }
  assert_eq(json_string(proof, "lane", default=""), "review")
  assert_eq(json_string(proof, "kind", default=""), "runtime.commit_created")
  assert_eq(json_string(proof, "command", default=""), "commit")
  let packet = runtime_json_object_field_or_empty(proof, "command_packet")
  assert_eq(json_string(packet, "command_id", default=""), "cmd-commit-1")
  assert_eq(json_string(packet, "action", default=""), "commit")
  assert_true(json_string(proof, "detail", default="").contains("Committed"))
}

///|
test "mooncode runtime event command progress groups scoped events" {
  let packet : Json = { "command_id": "cmd-tests", "action": "run_tests" }
  let progress = runtime_event_command_progress([
    event_record(
      id="unscoped",
      lane="runtime",
      kind="runtime_update",
      title="Unscoped",
      status="running",
      created_at="2026-06-15T00:00:00Z",
      detail="visible but not command proof",
    ),
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
    |> runtime_with_field("tool_call_id", "call-check".to_json()),
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
    |> runtime_with_field("tool_call_id", "call-check".to_json()),
    event_record(
      id="finish",
      lane="review",
      kind="finish",
      title="Agent finished",
      status="done",
      created_at="2026-06-15T00:00:03Z",
      detail="done",
      command_packet=packet,
    ),
  ])
  assert_eq(
    json_string(progress, "kind", default=""),
    "mooncode-runtime-event-command-progress",
  )
  assert_eq(runtime_json_int(progress, "command_count", default=0), 1)
  assert_eq(runtime_json_int(progress, "scoped_event_count", default=0), 3)
  assert_eq(runtime_json_int(progress, "running_command_count", default=0), 1)
  let commands = runtime_json_array_items(progress, "commands")
  assert_eq(commands.length(), 1)
  assert_eq(json_string(commands[0], "command_id", default=""), "cmd-tests")
  assert_eq(json_string(commands[0], "action", default=""), "run_tests")
  assert_eq(json_string(commands[0], "status", default=""), "running")
  assert_eq(runtime_json_int(commands[0], "event_count", default=0), 3)
  assert_eq(runtime_json_int(commands[0], "tool_call_count", default=0), 1)
  assert_eq(runtime_json_int(commands[0], "tool_result_count", default=0), 1)
  assert_eq(json_string(commands[0], "latest_event_id", default=""), "finish")
  assert_true(
    runtime_json_string_array_items(commands[0], "lanes").contains("test"),
  )
  assert_true(
    runtime_json_string_array_items(commands[0], "lanes").contains("review"),
  )
}

///|
test "mooncode runtime event sink response owns event surface" {
  let packet : Json = { "command_id": "cmd-1", "action": "prompt" }
  let event = event_record(
    id="event-1",
    lane="runtime",
    kind="runtime_update",
    title="Runtime update",
    status="done",
    created_at="2026-06-15T00:00:00Z",
    detail="ready",
    command_packet=packet,
  )
  let response = runtime_event_sink_response(
    "session-demo",
    [event],
    event_log_path="/tmp/session/events.jsonl",
    workspace_id="book-demo",
    workspace_name="Demo",
    task_id="task-demo",
  )
  assert_eq(
    json_string(response, "kind", default=""),
    "mooncode-runtime-event-sink",
  )
  assert_eq(runtime_json_int(response, "event_count", default=0), 1)
  assert_eq(
    json_string(response, "event_log_path", default=""),
    "/tmp/session/events.jsonl",
  )
  assert_eq(
    json_string(
      runtime_json_object_field_or_empty(response, "post_contract"),
      "endpoint",
      default="",
    ),
    "/api/mooncode/sessions/session-demo/runtime-events",
  )
  assert_true(
    runtime_json_object_field(response, "runtime_protocol")
    is Some(Json::Object(_)),
  )
  assert_eq(
    json_string(
      runtime_json_object_field_or_empty(response, "owner"),
      "runtime",
      default="",
    ),
    "moonclaw",
  )
  assert_eq(
    runtime_json_int(
      runtime_json_object_field_or_empty(response, "command_progress"),
      "command_count",
      default=0,
    ),
    1,
  )
  assert_eq(
    runtime_json_int(
      runtime_json_object_field_or_empty(response, "command_progress"),
      "scoped_event_count",
      default=0,
    ),
    1,
  )
  assert_eq(
    json_string(
      runtime_json_object_field_or_empty(response, "runtime_service"),
      "status",
      default="",
    ),
    "idle",
  )
  let aggregate = runtime_event_sink_result_response(
    "session-demo",
    [event],
    {
      "id": "session-demo",
      "workspace_id": "book-demo",
      "workspace_name": "Demo",
      "moonclaw_task_id": "task-demo",
    },
    event_log_path="/tmp/session/events.jsonl",
  )
  assert_eq(
    json_string(aggregate, "kind", default=""),
    "mooncode-runtime-event-sink",
  )
  assert_eq(json_string(aggregate, "workspace_id", default=""), "book-demo")
  assert_eq(json_string(aggregate, "workspace_name", default=""), "Demo")
  assert_eq(json_string(aggregate, "task_id", default=""), "task-demo")
  let native = runtime_event_sink_result_response_with_native(
    "session-demo",
    [event],
    {
      "id": "session-demo",
      "workspace_id": "book-demo",
      "workspace_name": "Demo",
      "moonclaw_task_id": "task-demo",
    },
    event_log_path="/tmp/session/events.jsonl",
    local_event_count=1,
    native_state={
      "native_runtime_ready": true,
      "endpoint": "/v1/mooncode/sessions/session-demo/runtime-events?book_root=%2Ftmp%2Fbook",
      "error": "",
    },
    native_report={
      "submitted_count": 3,
      "accepted_count": 2,
      "rejected_count": 1,
      "events": [{ "id": "native-1" }, { "id": "native-2" }],
    },
  )
  assert_eq(runtime_json_int(native, "event_count", default=0), 1)
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
    "/v1/mooncode/sessions/session-demo/runtime-events?book_root=%2Ftmp%2Fbook",
  )
  assert_true(
    runtime_json_object_field(native, "native_runtime_events_report")
    is Some(Json::Object(_)),
  )
}

///|
test "mooncode runtime event sink separates unscoped live events" {
  let scoped_packet : Json = { "command_id": "cmd-1", "action": "prompt" }
  let scoped = event_record(
    id="event-scoped",
    lane="runtime",
    kind="runtime_update",
    title="Runtime update",
    status="done",
    created_at="2026-06-15T00:00:00Z",
    detail="ready",
    command_packet=scoped_packet,
  )
  let unscoped_tool = event_record(
    id="event-unscoped-tool",
    lane="tool",
    kind="read",
    title="Tool call",
    status="running",
    created_at="2026-06-15T00:00:01Z",
    detail="reading context before command binding",
  )
  let unscoped_transcript = event_record(
    id="event-unscoped-transcript",
    lane="transcript",
    kind="assistant_delta",
    title="Assistant streaming",
    status="running",
    created_at="2026-06-15T00:00:02Z",
    detail="thinking",
  )
  let response = runtime_event_sink_response(
    "session-demo",
    [scoped, unscoped_tool, unscoped_transcript],
    event_log_path="/tmp/session/events.jsonl",
    workspace_id="book-demo",
    workspace_name="Demo",
    task_id="task-demo",
  )
  let command_progress = runtime_json_object_field_or_empty(
    response, "command_progress",
  )
  assert_eq(runtime_json_int(command_progress, "command_count", default=0), 1)
  assert_eq(
    runtime_json_int(command_progress, "scoped_event_count", default=0),
    1,
  )
  let unscoped_progress = runtime_json_object_field_or_empty(
    response, "unscoped_progress",
  )
  assert_eq(
    json_string(unscoped_progress, "kind", default=""),
    "mooncode-runtime-unscoped-progress",
  )
  assert_eq(runtime_json_int(unscoped_progress, "event_count", default=0), 2)
  assert_eq(
    runtime_json_int(unscoped_progress, "running_event_count", default=0),
    2,
  )
  assert_eq(
    runtime_json_int(unscoped_progress, "tool_event_count", default=0),
    1,
  )
  assert_eq(
    runtime_json_int(unscoped_progress, "transcript_event_count", default=0),
    1,
  )
  let recent = runtime_json_array_items(unscoped_progress, "recent_events")
  assert_eq(recent.length(), 2)
  assert_eq(
    json_string(recent[0], "id", default=""),
    "event-unscoped-transcript",
  )
  assert_true(
    json_string(unscoped_progress, "rule", default="").contains(
      "do not satisfy command proof gates",
    ),
  )
}

///|
test "mooncode runtime service state tracks daemon service lifecycle" {
  let idle = runtime_service_state("session-demo", [])
  assert_eq(json_string(idle, "status", default=""), "idle")
  assert_false(json_bool(idle, "active", default=true))
  let started : Json = {
    "id": "service-started",
    "kind": "runtime.service_started",
    "session_id": "session-demo",
    "service_id": "svc-demo",
    "status": "running",
    "created_at": "2026-06-18T00:00:00Z",
    "detail": "service running",
  }
  let running = runtime_service_state("session-demo", [started])
  assert_eq(json_string(running, "status", default=""), "running")
  assert_true(json_bool(running, "active", default=false))
  assert_eq(json_string(running, "service_id", default=""), "svc-demo")
  assert_eq(
    json_string(running, "started_at", default=""),
    "2026-06-18T00:00:00Z",
  )
  assert_eq(runtime_json_int(running, "started_count", default=0), 1)
  assert_true(
    json_string(running, "control_hint", default="").contains("cancel"),
  )
  let finished : Json = {
    "id": "service-finished",
    "kind": "runtime.service_finished",
    "session_id": "session-demo",
    "service_id": "svc-demo",
    "status": "cancelled",
    "created_at": "2026-06-18T00:00:01Z",
    "detail": "service stopped after cancel",
    "stopped_by": "cancelled",
    "ran_turn_count": 2,
    "failed_turn_count": 0,
  }
  let cancelled = runtime_service_state("session-demo", [started, finished])
  assert_eq(json_string(cancelled, "status", default=""), "cancelled")
  assert_false(json_bool(cancelled, "active", default=true))
  assert_eq(
    json_string(cancelled, "finished_at", default=""),
    "2026-06-18T00:00:01Z",
  )
  assert_eq(json_string(cancelled, "stopped_by", default=""), "cancelled")
  assert_eq(runtime_json_int(cancelled, "ran_turn_count", default=0), 2)
  assert_eq(runtime_json_int(cancelled, "finished_count", default=0), 1)
  let failed : Json = {
    "id": "service-failed",
    "kind": "runtime.service_failed",
    "session_id": "session-demo",
    "service_id": "svc-demo",
    "status": "failed",
    "created_at": "2026-06-18T00:00:02Z",
    "detail": "service failed",
    "failed_turn_count": 1,
  }
  let failed_state = runtime_service_state("session-demo", [started, failed])
  assert_eq(json_string(failed_state, "status", default=""), "failed")
  assert_eq(runtime_json_int(failed_state, "failed_count", default=0), 1)
  assert_eq(runtime_json_int(failed_state, "failed_turn_count", default=0), 1)
}

///|
test "mooncode native runtime events state owns unavailable shape" {
  let state = native_runtime_events_unavailable_state(
    "/v1/mooncode/sessions/session-demo/runtime-events?book_root=%2Ftmp%2Fbook",
    "MoonClaw daemon is not running",
  )
  assert_false(json_bool(state, "native_runtime_ready", default=true))
  assert_eq(
    json_string(state, "endpoint", default=""),
    "/v1/mooncode/sessions/session-demo/runtime-events?book_root=%2Ftmp%2Fbook",
  )
  assert_eq(
    json_string(state, "error", default=""),
    "MoonClaw daemon is not running",
  )
  assert_eq(json_array_items(state, "events").length(), 0)
}

///|
test "mooncode native runtime events state annotates available payload" {
  let state = native_runtime_events_available_state(
    {
      "kind": "mooncode-native-runtime-events",
      "events": [{ "id": "native-1" }],
    },
    "/v1/mooncode/sessions/session-demo/runtime-events?book_root=%2Ftmp%2Fbook",
  )
  assert_true(json_bool(state, "native_runtime_ready", default=false))
  assert_eq(
    json_string(state, "endpoint", default=""),
    "/v1/mooncode/sessions/session-demo/runtime-events?book_root=%2Ftmp%2Fbook",
  )
  assert_eq(json_string(state, "error", default="fallback"), "")
  assert_eq(json_array_items(state, "events").length(), 1)
  assert_eq(
    json_string(state, "kind", default=""),
    "mooncode-native-runtime-events",
  )
}

///|
test "mooncode runtime event ingest result response owns manifest surface" {
  let packet : Json = { "command_id": "cmd-1", "action": "run_tests" }
  let event = event_record(
    id="event-1",
    lane="test",
    kind=event_test_result(),
    title="Tests passed",
    status="done",
    created_at="2026-06-15T00:00:00Z",
    detail="Total tests: 1, passed: 1",
    command="moon test",
    command_packet=packet,
  )
  let ingest_report : Json = {
    "kind": "mooncode-runtime-event-ingest-report",
    "accepted_count": 1,
  }
  let final_session : Json = {
    "mooncode_last_action_plan_manifest": { "kind": "mooncode-action-plan" },
    "mooncode_last_change_set_manifest": { "kind": "mooncode-change-set" },
    "mooncode_last_patch_set_manifest": { "kind": "mooncode-patch-set" },
    "mooncode_last_tool_approvals_manifest": {
      "kind": "mooncode-tool-approvals",
    },
    "mooncode_last_test_runs_manifest": { "kind": "mooncode-test-runs" },
    "mooncode_last_runtime_evidence_manifest": {
      "kind": "mooncode-runtime-evidence",
    },
    "mooncode_last_eval_report_manifest": { "kind": "mooncode-eval-report" },
    "mooncode_last_runtime_handoff_manifest": {
      "kind": "mooncode-runtime-handoff",
    },
  }
  let response = runtime_event_ingest_result_response(
    "session-demo",
    [event],
    [event],
    ingest_report,
    final_session,
    { "id": "session-demo", "kind": "mooncode-session" },
    event_log_path="/tmp/session/events.jsonl",
  )
  assert_eq(
    json_string(response, "kind", default=""),
    "mooncode-runtime-event-ingest-result",
  )
  assert_eq(runtime_json_int(response, "accepted_event_count", default=0), 1)
  assert_eq(
    json_string(response, "event_log_path", default=""),
    "/tmp/session/events.jsonl",
  )
  assert_eq(
    json_string(
      runtime_json_object_field_or_empty(response, "action_plan"),
      "kind",
      default="",
    ),
    "mooncode-action-plan",
  )
  assert_eq(
    runtime_json_int(
      runtime_json_object_field_or_empty(response, "command_progress"),
      "command_count",
      default=0,
    ),
    1,
  )
  assert_eq(
    json_string(
      runtime_json_object_field_or_empty(response, "session"),
      "id",
      default="",
    ),
    "session-demo",
  )
}
