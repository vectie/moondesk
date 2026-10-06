///|
test "model workspace changes typed fingerprint while keeping execution root" {
  guard decode_command_submission({
      "action": "prompt",
      "client_turn_id": "fixture",
      "message": "inspect",
      "model": "moongate/exact",
      "model_workspace": "/owner",
    })
    is Ok(command) else {
    fail("decode")
  }
  let session : Json = { "id": "rooted", "workspace_root": "/external/source" }
  let body = native_command_body(
    session,
    command,
    "fixture",
    Json::empty_object(),
  )
  assert_eq(json_string(body, "model_workspace", default=""), "/owner")
  assert_eq(json_string(body, "book_root", default=""), "/external/source")
  assert_false(
    command_submission_fingerprint(command) ==
    command_submission_fingerprint({
      ..command,
      model_workspace: "/other-owner",
    }),
  )
}
