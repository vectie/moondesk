///|
pub fn serve_scheduler_contract_json() -> Json {
  {
    "kind": "mooncode-serve-scheduler-contract",
    "protocol": protocol_version(),
    "owner": "mooncode",
    "runtime_owner": "moonclaw-or-standalone-mooncode",
    "reference": "../openseek/cmd/openseek/serve.mbt",
    "rule": "A MoonCode runtime consumes one ordered command queue. Prompt and command actions start turns, steer targets the active turn, next pending turn, or defers into the next future turn, and cancel targets the active turn or withdraws the next pending turn.",
    "turn_starting_actions": "all supported actions except steer, cancel, and note",
    "active_statuses": ["running", "dispatched"],
    "terminal_statuses": ["completed", "failed"],
    "blocked_statuses": [
      "blocked-invalid", "blocked-tool-authorization", "blocked-missing-proof",
    ],
    "wire_effects": [
      "start-turn", "queue-turn", "deliver-steer", "queue-steer", "defer-steer",
      "cancel-active", "withdraw-pending", "drop-cancel", "record-note", "wait-for-proof",
      "blocked",
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
    "protocol": protocol_version(),
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
