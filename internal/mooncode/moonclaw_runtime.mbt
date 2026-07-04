///|
pub fn moonclaw_runtime_loop_request(
  session_id : String,
  book_root : String,
  consumer_id? : String = "moonclaw-native-runtime-loop",
  max_turns? : Int = 8,
  live_wait_ms? : Int = 0,
  poll_ms? : Int = 250,
) -> Json {
  {
    "protocol": protocol_version(),
    "session_id": session_id,
    "book_root": book_root,
    "consumer_id": consumer_id,
    "max_turns": max_turns,
    "live_wait_ms": live_wait_ms,
    "poll_ms": poll_ms,
  }
}

///|
pub fn moonclaw_runtime_turn_request(
  session_id : String,
  book_root : String,
  consumer_id? : String = "moonclaw-native-runtime-turn",
) -> Json {
  {
    "protocol": protocol_version(),
    "session_id": session_id,
    "book_root": book_root,
    "consumer_id": consumer_id,
  }
}

///|
pub fn moonclaw_runtime_receipt_mode(
  response : Json,
  accepted? : Bool = true,
) -> String {
  if !accepted {
    return "moonclaw-mooncode-runtime"
  }
  match json_string(response, "kind", default="") {
    "mooncode-runtime-loop" => "moonclaw-mooncode-runtime-loop"
    "mooncode-runtime-service" => "moonclaw-mooncode-runtime-service"
    "mooncode-runtime-service-result" => "moonclaw-mooncode-runtime-service"
    _ => "moonclaw-mooncode-runtime-turn"
  }
}

///|
pub fn moonclaw_native_runtime_receipt_result(
  queue_response : Json,
  runtime_payload : Json,
  command_packet : Json,
  queue_accepted~ : Bool,
  runtime_succeeded~ : Bool,
  runtime_error~ : String,
) -> Json {
  let runtime_accepted = json_bool(runtime_payload, "accepted", default=false)
  let status = if !queue_accepted {
    "failed"
  } else if !runtime_succeeded {
    "failed"
  } else if runtime_accepted {
    "done"
  } else {
    "failed"
  }
  let detail = json_string(
    runtime_payload,
    "message",
    default=if runtime_succeeded {
      json_string(
        queue_response,
        "message",
        default="MoonClaw MoonCode runtime accepted \{json_string(command_packet, "action", default="command")}",
      )
    } else {
      "MoonClaw queued command but native runtime execution failed: \{runtime_error}"
    },
  )
  {
    "kind": "mooncode-native-runtime-receipt-result",
    "protocol": protocol_version(),
    "queue_accepted": queue_accepted,
    "runtime_succeeded": runtime_succeeded,
    "runtime_accepted": runtime_accepted,
    "status": status,
    "detail": detail,
    "runtime_mode": moonclaw_runtime_receipt_mode(
      runtime_payload,
      accepted=runtime_accepted,
    ),
  }
}

///|
pub fn moonclaw_native_runtime_session_patch(
  receipt_result : Json,
  command_packet : Json,
  message : String,
  updated_at : String,
) -> Json {
  let status = json_string(receipt_result, "status", default="failed")
  let detail = json_string(receipt_result, "detail", default="")
  let runtime_mode = json_string(receipt_result, "runtime_mode", default="")
  {
    "kind": "mooncode-native-runtime-session-patch",
    "protocol": protocol_version(),
    "status": status,
    "detail": detail,
    "last_message": message,
    "mooncode_last_command_packet": command_packet,
    "mooncode_runtime_mode": runtime_mode,
    "updated_at": updated_at,
    "status_message": {
      "role": "status",
      "content": detail,
      "status": status,
      "created_at": updated_at,
    },
  }
}

///|
pub fn moonclaw_runtime_supervisor_run_session_patch(
  response : Json,
  updated_at : String,
) -> Json {
  let accepted = json_bool(response, "accepted", default=false)
  let service_started = json_string(response, "kind", default="") ==
    "mooncode-runtime-service" &&
    accepted
  let status = if service_started {
    "running"
  } else if accepted {
    "done"
  } else {
    "failed"
  }
  let detail = json_string(
    response,
    "message",
    default=if service_started {
      "MoonClaw native MoonCode runtime service started"
    } else if accepted {
      "MoonClaw native MoonCode runtime loop completed"
    } else {
      "MoonClaw native MoonCode runtime loop did not accept work"
    },
  )
  {
    "kind": "mooncode-runtime-supervisor-run-session-patch",
    "protocol": protocol_version(),
    "status": status,
    "detail": detail,
    "mooncode_runtime_mode": moonclaw_runtime_receipt_mode(response),
    "updated_at": updated_at,
    "status_message": {
      "role": "status",
      "content": detail,
      "status": status,
      "created_at": updated_at,
    },
  }
}

///|
pub fn apply_moonclaw_runtime_session_patch(
  session : Json,
  patch : Json,
) -> Json {
  let mut next = session
  match moonclaw_patch_field(patch, "status") {
    Some(value) => next = session_with_field(next, "status", value)
    None => ()
  }
  match moonclaw_patch_field(patch, "detail") {
    Some(value) =>
      next = session_with_field(next, "mooncode_runtime_detail", value)
    None => ()
  }
  match moonclaw_patch_field(patch, "last_message") {
    Some(value) => next = session_with_field(next, "last_message", value)
    None => ()
  }
  match moonclaw_patch_field(patch, "mooncode_last_command_packet") {
    Some(value) =>
      next = session_with_field(next, "mooncode_last_command_packet", value)
    None => ()
  }
  match moonclaw_patch_field(patch, "mooncode_runtime_mode") {
    Some(value) =>
      next = session_with_field(next, "mooncode_runtime_mode", value)
    None => ()
  }
  match moonclaw_patch_field(patch, "updated_at") {
    Some(value) => next = session_with_field(next, "updated_at", value)
    None => ()
  }
  next
}

///|
fn moonclaw_patch_field(patch : Json, key : String) -> Json? {
  match patch {
    Object(fields) => fields.get(key)
    _ => None
  }
}
