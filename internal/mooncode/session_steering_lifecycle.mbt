///|
// MoonCode steering lifecycle projection for MoonCode steer visibility.

///|
pub fn session_steering_lifecycle(events : Array[Json]) -> Json {
  let command_ids : Array[String] = []
  for event in events {
    if steering_event_is_steer_command(event) {
      steering_push_command_id(command_ids, steering_event_command_id(event))
    }
  }
  for event in events {
    if steering_event_is_settlement(event) {
      steering_push_command_id(command_ids, steering_event_command_id(event))
    }
  }
  let rows = [
    for command_id in command_ids => steering_lifecycle_row(command_id, events)
  ]
  let mut applied_count = 0
  let mut deferred_count = 0
  let mut dropped_count = 0
  let mut pending_count = 0
  for row in rows {
    match json_string(row, "status", default="pending") {
      "applied" => applied_count += 1
      "deferred" => deferred_count += 1
      "dropped" => dropped_count += 1
      _ => pending_count += 1
    }
  }
  {
    "kind": "mooncode-steering-lifecycle",
    "protocol": protocol_version(),
    "steer_command_count": command_ids.length(),
    "applied_count": applied_count,
    "deferred_count": deferred_count,
    "dropped_count": dropped_count,
    "pending_count": pending_count,
    "settled_count": applied_count + dropped_count,
    "latest_status": steering_latest_status(rows),
    "next_step": steering_next_step(
      pending_count, deferred_count, dropped_count, applied_count,
    ),
    "rows": Json::array(rows),
    "rule": "Steering lifecycle is derived from durable MoonCode steer command packets plus command-scoped steer_applied, steer_deferred, and steer_dropped runtime events. Deferred steering remains pending product work until a later steer_applied event binds it to a turn.",
  }
}

///|
fn steering_lifecycle_row(command_id : String, events : Array[Json]) -> Json {
  let command = steering_find_command_event(command_id, events)
  let settlement = steering_find_settlement_event(command_id, events)
  let kind = json_string(settlement, "kind", default="")
  let status = match kind {
    "steer_applied" => "applied"
    "steer_deferred" => "deferred"
    "steer_dropped" => "dropped"
    _ => "pending"
  }
  let command_recorded = json_string(command, "id", default="") != ""
  let settlement_recorded = json_string(settlement, "id", default="") != ""
  {
    "command_id": command_id,
    "status": status,
    "command_recorded": command_recorded,
    "settlement_recorded": settlement_recorded,
    "command_created_at": json_string(command, "created_at", default=""),
    "settlement_created_at": json_string(settlement, "created_at", default=""),
    "settlement_kind": kind,
    "target": json_string(
      command,
      "path",
      default=json_string(settlement, "path", default=""),
    ),
    "message": steering_lifecycle_message(command, settlement, status),
    "applied_to_command_id": json_string(
      settlement,
      "applied_to_command_id",
      default="",
    ),
    "event_id": json_string(
      settlement,
      "id",
      default=json_string(command, "id", default=""),
    ),
  }
}

///|
fn steering_lifecycle_message(
  command : Json,
  settlement : Json,
  status : String,
) -> String {
  let settlement_detail = json_string(settlement, "detail", default="")
  if settlement_detail != "" {
    return settlement_detail
  }
  let command_detail = json_string(command, "detail", default="")
  if command_detail != "" {
    command_detail
  } else {
    match status {
      "applied" => "Steering was applied to a runtime turn."
      "deferred" => "Steering was saved for the next eligible turn."
      "dropped" => "Steering could not be applied."
      _ => "Steering is waiting for runtime apply/defer/drop evidence."
    }
  }
}

///|
fn steering_find_command_event(
  command_id : String,
  events : Array[Json],
) -> Json {
  for event in events {
    if steering_event_is_steer_command(event) &&
      steering_event_command_id(event) == command_id {
      return event
    }
  }
  Json::object({})
}

///|
fn steering_find_settlement_event(
  command_id : String,
  events : Array[Json],
) -> Json {
  let mut found = Json::object({})
  for event in events {
    if steering_event_is_settlement(event) &&
      steering_event_command_id(event) == command_id {
      found = event
    }
  }
  found
}

///|
fn steering_event_is_steer_command(event : Json) -> Bool {
  json_string(event, "command", default="") == "steer" ||
  json_string(event, "kind", default="") == "command.steer" ||
  json_string(
    summary_json_object_field_or_empty(event, "command_packet"),
    "action",
    default="",
  ) ==
  "steer"
}

///|
fn steering_event_is_settlement(event : Json) -> Bool {
  let kind = json_string(event, "kind", default="")
  kind == event_steer_applied() ||
  kind == event_steer_deferred() ||
  kind == event_steer_dropped()
}

///|
fn steering_event_command_id(event : Json) -> String {
  let packet = summary_json_object_field_or_empty(event, "command_packet")
  let from_packet = json_string(packet, "command_id", default="")
  if from_packet != "" {
    from_packet
  } else {
    json_string(event, "command_id", default="")
  }
}

///|
fn steering_push_command_id(ids : Array[String], command_id : String) -> Unit {
  if command_id == "" {
    return
  }
  for id in ids {
    if id == command_id {
      return
    }
  }
  ids.push(command_id)
}

///|
fn steering_latest_status(rows : Array[Json]) -> String {
  if rows.length() == 0 {
    return "idle"
  }
  json_string(rows[rows.length() - 1], "status", default="pending")
}

///|
fn steering_next_step(
  pending_count : Int,
  deferred_count : Int,
  dropped_count : Int,
  applied_count : Int,
) -> String {
  if pending_count > 0 {
    "Wait for MoonClaw to emit steer_applied, steer_deferred, or steer_dropped for pending steering."
  } else if deferred_count > 0 {
    "Start or continue the next MoonCode turn so MoonClaw can apply deferred steering."
  } else if dropped_count > 0 && applied_count == 0 {
    "Send a fresh steer while a turn is active or queued."
  } else if applied_count > 0 {
    "Steering lifecycle is settled for the visible command rows."
  } else {
    "No steering commands have been recorded."
  }
}
