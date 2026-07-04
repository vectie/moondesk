///|
pub fn runtime_control_contract_json() -> Json {
  @mooncode_core.runtime_control_contract_json()
}

///|
pub fn runtime_control_projection(
  session_id : String,
  command_log : Array[Json],
  lifecycle : Json,
) -> Json {
  let lifecycle_items = runtime_control_json_array_items(lifecycle, "commands")
  let active_turn_id = runtime_control_active_turn_id(lifecycle_items)
  let pending_turn_ids = runtime_control_pending_turn_ids(lifecycle_items)
  let decisions = runtime_control_decisions(
    command_log, lifecycle_items, active_turn_id, pending_turn_ids,
  )
  {
    "kind": @mooncode_core.runtime_control_state_kind(),
    "protocol": protocol_version(),
    "session_id": session_id,
    "command_count": command_log.length(),
    "lifecycle_command_count": lifecycle_items.length(),
    "active_turn_id": active_turn_id,
    "pending_turn_ids": runtime_control_string_array_json(pending_turn_ids),
    "pending_turn_count": pending_turn_ids.length(),
    "decision_count": decisions.length(),
    "decisions": Json::array(decisions),
    "contract": runtime_control_contract_json(),
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "standalone_component": "mooncode",
    },
  }
}

///|
pub fn runtime_control_response(
  session_id : String,
  command_log : Array[Json],
  runtime_commands : Array[Json],
  runtime_receipts : Array[Json],
  events : Array[Json],
  lease_now~ : String,
) -> Json {
  runtime_control_projection(
    session_id,
    command_log,
    runtime_command_lifecycle(
      session_id,
      runtime_commands,
      runtime_receipts,
      events,
      lease_now~,
    ),
  )
}

///|
fn runtime_control_active_turn_id(lifecycle_items : Array[Json]) -> String {
  for item in lifecycle_items {
    let action = runtime_control_command_action(item)
    let status = runtime_control_json_string(item, "status", default="")
    if @mooncode_core.runtime_control_action_starts_turn(action) &&
      @mooncode_core.runtime_control_status_is_active(status) {
      return runtime_control_json_string(item, "command_id", default="")
    }
  }
  ""
}

///|
fn runtime_control_pending_turn_ids(
  lifecycle_items : Array[Json],
) -> Array[String] {
  let ids : Array[String] = []
  for item in lifecycle_items {
    let action = runtime_control_command_action(item)
    let status = runtime_control_json_string(item, "status", default="")
    let command_id = runtime_control_json_string(item, "command_id", default="")
    if command_id != "" &&
      @mooncode_core.runtime_control_action_starts_turn(action) &&
      @mooncode_core.runtime_control_status_is_pending(status) {
      ids.push(command_id)
    }
  }
  ids
}

///|
fn runtime_control_lifecycle_status(
  lifecycle_items : Array[Json],
  command_id : String,
  default~ : String,
) -> String {
  for item in lifecycle_items {
    if runtime_control_json_string(item, "command_id", default="") == command_id {
      return runtime_control_json_string(item, "status", default~)
    }
  }
  default
}

///|
fn runtime_control_command_action(command : Json) -> String {
  runtime_control_json_string(command, "action", default="prompt")
}

///|
fn runtime_control_json_array_items(json : Json, key : String) -> Array[Json] {
  @mooncore.json_array_items(json, key)
}

///|
fn runtime_control_json_string(
  json : Json,
  key : String,
  default~ : String,
) -> String {
  @mooncore.json_string(json, key, default~)
}

///|
fn runtime_control_string_array_json(items : Array[String]) -> Json {
  @mooncore.string_array_json(items)
}
