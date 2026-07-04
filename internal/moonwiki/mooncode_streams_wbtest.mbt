///|
test "mooncode jsonl stream includes meta events and done records" {
  let event = @mooncode.event_record(
    id="e1",
    lane="test",
    kind="command.run_tests",
    title="Run tests: queued",
    status="queued",
    created_at="1",
    detail="Run tests",
  )
  let fields : Map[String, Json] = {}
  fields["id"] = "s1".to_json()
  fields["workspace_id"] = "book".to_json()
  fields["mooncode_runtime_session_id"] = "runtime".to_json()
  fields["mooncode_events"] = Json::array([event])
  let session = Json::object(fields)
  let text = @mooncode.stream_jsonl_text(session, [event])
  let lines = text.trim().split("\n").to_array()
  assert_eq(lines.length(), 3)
  let meta = @json.parse(lines[0].to_owned()) catch { _ => Json::object({}) }
  let item = @json.parse(lines[1].to_owned()) catch { _ => Json::object({}) }
  let done = @json.parse(lines[2].to_owned()) catch { _ => Json::object({}) }
  assert_eq(json_string(meta, "type", default=""), "meta")
  assert_eq(json_int(meta, "event_count", default=0), 1)
  assert_eq(json_int(meta, "since", default=-1), 0)
  assert_eq(json_int(meta, "emitted_count", default=0), 1)
  assert_eq(json_int(meta, "next_since", default=0), 1)
  assert_eq(
    json_string(meta, "stream_source", default=""),
    "moondesk-append-log-projection",
  )
  assert_eq(json_string(item, "type", default=""), "event")
  assert_eq(json_int(item, "sequence", default=0), 1)
  assert_eq(
    json_string(item, "stream_source", default=""),
    "moondesk-append-log-projection",
  )
  assert_eq(json_string(done, "type", default=""), "done")
  assert_eq(json_int(done, "next_since", default=0), 1)
  assert_eq(
    json_string(done, "stream_source", default=""),
    "moondesk-append-log-projection",
  )
}

///|
test "mooncode jsonl stream supports incremental since sequence" {
  let first = @mooncode.event_record(
    id="e1",
    lane="tool",
    kind="tool.read",
    title="Read",
    status="done",
    created_at="1",
    detail="first",
  )
  let second = @mooncode.event_record(
    id="e2",
    lane="diff",
    kind="tool.write",
    title="Write",
    status="done",
    created_at="2",
    detail="second",
  )
  let fields : Map[String, Json] = {}
  fields["id"] = "s1".to_json()
  fields["mooncode_events"] = Json::array([first, second])
  let session = Json::object(fields)
  let text = @mooncode.stream_jsonl_text(session, [first, second], since=1)
  let lines = text.trim().split("\n").to_array()
  assert_eq(lines.length(), 3)
  let meta = @json.parse(lines[0].to_owned()) catch { _ => Json::object({}) }
  let item = @json.parse(lines[1].to_owned()) catch { _ => Json::object({}) }
  let done = @json.parse(lines[2].to_owned()) catch { _ => Json::object({}) }
  assert_eq(json_string(meta, "stream", default=""), "append-log-incremental")
  assert_eq(
    json_string(meta, "stream_source", default=""),
    "moondesk-append-log-projection",
  )
  assert_eq(json_int(meta, "since", default=0), 1)
  assert_eq(json_int(meta, "emitted_count", default=0), 1)
  assert_eq(json_int(meta, "next_since", default=0), 2)
  assert_eq(json_int(item, "sequence", default=0), 2)
  let event_payload = match item {
    Object(object) => object.get("event").unwrap_or(Json::object({}))
    _ => Json::object({})
  }
  assert_eq(json_string(event_payload, "id", default=""), "e2")
  assert_eq(json_int(done, "sequence", default=0), 2)
}

///|
async test "mooncode stream state records resumable checkpoint" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-mooncode-stream-state-wbtest-" +
    @desk.stable_id("mooncode-stream-state", @async.now().to_string()),
  )
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let session : Json = {
    "id": "code-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "workspace_root": root,
    "mooncode_runtime_session_id": "runtime-demo",
  }
  append_mooncode_event_log(
    root,
    "code-demo",
    @mooncode.event_record(
      id="event-1",
      lane="runtime",
      kind="assistant_delta",
      title="Assistant delta",
      status="running",
      created_at="1",
      detail="first",
    ),
  )
  append_mooncode_event_log(
    root,
    "code-demo",
    @mooncode.event_record(
      id="event-2",
      lane="test",
      kind="test_result",
      title="Tests passed",
      status="passed",
      created_at="2",
      detail="second",
    ),
  )
  assert_eq(read_mooncode_event_log(root, "code-demo").length(), 2)
  let state = mooncode_stream_state_projection(root, session, 1, "moondesk-ui")
  assert_eq(json_string(state, "kind", default=""), "mooncode-stream-state")
  assert_eq(json_int(state, "latest_sequence", default=0), 2)
  assert_eq(json_int(state, "emitted_count", default=0), 1)
  assert_eq(json_int(state, "next_since", default=0), 2)
  assert_false(json_bool(state, "checkpoint_ready", default=true))
  let tail = json_array_items(state, "tail_events")
  assert_eq(tail.length(), 1)
  assert_eq(json_int(tail[0], "sequence", default=0), 2)
  assert_eq(
    json_string(
      json_object_field_or_empty(tail[0], "event"),
      "kind",
      default="",
    ),
    "test_result",
  )
  let checkpoint = mooncode_stream_checkpoint_record(
    root,
    session,
    "moondesk-ui",
    json_int(state, "next_since", default=0),
    2,
  )
  write_mooncode_stream_checkpoint(root, "code-demo", "moondesk-ui", checkpoint)
  let resumed = mooncode_stream_state_projection(
    root, session, 2, "moondesk-ui",
  )
  assert_true(json_bool(resumed, "checkpoint_ready", default=false))
  assert_eq(json_int(resumed, "emitted_count", default=-1), 0)
  let saved = json_object_field_or_empty(resumed, "checkpoint")
  assert_eq(
    json_string(saved, "kind", default=""),
    "mooncode-stream-checkpoint",
  )
  assert_eq(json_int(saved, "last_seen_sequence", default=0), 2)
  assert_true(@fs.exists(json_string(saved, "checkpoint_path", default="")))
  assert_true(
    json_string(resumed, "checkpoint_endpoint", default="").contains(
      "/api/mooncode/sessions/code-demo/stream-state",
    ),
  )
  let native_tail = json_string(
    json_object_field_or_empty(resumed, "live_tail_boundary"),
    "native_blocking_tail",
    default="",
  )
  assert_true(
    native_tail.contains(
      @mooncode.moonclaw_native_stream_endpoint("code-demo", root, "sse", 2),
    ),
  )
}

///|
test "mooncode native stream state projection reads jsonl cursor state" {
  let root = "/tmp/moondesk-native-stream-state"
  let session : Json = { "id": "native-demo", "mooncode_events": [] }
  let events : Array[Json] = [
    @mooncode.event_record(
      id="event-1",
      lane="runtime",
      kind="assistant_delta",
      title="Assistant delta",
      status="running",
      created_at="1",
      detail="first",
    ),
    @mooncode.event_record(
      id="event-2",
      lane="test",
      kind="test_result",
      title="Tests passed",
      status="passed",
      created_at="2",
      detail="second",
    ),
  ]
  let text = @mooncode.stream_jsonl_text(session, events)
  let state = mooncode_native_stream_state_projection_from_text(
    root,
    "native-demo",
    text,
    1,
    "moondesk-ui",
    Json::object({}),
  )
  assert_eq(json_string(state, "kind", default=""), "mooncode-stream-state")
  assert_eq(json_string(state, "session_id", default=""), "native-demo")
  assert_eq(json_int(state, "latest_sequence", default=0), 2)
  assert_eq(json_int(state, "emitted_count", default=0), 1)
  assert_eq(json_int(state, "next_since", default=0), 2)
  let tail = json_array_items(state, "tail_events")
  assert_eq(tail.length(), 1)
  assert_eq(json_int(tail[0], "sequence", default=0), 2)
  assert_true(
    json_string(
      json_object_field_or_empty(state, "live_tail_boundary"),
      "native_blocking_tail",
      default="",
    ).contains(
      @mooncode.moonclaw_native_stream_endpoint("native-demo", root, "sse", 1),
    ),
  )
}

///|
test "mooncode native stream path targets typed runtime endpoint" {
  assert_eq(
    @mooncode.moonclaw_native_stream_endpoint(
      "code-demo",
      "/tmp/moon book",
      "sse",
      7,
      wait_ms=1000,
      poll_ms=100,
    ),
    "/v1/code/sessions/code-demo/stream?book_root=%2Ftmp%2Fmoon%20book&format=sse&since=7&wait_ms=1000&poll_ms=100",
  )
}

///|
test "mooncode stream live query opts into bounded tail" {
  assert_true(
    @mooncode.stream_live_enabled_value(
      query_value(
        "/api/mooncode/sessions/s1/stream?format=sse&since=2&live=true", "live",
      ).unwrap_or(""),
    ),
  )
  assert_true(
    @mooncode.stream_live_enabled_value(
      query_value(
        "/api/mooncode/sessions/s1/stream?format=jsonl&live=wait", "live",
      ).unwrap_or(""),
    ),
  )
  assert_false(
    @mooncode.stream_live_enabled_value(
      query_value("/api/mooncode/sessions/s1/stream?live=false", "live").unwrap_or(
        "",
      ),
    ),
  )
  assert_eq(
    @mooncode.stream_live_timeout_ms_value(
      query_value(
        "/api/mooncode/sessions/s1/stream?timeout_ms=20000", "timeout_ms",
      ).unwrap_or(""),
    ),
    15000,
  )
  assert_eq(
    @mooncode.stream_live_poll_ms_value(
      query_value("/api/mooncode/sessions/s1/stream?poll_ms=10", "poll_ms").unwrap_or(
        "",
      ),
    ),
    50,
  )
  assert_eq(
    @mooncode.stream_content_type("sse"),
    "text/event-stream; charset=utf-8",
  )
}

///|
test "mooncode sse stream uses named events" {
  let event = @mooncode.event_record(
    id="e1",
    lane="artifact",
    kind="command.package",
    title="Package result: queued",
    status="queued",
    created_at="1",
    detail="Package",
  )
  let fields : Map[String, Json] = {}
  fields["id"] = "s1".to_json()
  fields["mooncode_events"] = Json::array([event])
  let session = Json::object(fields)
  let text = @mooncode.stream_sse_text(session, [event])
  assert_true(text.contains("event: mooncode.meta\n"))
  assert_true(text.contains("event: mooncode.event\n"))
  assert_true(text.contains("event: mooncode.done\n"))
}
