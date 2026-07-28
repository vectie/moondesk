///|
fn watch_test_snapshot(revision : Int, next_sequence : Json) -> Json {
  {
    "kind": "moonsuite-conversation-watch",
    "contract_id": "moonsuite-conversation-watch.v1",
    "session_id": "session-a",
    "revision": revision,
    "next_sequence": next_sequence,
    "changed": true,
    "heartbeat": false,
    "terminal": false,
    "retry_after_ms": 0,
    "snapshot": {
      "protocol": "mooncode.v1",
      "id": "session-a",
      "workspace_id": "book-demo",
      "workspace_name": "Demo Book",
      "cwd": "/tmp/demo",
      "mooncode_runtime_session_id": "runtime-a",
      "title": "Typed watch",
      "model": "codex/gpt-5",
      "status": "running",
      "queued_count": 2,
      "last_message": "Keep metadata",
      "archived": false,
      "mooncode_conversation": {
        "kind": "mooncode-conversation",
        "protocol": "mooncode.v1",
        "contract_id": "moonsuite-conversation.v2",
        "session_id": "session-a",
        "workspace_id": "book-demo",
        "workspace_name": "Demo Book",
        "turn_count": 0,
        "revision": revision,
        "last_sequence": 0,
        "source_event_count": 0,
        "turns": [],
      },
    },
  }
}

///|
test "typed watch codec preserves snapshot metadata conversation and duplicate" {
  let current = @core.mooncode_watch_origin_cursor()
  match
    @core.decode_mooncode_watch_result(
      watch_test_snapshot(4, "7"),
      current~,
      expected_session_id="session-a",
    ) {
    Snapshot(cursor~, session~, conversation~, terminal~) => {
      assert_eq(cursor.revision(), 4)
      assert_eq(cursor.sequence(), "7")
      assert_eq(session.title, "Typed watch")
      assert_eq(session.runtime_session_id, Some("runtime-a"))
      assert_eq(session.queued_count, 2)
      assert_eq(conversation.session_id, "session-a")
      assert_eq(conversation.revision, 4)
      assert_false(terminal)
    }
    _ => fail("expected typed snapshot")
  }
  let accepted = @core.mooncode_watch_cursor(4, "7")
  assert_true(
    @core.decode_mooncode_watch_result(
      watch_test_snapshot(4, "8"),
      current=accepted,
      expected_session_id="session-a",
    )
    is Duplicate(cursor~, session_id="session-a") &&
    cursor.revision() == 4 &&
    cursor.sequence() == "8",
  )
}

///|
test "typed watch codec distinguishes heartbeat rollback malformed and disconnected" {
  let current = @core.mooncode_watch_cursor(8, "5")
  let heartbeat : Json = Json::object(
    Map::from_array([
      ("kind", "moonsuite-conversation-watch"),
      ("contract_id", "moonsuite-conversation-watch.v1"),
      ("session_id", "session-a"),
      ("revision", 8),
      ("next_sequence", "6"),
      ("changed", false),
      ("heartbeat", true),
      ("terminal", false),
      ("retry_after_ms", 125),
    ]),
  )
  assert_true(
    @core.decode_mooncode_watch_result(
      heartbeat,
      current~,
      expected_session_id="session-a",
    )
    is Heartbeat(
      cursor~,
      session_id="session-a",
      retry_after_ms=125,
      terminal=false
    ) &&
    cursor.revision() == 8 &&
    cursor.sequence() == "6",
  )
  assert_true(
    @core.decode_mooncode_watch_result(
      watch_test_snapshot(4, "9223372036854775810"),
      current~,
      expected_session_id="session-a",
    )
    is Rollback(cursor~, session_id="session-a", received_revision=4) &&
    cursor.revision() == 8 &&
    cursor.sequence() == "9223372036854775810",
  )
  assert_true(
    @core.decode_mooncode_watch_text(
      "not-json",
      current~,
      expected_session_id="session-a",
    )
    is Malformed(cursor~, ..) &&
    cursor == current,
  )
  assert_true(
    @core.decode_mooncode_watch_result(
      watch_test_snapshot(9, "9"),
      current~,
      expected_session_id="session-other",
    )
    is Malformed(cursor~, ..) &&
    cursor == current,
  )
  assert_true(
    @core.decode_mooncode_watch_result(
      watch_test_snapshot(9, 9),
      current~,
      expected_session_id="session-a",
    )
    is Malformed(cursor~, ..) &&
    cursor == current,
  )
  assert_true(
    @core.mooncode_watch_disconnected(current~, reason="connection reset")
    is Disconnected(cursor~, reason="connection reset") &&
    cursor == current,
  )
}

///|
test "native stream cursor preserves a sequence larger than Int" {
  let current = @core.mooncode_watch_origin_cursor()
  let stream = [
    "{\"type\":\"meta\",\"next_since\":\"8\"}", "{\"type\":\"event\",\"sequence\":\"9\"}",
    "{\"type\":\"done\",\"sequence\":\"9223372036854775810\",\"next_since\":\"9223372036854775810\"}",
  ].join("\n")
  assert_true(
    @core.decode_mooncode_stream_cursor(stream, current~) is Advanced(cursor) &&
    cursor.sequence() == "9223372036854775810",
  )
}
