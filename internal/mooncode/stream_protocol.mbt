///|
pub fn stream_jsonl_text(
  session : Json,
  events : Array[Json],
  since? : Int = 0,
) -> String {
  let latest_sequence = events.length()
  let emitted_count = stream_emitted_count(events, since)
  let lines : Array[String] = [
    stream_meta_record(session, since~, emitted_count~, latest_sequence~).stringify(),
  ]
  let mut sequence = 0
  for event in events {
    sequence += 1
    if sequence <= since {
      continue
    }
    lines.push(
      stream_event_record(session, event, sequence, since~).stringify(),
    )
  }
  lines.push(
    stream_done_record(session, latest_sequence, since~, emitted_count~).stringify(),
  )
  lines.join("\n") + "\n"
}

///|
pub fn stream_sse_text(
  session : Json,
  events : Array[Json],
  since? : Int = 0,
) -> String {
  let latest_sequence = events.length()
  let emitted_count = stream_emitted_count(events, since)
  let chunks : Array[String] = [
    stream_sse_chunk(
      "mooncode.meta",
      stream_meta_record(session, since~, emitted_count~, latest_sequence~),
    ),
  ]
  let mut sequence = 0
  for event in events {
    sequence += 1
    if sequence <= since {
      continue
    }
    chunks.push(
      stream_sse_chunk(
        "mooncode.event",
        stream_event_record(session, event, sequence, since~),
      ),
    )
  }
  chunks.push(
    stream_sse_chunk(
      "mooncode.done",
      stream_done_record(session, latest_sequence, since~, emitted_count~),
    ),
  )
  chunks.join("")
}

///|
pub fn stream_tail_event_records(
  session : Json,
  events : Array[Json],
  since : Int,
) -> Array[Json] {
  let tail : Array[Json] = []
  let mut sequence = 0
  for event in events {
    sequence += 1
    if sequence > since {
      tail.push(stream_event_record(session, event, sequence, since~))
    }
  }
  tail
}

///|
pub fn stream_checkpoint_sequence(
  payload : Json,
  fallback_since : Int,
  latest_sequence : Int,
) -> Int {
  let requested = match stream_json_int_opt(payload, "last_seen_sequence") {
    Some(sequence) => sequence
    None => stream_json_int(payload, "next_since", default=fallback_since)
  }
  clamp_sequence(requested, latest_sequence)
}

///|
pub fn stream_checkpoint_record(
  session : Json,
  consumer_id : String,
  last_seen_sequence : Int,
  latest_sequence : Int,
  recorded_at : String,
  checkpoint_path : String,
  stream_endpoint : String,
  resume_endpoint : String,
  stream_state_endpoint : String,
  runtime_event_ingest_endpoint : String,
) -> Json {
  let clamped = clamp_sequence(last_seen_sequence, latest_sequence)
  {
    "protocol": "mooncode.v1",
    "kind": "mooncode-stream-checkpoint",
    "session_id": stream_json_string(session, "id", default=""),
    "consumer_id": consumer_id,
    "workspace_id": stream_json_string(session, "workspace_id", default=""),
    "workspace_name": stream_json_string(session, "workspace_name", default=""),
    "task_id": stream_json_string(session, "moonclaw_task_id", default=""),
    "last_seen_sequence": clamped,
    "latest_sequence_at_record": latest_sequence,
    "recorded_at": recorded_at,
    "checkpoint_path": checkpoint_path,
    "stream_endpoint": stream_endpoint,
    "resume_endpoint": resume_endpoint,
    "stream_state_endpoint": stream_state_endpoint,
    "runtime_event_ingest_endpoint": runtime_event_ingest_endpoint,
    "owner": stream_owner_record(),
  }
}

///|
pub fn stream_state_record(
  session : Json,
  consumer_id : String,
  requested_since : Int,
  latest_sequence : Int,
  emitted_count : Int,
  event_log_path : String,
  checkpoint_ready : Bool,
  checkpoint_path : String,
  checkpoint : Json,
  tail_events : Array[Json],
  stream_endpoint : String,
  sse_stream_endpoint : String,
  checkpoint_endpoint : String,
  runtime_event_ingest_endpoint : String,
  moondesk_live_endpoint : String,
  native_blocking_tail : String,
) -> Json {
  {
    "protocol": "mooncode.v1",
    "kind": "mooncode-stream-state",
    "session_id": stream_json_string(session, "id", default=""),
    "consumer_id": consumer_id,
    "workspace_id": stream_json_string(session, "workspace_id", default=""),
    "workspace_name": stream_json_string(session, "workspace_name", default=""),
    "task_id": stream_json_string(session, "moonclaw_task_id", default=""),
    "requested_since": requested_since,
    "latest_sequence": latest_sequence,
    "emitted_count": emitted_count,
    "next_since": latest_sequence,
    "has_more": emitted_count > 0,
    "event_log_path": event_log_path,
    "checkpoint_ready": checkpoint_ready,
    "checkpoint_path": checkpoint_path,
    "checkpoint": checkpoint,
    "tail_events": Json::array(tail_events),
    "stream_endpoint": stream_endpoint,
    "sse_stream_endpoint": sse_stream_endpoint,
    "checkpoint_endpoint": checkpoint_endpoint,
    "runtime_event_ingest_endpoint": runtime_event_ingest_endpoint,
    "poll_contract": {
      "get": "Read current append-log cursor state and tail records after ?since=<sequence>.",
      "live_get": "Use /stream?format=jsonl|sse&since=<sequence>&live=true for bounded live-tail waiting before replay.",
      "post": "Persist {consumer_id,last_seen_sequence} after a UI, MoonClaw, or standalone mooncode consumer has processed a tail batch.",
      "cursor_rule": "Use response.next_since as the next ?since value; sequence numbers are 1-based event positions and ?since means already seen.",
    },
    "live_tail_boundary": {
      "current": "bounded live append-log tail over the Moondesk projection, falling back to MoonClaw native /v1/mooncode stream when available",
      "moondesk_live_endpoint": moondesk_live_endpoint,
      "native_blocking_tail": native_blocking_tail,
      "rule": "Moondesk owns resumable cursor state and live-tail projection; MoonClaw or standalone mooncode owns event production and native blocking runtime streams.",
    },
    "owner": stream_owner_record(),
  }
}

///|
pub fn stream_emitted_count(events : Array[Json], since : Int) -> Int {
  if since >= events.length() {
    0
  } else {
    events.length() - since
  }
}

///|
pub fn stream_mode(since : Int) -> String {
  if since > 0 {
    "append-log-incremental"
  } else {
    "append-log-snapshot"
  }
}

///|
pub fn stream_source() -> String {
  "moondesk-append-log-projection"
}

///|
pub fn stream_meta_record(
  session : Json,
  since~ : Int,
  emitted_count~ : Int,
  latest_sequence~ : Int,
) -> Json {
  {
    "protocol": "mooncode.v1",
    "stream": stream_mode(since),
    "stream_source": stream_source(),
    "type": "meta",
    "session_id": stream_json_string(session, "id", default=""),
    "workspace_id": stream_json_string(session, "workspace_id", default=""),
    "task_id": stream_json_string(session, "moonclaw_task_id", default=""),
    "event_count": stream_json_array_items(session, "mooncode_events").length(),
    "since": since,
    "emitted_count": emitted_count,
    "next_since": latest_sequence,
  }
}

///|
pub fn stream_event_record(
  session : Json,
  event : Json,
  sequence : Int,
  since~ : Int,
) -> Json {
  {
    "protocol": "mooncode.v1",
    "stream": stream_mode(since),
    "stream_source": stream_source(),
    "type": "event",
    "sequence": sequence,
    "session_id": stream_json_string(session, "id", default=""),
    "event": event,
  }
}

///|
pub fn stream_done_record(
  session : Json,
  sequence : Int,
  since~ : Int,
  emitted_count~ : Int,
) -> Json {
  {
    "protocol": "mooncode.v1",
    "stream": stream_mode(since),
    "stream_source": stream_source(),
    "type": "done",
    "session_id": stream_json_string(session, "id", default=""),
    "sequence": sequence,
    "since": since,
    "emitted_count": emitted_count,
    "next_since": sequence,
  }
}

///|
fn stream_sse_chunk(name : String, payload : Json) -> String {
  "event: \{name}\n" + "data: \{payload.stringify()}\n\n"
}

///|
fn clamp_sequence(sequence : Int, latest_sequence : Int) -> Int {
  if sequence < 0 {
    0
  } else if sequence > latest_sequence {
    latest_sequence
  } else {
    sequence
  }
}

///|
fn stream_owner_record() -> Json {
  {
    "ui": "moondesk",
    "runtime": "moonclaw",
    "extractable_component": "mooncode",
  }
}

///|
fn stream_json_array_items(json : Json, key : String) -> Array[Json] {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::Array(items)) => items
        _ => []
      }
    _ => []
  }
}

///|
fn stream_json_string(json : Json, key : String, default~ : String) -> String {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::String(value)) => value
        _ => default
      }
    _ => default
  }
}

///|
fn stream_json_int(json : Json, key : String, default~ : Int) -> Int {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(value) => @json.from_json(value) catch { _ => default }
        _ => default
      }
    _ => default
  }
}

///|
fn stream_json_int_opt(json : Json, key : String) -> Int? {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(value) => Some(@json.from_json(value) catch { _ => 0 })
        _ => None
      }
    _ => None
  }
}

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
