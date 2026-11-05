///|
test "native watch metadata adaptation preserves exact cursor and canonical conversation" {
  let record = canonical_test_record()
  let conversation = json_object_field_or_empty(record, "mooncode_conversation")
    |> mooncode_session_with_field("contract_id", "moonsuite-conversation.v3")
    |> mooncode_session_with_field("protocol", "mooncode.v1")
    |> mooncode_session_with_field("revision", "9223372036854775810")
    |> mooncode_session_with_field("last_sequence", "9223372036854775810")
    |> mooncode_session_with_field("source_event_count", ToJson::to_json(3))
    |> mooncode_session_with_field("turns", [
      {
        "kind": "mooncode-conversation-turn",
        "turn_id": "turn-1",
        "client_turn_id": "client-1",
        "command_id": "command-1",
        "status": "running",
        "ordinal": 0,
        "user": {
          "role": "user",
          "content": "Fix the parser",
          "item_id": "turn-1:user",
          "status": "done",
        },
        "work": {},
        "assistant": {},
      },
    ])
  let record = mooncode_session_with_field(
    record, "mooncode_conversation", conversation,
  )
  let cursor = @mooncode_core.mooncode_watch_cursor(
    "9223372036854775810", "9223372036854775810",
  )
  let native = @mooncode_core.conversation_watch_response_for_cursor(
    session_id="session-canonical",
    cursor~,
    changed=true,
    heartbeat=false,
    terminal=false,
    retry_after_ms=100,
    snapshot=record,
  )
  guard mooncode_watch_desktop_response(
      "/tmp/moonsuite", "session-canonical", native,
    )
    is Ok(projected) else {
    fail("native watch adaptation failed")
  }
  assert_eq(json_string(projected, "revision", default=""), cursor.revision())
  match
    @mooncode_core.decode_mooncode_watch_text(
      projected.stringify(),
      current=@mooncode_core.mooncode_watch_origin_cursor(),
      expected_session_id="session-canonical",
    ) {
    Snapshot(..) => ()
    other => fail("watch did not decode: \{Repr(other)}")
  }
  let heartbeat = @mooncode_core.conversation_watch_response_for_cursor(
    session_id="session-canonical",
    cursor~,
    changed=false,
    heartbeat=true,
    terminal=false,
    retry_after_ms=100,
    snapshot=Json::null(),
  )
  assert_eq(
    mooncode_watch_desktop_response(
      "/tmp/moonsuite", "session-canonical", heartbeat,
    ),
    Ok(heartbeat),
  )
  assert_true(
    mooncode_watch_desktop_response("/tmp/moonsuite", "other-session", native)
    is Err(_),
  )
}
