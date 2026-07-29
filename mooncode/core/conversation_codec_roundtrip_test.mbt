///|
test "canonical conversation codec round trips an explicit null message slot" {
  let payload : Json = {
    "kind": "mooncode-conversation",
    "protocol": "mooncode.v1",
    "contract_id": "moonsuite-conversation.v3",
    "session_id": "session-a",
    "revision": "1",
    "last_sequence": "1",
    "turns": [
      {
        "kind": "mooncode-conversation-turn",
        "turn_id": "turn-a",
        "client_turn_id": "client-a",
        "command_id": "command-a",
        "ordinal": 0,
        "status": "running",
        "user": null,
        "work": {},
        "assistant": null,
      },
    ],
  }
  guard @core.decode_mooncode_conversation(payload) is Ok(conversation) else {
    fail("expected supported conversation")
  }
  assert_true(
    @core.decode_mooncode_conversation(
      @core.encode_mooncode_conversation(conversation),
    )
    is Ok(round_trip) &&
    round_trip.turns[0].assistant is None,
  )
}
