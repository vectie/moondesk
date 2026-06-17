///|
test "mooncode stream jsonl includes meta event and done records" {
  let event = event_record(
    id="e1",
    lane="test",
    kind="command.run_tests",
    title="Run tests: queued",
    status="queued",
    created_at="1",
    detail="Run tests",
  )
  let session : Json = {
    "id": "s1",
    "workspace_id": "book",
    "moonclaw_task_id": "task",
    "mooncode_events": [event],
  }
  let text = stream_jsonl_text(session, [event])
  let lines = text.trim().split("\n").to_array()
  assert_eq(lines.length(), 3)
  let meta = @json.parse(lines[0].to_owned()) catch { _ => Json::object({}) }
  let item = @json.parse(lines[1].to_owned()) catch { _ => Json::object({}) }
  let done = @json.parse(lines[2].to_owned()) catch { _ => Json::object({}) }
  assert_eq(stream_json_string(meta, "type", default=""), "meta")
  assert_eq(stream_json_int(meta, "event_count", default=0), 1)
  assert_eq(stream_json_int(meta, "since", default=-1), 0)
  assert_eq(stream_json_int(meta, "emitted_count", default=0), 1)
  assert_eq(stream_json_int(meta, "next_since", default=0), 1)
  assert_eq(stream_json_string(item, "type", default=""), "event")
  assert_eq(stream_json_int(item, "sequence", default=0), 1)
  assert_eq(stream_json_string(done, "type", default=""), "done")
  assert_eq(stream_json_int(done, "next_since", default=0), 1)
  assert_eq(
    stream_json_string(done, "stream_source", default=""),
    stream_source(),
  )
}

///|
test "mooncode stream jsonl supports incremental since sequence" {
  let first = event_record(
    id="e1",
    lane="tool",
    kind="tool.read",
    title="Read",
    status="done",
    created_at="1",
    detail="first",
  )
  let second = event_record(
    id="e2",
    lane="diff",
    kind="tool.write",
    title="Write",
    status="done",
    created_at="2",
    detail="second",
  )
  let session : Json = { "id": "s1", "mooncode_events": [first, second] }
  let text = stream_jsonl_text(session, [first, second], since=1)
  let lines = text.trim().split("\n").to_array()
  assert_eq(lines.length(), 3)
  let meta = @json.parse(lines[0].to_owned()) catch { _ => Json::object({}) }
  let item = @json.parse(lines[1].to_owned()) catch { _ => Json::object({}) }
  let done = @json.parse(lines[2].to_owned()) catch { _ => Json::object({}) }
  assert_eq(
    stream_json_string(meta, "stream", default=""),
    "append-log-incremental",
  )
  assert_eq(stream_json_int(meta, "since", default=0), 1)
  assert_eq(stream_json_int(meta, "emitted_count", default=0), 1)
  assert_eq(stream_json_int(meta, "next_since", default=0), 2)
  assert_eq(stream_json_int(item, "sequence", default=0), 2)
  let event_payload = match item {
    Json::Object(object) => object.get("event").unwrap_or(Json::object({}))
    _ => Json::object({})
  }
  assert_eq(stream_json_string(event_payload, "id", default=""), "e2")
  assert_eq(stream_json_int(done, "sequence", default=0), 2)
}

///|
test "mooncode stream tail and sse preserve event names" {
  let event = event_record(
    id="e1",
    lane="artifact",
    kind="command.package",
    title="Package result: queued",
    status="queued",
    created_at="1",
    detail="Package",
  )
  let session : Json = { "id": "s1", "mooncode_events": [event] }
  let tail = stream_tail_event_records(session, [event], 0)
  assert_eq(tail.length(), 1)
  assert_eq(stream_json_int(tail[0], "sequence", default=0), 1)
  let text = stream_sse_text(session, [event])
  assert_true(text.contains("event: mooncode.meta\n"))
  assert_true(text.contains("event: mooncode.event\n"))
  assert_true(text.contains("event: mooncode.done\n"))
}

///|
test "mooncode stream checkpoint clamps and records cursor state" {
  assert_eq(stream_checkpoint_sequence({ "last_seen_sequence": -5 }, 2, 3), 0)
  assert_eq(stream_checkpoint_sequence({ "next_since": 99 }, 1, 3), 3)
  assert_eq(stream_checkpoint_sequence({}, 2, 3), 2)
  assert_eq(
    stream_checkpoint_consumer_id({ "consumer_id": "payload-ui" }, "query-ui"),
    "payload-ui",
  )
  assert_eq(stream_checkpoint_consumer_id({}, "query ui"), "query ui")
  assert_eq(stream_checkpoint_consumer_id({}, ""), "moondesk-ui")
  assert_eq(
    stream_checkpoint_consumer_id({ "consumer_id": "../ui one" }, ""),
    "moondesk-ui",
  )
  let session : Json = {
    "id": "agent-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "moonclaw_task_id": "task-demo",
  }
  let checkpoint = stream_checkpoint_record(
    session, "moondesk-ui", 99, 2, "2026-06-15T00:00:00Z", "/tmp/checkpoint.json",
    "/stream?since=2", "/stream?since=2", "/stream-state?since=2", "/runtime-events",
  )
  assert_eq(
    stream_json_string(checkpoint, "kind", default=""),
    "mooncode-stream-checkpoint",
  )
  assert_eq(stream_json_int(checkpoint, "last_seen_sequence", default=0), 2)
  assert_eq(
    stream_json_string(checkpoint, "checkpoint_path", default=""),
    "/tmp/checkpoint.json",
  )
}

///|
test "mooncode stream state record includes resumable tail contract" {
  let event = event_record(
    id="e1",
    lane="test",
    kind=event_test_result(),
    title="Tests",
    status="passed",
    created_at="1",
    detail="passed",
  )
  let session : Json = {
    "id": "agent-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "moonclaw_task_id": "task-demo",
  }
  let state = stream_state_record(
    session,
    "moondesk-ui",
    0,
    1,
    1,
    "/tmp/events.jsonl",
    false,
    "/tmp/checkpoint.json",
    Json::object({}),
    stream_tail_event_records(session, [event], 0),
    "/stream?since=0",
    "/stream?format=sse&since=0",
    "/stream-state",
    "/runtime-events",
    "/stream?format=sse&live=true",
    "/v1/mooncode/sessions/<id>/stream",
  )
  assert_eq(
    stream_json_string(state, "kind", default=""),
    "mooncode-stream-state",
  )
  assert_eq(stream_json_int(state, "latest_sequence", default=0), 1)
  assert_eq(stream_json_array_items(state, "tail_events").length(), 1)
  let live = match state {
    Json::Object(object) => object.get("live_tail_boundary").unwrap_or({})
    _ => {}
  }
  assert_eq(
    stream_json_string(live, "native_blocking_tail", default=""),
    "/v1/mooncode/sessions/<id>/stream",
  )
}

///|
test "mooncode moondesk stream endpoints are protocol owned" {
  assert_eq(
    moondesk_stream_endpoint("agent demo", "jsonl", 2),
    "/api/mooncode/sessions/agent%20demo/stream?format=jsonl&since=2",
  )
  assert_eq(
    moondesk_stream_endpoint("agent/unsafe", "sse", 0),
    "/api/mooncode/sessions/agent%2Funsafe/stream?format=sse&since=0",
  )
  assert_eq(
    moondesk_live_stream_endpoint("agent demo", "sse", 7, timeout_ms=12000),
    "/api/mooncode/sessions/agent%20demo/stream?format=sse&since=7&live=true&timeout_ms=12000",
  )
  assert_eq(
    moondesk_stream_state_endpoint("agent demo", "ui one", 3),
    "/api/mooncode/sessions/agent%20demo/stream-state?consumer=ui%20one&since=3",
  )
  assert_eq(
    moondesk_stream_state_base_endpoint("agent demo"),
    "/api/mooncode/sessions/agent%20demo/stream-state",
  )
  assert_eq(
    moondesk_runtime_event_ingest_endpoint("agent demo"),
    "/api/mooncode/sessions/agent%20demo/runtime-events",
  )
}

///|
test "mooncode moondesk stream checkpoint wrapper fills endpoints" {
  let session : Json = {
    "id": "agent demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "moonclaw_task_id": "task-demo",
  }
  let checkpoint = moondesk_stream_checkpoint_record(
    session, "ui one", 99, 5, "2026-06-16T16:00:00Z", "/tmp/checkpoint.json",
  )
  assert_eq(stream_json_int(checkpoint, "last_seen_sequence", default=0), 5)
  assert_eq(
    stream_json_string(checkpoint, "stream_endpoint", default=""),
    "/api/mooncode/sessions/agent%20demo/stream?format=jsonl&since=5",
  )
  assert_eq(
    stream_json_string(checkpoint, "stream_state_endpoint", default=""),
    "/api/mooncode/sessions/agent%20demo/stream-state?consumer=ui%20one&since=5",
  )
  assert_eq(
    stream_json_string(checkpoint, "runtime_event_ingest_endpoint", default=""),
    "/api/mooncode/sessions/agent%20demo/runtime-events",
  )
}

///|
test "mooncode moondesk stream state wrapper fills endpoints" {
  let event = event_record(
    id="e1",
    lane="test",
    kind=event_test_result(),
    title="Tests",
    status="passed",
    created_at="1",
    detail="passed",
  )
  let session : Json = {
    "id": "agent demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "moonclaw_task_id": "task-demo",
  }
  let state = moondesk_stream_state_record(
    session,
    "ui one",
    4,
    5,
    1,
    "/tmp/events.jsonl",
    true,
    "/tmp/checkpoint.json",
    { "kind": "mooncode-stream-checkpoint" },
    stream_tail_event_records(session, [event], 0),
    "/v1/native-tail",
  )
  assert_eq(
    stream_json_string(state, "stream_endpoint", default=""),
    "/api/mooncode/sessions/agent%20demo/stream?format=jsonl&since=4",
  )
  assert_eq(
    stream_json_string(state, "sse_stream_endpoint", default=""),
    "/api/mooncode/sessions/agent%20demo/stream?format=sse&since=4",
  )
  assert_eq(
    stream_json_string(state, "checkpoint_endpoint", default=""),
    "/api/mooncode/sessions/agent%20demo/stream-state",
  )
  let live = match state {
    Json::Object(object) => object.get("live_tail_boundary").unwrap_or({})
    _ => {}
  }
  assert_eq(
    stream_json_string(live, "moondesk_live_endpoint", default=""),
    "/api/mooncode/sessions/agent%20demo/stream?format=sse&since=4&live=true&timeout_ms=8000",
  )
  assert_eq(
    stream_json_string(live, "native_blocking_tail", default=""),
    "/v1/native-tail",
  )
}

///|
test "mooncode moondesk stream state projection computes cursor policy" {
  let first = event_record(
    id="e1",
    lane="runtime",
    kind="assistant_delta",
    title="Assistant delta",
    status="running",
    created_at="1",
    detail="first",
  )
  let second = event_record(
    id="e2",
    lane="test",
    kind=event_test_result(),
    title="Tests",
    status="passed",
    created_at="2",
    detail="second",
  )
  let session : Json = {
    "id": "agent demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "moonclaw_task_id": "task-demo",
  }
  let state = moondesk_stream_state_projection_record(
    session,
    [first, second],
    1,
    "ui one",
    "/tmp/events.jsonl",
    "/tmp/checkpoint.json",
    { "kind": "mooncode-stream-checkpoint", "last_seen_sequence": 1 },
    "/v1/native-tail",
  )
  assert_eq(stream_json_int(state, "latest_sequence", default=0), 2)
  assert_eq(stream_json_int(state, "emitted_count", default=0), 1)
  assert_eq(stream_json_int(state, "next_since", default=0), 2)
  guard state is Json::Object(fields) &&
    fields.get("checkpoint_ready") is Some(Json::True) else {
    fail("expected checkpoint_ready=true")
  }
  let tail = stream_json_array_items(state, "tail_events")
  assert_eq(tail.length(), 1)
  assert_eq(stream_json_int(tail[0], "sequence", default=0), 2)
  let payload = match tail[0] {
    Json::Object(object) => object.get("event").unwrap_or({})
    _ => {}
  }
  assert_eq(stream_json_string(payload, "id", default=""), "e2")
  assert_eq(
    stream_json_string(state, "stream_endpoint", default=""),
    "/api/mooncode/sessions/agent%20demo/stream?format=jsonl&since=1",
  )
}

///|
test "mooncode stream live option policy is protocol-owned" {
  assert_eq(stream_since_value("-1"), 0)
  assert_eq(stream_since_value("7"), 7)
  assert_eq(stream_since_value("not-a-number"), 0)
  assert_true(stream_live_enabled_value("true"))
  assert_true(stream_live_enabled_value("1"))
  assert_true(stream_live_enabled_value("tail"))
  assert_true(stream_live_enabled_value("wait"))
  assert_false(stream_live_enabled_value("false"))
  assert_false(stream_live_enabled_value(""))
  assert_eq(stream_live_timeout_ms_value("20000"), 15000)
  assert_eq(stream_live_timeout_ms_value("-5"), 0)
  assert_eq(stream_live_timeout_ms_value(""), 8000)
  assert_eq(stream_live_poll_ms_value("10"), 50)
  assert_eq(stream_live_poll_ms_value("5000"), 1000)
  assert_eq(stream_live_poll_ms_value(""), 250)
  assert_eq(stream_live_attempt_count(801, 250), 4)
  assert_eq(stream_live_attempt_count(0, 250), 0)
  assert_eq(stream_content_type("sse"), "text/event-stream; charset=utf-8")
  assert_eq(stream_content_type("jsonl"), "application/x-ndjson; charset=utf-8")
}
