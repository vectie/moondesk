///|
test "model workspace typed command preserves exact owner root and legacy omission" {
  let legacy : Json = {
    "action": "prompt",
    "client_turn_id": "fixture",
    "message": "inspect",
    "model": "moongate/exact",
  }
  guard @core.decode_mooncode_command(legacy) is Ok(old) else {
    fail("legacy decode")
  }
  assert_eq(old.model_workspace, "")
  guard @core.encode_mooncode_command(old) is Ok(Object(old_fields)) else {
    fail("legacy encode")
  }
  assert_true(old_fields.get("model_workspace") is None)
  let rooted = { ..old, model_workspace: "/owner", }
  guard @core.encode_mooncode_command(rooted) is Ok(payload) else {
    fail("root encode")
  }
  guard @core.decode_mooncode_command(payload) is Ok(decoded) else {
    fail("root decode")
  }
  assert_eq(decoded, rooted)
  assert_true(
    @core.decode_mooncode_command({ "action": "prompt", "model_workspace": 1 })
    is Err(_),
  )
}
