///|
fn command_codec_public_payload(action : String) -> Json {
  {
    "action": action,
    "client_turn_id": " client-one ",
    "message": "  preserve content exactly  ",
    "model": "codex/gpt-5.4",
    "web_search": false,
  }
}

///|
fn command_codec_public_with(
  payload : Json,
  key : String,
  value : Json,
) -> Json {
  guard payload is Object(fields) else { return payload }
  let copy = fields.copy()
  copy[key] = value
  Json::object(copy)
}

///|
fn command_codec_public_scoped(action : String) -> Json {
  let base = command_codec_public_payload(action)
  if action == "approve_tool" || action == "reject_tool" {
    base
    |> command_codec_public_with("approval_id", "approval-one".to_json())
    |> command_codec_public_with(
      "target_command_id",
      "command-target".to_json(),
    )
    |> command_codec_public_with("tool_call_id", "call-one".to_json())
  } else if action == "apply_patch" ||
    action == "revert_patch" ||
    action == "cancel" {
    command_codec_public_with(
      base,
      "target_command_id",
      "command-target".to_json(),
    )
  } else {
    base
  }
}

///|
test "public command codec covers every supported command kind" {
  let actions = [
    "prompt", "steer", "run_tests", "run_build", "run_eval", "package", "commit",
    "accept", "reject", "approve_tool", "reject_tool", "apply_patch", "revert_patch",
    "cancel", "note",
  ]
  for action in actions {
    guard @core.decode_mooncode_command(command_codec_public_scoped(action))
      is Ok(command) else {
      fail("failed to decode \{action}")
    }
    guard @core.encode_mooncode_command(command) is Ok(encoded) else {
      fail("failed to encode \{action}")
    }
    assert_true(encoded.stringify().contains("\"action\":\"\{action}\""))
  }
}

///|
test "public command codec preserves opaque identity and content across round trip" {
  let payload = command_codec_public_payload("prompt")
  guard @core.decode_mooncode_command(payload) is Ok(first) else {
    fail("command must decode")
  }
  assert_eq(first.client_turn_id, " client-one ")
  assert_eq(first.message, "  preserve content exactly  ")
  guard @core.encode_mooncode_command(first) is Ok(encoded) else {
    fail("command must encode")
  }
  guard @core.decode_mooncode_command(encoded) is Ok(second) else {
    fail("encoded command must decode")
  }
  assert_eq(first, second)
}

///|
test "public command codec rejects malformed unsupported and invalid combinations" {
  assert_true(@core.decode_mooncode_command([]) is Err(_))
  assert_true(
    @core.decode_mooncode_command(command_codec_public_payload("unsupported"))
    is Err(_),
  )
  assert_true(
    @core.decode_mooncode_command(
      command_codec_public_with(
        command_codec_public_payload("prompt"),
        "action",
        true.to_json(),
      ),
    )
    is Err(_),
  )
  assert_true(
    @core.decode_mooncode_command(command_codec_public_payload("cancel"))
    is Err(_),
  )
  assert_true(
    @core.decode_mooncode_command(
      command_codec_public_with(
        command_codec_public_payload("prompt"),
        "target_command_id",
        "unexpected".to_json(),
      ),
    )
    is Err(_),
  )
  assert_true(
    @core.decode_mooncode_command(
      command_codec_public_with(
        command_codec_public_scoped("approve_tool"),
        "tool_call_id",
        "".to_json(),
      ),
    )
    is Err(_),
  )
}

///|
test "public command codec omits absent planner limit and preserves positive integers" {
  guard @core.decode_mooncode_command(command_codec_public_payload("prompt"))
    is Ok(absent) else {
    fail("absent limit must decode")
  }
  guard @core.encode_mooncode_command(absent) is Ok(absent_json) else {
    fail("absent limit must encode")
  }
  assert_false(absent_json.stringify().contains("planner_max_steps"))
  let explicit = command_codec_public_with(
    command_codec_public_payload("prompt"),
    "planner_max_steps",
    (13).to_json(),
  )
  guard @core.decode_mooncode_command(explicit) is Ok(command) else {
    fail("positive integer limit must decode")
  }
  assert_eq(command.planner_max_steps, Some(13))
  guard @core.encode_mooncode_command(command) is Ok(encoded) else {
    fail("positive integer limit must encode")
  }
  assert_true(encoded.stringify().contains("\"planner_max_steps\":13"))
  for value in [0.0, -1.0, 1.5] {
    assert_true(
      @core.decode_mooncode_command(
        command_codec_public_with(
          command_codec_public_payload("prompt"),
          "planner_max_steps",
          value.to_json(),
        ),
      )
      is Err(_),
    )
  }
}
