///|
// MoonCode cancel lifecycle projection for command-scoped cancellation proof.

///|
pub fn session_cancel_lifecycle(events : Array[Json]) -> Json {
  let command_ids : Array[String] = []
  for event in events {
    if cancel_event_is_command(event) {
      cancel_push_command_id(command_ids, cancel_event_command_id(event))
    }
  }
  for event in events {
    if cancel_event_is_settlement(event) {
      cancel_push_command_id(command_ids, cancel_event_command_id(event))
    }
  }
  let rows = [
    for command_id in command_ids => cancel_lifecycle_row(command_id, events)
  ]
  let mut cancelled_count = 0
  let mut dropped_count = 0
  let mut failed_count = 0
  let mut pending_count = 0
  for row in rows {
    match json_string(row, "status", default="pending") {
      "cancelled" => cancelled_count += 1
      "dropped" => dropped_count += 1
      "failed" => failed_count += 1
      _ => pending_count += 1
    }
  }
  {
    "kind": "mooncode-cancel-lifecycle",
    "protocol": protocol_version(),
    "cancel_command_count": command_ids.length(),
    "cancelled_count": cancelled_count,
    "dropped_count": dropped_count,
    "failed_count": failed_count,
    "pending_count": pending_count,
    "settled_count": cancelled_count + dropped_count + failed_count,
    "latest_status": cancel_latest_status(rows),
    "next_step": cancel_next_step(
      pending_count, failed_count, dropped_count, cancelled_count,
    ),
    "rows": Json::array(rows),
    "rule": "Cancel lifecycle is derived from durable MoonCode cancel command packets plus command-scoped runtime_aborted and cancel_dropped runtime events. A dropped cancel means MoonClaw found no active or pending turn to cancel.",
  }
}

///|
fn cancel_lifecycle_row(command_id : String, events : Array[Json]) -> Json {
  let command = cancel_find_command_event(command_id, events)
  let settlement = cancel_find_settlement_event(command_id, events)
  let settlement_kind = json_string(settlement, "kind", default="")
  let command_status = json_string(command, "status", default="")
  let status = if settlement_kind == "runtime_aborted" {
    "cancelled"
  } else if settlement_kind == event_cancel_dropped() {
    "dropped"
  } else if command_status == "failed" {
    "failed"
  } else {
    "pending"
  }
  let command_recorded = json_string(command, "id", default="") != ""
  let settlement_recorded = json_string(settlement, "id", default="") != ""
  {
    "command_id": command_id,
    "status": status,
    "command_recorded": command_recorded,
    "settlement_recorded": settlement_recorded,
    "command_status": command_status,
    "command_created_at": json_string(command, "created_at", default=""),
    "settlement_created_at": json_string(settlement, "created_at", default=""),
    "settlement_kind": settlement_kind,
    "target": json_string(
      command,
      "path",
      default=json_string(settlement, "path", default=""),
    ),
    "message": cancel_lifecycle_message(command, settlement, status),
    "event_id": json_string(
      settlement,
      "id",
      default=json_string(command, "id", default=""),
    ),
  }
}

///|
fn cancel_lifecycle_message(
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
      "cancelled" => "Cancel reached MoonClaw and aborted active work."
      "dropped" =>
        "Cancel reached MoonClaw but no active or pending turn existed."
      "failed" => "Cancel command failed before MoonClaw accepted it."
      _ => "Cancel is waiting for runtime_aborted or cancel_dropped evidence."
    }
  }
}

///|
fn cancel_find_command_event(command_id : String, events : Array[Json]) -> Json {
  for event in events {
    if cancel_event_is_command(event) &&
      cancel_event_command_id(event) == command_id {
      return event
    }
  }
  Json::object({})
}

///|
fn cancel_find_settlement_event(
  command_id : String,
  events : Array[Json],
) -> Json {
  let mut found = Json::object({})
  for event in events {
    if cancel_event_is_settlement(event) &&
      cancel_event_command_id(event) == command_id {
      found = event
    }
  }
  found
}

///|
fn cancel_event_is_command(event : Json) -> Bool {
  json_string(event, "command", default="") == "cancel" ||
  json_string(event, "kind", default="") == "command.cancel"
}

///|
fn cancel_event_is_settlement(event : Json) -> Bool {
  let kind = json_string(event, "kind", default="")
  (kind == "runtime_aborted" || kind == event_cancel_dropped()) &&
  json_string(
    summary_json_object_field_or_empty(event, "command_packet"),
    "action",
    default="",
  ) ==
  "cancel"
}

///|
fn cancel_event_command_id(event : Json) -> String {
  let packet = summary_json_object_field_or_empty(event, "command_packet")
  let from_packet = json_string(packet, "command_id", default="")
  if from_packet != "" {
    from_packet
  } else {
    json_string(event, "command_id", default="")
  }
}

///|
fn cancel_push_command_id(ids : Array[String], command_id : String) -> Unit {
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
fn cancel_latest_status(rows : Array[Json]) -> String {
  if rows.length() == 0 {
    return "idle"
  }
  json_string(rows[rows.length() - 1], "status", default="pending")
}

///|
fn cancel_next_step(
  pending_count : Int,
  failed_count : Int,
  dropped_count : Int,
  cancelled_count : Int,
) -> String {
  if pending_count > 0 {
    "Wait for MoonClaw to emit runtime_aborted or cancel_dropped for pending cancellation."
  } else if failed_count > 0 {
    "Restart or reconnect MoonClaw before sending another cancel command."
  } else if dropped_count > 0 && cancelled_count == 0 {
    "No work was active when cancel arrived; start or resume a turn before cancelling."
  } else if cancelled_count > 0 {
    "Cancellation lifecycle is settled for the visible command rows."
  } else {
    "No cancel commands have been recorded."
  }
}
