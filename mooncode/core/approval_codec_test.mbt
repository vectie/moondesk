///|
fn approval_evidence(
  state : String,
  approval_id? : String = "approval-one",
  target_command_id? : String = "command-one",
  tool_call_id? : String = "call-one",
) -> Json {
  {
    "kind": "approval",
    "state": state,
    "approval_id": approval_id,
    "target_command_id": target_command_id,
    "tool_call_id": tool_call_id,
    "arguments": "{\"path\":\"src/main.mbt\"}",
  }
}

///|
test "projected approval evidence decodes pending and settled real shapes" {
  for state in ["pending", "approved", "rejected"] {
    guard @core.decode_mooncode_approval(
        approval_evidence(state),
        "session-one",
        "command-one",
      )
      is Ok(approval) else {
      fail("approval evidence must decode")
    }
    assert_eq(approval.approval_id(), "approval-one")
    let expected = match state {
      "pending" => @core.MoonCodeApprovalState::Pending
      "approved" => @core.MoonCodeApprovalState::Approved
      _ => @core.MoonCodeApprovalState::Rejected
    }
    assert_eq(approval.state(), expected)
    assert_eq(approval.arguments(), "{\"path\":\"src/main.mbt\"}")
  }
}

///|
test "pending snapshot encodes accept and reject with immutable ownership" {
  guard @core.decode_mooncode_approval(
      approval_evidence("pending"),
      "session-one",
      "command-one",
    )
    is Ok(approval) else {
    fail("approval evidence must decode")
  }
  let decisions : Array[(@core.MoonCodeApprovalDecision, String)] = [
    (@core.MoonCodeApprovalDecision::Approve, "approve_tool"),
    (@core.MoonCodeApprovalDecision::Reject, "reject_tool"),
  ]
  for pair in decisions {
    let (decision, action) = pair
    guard approval.decision_wire(decision, "session-one") is Ok(wire) else {
      fail("current approval must encode")
    }
    assert_true(
      wire
      is {
        "action": String(actual),
        "approval_id": "approval-one",
        "target_command_id": "command-one",
        "tool_call_id": "call-one",
        ..
      } &&
      actual == action,
    )
    let text = wire.stringify()
    assert_false(text.contains("session_id"))
    assert_false(text.contains("revision"))
  }
}

///|
test "approval decoder distinguishes unsupported state and ownership mismatch" {
  assert_true(
    @core.decode_mooncode_approval(
      approval_evidence("expired"),
      "session-one",
      "command-one",
    )
    is Err(UnsupportedState("expired")),
  )
  assert_true(
    @core.decode_mooncode_approval([], "session-one", "command-one")
    is Err(Malformed(_)),
  )
  assert_true(
    @core.decode_mooncode_approval(
      approval_evidence("pending", approval_id=""),
      "session-one",
      "command-one",
    )
    is Err(Malformed(_)),
  )
  assert_true(
    @core.decode_mooncode_approval(
      approval_evidence("pending", target_command_id="command-two"),
      "session-one",
      "command-one",
    )
    is Err(Malformed(_)),
  )
}

///|
test "decision encoding rejects settled and wrong endpoint session" {
  guard @core.decode_mooncode_approval(
      approval_evidence("approved"),
      "session-one",
      "command-one",
    )
    is Ok(settled) else {
    fail("settled evidence must decode")
  }
  assert_true(settled.decision_wire(Approve, "session-one") is Err(Stale))
  guard @core.decode_mooncode_approval(
      approval_evidence("pending"),
      "session-one",
      "command-one",
    )
    is Ok(pending) else {
    fail("pending evidence must decode")
  }
  assert_true(
    pending.decision_wire(Approve, "session-two")
    is Err(WrongSessionOwnership(..)),
  )
}
