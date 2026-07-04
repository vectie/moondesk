///|
test "mooncode conversation projection groups a clean turn" {
  let events : Array[Json] = [
    event_record(
      id="cmd-1",
      lane="runtime",
      kind="command.prompt",
      title="Prompt: queued",
      status="queued",
      created_at="001",
      detail="Fix the UI ordering",
      command="prompt",
      command_packet={ "command_id": "cmd-1" },
    ),
    event_record(
      id="service-start",
      lane="runtime",
      kind="runtime.service_started",
      title="Runtime service started",
      status="running",
      created_at="002",
      detail="daemon started",
    ),
    event_record(
      id="thinking",
      lane="runtime",
      kind="reasoning_delta",
      title="MoonCode planner step 1",
      status="running",
      created_at="003",
      detail="Inspecting the renderer.",
      command_packet={ "command_id": "cmd-1" },
    ),
    event_record(
      id="finish",
      lane="review",
      kind="finish",
      title="MoonCode tool `finish` completed",
      status="done",
      created_at="004",
      detail="The UI ordering is fixed.",
      command_packet={ "command_id": "cmd-1" },
    ),
  ]
  let projection = conversation_projection(
    { "id": "session-a", "workspace_id": "book-a", "workspace_name": "Book A" },
    events,
  )
  assert_eq(
    json_string(projection, "kind", default=""),
    "mooncode-conversation",
  )
  assert_eq(summary_json_int(projection, "turn_count", default=0), 1)
  let turns = json_array_items(projection, "turns")
  assert_eq(turns.length(), 1)
  let turn = turns[0]
  assert_eq(json_string(turn, "command_id", default=""), "cmd-1")
  let items = json_array_items(turn, "items")
  assert_eq(items.length(), 3)
  assert_eq(json_string(items[0], "role", default=""), "user")
  assert_eq(json_string(items[0], "content", default=""), "Fix the UI ordering")
  assert_eq(json_string(items[1], "role", default=""), "progress")
  assert_eq(json_string(items[1], "title", default=""), "Thinking")
  assert_eq(json_string(items[2], "role", default=""), "assistant")
  assert_eq(
    json_string(items[2], "content", default=""),
    "The UI ordering is fixed.",
  )
}
