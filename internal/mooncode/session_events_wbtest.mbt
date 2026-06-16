///|
test "mooncode appends command event to durable session events" {
  let session = append_command_event(
    { "id": "agent-demo" },
    action="run_tests",
    status="queued",
    detail="Run tests",
    created_at="2026-06-16T00:00:00Z",
    path="tools/demo/main.mbt",
    command_packet={ "command_id": "cmd-run-tests", "action": "run_tests" },
    event_id="cmd-run-tests",
  )
  let events = session_json_array_items(session, "mooncode_command_events")
  assert_eq(events.length(), 1)
  assert_eq(
    json_string(session, "updated_at", default=""),
    "2026-06-16T00:00:00Z",
  )
  assert_eq(json_string(events[0], "id", default=""), "cmd-run-tests")
  assert_eq(json_string(events[0], "lane", default=""), "test")
  assert_eq(json_string(events[0], "kind", default=""), "command.run_tests")
  assert_eq(json_string(events[0], "command", default=""), "run_tests")
}

///|
test "mooncode shapes transcript messages as reusable lane events" {
  let user_event = transcript_message_event(
    {
      "role": "user",
      "content": "Create a CLI tool",
      "created_at": "2026-06-16T00:00:00Z",
    },
    fallback_id="message-fallback",
  )
  assert_eq(json_string(user_event, "id", default=""), "message-fallback")
  assert_eq(json_string(user_event, "lane", default=""), "transcript")
  assert_eq(json_string(user_event, "kind", default=""), "user")
  assert_eq(json_string(user_event, "title", default=""), "User prompt")
  assert_eq(json_string(user_event, "detail", default=""), "Create a CLI tool")
  let tool_event = transcript_message_event(
    { "role": "tool", "id": "tool-message", "content": "done" },
    fallback_id="unused",
  )
  assert_eq(json_string(tool_event, "id", default=""), "tool-message")
  assert_eq(json_string(tool_event, "lane", default=""), "tool")
  assert_eq(json_string(tool_event, "title", default=""), "Tool result")
}
