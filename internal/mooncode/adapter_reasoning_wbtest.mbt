///|
test "typed adapter forwards reasoning effort to MoonClaw planner payload" {
  let session : Json = {
    "id": "session-reasoning",
    "workspace_id": "book-one",
    "workspace_name": "Book One",
    "workspace_root": "/tmp/book-one",
  }
  guard decode_command_submission({
      "action": "prompt",
      "client_turn_id": "client-reasoning",
      "message": "Inspect the parser",
      "planner_reasoning_effort": "xhigh",
    })
    is Ok(command) else {
    fail("reasoning command must decode")
  }
  let body = native_command_body(
    session,
    command,
    "2026-08-29T00:00:00Z",
    Json::empty_object(),
  )
  assert_eq(
    json_string(
      json_object_field_or_empty(body, "payload"),
      "planner_reasoning_effort",
      default="",
    ),
    "xhigh",
  )
}
