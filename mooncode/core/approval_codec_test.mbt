///|
fn approval_conversation(state : String) -> Json {
  {
    "kind": "mooncode-conversation",
    "protocol": "mooncode.v1",
    "contract_id": "moonsuite-conversation.v3",
    "session_id": "session-one",
    "revision": "1",
    "last_sequence": "1",
    "turns": [
      {
        "kind": "mooncode-conversation-turn",
        "turn_id": "turn-one",
        "client_turn_id": "client-one",
        "command_id": "command-one",
        "ordinal": 1,
        "status": "running",
        "user": null,
        "work": {
          "steps": [
            {
              "kind": "tool",
              "evidence": {
                "kind": "approval",
                "state": state,
                "approval_id": "approval-one",
                "target_command_id": "command-one",
                "tool_call_id": "call-one",
                "arguments": "{\"path\":\"src/main.mbt\"}",
              },
            },
          ],
        },
        "assistant": null,
      },
    ],
  }
}

///|
test "approval evidence decodes retained aggregate variants" {
  for state in ["pending", "approved", "rejected"] {
    guard decode_mooncode_conversation(approval_conversation(state))
      is Ok(conversation) else {
      fail("approval evidence must decode")
    }
    let approval = conversation.turns[0].approvals[0]
    assert_true(
      match state {
        "pending" => approval is MoonCodeApproval::Pending(..)
        "approved" => approval is MoonCodeApproval::Approved(..)
        _ => approval is MoonCodeApproval::Rejected(..)
      },
    )
  }
}

///|
test "approval decoder rejects unsupported state" {
  assert_true(
    decode_mooncode_conversation(approval_conversation("expired"))
    is Err(Malformed("unsupported approval state: expired")),
  )
}
