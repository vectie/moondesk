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
  let packet = runtime_json_object_field_or_empty(normalized, "command_packet")
  assert_eq(json_string(packet, "command_id", default=""), "cmd-1")
}

///|
test "mooncode normalizes native compact command ids into packets" {
  let normalized = normalize_event_record({
    "id": "native-event",
    "lane": "tool",
    "kind": "runtime.tool_result",
    "command_id": "cmd-native",
    "raw_event": {
      "command_packet": { "command_id": "cmd-native", "action": "prompt" },
    },
  })
  let packet = runtime_json_object_field_or_empty(normalized, "command_packet")
  assert_eq(json_string(packet, "command_id", default=""), "cmd-native")
  assert_eq(json_string(packet, "action", default=""), "prompt")
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
    "protocol": protocol_version(),
    "kind": kind_command(),
    "command_id": "cmd-1",
    "action": "prompt",
  }
  let runtime : Json = {
    "protocol": protocol_version(),
    "kind": "mooncode.runtime-command",
    "command_id": "cmd-1",
    "code_command": "prompt",
  }
  let control : Json = {
    "protocol": protocol_version(),
    "kind": kind_runtime_receipt(),
    "command_id": "cmd-1",
    "status": "recorded",
  }
  let text = jsonl_text([event, command, runtime, control]) + "not-json\n"
  assert_eq(parse_event_log_text(text).length(), 1)
  assert_eq(parse_command_log_text(text).length(), 3)
  assert_eq(parse_runtime_command_log_text(text).length(), 1)
  assert_eq(parse_runtime_receipt_log_text(text).length(), 1)
}

///|
test "mooncode appends durable jsonl text with newline repair" {
  let item : Json = { "id": "event-2", "lane": "runtime" }
  assert_eq(append_jsonl_text("", item), item.stringify() + "\n")
  assert_eq(
    append_jsonl_text("{\"id\":\"event-1\"}", item),
    "{\"id\":\"event-1\"}\n" + item.stringify() + "\n",
  )
  assert_eq(
    append_jsonl_text("{\"id\":\"event-1\"}\n", item),
    "{\"id\":\"event-1\"}\n" + item.stringify() + "\n",
  )
}

///|
test "mooncode validates durable protocol records centrally" {
  let command : Json = {
    "protocol": protocol_version(),
    "kind": kind_command(),
    "command_id": "cmd-1",
  }
  let runtime : Json = {
    "protocol": protocol_version(),
    "kind": "mooncode.runtime-command",
    "command_id": "cmd-1",
  }
  let control : Json = {
    "protocol": protocol_version(),
    "kind": kind_runtime_receipt(),
    "command_id": "cmd-1",
  }
  let snapshot : Json = {
    "protocol": protocol_version(),
    "kind": "mooncode-session-snapshot",
  }
  assert_true(command_packet_valid(command))
  assert_false(command_packet_valid({ "protocol": protocol_version() }))
  assert_true(runtime_command_record_valid(runtime))
  assert_false(runtime_command_record_valid(command))
  assert_true(runtime_receipt_record_valid(control))
  assert_false(runtime_receipt_record_valid(runtime))
  assert_true(session_snapshot_valid(snapshot))
  assert_false(session_snapshot_valid({ "protocol": protocol_version() }))
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
test "mooncode session event projection merges and normalizes sources" {
  let inline = event_record(
    id="event-inline",
    lane="review",
    kind="command.accept",
    title="Accept",
    status="queued",
    created_at="2026-06-15T00:00:00Z",
    detail=" accepted ",
  )
  let durable : Json = {
    "id": "event-durable",
    "detail": " durable note ",
    "command_id": "cmd-native",
  }
  let duplicate = event_record(
    id="event-inline",
    lane="runtime",
    kind="runtime.duplicate",
    title="Duplicate",
    status="done",
    created_at="2026-06-15T00:00:01Z",
    detail="ignored",
  )
  let projected = project_session_events([inline], [duplicate], [durable])
  assert_eq(projected.length(), 2)
  assert_eq(json_string(projected[0], "id", default=""), "event-inline")
  assert_eq(json_string(projected[0], "detail", default=""), "accepted")
  assert_eq(json_string(projected[1], "lane", default=""), "runtime")
  assert_eq(json_string(projected[1], "kind", default=""), "runtime_update")
  assert_eq(json_string(projected[1], "detail", default=""), "durable note")
  let packet = runtime_json_object_field_or_empty(
    projected[1],
    "command_packet",
  )
  assert_eq(json_string(packet, "command_id", default=""), "cmd-native")
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
    runtime_receipt_log_relative_path("s1"),
    ".moontown/mooncode-sessions/s1/runtime-receipts.jsonl",
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
