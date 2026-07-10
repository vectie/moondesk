///|
async test "mooncode writes and lists native session records outside generic agent store" {
  let root = "/tmp/moondesk-mooncode-session-record-wbtest-" +
    @async.now().to_string()
  let session_id = "session-a"
  let session : Json = {
    "id": session_id,
    "component": "mooncode",
    "protocol": @mooncode.protocol_version(),
    "workspace_root": root,
    "messages": [],
  }
  write_mooncode_session_record(root, session)
  match read_mooncode_session_record(root, session_id) {
    Some(read_back) => {
      assert_eq(json_string(read_back, "id", default=""), session_id)
      assert_eq(json_string(read_back, "component", default=""), "mooncode")
    }
    None => fail("MoonCode session record should be readable")
  }
  let records = read_mooncode_session_records(root)
  assert_eq(records.length(), 1)
  assert_true(@fs.exists(mooncode_session_record_path(root, session_id)))
}

///|
async test "mooncode response enrichment uses MoonCode defaults only" {
  let root = "/tmp/moondesk-mooncode-response-defaults-wbtest-" +
    @async.now().to_string()
  let session : Json = {
    "id": "session-a",
    "component": "mooncode",
    "protocol": @mooncode.protocol_version(),
    "workspace_root": root,
    "mooncode_runtime_session_id": "session-a",
  }
  let enriched = enrich_mooncode_session_for_response(root, session)
  assert_eq(json_string(enriched, "title", default=""), "MoonCode Session")
  assert_eq(json_string(enriched, "cwd", default=""), root)
  assert_true(json_object_field(enriched, "transcript") is None)
}

///|
async test "mooncode command response stays compact for chat mutations" {
  let root = "/tmp/moondesk-mooncode-compact-command-response-wbtest-" +
    @async.now().to_string()
  let command_packet : Json = {
    "protocol": @mooncode.protocol_version(),
    "kind": "mooncode.command",
    "command_id": "cmd-1",
    "client_turn_id": "client-1",
    "action": "prompt",
    "session_id": "s1",
    "runtime_session_id": "s1",
    "message": "hello",
  }
  let conversation : Json = {
    "kind": @mooncode.conversation_kind(),
    "protocol": @mooncode.protocol_version(),
    "contract_id": @mooncode.conversation_contract_id(),
    "session_id": "s1",
    "workspace_id": "book",
    "workspace_name": "Book",
    "turn_count": 1,
    "revision": 2,
    "last_sequence": 2,
    "source_event_count": 2,
    "turns": [
      {
        "kind": @mooncode.conversation_turn_kind(),
        "turn_id": "cmd-1",
        "client_turn_id": "client-1",
        "command_id": "cmd-1",
        "status": "done",
        "started_at": "1",
        "updated_at": "2",
        "user": {
          "role": "user",
          "content": "hello",
          "status": "done",
          "client_turn_id": "client-1",
          "command_id": "cmd-1",
        },
        "ordinal": 0,
        "work": {
          "item_id": "turn:cmd-1:work",
          "status": "done",
          "summary": "Completed work",
          "steps": [],
          "live": {},
        },
        "assistant": {
          "role": "assistant",
          "content": "reply",
          "status": "done",
          "client_turn_id": "client-1",
          "command_id": "cmd-1",
        },
      },
    ],
  }
  let compact = compact_mooncode_session_command_response(
    root,
    {
      "id": "s1",
      "workspace_id": "book",
      "workspace_name": "Book",
      "workspace_root": root,
      "cwd": root,
      "title": "MoonCode - Book",
      "model": "codex/gpt-5.4",
      "status": "done",
      "queued_count": 0,
      "mooncode_conversation": conversation,
      "mooncode_last_change_set_manifest": {
        "kind": "mooncode-change-set",
        "detail": "large diagnostic payload that must not ride on chat sends",
      },
    },
    command_packet,
  )
  assert_true(json_object_field(compact, "mooncode_events") is None)
  assert_true(
    json_object_field(compact, "mooncode_last_change_set_manifest") is None,
  )
  assert_eq(json_string(compact, "client_turn_id", default=""), "client-1")
  assert_eq(json_string(compact, "turn_id", default=""), "cmd-1")
  let turn = json_object_field_or_empty(compact, "mooncode_turn")
  assert_eq(json_string(turn, "client_turn_id", default=""), "client-1")
  let returned = json_object_field_or_empty(compact, "mooncode_conversation")
  assert_eq(json_int(returned, "turn_count", default=0), 1)
  let summary = json_object_field_or_empty(compact, "mooncode_summary")
  assert_eq(json_int(summary, "event_count", default=-1), 0)
  assert_eq(json_int(summary, "verified_test_count", default=-1), 0)
  assert_eq(json_int(summary, "pending_diff_count", default=-1), 0)
}

///|
test "mooncode native full session preserves MoonClaw canonical conversation" {
  let conversation : Json = {
    "kind": @mooncode.conversation_kind(),
    "protocol": @mooncode.protocol_version(),
    "contract_id": @mooncode.conversation_contract_id(),
    "session_id": "native-session",
    "workspace_id": "/tmp/book",
    "workspace_name": "/tmp/book",
    "turn_count": 1,
    "revision": 2,
    "last_sequence": 2,
    "source_event_count": 2,
    "turns": [
      {
        "kind": @mooncode.conversation_turn_kind(),
        "turn_id": "cmd-1",
        "client_turn_id": "client-1",
        "command_id": "cmd-1",
        "status": "done",
        "started_at": "2026-07-07T00:00:00Z",
        "updated_at": "2026-07-07T00:00:02Z",
        "user": { "role": "user", "content": "hey", "status": "queued" },
        "ordinal": 0,
        "work": {
          "item_id": "turn:cmd-1:work",
          "status": "done",
          "summary": "Completed work",
          "steps": [],
          "live": {},
        },
        "assistant": {
          "role": "assistant",
          "content": "hello reply",
          "status": "done",
        },
      },
    ],
  }
  let row : Json = {
    "id": "native-session",
    "title": "Native Session",
    "workspace_id": "book-id",
    "workspace_name": "Book",
    "workspace_root": "/tmp/book",
    "cwd": "/tmp/book",
    "status": "done",
    "model": "moonclaw",
    "queued_count": 0,
    "updated_at": "2026-07-07T00:00:02Z",
  }
  let native_record : Json = {
    "session_id": "native-session",
    "book_root": "/tmp/book",
    "mooncode_conversation": conversation,
    "event_log_count": 2,
    "command_log_count": 1,
    "runtime_receipt_log_count": 1,
    "storage": {
      "events_jsonl": "/tmp/book/.moonsuite/products/moonclaw/mooncode/sessions/native-session/events.jsonl",
      "commands_jsonl": "/tmp/book/.moonsuite/products/moonclaw/mooncode/sessions/native-session/commands.jsonl",
      "runtime_receipts_jsonl": "/tmp/book/.moonsuite/products/moonclaw/mooncode/sessions/native-session/runtime-receipts.jsonl",
    },
  }
  let session = moonclaw_runtime_full_session_base(
    "/tmp/book", row, native_record,
  )
  let projected = @mooncode.session_projection_response(
    mooncode_session_response_defaults(session),
    [],
    event_log_path=moonclaw_runtime_record_storage_path(
      native_record, "events_jsonl", "",
    ),
    append_log_count=json_int(native_record, "event_log_count", default=0),
    command_log_path=moonclaw_runtime_record_storage_path(
      native_record, "commands_jsonl", "",
    ),
    command_log_count=json_int(native_record, "command_log_count", default=0),
    runtime_command_log_path=moonclaw_runtime_record_storage_path(
      native_record, "commands_jsonl", "",
    ),
    runtime_command_log_count=json_int(
      native_record,
      "command_log_count",
      default=0,
    ),
    runtime_receipt_log_path=moonclaw_runtime_record_storage_path(
      native_record, "runtime_receipts_jsonl", "",
    ),
    runtime_receipt_log_count=json_int(
      native_record,
      "runtime_receipt_log_count",
      default=0,
    ),
  )
  let preserved = json_object_field_or_empty(projected, "mooncode_conversation")
  assert_eq(
    json_string(preserved, "kind", default=""),
    @mooncode.conversation_kind(),
  )
  let turns = json_array_items(preserved, "turns")
  assert_eq(turns.length(), 1)
  assert_eq(
    json_string(
      json_object_field_or_empty(turns[0], "assistant"),
      "content",
      default="",
    ),
    "hello reply",
  )
}
