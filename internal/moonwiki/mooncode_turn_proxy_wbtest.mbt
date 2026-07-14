///|
fn canonical_test_record() -> Json {
  {
    "kind": "mooncode-session-record",
    "owner": "moonclaw",
    "session_id": "session-canonical",
    "book_root": "/tmp/moonsuite/books/code-lab",
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
    "{\"type\":\"meta\",\"next_since\":8}", "{\"type\":\"event\",\"sequence\":9}",
    "{\"type\":\"done\",\"sequence\":11}", "not-json",
  ].join("\n")
  assert_eq(mooncode_native_stream_latest_sequence(stream), 11)
}
