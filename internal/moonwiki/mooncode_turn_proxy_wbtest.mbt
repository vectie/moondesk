///|
fn canonical_test_record() -> Json {
  {
    "kind": "mooncode-session-record",
    "owner": "moonclaw",
    "session_id": "session-canonical",
    "book_root": "/tmp/moonsuite/books/code-lab",
    "journal_sequence": 5,
    "storage": {
      "journal_jsonl": "/tmp/moonsuite/.moonsuite/products/moonclaw/mooncode/sessions/session-canonical/journal.jsonl",
    },
    "snapshot": {
      "first_user_prompt": "Fix the parser",
      "last_updated": "2026-07-15T10:00:00Z",
    },
    "mooncode_conversation": {
      "kind": @mooncode.conversation_kind(),
      "session_id": "session-canonical",
      "workspace_id": "book-code-lab",
      "workspace_name": "Code Lab",
      "revision": 5,
      "turns": [
        {
          "turn_id": "turn-1",
          "command_id": "command-1",
          "client_turn_id": "client-1",
          "status": "running",
          "updated_at": "2026-07-15T10:00:00Z",
          "user": { "content": "Fix the parser" },
        },
      ],
    },
  }
}

///|
fn idempotency_test_command(
  message : String,
) -> @mooncode_core.MoonCodeCommand raise {
  match
    @mooncode.decode_command_submission({
      "action": "prompt",
      "client_turn_id": "client-stable",
      "message": message,
    }) {
    Ok(command) => command
    Err(error) => fail(error)
  }
}

///|
fn idempotency_test_session(command : @mooncode_core.MoonCodeCommand) -> Json {
  let base : Json = {
    "id": "session-stable",
    "workspace_id": "book-code-lab",
    "workspace_name": "Code Lab",
    "workspace_root": "/tmp/moonsuite/books/code-lab",
  }
  let accepted = @mooncode.accepted_command_packet(base, command, "ignored")
  let conversation : Json = {
    "kind": @mooncode.conversation_kind(),
    "protocol": @mooncode.protocol_version(),
    "contract_id": @mooncode.conversation_contract_id(),
    "session_id": "session-stable",
    "workspace_id": "book-code-lab",
    "workspace_name": "Code Lab",
    "turn_count": 1,
    "revision": 1,
    "last_sequence": 1,
    "source_event_count": 1,
    "turns": [
      {
        "kind": @mooncode_core.conversation_turn_kind(),
        "turn_id": "turn-stable",
        "command_id": accepted.command_id(),
        "client_turn_id": command.client_turn_id(),
        "ordinal": 1,
        "status": "running",
        "started_at": "2026-07-28T00:00:00Z",
        "updated_at": "2026-07-28T00:00:00Z",
        "user": {
          "item_id": "message-stable",
          "role": "user",
          "content": command.message(),
          "status": "completed",
        },
        "work": {},
        "assistant": null,
      },
    ],
  }
  mooncode_session_with_field(base, "mooncode_conversation", conversation)
}

///|
test "durable command id recognizes an identical idempotent retry" {
  let command = idempotency_test_command("Fix the parser")
  let result = mooncode_existing_command_response(
    "/tmp/moonsuite",
    idempotency_test_session(command),
    command,
  )
  assert_true(result is Ok(Some(_)))
}

///|
test "durable command id rejects conflicting client turn reuse" {
  let original = idempotency_test_command("Fix the parser")
  let conflicting = idempotency_test_command("Rewrite the parser")
  let result = mooncode_existing_command_response(
    "/tmp/moonsuite",
    idempotency_test_session(original),
    conflicting,
  )
  guard result is Err(error) else { fail("expected idempotency conflict") }
  assert_eq(json_int(error, "code", default=0), 409)
}

///|
async test "submit path idempotent retry short circuits before unavailable daemon" {
  let command = idempotency_test_command("Fix the parser")
  let result = submit_mooncode_turn(
    "/definitely/unavailable/mooncode-idempotency-test",
    idempotency_test_session(command),
    command,
    Json::empty_object(),
    "later",
  )
  guard result is Ok(response) else { fail("expected idempotent response") }
  assert_eq(
    json_string(response, "client_turn_id", default=""),
    "client-stable",
  )
  assert_eq(json_string(response, "turn_id", default=""), "turn-stable")
}

///|
async test "submit path conflicting retry returns 409 before unavailable daemon" {
  let original = idempotency_test_command("Fix the parser")
  let result = submit_mooncode_turn(
    "/definitely/unavailable/mooncode-idempotency-test",
    idempotency_test_session(original),
    idempotency_test_command("Rewrite the parser"),
    Json::empty_object(),
    "later",
  )
  guard result is Err(error) else { fail("expected idempotency conflict") }
  assert_eq(json_int(error, "code", default=0), 409)
}

///|
test "native record is the only canonical conversation projected into chat" {
  let base : Json = {
    "id": "session-canonical",
    "workspace_id": "book-code-lab",
    "workspace_name": "Code Lab",
    "workspace_root": "/tmp/moonsuite/books/code-lab",
    "status": "created",
  }
  let session = mooncode_session_from_native_record(
    base,
    canonical_test_record(),
    "2026-07-15T10:00:00Z",
  )
  assert_eq(json_string(session, "status", default=""), "running")
  assert_eq(
    json_string(session, "source", default=""),
    "moonclaw-canonical-session",
  )
  let conversation = json_object_field_or_empty(
    session, "mooncode_conversation",
  )
  assert_eq(json_int(conversation, "revision", default=0), 5)
  assert_eq(json_array_items(conversation, "turns").length(), 1)
}

///|
test "native session metadata preserves MoonBook grouping" {
  let row = moonclaw_runtime_listing_row_from_record(
    "/tmp/moonsuite",
    canonical_test_record(),
  )
  assert_eq(json_string(row, "id", default=""), "session-canonical")
  assert_eq(json_string(row, "title", default=""), "Fix the parser")
  assert_eq(json_string(row, "workspace_id", default=""), "book-code-lab")
  assert_eq(json_string(row, "workspace_name", default=""), "Code Lab")
  assert_eq(
    json_string(row, "workspace_root", default=""),
    "/tmp/moonsuite/books/code-lab",
  )
}

///|
test "canonical conversation repairs incomplete lightweight listing metadata" {
  let session = moonclaw_runtime_full_session_from_record(
    "/tmp/moonsuite",
    canonical_test_record(),
    row={
      "id": "session-canonical",
      "title": "Fix the parser",
      "workspace_id": "",
      "workspace_name": "code-lab",
      "workspace_root": "/tmp/moonsuite/books/code-lab",
    },
  )
  assert_eq(json_string(session, "workspace_id", default=""), "book-code-lab")
  assert_eq(json_string(session, "workspace_name", default=""), "Code Lab")
  assert_eq(json_int(session, "mooncode_journal_sequence", default=0), 5)
  assert_eq(
    json_string(session, "mooncode_journal_path", default=""),
    "/tmp/moonsuite/.moonsuite/products/moonclaw/mooncode/sessions/session-canonical/journal.jsonl",
  )
  let conversation = json_object_field_or_empty(
    session, "mooncode_conversation",
  )
  assert_eq(json_int(conversation, "revision", default=0), 5)
}

///|
test "session listing joins MoonClaw rows to the actual MoonBook catalog" {
  let row : Json = {
    "id": "session-canonical",
    "workspace_id": "",
    "workspace_name": "code-lab",
    "workspace_root": "/tmp/moonsuite/books/code-lab",
  }
  let workspace = @desk.workspace(
    id="book-code-lab",
    name="Code Lab",
    root_path="/tmp/moonsuite/books/code-lab",
    kind=MoonBook,
  )
  let normalized = moonclaw_runtime_listing_row_with_workspace(row, [workspace])
  assert_eq(
    json_string(normalized, "workspace_id", default=""),
    "book-code-lab",
  )
  assert_eq(json_string(normalized, "workspace_name", default=""), "Code Lab")
  let general = moonclaw_runtime_listing_row_with_workspace(row, [])
  assert_eq(json_string(general, "workspace_id", default="missing"), "")
}

///|
test "canonical stream resumes from the greatest durable sequence" {
  let stream = [
    "{\"type\":\"meta\",\"next_since\":\"8\"}", "{\"type\":\"event\",\"sequence\":\"9\"}",
    "{\"type\":\"done\",\"sequence\":\"9223372036854775810\",\"next_since\":\"9223372036854775810\"}",
  ].join("\n")
  let current = @mooncode_core.mooncode_watch_cursor(4, "2")
  let decoded = mooncode_native_stream_cursor(stream, current)
  match decoded {
    @mooncode_core.Advanced(cursor) => {
      assert_eq(cursor.revision(), 4)
      assert_eq(cursor.sequence(), "9223372036854775810")
    }
    _ => fail("expected advanced native stream cursor")
  }
}
