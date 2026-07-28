///|
test "canonical session response selects its owning turn" {
  let conversation : Json = {
    "kind": @mooncode.conversation_kind(),
    "protocol": @mooncode.protocol_version(),
    "contract_id": @mooncode.conversation_contract_id(),
    "session_id": "session-a",
    "revision": 4,
    "last_sequence": 4,
    "turns": [
      {
        "kind": @mooncode_core.conversation_turn_kind(),
        "turn_id": "turn-1",
        "command_id": "command-1",
        "client_turn_id": "client-1",
        "ordinal": 0,
        "status": "done",
        "user": null,
        "work": {},
        "assistant": null,
      },
      {
        "kind": @mooncode_core.conversation_turn_kind(),
        "turn_id": "turn-2",
        "command_id": "command-2",
        "client_turn_id": "client-2",
        "ordinal": 1,
        "status": "running",
        "user": null,
        "work": {},
        "assistant": null,
      },
    ],
  }
  let response = compact_mooncode_session_command_response(
    "/tmp/book",
    {
      "id": "session-a",
      "workspace_root": "/tmp/book",
      "mooncode_conversation": conversation,
    },
    { "command_id": "command-2", "client_turn_id": "client-2" },
  )
  assert_eq(json_string(response, "turn_id", default=""), "turn-2")
  assert_eq(json_int(response, "canonical_revision", default=0), 4)
  assert_false(json_bool(response, "archived", default=true))
  assert_eq(
    json_string(
      json_object_field_or_empty(response, "mooncode_turn"),
      "status",
      default="",
    ),
    "running",
  )
}

///|
test "equal canonical revision returns metadata-only unchanged response" {
  let response = compact_mooncode_session_revision_response(
    "/tmp/book",
    {
      "id": "session-a",
      "workspace_root": "/tmp/book",
      "mooncode_conversation": {
        "kind": @mooncode.conversation_kind(),
        "protocol": @mooncode.protocol_version(),
        "contract_id": @mooncode.conversation_contract_id(),
        "session_id": "session-a",
        "revision": 7,
        "last_sequence": 7,
        "turns": [],
      },
    },
    Json::object({}),
    7,
  )
  assert_true(json_bool(response, "canonical_unchanged", default=false))
  assert_true(
    json_object_field(response, "mooncode_conversation") is Some(Null),
  )
  assert_true(json_object_field(response, "mooncode_turn") is Some(Null))
}

///|
test "chat and compact formats bypass malformed selected-session validation" {
  assert_true(mooncode_session_uses_compact_response("chat"))
  assert_true(mooncode_session_uses_compact_response("compact"))
  assert_false(mooncode_session_uses_compact_response("full"))
  assert_true(@mooncode.selected_session_response({ "status": 1 }) is Err(_))
}
