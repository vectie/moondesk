///|
// MoonCode serve scheduler command decision engine.

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
          idle_effect="defer-steer",
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
    "mooncode_command": scheduler_mooncode_command(command),
    "detail": detail,
    "owner": { "scheduler": "mooncode", "runtime": "moonclaw" },
  }
}

///|
fn scheduler_mooncode_command(command : Json) -> Json {
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
