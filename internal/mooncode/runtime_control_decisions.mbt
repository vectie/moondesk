///|
// MoonCode runtime control command decision engine.

///|
pub fn runtime_control_decisions(
  command_log : Array[Json],
  lifecycle_items : Array[Json],
  active_turn_id : String,
  pending_turn_ids : Array[String],
) -> Array[Json] {
  let decisions : Array[Json] = []
  for index in 0..<command_log.length() {
    let command = command_log[index]
    let action = runtime_control_command_action(command)
    let command_id = runtime_control_json_string(
      command,
      "command_id",
      default="",
    )
    let status = runtime_control_lifecycle_status(
      lifecycle_items,
      command_id,
      default="unknown",
    )
    let decision = if action == @mooncode_core.command_steer() {
      runtime_control_command_decision(
        index,
        command,
        action,
        status,
        active_turn_id,
        pending_turn_ids,
        active_effect=@mooncode_core.runtime_control_effect_deliver_steer(),
        pending_effect=@mooncode_core.runtime_control_effect_queue_steer(),
        idle_effect=@mooncode_core.runtime_control_effect_defer_steer(),
      )
    } else if action == @mooncode_core.command_cancel() {
      runtime_control_command_decision(
        index,
        command,
        action,
        status,
        active_turn_id,
        pending_turn_ids,
        active_effect=@mooncode_core.runtime_control_effect_cancel_active(),
        pending_effect=@mooncode_core.runtime_control_effect_withdraw_pending(),
        idle_effect=@mooncode_core.runtime_control_effect_drop_cancel(),
      )
    } else if action == @mooncode_core.command_note() {
      runtime_control_decision(
        index,
        command,
        status,
        effect=@mooncode_core.runtime_control_effect_record_note(),
        target_command_id="",
        target_state=@mooncode_core.runtime_control_target_state_recorded(),
        detail="Note is recorded in the session and does not start an agent turn.",
      )
    } else {
      runtime_control_turn_decision(
        index, command, status, active_turn_id, pending_turn_ids,
      )
    }
    decisions.push(decision)
  }
  decisions
}

///|
fn runtime_control_turn_decision(
  index : Int,
  command : Json,
  status : String,
  active_turn_id : String,
  pending_turn_ids : Array[String],
) -> Json {
  let command_id = runtime_control_json_string(
    command,
    "command_id",
    default="",
  )
  if status == @mooncode_core.runtime_control_status_completed() {
    return runtime_control_decision(
      index,
      command,
      status,
      effect=@mooncode_core.runtime_control_effect_already_completed(),
      target_command_id=command_id,
      target_state=@mooncode_core.runtime_control_target_state_terminal(),
      detail="Turn already completed; no runtime-control action is required.",
    )
  }
  if status == @mooncode_core.runtime_control_status_failed() {
    return runtime_control_decision(
      index,
      command,
      status,
      effect=@mooncode_core.runtime_control_effect_failed(),
      target_command_id=command_id,
      target_state=@mooncode_core.runtime_control_target_state_terminal(),
      detail="Turn failed; retry or operator review is required before later queued work should proceed.",
    )
  }
  if @mooncode_core.runtime_control_status_is_blocked(status) {
    return runtime_control_decision(
      index,
      command,
      status,
      effect=@mooncode_core.runtime_control_effect_blocked(),
      target_command_id=command_id,
      target_state=@mooncode_core.runtime_control_target_state_blocked(),
      detail="Turn is blocked by decode, authorization, or missing proof state.",
    )
  }
  if command_id == active_turn_id {
    return runtime_control_decision(
      index,
      command,
      status,
      effect=@mooncode_core.runtime_control_effect_active_turn(),
      target_command_id=command_id,
      target_state=@mooncode_core.runtime_control_target_state_active(),
      detail="This turn owns the active MoonCode runtime slot.",
    )
  }
  if active_turn_id != "" {
    return runtime_control_decision(
      index,
      command,
      status,
      effect=@mooncode_core.runtime_control_effect_queue_turn(),
      target_command_id=active_turn_id,
      target_state=@mooncode_core.runtime_control_target_state_active(),
      detail="A prior turn is active; this turn must wait in command-log order.",
    )
  }
  if pending_turn_ids.length() > 0 && pending_turn_ids[0] == command_id {
    runtime_control_decision(
      index,
      command,
      status,
      effect=@mooncode_core.runtime_control_effect_start_turn(),
      target_command_id=command_id,
      target_state=@mooncode_core.runtime_control_target_state_pending(),
      detail="No turn is active; this is the next pending turn to start.",
    )
  } else {
    runtime_control_decision(
      index,
      command,
      status,
      effect=@mooncode_core.runtime_control_effect_queue_turn(),
      target_command_id=if pending_turn_ids.length() > 0 {
        pending_turn_ids[0]
      } else {
        ""
      },
      target_state=@mooncode_core.runtime_control_target_state_pending(),
      detail="A prior pending turn must be consumed before this command.",
    )
  }
}

///|
fn runtime_control_command_decision(
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
    return runtime_control_decision(
      index,
      command,
      status,
      effect=active_effect,
      target_command_id=active_turn_id,
      target_state=@mooncode_core.runtime_control_target_state_active(),
      detail="\{action} targets the active MoonCode turn.",
    )
  }
  if pending_turn_ids.length() > 0 {
    return runtime_control_decision(
      index,
      command,
      status,
      effect=pending_effect,
      target_command_id=pending_turn_ids[0],
      target_state=@mooncode_core.runtime_control_target_state_pending(),
      detail="\{action} targets the next pending MoonCode turn.",
    )
  }
  runtime_control_decision(
    index,
    command,
    status,
    effect=idle_effect,
    target_command_id="",
    target_state=@mooncode_core.runtime_control_target_state_idle(),
    detail="\{action} arrived with no active or pending MoonCode turn.",
  )
}

///|
fn runtime_control_decision(
  index : Int,
  command : Json,
  status : String,
  effect~ : String,
  target_command_id~ : String,
  target_state~ : String,
  detail~ : String,
) -> Json {
  let action = runtime_control_command_action(command)
  let source_command_id = runtime_control_json_string(
    command,
    "command_id",
    default="",
  )
  {
    "index": index,
    "command_id": source_command_id,
    "action": action,
    "control": runtime_control_json_string(
      command,
      "control",
      default=command_control(action),
    ),
    "status": status,
    "effect": effect,
    "target_command_id": target_command_id,
    "target_state": target_state,
    "source_owner": runtime_control_owner(command, source_command_id),
    "target_owner": runtime_control_target_owner(
      target_command_id, target_state,
    ),
    "settlement_required": @mooncode_core.runtime_control_settlement_required(
      action, effect,
    ),
    "settlement_events": Json::array(
      [
        for
          event in @mooncode_core.runtime_control_settlement_events(
            action, effect,
          ) => Json::string(event)
      ],
    ),
    "text": runtime_control_json_string(command, "message", default=""),
    "created_at": runtime_control_json_string(command, "created_at", default=""),
    "mooncode_command": runtime_control_mooncode_command(command),
    "detail": detail,
    "owner": { "runtime_control": "mooncode", "runtime": "moonclaw" },
  }
}

///|
fn runtime_control_owner(command : Json, command_id : String) -> Json {
  {
    "command_id": command_id,
    "turn_id": command_id,
    "client_turn_id": runtime_control_json_string(
      command,
      "client_turn_id",
      default=command_id,
    ),
    "runtime_session_id": runtime_control_json_string(
      command,
      "runtime_session_id",
      default="",
    ),
    "run_id": runtime_control_json_string(command, "run_id", default=""),
    "action": runtime_control_command_action(command),
  }
}

///|
fn runtime_control_target_owner(
  target_command_id : String,
  target_state : String,
) -> Json {
  {
    "command_id": target_command_id,
    "turn_id": target_command_id,
    "target_state": target_state,
  }
}

///|
fn runtime_control_mooncode_command(command : Json) -> Json {
  let action = runtime_control_command_action(command)
  if action == @mooncode_core.command_steer() {
    mooncode_protocol_command(
      @mooncode_core.command_steer(),
      command_packet=command,
      text=runtime_control_json_string(command, "message", default=""),
    )
  } else if action == @mooncode_core.command_cancel() {
    mooncode_protocol_command(
      @mooncode_core.command_cancel(),
      command_packet=command,
    )
  } else {
    mooncode_protocol_command(
      @mooncode_core.command_prompt(),
      command_packet=command,
      text=runtime_control_json_string(command, "message", default=""),
    )
  }
}
