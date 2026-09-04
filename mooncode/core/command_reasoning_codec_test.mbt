///|
fn reasoning_command_payload() -> Json {
  {
    "action": "prompt",
    "client_turn_id": "client-reasoning",
    "message": "Inspect the parser",
  }
}

///|
fn reasoning_command_with(value : Json) -> Json {
  guard reasoning_command_payload() is Object(fields) else {
    return Json::empty_object()
  }
  let fields = fields.copy()
  fields["planner_reasoning_effort"] = value
  Json::object(fields)
}

///|
test "command reasoning effort defaults compatibly and round trips supported values" {
  guard @core.decode_mooncode_command(reasoning_command_payload())
    is Ok(automatic) else {
    fail("missing reasoning effort must remain compatible")
  }
  assert_eq(automatic.planner_reasoning_effort, "none")
  for value in ["none", "minimal", "low", "medium", "high", "xhigh"] {
    guard @core.decode_mooncode_command(reasoning_command_with(value.to_json()))
      is Ok(command) else {
      fail("supported reasoning effort must decode: \{value}")
    }
    assert_eq(command.planner_reasoning_effort, value)
    guard @core.encode_mooncode_command(command) is Ok(encoded) else {
      fail("supported reasoning effort must encode: \{value}")
    }
    assert_true(
      encoded.stringify().contains("\"planner_reasoning_effort\":\"\{value}\""),
    )
  }
}

///|
test "command reasoning effort rejects invalid names and primitive types" {
  assert_true(
    @core.decode_mooncode_command(reasoning_command_with("maximum".to_json()))
    is Err(_),
  )
  assert_true(
    @core.decode_mooncode_command(reasoning_command_with(true.to_json()))
    is Err(_),
  )
}
