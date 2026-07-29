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
        "contract_id": "moonsuite-conversation.v3",
        "session_id": "session-a",
        "workspace_id": "book-demo",
        "workspace_name": "Demo Book",
        "turn_count": 0,
        "revision": revision.to_string(),
        "last_sequence": "0",
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
    @core.decode_mooncode_watch_text(
      watch_test_snapshot(4, 7).stringify(),
      current~,
      expected_session_id="session-a",
    ) {
    Snapshot(cursor~, session~, conversation~, terminal~) => {
      assert_eq(cursor.revision(), "4")
      assert_eq(cursor.sequence(), "7")
      assert_eq(session.title, "Typed watch")
      assert_eq(session.runtime_session_id, Some("runtime-a"))
      assert_eq(session.queued_count, 2)
      assert_eq(conversation.session_id, "session-a")
      assert_eq(conversation.revision, "4")
      assert_false(terminal)
    }
    _ => fail("expected typed snapshot")
  }
  let accepted = @core.mooncode_watch_cursor("4", "7")
  assert_true(
    @core.decode_mooncode_watch_text(
      watch_test_snapshot(4, 8).stringify(),
      current=accepted,
      expected_session_id="session-a",
    )
    is Duplicate(cursor~, session_id="session-a") &&
    cursor.revision() == "4" &&
    cursor.sequence() == "8",
  )
}

///|
test "typed watch codec distinguishes heartbeat rollback malformed and disconnected" {
  let current = @core.mooncode_watch_cursor("8", "5")
  let heartbeat : Json = Json::object(
    Map::from_array([
      ("kind", "moonsuite-conversation-watch"),
      ("contract_id", "moonsuite-conversation-watch.v1"),
      ("session_id", "session-a"),
      ("revision", 8),
      ("next_sequence", 6),
      ("changed", false),
      ("heartbeat", true),
      ("terminal", false),
      ("retry_after_ms", 125),
    ]),
  )
  assert_true(
    @core.decode_mooncode_watch_text(
      heartbeat.stringify(),
      current~,
      expected_session_id="session-a",
    )
    is Heartbeat(
      cursor~,
      session_id="session-a",
      retry_after_ms=125,
      terminal=false
    ) &&
    cursor.revision() == "8" &&
    cursor.sequence() == "6",
  )
  let rollback : Json = {
    "kind": "moonsuite-conversation-watch",
    "contract_id": "moonsuite-conversation-watch.v2",
    "session_id": "session-a",
    "revision": "4",
    "next_sequence": "9223372036854775810",
    "changed": true,
    "heartbeat": false,
    "terminal": false,
    "retry_after_ms": 0,
    "snapshot": Json::null(),
  }
  assert_true(
    @core.decode_mooncode_watch_text(
      rollback.stringify(),
      current~,
      expected_session_id="session-a",
    )
    is Rollback(cursor~, session_id="session-a", received_revision="4") &&
    cursor.revision() == "8" &&
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
    @core.decode_mooncode_watch_text(
      watch_test_snapshot(9, "9").stringify(),
      current~,
      expected_session_id="session-other",
    )
    is Malformed(cursor~, ..) &&
    cursor == current,
  )
  let numeric_v2_sequence : Json = {
    "kind": "moonsuite-conversation-watch",
    "contract_id": "moonsuite-conversation-watch.v2",
    "session_id": "session-a",
    "revision": "9",
    "next_sequence": 9,
    "changed": true,
    "heartbeat": false,
    "terminal": false,
    "retry_after_ms": 0,
    "snapshot": Json::null(),
  }
  assert_true(
    @core.decode_mooncode_watch_text(
      numeric_v2_sequence.stringify(),
      current~,
      expected_session_id="session-a",
    )
    is Malformed(cursor~, ..) &&
    cursor == current,
  )
  assert_true(
    @core.MoonCodeWatchResult::Disconnected(
      cursor=current,
      reason="connection reset",
    )
    is Disconnected(cursor~, reason="connection reset") &&
    cursor == current,
  )
}

///|
fn watch_v2_decimal_fixture(revision : Json, next_sequence : Json) -> Json {
  {
    "kind": "moonsuite-conversation-watch",
    "contract_id": "moonsuite-conversation-watch.v2",
    "session_id": "session-a",
    "revision": revision,
    "next_sequence": next_sequence,
    "changed": false,
    "heartbeat": true,
    "terminal": false,
    "retry_after_ms": 0,
    "snapshot": Json::null(),
  }
}

///|
test "watch v2 requires canonical exact decimal strings" {
  let current = @core.mooncode_watch_origin_cursor()
  for invalid in ["01", "+1", "-1", " 1", "1 "] {
    assert_true(
      @core.decode_mooncode_watch_text(
        watch_v2_decimal_fixture(invalid.to_json(), "1".to_json()).stringify(),
        current~,
      )
      is Malformed(_),
    )
    assert_true(
      @core.decode_mooncode_watch_text(
        watch_v2_decimal_fixture("1".to_json(), invalid.to_json()).stringify(),
        current~,
      )
      is Malformed(_),
    )
  }
  for invalid in ([1, 1.5] : Array[Json]) {
    assert_true(
      @core.decode_mooncode_watch_text(
        watch_v2_decimal_fixture(invalid, "1".to_json()).stringify(),
        current~,
      )
      is Malformed(_),
    )
    assert_true(
      @core.decode_mooncode_watch_text(
        watch_v2_decimal_fixture("1".to_json(), invalid).stringify(),
        current~,
      )
      is Malformed(_),
    )
  }
}

///|
test "watch v2 compares arbitrary decimal magnitude exactly" {
  let current = @core.mooncode_watch_cursor(
    "100000000000000000000000000000000000000", "99999999999999999999999999999999999999",
  )
  assert_true(
    @core.decode_mooncode_watch_text(
      watch_v2_decimal_fixture(
        "99999999999999999999999999999999999999".to_json(),
        "100000000000000000000000000000000000001".to_json(),
      ).stringify(),
      current~,
    )
    is Rollback(cursor~, ..) &&
    cursor.revision() == "100000000000000000000000000000000000000" &&
    cursor.sequence() == "100000000000000000000000000000000000001",
  )
}

///|
test "typed watch encoder emits canonical v2 snapshot heartbeat and rejects local states" {
  let snapshot_json = watch_test_snapshot(4, "7")
  guard snapshot_json is { "snapshot": Object(snapshot_fields), .. } else {
    fail("expected snapshot fixture")
  }
  let provider_metadata : Json = { "region": "test-zone" }
  snapshot_fields["provider_metadata"] = provider_metadata
  let snapshot = snapshot_fields.to_json()
  guard @core.decode_mooncode_selected_session(snapshot) is Ok(session) else {
    fail("expected typed session")
  }
  guard snapshot is { "mooncode_conversation": conversation_json, .. } &&
    @core.decode_mooncode_conversation(conversation_json) is Ok(conversation) else {
    fail("expected typed conversation")
  }
  let cursor = @core.mooncode_watch_cursor("4", "7")
  guard @core.encode_mooncode_watch_result(
      Snapshot(cursor~, session~, conversation~, terminal=false),
    )
    is Ok(encoded_snapshot) else {
    fail("expected encoded snapshot")
  }
  assert_true(
    encoded_snapshot
    is {
      "kind": "moonsuite-conversation-watch",
      "contract_id": "moonsuite-conversation-watch.v2",
      "session_id": "session-a",
      "revision": "4",
      "next_sequence": "7",
      "changed": true,
      "heartbeat": false,
      "terminal": false,
      "retry_after_ms": 0,
      "snapshot": {
        "id": "session-a",
        "mooncode_runtime_session_id": "runtime-a",
        "provider_metadata": { "region": "test-zone" },
        "mooncode_conversation": encoded_conversation,
        ..
      },
      ..
    } &&
    encoded_conversation == @core.encode_mooncode_conversation(conversation),
  )
  guard @core.encode_mooncode_watch_result(
      Heartbeat(
        cursor~,
        session_id="session-a",
        retry_after_ms=-10,
        terminal=false,
      ),
    )
    is Ok(encoded_heartbeat) else {
    fail("expected encoded heartbeat")
  }
  assert_true(
    encoded_heartbeat
    is {
      "kind": "moonsuite-conversation-watch",
      "contract_id": "moonsuite-conversation-watch.v2",
      "session_id": "session-a",
      "revision": "4",
      "next_sequence": "7",
      "changed": false,
      "heartbeat": true,
      "terminal": false,
      "retry_after_ms": 0,
      "snapshot": Null,
      ..
    },
  )
  let local_states : Array[@core.MoonCodeWatchResult] = [
    Duplicate(cursor~, session_id="session-a"),
    Rollback(cursor~, session_id="session-a", received_revision="3"),
    Disconnected(cursor~, reason="offline"),
    Malformed(cursor~, reason="bad"),
  ]
  for state in local_states {
    assert_true(@core.encode_mooncode_watch_result(state) is Err(Malformed(_)))
  }
}

///|
test "native stream cursor preserves a sequence larger than Int" {
  let current = @core.mooncode_watch_origin_cursor()
  let stream = [
    "{\"type\":\"meta\",\"next_since\":\"8\"}", "{\"type\":\"event\",\"sequence\":\"9\"}",
    "{\"type\":\"done\",\"sequence\":\"9223372036854775810\",\"next_since\":\"9223372036854775810\"}",
  ].join("\n")
  assert_true(
    @core.decode_mooncode_stream_cursor(stream, current~) is Ok(cursor) &&
    cursor.sequence() == "9223372036854775810",
  )
}
