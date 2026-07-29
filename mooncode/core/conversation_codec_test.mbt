///|
fn conversation_fixture() -> Json {
  {
    "kind": "mooncode-conversation",
    "protocol": "mooncode.v1",
    "contract_id": "moonsuite-conversation.v3",
    "session_id": "session-a",
    "revision": "4",
    "last_sequence": "4",
    "turns": [
      {
        "kind": "mooncode-conversation-turn",
        "turn_id": "turn-a",
        "client_turn_id": "client-a",
        "command_id": "command-a",
        "ordinal": 1,
        "status": "done",
        "user": {
          "item_id": "turn-a:user",
          "role": "user",
          "content": "Fix it",
          "status": "done",
          "future_message": true,
        },
        "work": {
          "steps": [
            {
              "kind": "tool",
              "evidence": {
                "kind": "approval",
                "state": "pending",
                "approval_id": "approval-a",
                "target_command_id": "command-a",
                "tool_call_id": "call-a",
                "arguments": "{\"path\":\"src/main.mbt\"}",
              },
            },
            {
              "kind": "tool",
              "evidence": { "kind": "result", "content": "ignored" },
            },
          ],
        },
        "assistant": {
          "item_id": "turn-a:assistant",
          "role": "assistant",
          "content": "Fixed",
          "status": "done",
        },
        "future_turn": 1,
      },
    ],
    "future_conversation": { "enabled": true },
  }
}

///|
test "canonical conversation codec decodes visible turns and messages" {
  guard @core.decode_mooncode_conversation(conversation_fixture())
    is Supported(conversation) else {
    fail("expected supported conversation")
  }
  assert_eq(conversation.session_id, "session-a")
  assert_eq(conversation.revision, "4")
  assert_eq(conversation.turns.length(), 1)
  let turn = conversation.turns[0]
  assert_eq(turn.turn_id, "turn-a")
  assert_true(turn.user is Some(message) && message.content == "Fix it")
  assert_true(turn.assistant is Some(message) && message.content == "Fixed")
  assert_eq(turn.approvals.length(), 1)
  let approval = turn.approvals[0]
  assert_eq(approval.approval_id(), "approval-a")
  assert_eq(approval.state(), @core.MoonCodeApprovalState::Pending)
  assert_eq(approval.arguments(), "{\"path\":\"src/main.mbt\"}")
}

///|
test "canonical conversation codec distinguishes absence and malformed fields" {
  assert_true(@core.decode_mooncode_conversation(Json::null()) is Absent)
  assert_true(
    @core.decode_mooncode_conversation({
      "kind": "mooncode-conversation",
      "protocol": "mooncode.v1",
      "contract_id": "moonsuite-conversation.v3",
      "session_id": "session-a",
      "revision": "four",
      "last_sequence": "4",
      "turns": [],
    })
    is Malformed(_),
  )
  assert_true(
    @core.decode_mooncode_conversation({
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
          "status": "done",
          "user": { "item_id": "user-a", "status": "done", "content": 1 },
          "work": {},
          "assistant": null,
        },
      ],
    })
    is Malformed(_),
  )
}

///|
test "canonical conversation codec rejects malformed, unsupported, and wrong-owner approvals" {
  let cases : Array[Json] = [
    {
      "kind": "approval",
      "state": "pending",
      "approval_id": "",
      "target_command_id": "command-a",
      "tool_call_id": "call-a",
      "arguments": "{}",
    },
    {
      "kind": "approval",
      "state": "expired",
      "approval_id": "approval-a",
      "target_command_id": "command-a",
      "tool_call_id": "call-a",
      "arguments": "{}",
    },
    {
      "kind": "approval",
      "state": "pending",
      "approval_id": "approval-a",
      "target_command_id": "command-b",
      "tool_call_id": "call-a",
      "arguments": "{}",
    },
  ]
  for evidence in cases {
    let fixture = conversation_fixture()
    guard fixture is Object(fields) &&
      fields.get("turns") is Some(Array(turns)) &&
      turns[0] is Object(turn_fields) else {
      fail("fixture shape changed")
    }
    let next_turn = turn_fields.copy()
    next_turn["work"] = { "steps": [{ "evidence": evidence }] }
    let next_fields = fields.copy()
    next_fields["turns"] = [Json::object(next_turn)].to_json()
    assert_true(
      @core.decode_mooncode_conversation(Json::object(next_fields))
      is Malformed(_),
    )
  }
}

///|
test "canonical conversation codec reports unsupported protocol and contract" {
  let unsupported_protocol : Json = match conversation_fixture() {
    Object(fields) => {
      let next = fields.copy()
      next["protocol"] = "mooncode.v7".to_json()
      Json::object(next)
    }
    _ => Json::null()
  }
  assert_true(
    @core.decode_mooncode_conversation(unsupported_protocol)
    is UnsupportedProtocol("mooncode.v7"),
  )
  let unsupported_contract : Json = match conversation_fixture() {
    Object(fields) => {
      let next = fields.copy()
      next["contract_id"] = "moonsuite-conversation.v9".to_json()
      Json::object(next)
    }
    _ => Json::null()
  }
  assert_true(
    @core.decode_mooncode_conversation(unsupported_contract)
    is UnsupportedContract("moonsuite-conversation.v9"),
  )
}

///|
test "canonical conversation codec preserves unknown optional fields" {
  guard @core.decode_mooncode_conversation(conversation_fixture())
    is Supported(conversation) else {
    fail("expected supported conversation")
  }
  guard @core.encode_mooncode_conversation(conversation)
    is {
      "future_conversation": { "enabled": true },
      "turns": [
        { "future_turn": 1, "user": { "future_message": true, .. }, .. },
      ],
      ..
    } else {
    fail("unknown optional fields were not preserved")
  }
}

///|
test "canonical conversation codec reports stale revisions" {
  assert_true(
    @core.decode_mooncode_conversation(
      conversation_fixture(),
      current_revision="5",
    )
    is Stale(revision="4", current_revision="5"),
  )
}

///|
test "conversation v3 requires canonical exact decimal strings" {
  for invalid in ["01", "+1", "-1", " 1", "1 "] {
    let payload = conversation_fixture()
    guard payload is Object(fields) else { fail("fixture") }
    fields["revision"] = invalid.to_json()
    assert_true(@core.decode_mooncode_conversation(payload) is Malformed(_))
    fields["revision"] = "4".to_json()
    fields["last_sequence"] = invalid.to_json()
    assert_true(@core.decode_mooncode_conversation(payload) is Malformed(_))
  }
  for invalid in ([1, 1.5] : Array[Json]) {
    let payload = conversation_fixture()
    guard payload is Object(fields) else { fail("fixture") }
    fields["revision"] = invalid
    assert_true(@core.decode_mooncode_conversation(payload) is Malformed(_))
    fields["revision"] = "4".to_json()
    fields["last_sequence"] = invalid
    assert_true(@core.decode_mooncode_conversation(payload) is Malformed(_))
  }
}

///|
test "conversation v3 compares arbitrary decimal magnitude exactly" {
  let payload = conversation_fixture()
  guard payload is Object(fields) else { fail("fixture") }
  fields["revision"] = "100000000000000000000000000000000000000".to_json()
  fields["last_sequence"] = "100000000000000000000000000000000000000".to_json()
  assert_true(
    @core.decode_mooncode_conversation(
      payload,
      current_revision="99999999999999999999999999999999999999",
    )
    is Supported(_),
  )
  assert_true(
    @core.decode_mooncode_conversation(
      payload,
      current_revision="100000000000000000000000000000000000001",
    )
    is Stale(_),
  )
}

///|
test "canonical conversation codec rejects missing required known fields" {
  assert_true(
    @core.decode_mooncode_conversation({
      "kind": "mooncode-conversation",
      "protocol": "mooncode.v1",
      "contract_id": "moonsuite-conversation.v3",
      "session_id": "session-a",
      "revision": "1",
      "turns": [],
    })
    is Malformed(_),
  )
  assert_true(
    @core.decode_mooncode_conversation({
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
          "status": "done",
          "user": null,
          "work": {},
          "assistant": null,
        },
      ],
    })
    is Malformed(_),
  )
}
