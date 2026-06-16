///|
pub fn serve_scheduler_contract_json() -> Json {
  {
    "kind": "mooncode-serve-scheduler-contract",
    "protocol": "mooncode.v1",
    "owner": "mooncode",
    "runtime_owner": "moonclaw-or-standalone-mooncode",
    "reference": "../openseek/cmd/openseek/serve.mbt",
    "rule": "A MoonCode runtime consumes one ordered command queue. Prompt and command actions start turns, steer targets the active turn or next pending turn, and cancel targets the active turn or withdraws the next pending turn.",
    "turn_starting_actions": "all supported actions except steer, cancel, and note",
    "active_statuses": ["running", "dispatched"],
    "terminal_statuses": ["completed", "failed"],
    "blocked_statuses": [
      "blocked-invalid", "blocked-tool-authorization", "blocked-missing-proof",
    ],
    "wire_effects": [
      "start-turn", "queue-turn", "deliver-steer", "queue-steer", "drop-steer", "cancel-active",
      "withdraw-pending", "drop-cancel", "record-note", "wait-for-proof", "blocked",
    ],
    "boundary": {
      "ui": "Moondesk records commands and renders decisions.",
      "runtime": "MoonClaw or standalone mooncode enforces the scheduler before executing tools.",
      "store": "commands.jsonl, runtime-commands.jsonl, runtime-dispatches.jsonl, and events.jsonl remain append-only.",
    },
  }
}

///|
pub fn serve_scheduler_projection(
  session_id : String,
  command_log : Array[Json],
  lifecycle : Json,
) -> Json {
  let lifecycle_items = scheduler_json_array_items(lifecycle, "commands")
  let active_turn_id = scheduler_active_turn_id(lifecycle_items)
  let pending_turn_ids = scheduler_pending_turn_ids(lifecycle_items)
  let decisions = serve_scheduler_decisions(
    command_log, lifecycle_items, active_turn_id, pending_turn_ids,
  )
  {
    "kind": "mooncode-serve-scheduler-state",
    "protocol": "mooncode.v1",
    "session_id": session_id,
    "command_count": command_log.length(),
    "lifecycle_command_count": lifecycle_items.length(),
    "active_turn_id": active_turn_id,
    "pending_turn_ids": scheduler_string_array_json(pending_turn_ids),
    "pending_turn_count": pending_turn_ids.length(),
    "decision_count": decisions.length(),
    "decisions": Json::array(decisions),
    "contract": serve_scheduler_contract_json(),
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw-or-standalone-mooncode",
      "extractable_component": "mooncode",
    },
  }
}

///|
pub fn serve_scheduler_response(
  session_id : String,
  command_log : Array[Json],
  runtime_commands : Array[Json],
  dispatch_receipts : Array[Json],
  events : Array[Json],
  lease_now~ : String,
) -> Json {
  serve_scheduler_projection(
    session_id,
    command_log,
    runtime_command_lifecycle(
      session_id,
      runtime_commands,
      dispatch_receipts,
      events,
      lease_now~,
    ),
  )
}

///|
pub fn serve_scheduler_decisions(
  command_log : Array[Json],
  lifecycle_items : Array[Json],
  active_turn_id : String,
  pending_turn_ids : Array[String],
) -> Array[Json] {
  let decisions : Array[Json] = []
  for index in 0..<command_log.length() {
    let command = command_log[index]
    let action = scheduler_command_action(command)
    let command_id = scheduler_json_string(command, "command_id", default="")
    let status = scheduler_lifecycle_status(
      lifecycle_items,
      command_id,
      default="unknown",
    )
    let decision = match action {
      "steer" =>
        scheduler_control_decision(
          index,
          command,
          action,
          status,
          active_turn_id,
          pending_turn_ids,
          active_effect="deliver-steer",
          pending_effect="queue-steer",
          idle_effect="drop-steer",
        )
      "cancel" =>
        scheduler_control_decision(
          index,
          command,
          action,
          status,
          active_turn_id,
          pending_turn_ids,
          active_effect="cancel-active",
          pending_effect="withdraw-pending",
          idle_effect="drop-cancel",
        )
      "note" =>
        scheduler_decision(
          index,
          command,
          status,
          effect="record-note",
          target_command_id="",
          target_state="recorded",
          detail="Note is recorded in the session and does not start an agent turn.",
        )
      _ =>
        scheduler_turn_decision(
          index, command, status, active_turn_id, pending_turn_ids,
        )
    }
    decisions.push(decision)
  }
  decisions
}

///|
fn scheduler_turn_decision(
  index : Int,
  command : Json,
  status : String,
  active_turn_id : String,
  pending_turn_ids : Array[String],
) -> Json {
  let command_id = scheduler_json_string(command, "command_id", default="")
  if status == "completed" {
    return scheduler_decision(
      index,
      command,
      status,
      effect="already-completed",
      target_command_id=command_id,
      target_state="terminal",
      detail="Turn already completed; no scheduler action is required.",
    )
  }
  if status == "failed" {
    return scheduler_decision(
      index,
      command,
      status,
      effect="failed",
      target_command_id=command_id,
      target_state="terminal",
      detail="Turn failed; retry or operator review is required before later queued work should proceed.",
    )
  }
  if scheduler_status_blocked(status) {
    return scheduler_decision(
      index,
      command,
      status,
      effect="blocked",
      target_command_id=command_id,
      target_state="blocked",
      detail="Turn is blocked by decode, authorization, or missing proof state.",
    )
  }
  if command_id == active_turn_id {
    return scheduler_decision(
      index,
      command,
      status,
      effect="active-turn",
      target_command_id=command_id,
      target_state="active",
      detail="This turn owns the active MoonCode runtime slot.",
    )
  }
  if active_turn_id != "" {
    return scheduler_decision(
      index,
      command,
      status,
      effect="queue-turn",
      target_command_id=active_turn_id,
      target_state="active",
      detail="A prior turn is active; this turn must wait in command-log order.",
    )
  }
  if pending_turn_ids.length() > 0 && pending_turn_ids[0] == command_id {
    scheduler_decision(
      index,
      command,
      status,
      effect="start-turn",
      target_command_id=command_id,
      target_state="pending",
      detail="No turn is active; this is the next pending turn to start.",
    )
  } else {
    scheduler_decision(
      index,
      command,
      status,
      effect="queue-turn",
      target_command_id=if pending_turn_ids.length() > 0 {
        pending_turn_ids[0]
      } else {
        ""
      },
      target_state="pending",
      detail="A prior pending turn must be consumed before this command.",
    )
  }
}

///|
fn scheduler_control_decision(
  index : Int,
  command : Json,
  action : String,
  status : String,
  active_turn_id : String,
  pending_turn_ids : Array[String],
  active_effect~ : String,
  pending_effect~ : String,
  idle_effect~ : String,
) -> Json {
  if active_turn_id != "" {
    return scheduler_decision(
      index,
      command,
      status,
      effect=active_effect,
      target_command_id=active_turn_id,
      target_state="active",
      detail="\{action} targets the active MoonCode turn.",
    )
  }
  if pending_turn_ids.length() > 0 {
    return scheduler_decision(
      index,
      command,
      status,
      effect=pending_effect,
      target_command_id=pending_turn_ids[0],
      target_state="pending",
      detail="\{action} targets the next pending MoonCode turn.",
    )
  }
  scheduler_decision(
    index,
    command,
    status,
    effect=idle_effect,
    target_command_id="",
    target_state="idle",
    detail="\{action} arrived with no active or pending MoonCode turn.",
  )
}

///|
fn scheduler_decision(
  index : Int,
  command : Json,
  status : String,
  effect~ : String,
  target_command_id~ : String,
  target_state~ : String,
  detail~ : String,
) -> Json {
  let action = scheduler_command_action(command)
  {
    "index": index,
    "command_id": scheduler_json_string(command, "command_id", default=""),
    "action": action,
    "dispatch": scheduler_json_string(
      command,
      "dispatch",
      default=command_dispatch(action),
    ),
    "status": status,
    "effect": effect,
    "target_command_id": target_command_id,
    "target_state": target_state,
    "text": scheduler_json_string(command, "message", default=""),
    "created_at": scheduler_json_string(command, "created_at", default=""),
    "openseek_wire_command": scheduler_openseek_wire_command(command),
    "detail": detail,
    "owner": {
      "scheduler": "mooncode",
      "runtime": "moonclaw-or-standalone-mooncode",
    },
  }
}

///|
fn scheduler_openseek_wire_command(command : Json) -> Json {
  let action = scheduler_command_action(command)
  match action {
    "steer" =>
      {
        "command": "steer",
        "text": scheduler_json_string(command, "message", default=""),
      }
    "cancel" => { "command": "cancel" }
    _ =>
      {
        "command": "prompt",
        "text": scheduler_json_string(command, "message", default=""),
      }
  }
}

///|
fn scheduler_active_turn_id(lifecycle_items : Array[Json]) -> String {
  for item in lifecycle_items {
    let action = scheduler_command_action(item)
    let status = scheduler_json_string(item, "status", default="")
    if scheduler_turn_starting_action(action) &&
      (status == "running" || status == "dispatched") {
      return scheduler_json_string(item, "command_id", default="")
    }
  }
  ""
}

///|
fn scheduler_pending_turn_ids(lifecycle_items : Array[Json]) -> Array[String] {
  let ids : Array[String] = []
  for item in lifecycle_items {
    let action = scheduler_command_action(item)
    let status = scheduler_json_string(item, "status", default="")
    let command_id = scheduler_json_string(item, "command_id", default="")
    if command_id != "" &&
      scheduler_turn_starting_action(action) &&
      status == "pending" {
      ids.push(command_id)
    }
  }
  ids
}

///|
fn scheduler_turn_starting_action(action : String) -> Bool {
  action != "steer" && action != "cancel" && action != "note"
}

///|
fn scheduler_status_blocked(status : String) -> Bool {
  status == "blocked-invalid" ||
  status == "blocked-tool-authorization" ||
  status == "blocked-missing-proof"
}

///|
fn scheduler_lifecycle_status(
  lifecycle_items : Array[Json],
  command_id : String,
  default~ : String,
) -> String {
  for item in lifecycle_items {
    if scheduler_json_string(item, "command_id", default="") == command_id {
      return scheduler_json_string(item, "status", default~)
    }
  }
  default
}

///|
fn scheduler_command_action(command : Json) -> String {
  scheduler_json_string(command, "action", default="prompt")
}

///|
fn scheduler_json_array_items(json : Json, key : String) -> Array[Json] {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::Array(items)) => items
        _ => []
      }
    _ => []
  }
}

///|
fn scheduler_json_string(
  json : Json,
  key : String,
  default~ : String,
) -> String {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::String(value)) => value
        _ => default
      }
    _ => default
  }
}

///|
fn scheduler_string_array_json(items : Array[String]) -> Json {
  Json::array([ for item in items => Json::string(item) ])
}

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
