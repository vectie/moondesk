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
    kind="test_result",
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
