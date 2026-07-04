///|
test "mooncode parses jsonl event log and skips invalid lines" {
  let event = @mooncode.event_record(
    id="event-1",
    lane="runtime",
    kind="command.note",
    title="Note",
    status="queued",
    created_at="1",
    detail="hello",
  )
  let events = parse_mooncode_event_log_text(
    event.stringify() + "\nnot-json\n\n" + event.stringify() + "\n",
  )
  assert_eq(events.length(), 2)
  assert_eq(json_string(events[0], "id", default=""), "event-1")
}

///|
test "mooncode event merge dedupes durable log against inline commands" {
  let event = @mooncode.event_record(
    id="event-1",
    lane="review",
    kind="command.accept",
    title="Accept",
    status="queued",
    created_at="1",
    detail="accepted",
  )
  let merged = @mooncode.merge_events([], [event], [event])
  assert_eq(merged.length(), 1)
  assert_eq(json_string(merged[0], "lane", default=""), "review")
}

///|
async test "mooncode appends and replays durable session event log" {
  let root = "/tmp/moondesk-mooncode-event-log-wbtest-" +
    @async.now().to_string()
  let session_id = "session-a"
  let event = @mooncode.event_record(
    id="event-1",
    lane="runtime",
    kind="command.note",
    title="Note",
    status="queued",
    created_at="1",
    detail="hello",
  )
  let second = @mooncode.event_record(
    id="event-2",
    lane="test",
    kind="test_result",
    title="Tests",
    status="passed",
    created_at="2",
    detail="passed",
  )
  append_mooncode_event_log(root, session_id, event)
  append_mooncode_event_log(root, session_id, second)
  let events = read_mooncode_event_log(root, session_id)
  assert_eq(events.length(), 2)
  assert_eq(json_string(events[0], "id", default=""), "event-1")
  assert_eq(json_string(events[1], "id", default=""), "event-2")
  assert_true(@fs.exists(mooncode_event_log_path(root, session_id)))
}

///|
async test "mooncode durable logs use suite product home for hosted book roots" {
  let suite_root = "/tmp/moondesk-mooncode-suite-log-wbtest-" +
    @async.now().to_string()
  let book_root = suite_root + "/books/code-lab"
  let session_id = "session-suite"
  let event = @mooncode.event_record(
    id="event-suite",
    lane="runtime",
    kind="command.note",
    title="Note",
    status="queued",
    created_at="1",
    detail="hello",
  )
  append_mooncode_event_log(book_root, session_id, event)
  let event_path = mooncode_event_log_path(book_root, session_id)
  assert_eq(
    event_path,
    suite_root +
    "/.moonsuite/products/mooncode/sessions/session-suite/events.jsonl",
  )
  assert_true(@fs.exists(event_path))
  assert_false(
    @fs.exists(
      book_root +
      "/.moonsuite/products/mooncode/sessions/session-suite/events.jsonl",
    ),
  )
  let events = read_mooncode_event_log(book_root, session_id)
  assert_eq(events.length(), 1)
  assert_eq(json_string(events[0], "id", default=""), "event-suite")
}

///|
async test "mooncode sync imports command-scoped native runtime events before projection" {
  let root = "/tmp/moondesk-mooncode-moonclaw-projection-wbtest-" +
    @async.now().to_string()
  let session_id = "session-native"
  let session = @mooncode.session_record(
    session_id~,
    workspace_id="book-demo",
    workspace_name="Demo Book",
    workspace_root=root,
    runtime={
      "id": session_id,
      "status": "created",
      "model": "codex/gpt-5.4",
      "web_search": false,
      "queued_messages": [],
    },
    title="MoonCode - native durable event",
    created_at="1",
    updated_at="1",
    last_message="hello",
    initial_context_path="",
  )
  write_mooncode_session_record(root, session)
  let event = @mooncode.event_record(
    id="native-assistant",
    lane="transcript",
    kind="assistant_delta",
    title="MoonCode assistant update",
    status="running",
    created_at="2",
    detail="Hello!",
    command_packet={
      "protocol": @mooncode.protocol_version(),
      "kind": @mooncode.kind_command(),
      "command_id": "cmd-native",
      "action": "prompt",
    },
  )

  let cold_projected = attach_mooncode_session_projection(root, session)
  assert_eq(json_array_items(cold_projected, "mooncode_events").length(), 0)
  assert_eq(
    json_int(
      json_object_field_or_empty(cold_projected, "mooncode_summary"),
      "append_log_count",
      default=0,
    ),
    0,
  )

  let native_report = @mooncode.runtime_native_event_report(
    { "events": [event] },
    session_id~,
    observed_at="3",
  )
  let synced = sync_mooncode_native_runtime_events_from_report(
    root, session_id, session, native_report,
  )
  let projected = attach_mooncode_session_projection(root, synced)
  let events = json_array_items(projected, "mooncode_events")
  let summary = json_object_field_or_empty(projected, "mooncode_summary")
  assert_eq(events.length(), 1)
  assert_eq(json_string(events[0], "id", default=""), "native-assistant")
  assert_eq(json_string(events[0], "detail", default=""), "Hello!")
  assert_eq(json_int(summary, "event_count", default=0), 1)
  assert_eq(json_int(summary, "append_log_count", default=0), 1)
  let durable_events = read_mooncode_event_log(root, session_id)
  assert_eq(durable_events.length(), 1)
  ignore(
    sync_mooncode_native_runtime_events_from_report(
      root, session_id, synced, native_report,
    ),
  )
  assert_eq(read_mooncode_event_log(root, session_id).length(), 1)
}

///|
async test "mooncode sync rejects unscoped native transcript events" {
  let root = "/tmp/moondesk-mooncode-native-contract-reject-wbtest-" +
    @async.now().to_string()
  let session_id = "session-native-unsafe"
  let session = @mooncode.session_record(
    session_id~,
    workspace_id="book-demo",
    workspace_name="Demo Book",
    workspace_root=root,
    runtime={ "id": session_id, "status": "created" },
    title="MoonCode - native unsafe event",
    created_at="1",
    updated_at="1",
    last_message="hello",
    initial_context_path="",
  )
  write_mooncode_session_record(root, session)
  let event = @mooncode.event_record(
    id="native-unscoped-assistant",
    lane="transcript",
    kind="assistant_delta",
    title="MoonCode assistant update",
    status="running",
    created_at="2",
    detail="This must not project.",
  )
  let native_report = @mooncode.runtime_native_event_report(
    { "events": [event] },
    session_id~,
    observed_at="3",
  )
  let synced = sync_mooncode_native_runtime_events_from_report(
    root, session_id, session, native_report,
  )
  ignore(synced)
  assert_eq(read_mooncode_event_log(root, session_id).length(), 0)
}

///|
test "mooncode parses command log and requires typed packets" {
  let command : Json = {
    "protocol": @mooncode.protocol_version(),
    "kind": @mooncode.kind_command(),
    "command_id": "cmd-1",
    "action": "prompt",
  }
  let commands = parse_mooncode_command_log_text(
    command.stringify() +
    "\nnot-json\n{\"protocol\":\"other\",\"command_id\":\"bad\"}\n",
  )
  assert_eq(commands.length(), 1)
  assert_eq(json_string(commands[0], "command_id", default=""), "cmd-1")
}

///|
test "mooncode parses runtime command log and requires typed records" {
  let command : Json = {
    "protocol": @mooncode.protocol_version(),
    "kind": @mooncode.kind_runtime_command(),
    "command_id": "cmd-1",
    "code_command": "prompt",
  }
  let commands = parse_mooncode_runtime_command_log_text(
    command.stringify() +
    "\nnot-json\n{\"protocol\":\"mooncode.v1\",\"kind\":\"mooncode.command\",\"command_id\":\"bad\"}\n",
  )
  assert_eq(commands.length(), 1)
  assert_eq(json_string(commands[0], "code_command", default=""), "prompt")
}

///|
test "mooncode parses runtime receipt log and requires typed receipts" {
  let receipt : Json = {
    "protocol": @mooncode.protocol_version(),
    "kind": @mooncode.kind_runtime_receipt(),
    "command_id": "cmd-1",
    "status": "recorded",
  }
  let receipts = parse_mooncode_runtime_receipt_log_text(
    receipt.stringify() +
    "\nnot-json\n{\"protocol\":\"mooncode.v1\",\"kind\":\"mooncode.command\",\"command_id\":\"bad\"}\n",
  )
  assert_eq(receipts.length(), 1)
  assert_eq(json_string(receipts[0], "status", default=""), "recorded")
}

///|
async test "mooncode appends and replays durable command queue" {
  let root = "/tmp/moondesk-mooncode-command-log-wbtest-" +
    @async.now().to_string()
  let session_id = "session-a"
  let command : Json = {
    "protocol": @mooncode.protocol_version(),
    "kind": @mooncode.kind_command(),
    "command_id": "cmd-1",
    "action": "prompt",
  }
  append_mooncode_command_log(root, session_id, command)
  let commands = read_mooncode_command_log(root, session_id)
  assert_eq(commands.length(), 1)
  assert_eq(json_string(commands[0], "action", default=""), "prompt")
  assert_true(@fs.exists(mooncode_command_log_path(root, session_id)))
}

///|
async test "mooncode appends and replays durable runtime command feed" {
  let root = "/tmp/moondesk-mooncode-runtime-command-log-wbtest-" +
    @async.now().to_string()
  let session_id = "session-a"
  let command : Json = {
    "protocol": @mooncode.protocol_version(),
    "kind": @mooncode.kind_runtime_command(),
    "command_id": "cmd-1",
    "code_command": "prompt",
  }
  append_mooncode_runtime_command_log(root, session_id, command)
  let commands = read_mooncode_runtime_command_log(root, session_id)
  assert_eq(commands.length(), 1)
  assert_eq(json_string(commands[0], "code_command", default=""), "prompt")
  assert_true(@fs.exists(mooncode_runtime_command_log_path(root, session_id)))
}

///|
async test "mooncode appends and replays durable runtime receipts" {
  let root = "/tmp/moondesk-mooncode-runtime-receipt-log-wbtest-" +
    @async.now().to_string()
  let session_id = "session-a"
  let receipt : Json = {
    "protocol": @mooncode.protocol_version(),
    "kind": @mooncode.kind_runtime_receipt(),
    "command_id": "cmd-1",
    "status": "recorded",
  }
  append_mooncode_runtime_receipt_log(root, session_id, receipt)
  let receipts = read_mooncode_runtime_receipt_log(root, session_id)
  assert_eq(receipts.length(), 1)
  assert_eq(json_string(receipts[0], "status", default=""), "recorded")
  assert_true(@fs.exists(mooncode_runtime_receipt_log_path(root, session_id)))
}

///|
async test "mooncode writes and reads typed durable session snapshot" {
  let root = "/tmp/moondesk-mooncode-session-snapshot-wbtest-" +
    @async.now().to_string()
  let session_id = "session-a"
  let snapshot : Json = {
    "kind": "mooncode-session-snapshot",
    "protocol": @mooncode.protocol_version(),
    "session_id": session_id,
  }
  write_mooncode_session_snapshot(root, session_id, snapshot)
  match read_mooncode_session_snapshot(root, session_id) {
    Some(read_back) =>
      assert_eq(json_string(read_back, "session_id", default=""), session_id)
    None => fail("snapshot should be readable")
  }
  assert_true(@fs.exists(mooncode_session_snapshot_path(root, session_id)))
}
