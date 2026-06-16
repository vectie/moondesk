///|
test "mooncode serve scheduler routes steer and cancel to active turn" {
  let commands : Array[Json] = [
    {
      "command_id": "cmd-active",
      "action": "prompt",
      "dispatch": "prompt",
      "message": "build a tool",
    },
    {
      "command_id": "cmd-steer",
      "action": "steer",
      "dispatch": "steer",
      "message": "focus tests",
    },
    { "command_id": "cmd-cancel", "action": "cancel", "dispatch": "cancel" },
  ]
  let lifecycle : Json = {
    "commands": [
      { "command_id": "cmd-active", "action": "prompt", "status": "running" },
      { "command_id": "cmd-steer", "action": "steer", "status": "pending" },
      { "command_id": "cmd-cancel", "action": "cancel", "status": "pending" },
    ],
  }
  let projection = serve_scheduler_projection("s1", commands, lifecycle)
  assert_eq(
    scheduler_json_string(projection, "active_turn_id", default=""),
    "cmd-active",
  )
  let decisions = scheduler_json_array_items(projection, "decisions")
  assert_eq(decisions.length(), 3)
  assert_eq(
    scheduler_json_string(decisions[1], "effect", default=""),
    "deliver-steer",
  )
  assert_eq(
    scheduler_json_string(decisions[1], "target_command_id", default=""),
    "cmd-active",
  )
  assert_eq(
    scheduler_json_string(decisions[2], "effect", default=""),
    "cancel-active",
  )
}

///|
test "mooncode serve scheduler response owns lifecycle assembly" {
  let command_log : Array[Json] = [
    {
      "command_id": "cmd-done",
      "action": "prompt",
      "dispatch": "prompt",
      "message": "already built",
    },
    {
      "command_id": "cmd-next",
      "action": "prompt",
      "dispatch": "prompt",
      "message": "build next",
    },
    {
      "command_id": "cmd-steer",
      "action": "steer",
      "dispatch": "steer",
      "message": "focus tests",
    },
  ]
  let runtime_commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-done",
      "action": "prompt",
      "dispatch": "prompt",
      "serve_command": "prompt",
      "openseek_wire_command": { "command": "prompt", "text": "done" },
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-next",
      "action": "prompt",
      "dispatch": "prompt",
      "serve_command": "prompt",
      "openseek_wire_command": { "command": "prompt", "text": "next" },
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-steer",
      "action": "steer",
      "dispatch": "steer",
      "serve_command": "steer",
      "openseek_wire_command": { "command": "steer", "text": "tests" },
    },
  ]
  let receipts : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
      "command_id": "cmd-done",
      "status": "runtime-completed",
      "created_at": "2026-06-15T00:00:00Z",
    },
  ]
  let response = serve_scheduler_response(
    "s1",
    command_log,
    runtime_commands,
    receipts,
    [],
    lease_now="2026-06-15T00:00:00Z",
  )
  assert_eq(
    scheduler_json_string(response, "kind", default=""),
    "mooncode-serve-scheduler-state",
  )
  let decisions = scheduler_json_array_items(response, "decisions")
  assert_eq(decisions.length(), 3)
  assert_eq(
    scheduler_json_string(decisions[0], "effect", default=""),
    "already-completed",
  )
  assert_eq(
    scheduler_json_string(decisions[1], "effect", default=""),
    "start-turn",
  )
  assert_eq(
    scheduler_json_string(decisions[2], "effect", default=""),
    "queue-steer",
  )
  assert_eq(
    scheduler_json_string(decisions[2], "target_command_id", default=""),
    "cmd-next",
  )
}

///|
test "mooncode serve scheduler starts first pending turn and queues controls" {
  let commands : Array[Json] = [
    {
      "command_id": "cmd-prompt",
      "action": "prompt",
      "dispatch": "prompt",
      "message": "make miniapp",
    },
    {
      "command_id": "cmd-steer",
      "action": "steer",
      "dispatch": "steer",
      "message": "keep it small",
    },
    { "command_id": "cmd-cancel", "action": "cancel", "dispatch": "cancel" },
  ]
  let lifecycle : Json = {
    "commands": [
      { "command_id": "cmd-prompt", "action": "prompt", "status": "pending" },
      { "command_id": "cmd-steer", "action": "steer", "status": "pending" },
      { "command_id": "cmd-cancel", "action": "cancel", "status": "pending" },
    ],
  }
  let projection = serve_scheduler_projection("s1", commands, lifecycle)
  let decisions = scheduler_json_array_items(projection, "decisions")
  assert_eq(
    scheduler_json_string(decisions[0], "effect", default=""),
    "start-turn",
  )
  assert_eq(
    scheduler_json_string(decisions[1], "effect", default=""),
    "queue-steer",
  )
  assert_eq(
    scheduler_json_string(decisions[1], "target_command_id", default=""),
    "cmd-prompt",
  )
  assert_eq(
    scheduler_json_string(decisions[2], "effect", default=""),
    "withdraw-pending",
  )
}

///|
test "mooncode serve scheduler drops idle steer and treats package as turn" {
  let commands : Array[Json] = [
    {
      "command_id": "cmd-steer",
      "action": "steer",
      "dispatch": "steer",
      "message": "too late",
    },
    {
      "command_id": "cmd-package",
      "action": "package",
      "dispatch": "command",
      "message": "package output",
    },
  ]
  let lifecycle : Json = {
    "commands": [
      { "command_id": "cmd-steer", "action": "steer", "status": "completed" },
      { "command_id": "cmd-package", "action": "package", "status": "pending" },
    ],
  }
  let projection = serve_scheduler_projection("s1", commands, lifecycle)
  let decisions = scheduler_json_array_items(projection, "decisions")
  assert_eq(
    scheduler_json_string(decisions[0], "effect", default=""),
    "queue-steer",
  )
  assert_eq(
    scheduler_json_string(decisions[0], "target_command_id", default=""),
    "cmd-package",
  )
  assert_eq(
    scheduler_json_string(decisions[1], "effect", default=""),
    "start-turn",
  )
}
