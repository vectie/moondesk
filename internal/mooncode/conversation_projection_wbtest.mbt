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

///|
fn test_command_packet(command_id : String, client_turn_id : String) -> Json {
  {
    "command_id": command_id,
    "client_turn_id": client_turn_id,
    "protocol": "mooncode.v1",
    "kind": "mooncode.command",
    "action": "prompt",
  }
}

///|
fn test_prompt_event(
  command_id : String,
  client_turn_id : String,
  content : String,
  created_at : String,
) -> Json {
  event_record(
    id=command_id,
    lane="runtime",
    kind="command.prompt",
    title="Prompt: queued",
    status="queued",
    created_at~,
    detail=content,
    command="prompt",
    command_packet=test_command_packet(command_id, client_turn_id),
  )
}

///|
fn test_progress_event(
  id : String,
  command_id : String,
  title : String,
  detail : String,
  created_at : String,
  status? : String = "running",
) -> Json {
  event_record(
    id~,
    lane="runtime",
    kind="reasoning_delta",
    title~,
    status~,
    created_at~,
    detail~,
    command_packet=test_command_packet(command_id, ""),
  )
}

///|
fn test_assistant_delta_event(
  id : String,
  command_id : String,
  content : String,
  created_at : String,
) -> Json {
  event_record(
    id~,
    lane="transcript",
    kind="assistant_delta",
    title="MoonCode assistant update",
    status="running",
    created_at~,
    detail=content,
    command_packet=test_command_packet(command_id, ""),
  )
}

///|
fn test_assistant_final_event(
  id : String,
  command_id : String,
  content : String,
  created_at : String,
) -> Json {
  event_record(
    id~,
    lane="transcript",
    kind="assistant",
    title="Assistant response",
    status="done",
    created_at~,
    detail=content,
    command_packet=test_command_packet(command_id, ""),
  )
}

///|
fn test_finish_event(
  id : String,
  command_id : String,
  content : String,
  created_at : String,
) -> Json {
  event_record(
    id~,
    lane="review",
    kind="finish",
    title="MoonCode tool `finish` completed",
    status="done",
    created_at~,
    detail=content,
    command_packet=test_command_packet(command_id, ""),
  )
}

///|
fn test_failed_event(
  id : String,
  command_id : String,
  content : String,
  created_at : String,
) -> Json {
  event_record(
    id~,
    lane="runtime",
    kind="command_error",
    title="MoonCode command failed",
    status="failed",
    created_at~,
    detail=content,
    command_packet=test_command_packet(command_id, ""),
  )
}

///|
fn test_projection_turns(events : Array[Json]) -> Array[Json] {
  let projection = conversation_projection(
    {
      "id": "session-phase7",
      "workspace_id": "book-a",
      "workspace_name": "Book A",
    },
    events,
  )
  json_array_items(projection, "turns")
}

///|
test "mooncode conversation projection keeps three sequential replies stable" {
  let events : Array[Json] = [
    test_prompt_event("cmd-1", "client-1", "first", "001"),
    test_progress_event("think-1", "cmd-1", "Thinking", "Read files", "002"),
    test_finish_event("finish-1", "cmd-1", "first answer", "003"),
    test_prompt_event("cmd-2", "client-2", "second", "004"),
    test_assistant_delta_event("delta-2", "cmd-2", "second answer", "005"),
    event_record(
      id="done-2",
      lane="runtime",
      kind="runtime.turn_finished",
      title="Turn finished",
      status="done",
      created_at="006",
      detail="finished",
      command_packet=test_command_packet("cmd-2", ""),
    ),
    test_prompt_event("cmd-3", "client-3", "third", "007"),
    test_finish_event("finish-3", "cmd-3", "third answer", "008"),
  ]
  let first_projection = conversation_projection(
    {
      "id": "session-phase7",
      "workspace_id": "book-a",
      "workspace_name": "Book A",
    },
    events,
  )
  let replay_projection = conversation_projection(
    {
      "id": "session-phase7",
      "workspace_id": "book-a",
      "workspace_name": "Book A",
    },
    events,
  )
  assert_eq(first_projection.stringify(), replay_projection.stringify())
  let turns = json_array_items(first_projection, "turns")
  assert_eq(turns.length(), 3)
  assert_eq(json_string(turns[0], "client_turn_id", default=""), "client-1")
  assert_eq(json_string(turns[1], "client_turn_id", default=""), "client-2")
  assert_eq(json_string(turns[2], "client_turn_id", default=""), "client-3")
  assert_eq(
    json_string(
      runtime_json_object_field_or_empty(turns[0], "user"),
      "content",
      default="",
    ),
    "first",
  )
  assert_eq(
    json_string(
      runtime_json_object_field_or_empty(turns[1], "assistant"),
      "content",
      default="",
    ),
    "second answer",
  )
  assert_eq(
    json_string(
      runtime_json_object_field_or_empty(turns[2], "assistant"),
      "content",
      default="",
    ),
    "third answer",
  )
}

///|
test "mooncode conversation projection uses native finish tool call answer" {
  let events : Array[Json] = [
    test_prompt_event("cmd-loop", "client-loop", "create proof", "001"),
    test_progress_event(
      "think-loop", "cmd-loop", "MoonCode planner step 1", "Planner step 1 used explicit-tool-calls.",
      "002",
    ),
    event_record(
      id="finish-call",
      lane="review",
      kind="tool_call",
      title="Tool started: finish",
      status="running",
      created_at="003",
      detail="{\"answer\":\"Live MoonClaw runtime loop completed.\"}",
      command_packet=test_command_packet("cmd-loop", ""),
    ),
    test_finish_event("finish-result", "cmd-loop", "finished", "004"),
  ]
  let turns = test_projection_turns(events)
  assert_eq(turns.length(), 1)
  assert_eq(json_string(turns[0], "status", default=""), "done")
  let assistant = runtime_json_object_field_or_empty(turns[0], "assistant")
  assert_eq(
    json_string(assistant, "content", default=""),
    "Live MoonClaw runtime loop completed.",
  )
  assert_eq(json_string(assistant, "status", default=""), "done")
}

///|
test "mooncode conversation projection keeps control commands out of chat" {
  let events : Array[Json] = [
    test_prompt_event("cmd-1", "client-1", "first prompt", "001"),
    test_finish_event("finish-1", "cmd-1", "first reply", "002"),
    event_record(
      id="cmd-steer",
      lane="runtime",
      kind="command.steer",
      title="Steer: queued",
      status="queued",
      created_at="003",
      detail="keep the next turn focused",
      command="steer",
      command_packet={
        "command_id": "cmd-steer",
        "client_turn_id": "client-steer",
        "action": "steer",
      },
    ),
    event_record(
      id="steer-deferred",
      lane="runtime",
      kind=event_steer_deferred(),
      title="Steering deferred",
      status="queued",
      created_at="004",
      detail="keep the next turn focused",
      command_packet={
        "command_id": "cmd-steer",
        "client_turn_id": "client-steer",
        "action": "steer",
      },
    ),
    test_prompt_event("cmd-2", "client-2", "second prompt", "005"),
    event_record(
      id="steer-applied",
      lane="runtime",
      kind=event_steer_applied(),
      title="Steering applied",
      status="done",
      created_at="006",
      detail="keep the next turn focused",
      command_packet={
        "command_id": "cmd-steer",
        "client_turn_id": "client-steer",
        "action": "steer",
      },
    ),
    test_finish_event("finish-2", "cmd-2", "second reply", "007"),
    event_record(
      id="cmd-cancel",
      lane="runtime",
      kind="command.cancel",
      title="Cancel session: queued",
      status="queued",
      created_at="008",
      detail="cancel after work is done",
      command="cancel",
      command_packet={
        "command_id": "cmd-cancel",
        "client_turn_id": "client-cancel",
        "action": "cancel",
      },
    ),
    event_record(
      id="cancel-dropped",
      lane="runtime",
      kind=event_cancel_dropped(),
      title="Cancel dropped",
      status="done",
      created_at="009",
      detail="no active work",
      command_packet={
        "command_id": "cmd-cancel",
        "client_turn_id": "client-cancel",
        "action": "cancel",
      },
    ),
  ]
  let turns = test_projection_turns(events)
  assert_eq(turns.length(), 2)
  assert_eq(json_string(turns[0], "command_id", default=""), "cmd-1")
  assert_eq(json_string(turns[1], "command_id", default=""), "cmd-2")
  assert_eq(
    json_string(
      runtime_json_object_field_or_empty(turns[0], "user"),
      "content",
      default="",
    ),
    "first prompt",
  )
  assert_eq(
    json_string(
      runtime_json_object_field_or_empty(turns[1], "user"),
      "content",
      default="",
    ),
    "second prompt",
  )
  let rendered = Json::array(turns).stringify()
  assert_false(rendered.contains("keep the next turn focused"))
  assert_false(rendered.contains("cancel after work is done"))
}

///|
test "mooncode conversation projection buffers scoped progress before prompt" {
  let events : Array[Json] = [
    test_progress_event(
      "early-progress", "cmd-early", "Thinking", "Scoped progress arrived first.",
      "001",
    ),
    test_prompt_event("cmd-early", "client-early", "hello", "002"),
    test_finish_event("finish-early", "cmd-early", "reply", "003"),
  ]
  let turns = test_projection_turns(events)
  assert_eq(turns.length(), 1)
  let items = json_array_items(turns[0], "items")
  assert_eq(items.length(), 3)
  assert_eq(json_string(items[0], "role", default=""), "user")
  assert_eq(json_string(items[1], "role", default=""), "progress")
  assert_eq(
    json_string(items[1], "detail", default=""),
    "Scoped progress arrived first.",
  )
  assert_eq(json_string(items[2], "role", default=""), "assistant")
}

///|
test "mooncode conversation projection ignores unscoped work before first user" {
  let events : Array[Json] = [
    event_record(
      id="unscoped",
      lane="runtime",
      kind="reasoning_delta",
      title="Thinking",
      status="running",
      created_at="001",
      detail="No turn owns this yet.",
    ),
    test_prompt_event("cmd-1", "client-1", "hello", "002"),
    test_finish_event("finish-1", "cmd-1", "reply", "003"),
  ]
  let turns = test_projection_turns(events)
  assert_eq(turns.length(), 1)
  assert_eq(json_array_items(turns[0], "progress").length(), 0)
}

///|
test "mooncode conversation projection ignores unscoped work after user" {
  let events : Array[Json] = [
    test_prompt_event("cmd-1", "client-1", "hello", "001"),
    event_record(
      id="unscoped-progress",
      lane="runtime",
      kind="reasoning_delta",
      title="Thinking",
      status="running",
      created_at="002",
      detail="This event has no command owner.",
    ),
    event_record(
      id="unscoped-assistant",
      lane="transcript",
      kind="assistant",
      title="Assistant response",
      status="done",
      created_at="003",
      detail="This answer has no command owner.",
    ),
    test_finish_event("finish-1", "cmd-1", "reply", "004"),
  ]
  let turns = test_projection_turns(events)
  assert_eq(turns.length(), 1)
  assert_eq(json_array_items(turns[0], "progress").length(), 0)
  let assistant = runtime_json_object_field_or_empty(turns[0], "assistant")
  assert_eq(json_string(assistant, "content", default=""), "reply")
  let items = json_array_items(turns[0], "items")
  assert_eq(items.length(), 2)
  assert_eq(json_string(items[0], "role", default=""), "user")
  assert_eq(json_string(items[1], "role", default=""), "assistant")
}

///|
test "mooncode conversation projection ignores arbitrary scoped runtime updates" {
  let events : Array[Json] = [
    test_prompt_event("cmd-1", "client-1", "hello", "001"),
    event_record(
      id="catch-all-runtime-update",
      lane="runtime",
      kind="runtime_update",
      title="Runtime update",
      status="running",
      created_at="002",
      detail="MoonClaw native runtime bookkeeping should not become chat progress.",
      command_packet=test_command_packet("cmd-1", ""),
    ),
    test_finish_event("finish-1", "cmd-1", "reply", "003"),
  ]
  let turns = test_projection_turns(events)
  assert_eq(turns.length(), 1)
  assert_eq(json_array_items(turns[0], "progress").length(), 0)
  let items = json_array_items(turns[0], "items")
  assert_eq(items.length(), 2)
  assert_eq(json_string(items[0], "role", default=""), "user")
  assert_eq(json_string(items[1], "role", default=""), "assistant")
}

///|
test "mooncode conversation projection exposes friendly event-backed progress only" {
  let tool_event = event_record(
      id="tool-read",
      lane="tool",
      kind=event_tool_call(),
      title="Tool started: read",
      status="running",
      created_at="004",
      detail="{\"path\":\"src/main.mbt\"}",
      path="src/main.mbt",
      command_packet=test_command_packet("cmd-1", ""),
    )
    |> runtime_with_field("event", event_tool_call().to_json())
    |> runtime_with_field("tool_name", "read".to_json())
  let events : Array[Json] = [
    test_prompt_event("cmd-1", "client-1", "hello", "001"),
    event_record(
      id="turn-started",
      lane="runtime",
      kind="runtime.turn_started",
      title="MoonCode native runtime turn started",
      status="running",
      created_at="002",
      detail="MoonClaw claimed command cmd-1 for book-local native tool execution.",
      command_packet=test_command_packet("cmd-1", ""),
    ),
    event_record(
      id="planner",
      lane="runtime",
      kind="reasoning_delta",
      title="MoonCode planner step 1",
      status="running",
      created_at="003",
      detail="Planner step 1 used model-tool-calls and selected 1 tool call(s).",
      command_packet=test_command_packet("cmd-1", ""),
    ),
    tool_event,
    test_finish_event("finish-1", "cmd-1", "reply", "005"),
  ]
  let turns = test_projection_turns(events)
  assert_eq(turns.length(), 1)
  let progress = json_array_items(turns[0], "progress")
  assert_eq(progress.length(), 3)
  assert_eq(json_string(progress[0], "title", default=""), "Starting request")
  assert_eq(
    json_string(progress[0], "detail", default=""),
    "Started working on the request.",
  )
  assert_eq(json_string(progress[1], "title", default=""), "Thinking")
  assert_eq(
    json_string(progress[1], "detail", default=""),
    "Chose what to do next.",
  )
  assert_eq(json_string(progress[2], "title", default=""), "Checking context")
  assert_eq(
    json_string(progress[2], "detail", default=""),
    "Checking relevant project context.",
  )
  let serialized = turns[0].stringify()
  assert_false(serialized.contains("MoonClaw"))
  assert_false(serialized.contains("model-tool-calls"))
  assert_false(serialized.contains("{\"path\""))
}

///|
test "mooncode conversation projection uses final answer over assistant delta" {
  let events : Array[Json] = [
    test_prompt_event("cmd-final", "client-final", "question", "001"),
    test_assistant_delta_event(
      "delta-final", "cmd-final", "draft answer", "002",
    ),
    test_finish_event("finish-final", "cmd-final", "final answer", "003"),
  ]
  let turns = test_projection_turns(events)
  assert_eq(turns.length(), 1)
  let assistant = runtime_json_object_field_or_empty(turns[0], "assistant")
  assert_eq(json_string(assistant, "content", default=""), "final answer")
  assert_eq(json_string(assistant, "status", default=""), "done")
}

///|
test "mooncode conversation projection attaches unscoped runtime failure to active turn" {
  let events : Array[Json] = [
    test_prompt_event("cmd-failed", "client-failed", "hello", "001"),
    event_record(
      id="runtime-unavailable",
      lane="runtime",
      kind="runtime_unavailable",
      title="MoonCode runtime unavailable",
      status="failed",
      created_at="002",
      detail="MoonCode runtime is not reachable.",
    ),
  ]
  let turns = test_projection_turns(events)
  assert_eq(turns.length(), 1)
  assert_eq(json_string(turns[0], "status", default=""), "failed")
  let assistant = runtime_json_object_field_or_empty(turns[0], "assistant")
  assert_eq(json_string(assistant, "status", default=""), "failed")
  assert_eq(
    json_string(assistant, "content", default=""),
    "MoonCode runtime is not reachable.",
  )
}

///|
test "mooncode conversation projection attaches runtime failure to active turn" {
  let events : Array[Json] = [
    test_prompt_event("cmd-failed", "client-failed", "hello", "001"),
    test_failed_event(
      "failed", "cmd-failed", "MoonCode runtime is not reachable.", "002",
    ),
  ]
  let turns = test_projection_turns(events)
  assert_eq(turns.length(), 1)
  assert_eq(json_string(turns[0], "status", default=""), "failed")
  let assistant = runtime_json_object_field_or_empty(turns[0], "assistant")
  assert_eq(json_string(assistant, "status", default=""), "failed")
  assert_eq(
    json_string(assistant, "content", default=""),
    "MoonCode runtime is not reachable.",
  )
}

///|
test "mooncode conversation projection lets native final answer recover stale runtime failure" {
  let events : Array[Json] = [
    test_prompt_event("cmd-recovered", "client-recovered", "hello", "001"),
    event_record(
      id="runtime-unavailable",
      lane="runtime",
      kind="runtime_unavailable",
      title="MoonCode runtime unavailable",
      status="failed",
      created_at="002",
      detail="MoonCode runtime is not reachable.",
    ),
    test_assistant_final_event(
      "native-answer", "cmd-recovered", "Real native answer.", "003",
    ),
  ]
  let turns = test_projection_turns(events)
  assert_eq(turns.length(), 1)
  assert_eq(json_string(turns[0], "status", default=""), "done")
  let assistant = runtime_json_object_field_or_empty(turns[0], "assistant")
  assert_eq(json_string(assistant, "status", default=""), "done")
  assert_eq(
    json_string(assistant, "content", default=""),
    "Real native answer.",
  )
  let items = json_array_items(turns[0], "items")
  assert_eq(items.length(), 2)
  assert_eq(json_string(items[0], "role", default=""), "user")
  assert_eq(json_string(items[1], "role", default=""), "assistant")
}
