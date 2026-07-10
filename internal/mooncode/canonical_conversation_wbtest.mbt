///|
test "canonical conversation accepts only MoonClaw v2 payload for the session" {
  let supplied : Json = {
    "kind": conversation_kind(),
    "protocol": protocol_version(),
    "contract_id": conversation_contract_id(),
    "session_id": "session-a",
    "revision": 7,
    "last_sequence": 7,
    "turn_count": 1,
    "turns": [{ "turn_id": "turn-a" }],
  }
  let canonical = session_canonical_conversation({
    "id": "session-a",
    "mooncode_conversation": supplied,
  })
  assert_eq(summary_json_int(canonical, "revision", default=0), 7)
  assert_eq(json_array_items(canonical, "turns").length(), 1)
}

///|
test "canonical conversation rejects stale or cross-session payloads" {
  let stale : Json = {
    "kind": conversation_kind(),
    "protocol": protocol_version(),
    "contract_id": "moonsuite-conversation.v1",
    "session_id": "session-b",
    "revision": 9,
    "last_sequence": 9,
    "turn_count": 1,
    "turns": [{ "turn_id": "stale-turn" }],
  }
  let canonical = session_canonical_conversation({
    "id": "session-a",
    "workspace_id": "book",
    "mooncode_conversation": stale,
  })
  assert_eq(
    json_string(canonical, "contract_id", default=""),
    conversation_contract_id(),
  )
  assert_eq(json_string(canonical, "session_id", default=""), "session-a")
  assert_eq(json_array_items(canonical, "turns").length(), 0)
}
