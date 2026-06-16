///|
test "mooncode event record trims durable text fields" {
  let long = "x".repeat(4010)
  let event = event_record(
    id="event-1",
    lane="runtime",
    kind="runtime.note",
    title="Note",
    status="queued",
    created_at="2026-06-15T00:00:00Z",
    detail=long,
    diff=long,
  )
  assert_eq(json_string(event, "detail", default="").length(), 4000)
  assert_eq(json_string(event, "diff", default="").length(), 4000)
}

///|
test "mooncode normalizes sparse runtime event records" {
  let event : Json = {
    "detail": "  running tool  ",
    "diff": "  patch  ",
    "command_packet": { "command_id": "cmd-1" },
  }
  let normalized = normalize_event_record(event)
  assert_true(
    json_string(normalized, "id", default="").has_prefix("mooncode-event-"),
  )
  assert_eq(json_string(normalized, "lane", default=""), "runtime")
  assert_eq(json_string(normalized, "kind", default=""), "runtime_update")
  assert_eq(json_string(normalized, "title", default=""), "runtime_update")
  assert_eq(json_string(normalized, "status", default=""), "info")
  assert_eq(json_string(normalized, "detail", default=""), "running tool")
  assert_eq(json_string(normalized, "diff", default=""), "patch")
  assert_eq(json_string(normalized, "path", default="x"), "")
  assert_eq(event_json_int(normalized, "exit_code", default=-1), 0)
  let packet = event_json_object_field_or_empty(normalized, "command_packet")
  assert_eq(json_string(packet, "command_id", default=""), "cmd-1")
}

///|
test "mooncode parses durable jsonl protocol records" {
  let event = event_record(
    id="event-1",
    lane="runtime",
    kind="runtime.note",
    title="Note",
    status="queued",
    created_at="2026-06-15T00:00:00Z",
    detail="hello",
  )
  let command : Json = {
    "protocol": "mooncode.v1",
    "kind": "mooncode.command",
    "command_id": "cmd-1",
    "action": "prompt",
  }
  let runtime : Json = {
    "protocol": "mooncode.v1",
    "kind": "mooncode.runtime-command",
    "command_id": "cmd-1",
    "serve_command": "prompt",
  }
  let dispatch : Json = {
    "protocol": "mooncode.v1",
    "kind": "mooncode.runtime-dispatch",
    "command_id": "cmd-1",
    "status": "bridged",
  }
  let text = jsonl_text([event, command, runtime, dispatch]) + "not-json\n"
  assert_eq(parse_event_log_text(text).length(), 1)
  assert_eq(parse_command_log_text(text).length(), 3)
  assert_eq(parse_runtime_command_log_text(text).length(), 1)
  assert_eq(parse_runtime_dispatch_log_text(text).length(), 1)
}

///|
test "mooncode event merge dedupes by durable event id" {
  let event = event_record(
    id="event-1",
    lane="review",
    kind="command.accept",
    title="Accept",
    status="queued",
    created_at="2026-06-15T00:00:00Z",
    detail="accepted",
  )
  let merged = merge_events([], [event], [event])
  assert_eq(merged.length(), 1)
  assert_eq(json_string(merged[0], "lane", default=""), "review")
}

///|
test "mooncode session id validation stays storage-backend neutral" {
  assert_true(session_id_valid("mooncode-20260615-000000"))
  assert_false(session_id_valid(""))
  assert_false(session_id_valid("."))
  assert_false(session_id_valid(".."))
  assert_false(session_id_valid("../x"))
  assert_false(session_id_valid("a\\b"))
}

///|
test "mooncode sidecar relative paths define durable session layout" {
  assert_eq(sessions_relative_dir(), ".moontown/mooncode-sessions")
  assert_eq(session_log_relative_dir("s1"), ".moontown/mooncode-sessions/s1")
  assert_eq(
    event_log_relative_path("s1"),
    ".moontown/mooncode-sessions/s1/events.jsonl",
  )
  assert_eq(
    command_log_relative_path("s1"),
    ".moontown/mooncode-sessions/s1/commands.jsonl",
  )
  assert_eq(
    runtime_command_log_relative_path("s1"),
    ".moontown/mooncode-sessions/s1/runtime-commands.jsonl",
  )
  assert_eq(
    runtime_dispatch_log_relative_path("s1"),
    ".moontown/mooncode-sessions/s1/runtime-dispatches.jsonl",
  )
  assert_eq(
    session_snapshot_relative_path("s1"),
    ".moontown/mooncode-sessions/s1/session.json",
  )
  assert_eq(
    stream_checkpoint_relative_dir("s1"),
    ".moontown/mooncode-sessions/s1/stream-checkpoints",
  )
  assert_eq(
    stream_checkpoint_relative_path("s1", "moondesk-ui"),
    ".moontown/mooncode-sessions/s1/stream-checkpoints/moondesk-ui.json",
  )
  assert_eq(
    stream_checkpoint_relative_path("s1", "moondesk/ui"),
    ".moontown/mooncode-sessions/s1/stream-checkpoints/default.json",
  )
}
