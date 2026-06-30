///|
test "mooncode runtime control routes steer and cancel to active turn" {
  let commands : Array[Json] = [
    {
      "command_id": "cmd-active",
      "action": "prompt",
      "control": "prompt",
      "message": "build a tool",
    },
    {
      "command_id": "cmd-steer",
      "action": "steer",
      "control": "steer",
      "message": "focus tests",
    },
    { "command_id": "cmd-cancel", "action": "cancel", "control": "cancel" },
  ]
  let lifecycle : Json = {
    "commands": [
      { "command_id": "cmd-active", "action": "prompt", "status": "running" },
      { "command_id": "cmd-steer", "action": "steer", "status": "pending" },
      { "command_id": "cmd-cancel", "action": "cancel", "status": "pending" },
    ],
  }
  let projection = runtime_control_projection("s1", commands, lifecycle)
  assert_eq(
    runtime_control_json_string(projection, "active_turn_id", default=""),
    "cmd-active",
  )
  let decisions = runtime_control_json_array_items(projection, "decisions")
  assert_eq(decisions.length(), 3)
  assert_eq(
    runtime_control_json_string(decisions[1], "effect", default=""),
    "deliver-steer",
  )
  assert_eq(
    runtime_control_json_string(decisions[1], "target_command_id", default=""),
    "cmd-active",
  )
  assert_eq(
    runtime_control_json_string(decisions[2], "effect", default=""),
    "cancel-active",
  )
}

///|
test "mooncode runtime control response owns lifecycle assembly" {
  let command_log : Array[Json] = [
    {
      "command_id": "cmd-done",
      "action": "prompt",
      "control": "prompt",
      "message": "already built",
    },
    {
      "command_id": "cmd-next",
      "action": "prompt",
      "control": "prompt",
      "message": "build next",
    },
    {
      "command_id": "cmd-steer",
      "action": "steer",
      "control": "steer",
      "message": "focus tests",
    },
  ]
  let runtime_commands : Array[Json] = [
    {
      "protocol": protocol_version(),
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-done",
      "action": "prompt",
      "control": "prompt",
      "code_command": "prompt",
      "mooncode_command": { "command": "prompt", "text": "done" },
    },
    {
      "protocol": protocol_version(),
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-next",
      "action": "prompt",
      "control": "prompt",
      "code_command": "prompt",
      "mooncode_command": { "command": "prompt", "text": "next" },
    },
    {
      "protocol": protocol_version(),
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-steer",
      "action": "steer",
      "control": "steer",
      "code_command": "steer",
      "mooncode_command": { "command": "steer", "text": "tests" },
    },
  ]
  let receipts : Array[Json] = [
    {
      "protocol": protocol_version(),
      "kind": kind_runtime_receipt(),
      "command_id": "cmd-done",
      "status": "runtime-completed",
      "created_at": "2026-06-15T00:00:00Z",
    },
  ]
  let response = runtime_control_response(
    "s1",
    command_log,
    runtime_commands,
    receipts,
    [],
    lease_now="2026-06-15T00:00:00Z",
  )
  assert_eq(
    runtime_control_json_string(response, "kind", default=""),
    "mooncode-runtime-control-state",
  )
  let decisions = runtime_control_json_array_items(response, "decisions")
  assert_eq(decisions.length(), 3)
  assert_eq(
    runtime_control_json_string(decisions[0], "effect", default=""),
    "already-completed",
  )
  assert_eq(
    runtime_control_json_string(decisions[1], "effect", default=""),
    "start-turn",
  )
  assert_eq(
    runtime_control_json_string(decisions[2], "effect", default=""),
    "queue-steer",
  )
  assert_eq(
    runtime_control_json_string(decisions[2], "target_command_id", default=""),
    "cmd-next",
  )
}

///|
test "mooncode runtime control starts first pending turn and queues controls" {
  let commands : Array[Json] = [
    {
      "command_id": "cmd-prompt",
      "action": "prompt",
      "control": "prompt",
      "message": "make miniapp",
    },
    {
      "command_id": "cmd-steer",
      "action": "steer",
      "control": "steer",
      "message": "keep it small",
    },
    { "command_id": "cmd-cancel", "action": "cancel", "control": "cancel" },
  ]
  let lifecycle : Json = {
    "commands": [
      { "command_id": "cmd-prompt", "action": "prompt", "status": "pending" },
      { "command_id": "cmd-steer", "action": "steer", "status": "pending" },
      { "command_id": "cmd-cancel", "action": "cancel", "status": "pending" },
    ],
  }
  let projection = runtime_control_projection("s1", commands, lifecycle)
  let decisions = runtime_control_json_array_items(projection, "decisions")
  assert_eq(
    runtime_control_json_string(decisions[0], "effect", default=""),
    "start-turn",
  )
  assert_eq(
    runtime_control_json_string(decisions[1], "effect", default=""),
    "queue-steer",
  )
  assert_eq(
    runtime_control_json_string(decisions[1], "target_command_id", default=""),
    "cmd-prompt",
  )
  assert_eq(
    runtime_control_json_string(decisions[2], "effect", default=""),
    "withdraw-pending",
  )
}

///|
test "mooncode runtime control preserves web search capability for start turn" {
  let commands : Array[Json] = [
    {
      "command_id": "cmd-web",
      "action": "prompt",
      "control": "prompt",
      "message": "rate vectie.com",
      "web_search": true,
    },
  ]
  let lifecycle : Json = {
    "commands": [
      { "command_id": "cmd-web", "action": "prompt", "status": "pending" },
    ],
  }
  let projection = runtime_control_projection("s1", commands, lifecycle)
  let decisions = runtime_control_json_array_items(projection, "decisions")
  assert_eq(decisions.length(), 1)
  assert_eq(
    runtime_control_json_string(decisions[0], "effect", default=""),
    "start-turn",
  )
  let mooncode_command = command_json_object_field_or_empty(
    decisions[0],
    "mooncode_command",
  )
  assert_true(json_bool(mooncode_command, "web_search", default=false))
  assert_true(
    command_json_string_array_items(mooncode_command, "allowed_tools").contains(
      "web_search",
    ),
  )
  assert_true(
    runtime_control_json_string(mooncode_command, "capability_note", default="").contains(
      "Web search is enabled",
    ),
  )
}

///|
test "mooncode runtime control queues steer to pending package turn" {
  let commands : Array[Json] = [
    {
      "command_id": "cmd-steer",
      "action": "steer",
      "control": "steer",
      "message": "too late",
    },
    {
      "command_id": "cmd-package",
      "action": "package",
      "control": "command",
      "message": "package output",
    },
  ]
  let lifecycle : Json = {
    "commands": [
      { "command_id": "cmd-steer", "action": "steer", "status": "completed" },
      { "command_id": "cmd-package", "action": "package", "status": "pending" },
    ],
  }
  let projection = runtime_control_projection("s1", commands, lifecycle)
  let decisions = runtime_control_json_array_items(projection, "decisions")
  assert_eq(
    runtime_control_json_string(decisions[0], "effect", default=""),
    "queue-steer",
  )
  assert_eq(
    runtime_control_json_string(decisions[0], "target_command_id", default=""),
    "cmd-package",
  )
  assert_eq(
    runtime_control_json_string(decisions[1], "effect", default=""),
    "start-turn",
  )
}

///|
test "mooncode runtime control defers truly idle steer" {
  let commands : Array[Json] = [
    {
      "command_id": "cmd-steer",
      "action": "steer",
      "control": "steer",
      "message": "apply to the next turn",
    },
  ]
  let lifecycle : Json = {
    "commands": [
      { "command_id": "cmd-steer", "action": "steer", "status": "pending" },
    ],
  }
  let projection = runtime_control_projection("s1", commands, lifecycle)
  assert_eq(
    runtime_control_json_string(projection, "active_turn_id", default=""),
    "",
  )
  let decisions = runtime_control_json_array_items(projection, "decisions")
  assert_eq(decisions.length(), 1)
  assert_eq(
    runtime_control_json_string(decisions[0], "effect", default=""),
    "defer-steer",
  )
  assert_eq(
    runtime_control_json_string(decisions[0], "target_command_id", default=""),
    "",
  )
}
