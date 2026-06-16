///|
pub fn runtime_claim_receipts(
  session : Json,
  commands : Array[Json],
  receipts : Array[Json],
  payload : Json,
) -> Array[Json] {
  let statuses = runtime_receipt_statuses(receipts)
  let latest_receipts = runtime_latest_receipts(receipts)
  let max_count = runtime_claim_max_count(payload)
  let force = rq_json_bool(payload, "force", default=false)
  let now = rq_json_string(payload, "now", default="")
  let claimed : Array[Json] = []
  for command in commands {
    if claimed.length() >= max_count {
      break
    }
    let command_id = rq_json_string(command, "command_id", default="")
    let status = statuses.get(command_id).unwrap_or("")
    let latest_receipt = latest_receipts
      .get(command_id)
      .unwrap_or(Json::object({}))
    let expired_claim = runtime_receipt_status_claimed(status) &&
      runtime_receipt_claim_expired(latest_receipt, now)
    if runtime_receipt_status_delivered(status) {
      continue
    }
    if command_id == "" ||
      !rq_json_bool(runtime_command_decode_report(command), "ok", default=false) {
      break
    }
    if runtime_command_tool_authorization_blocks(command) {
      break
    }
    if runtime_receipt_status_claimed(status) && !force && !expired_claim {
      break
    }
    claimed.push(
      runtime_claim_receipt(
        session,
        command,
        payload,
        recovered_expired_claim=expired_claim,
        previous_claim_receipt=latest_receipt,
      ),
    )
  }
  claimed
}

///|
pub fn runtime_claim_receipts_with_defaults(
  session : Json,
  commands : Array[Json],
  receipts : Array[Json],
  payload : Json,
  now~ : String,
) -> Array[Json] {
  runtime_claim_receipts(
    session,
    commands,
    receipts,
    rq_json_with_missing_string(
      rq_json_with_missing_string(payload, "now", now),
      "claimed_at",
      now,
    ),
  )
}

///|
pub fn runtime_claim_response(
  session_id : String,
  claim_receipts : Array[Json],
  runtime_replay : Json,
  runtime_claim : Json,
  session : Json,
) -> Json {
  {
    "protocol": "mooncode.v1",
    "kind": "mooncode-runtime-claim",
    "session_id": session_id,
    "claimed_count": claim_receipts.length(),
    "claim_receipts": Json::array(claim_receipts),
    "claimed_commands": Json::array(
      [
        for receipt in claim_receipts => {
          rq_json_object_field_or_empty(receipt, "runtime_command")
        }
      ],
    ),
    "runtime_replay": runtime_replay,
    "claim_state": runtime_claim,
    "consumer_contract": runtime_claim_consumer_contract_json(session_id),
    "session": session,
  }
}

///|
pub fn runtime_claim_result_response(
  session_id : String,
  commands : Array[Json],
  next_receipts : Array[Json],
  claim_receipts : Array[Json],
  session : Json,
  runtime_command_log_path~ : String,
  runtime_dispatch_log_path~ : String,
) -> Json {
  runtime_claim_response(
    session_id,
    claim_receipts,
    runtime_replay_state(
      session_id,
      commands,
      next_receipts,
      workspace_id=rq_json_string(session, "workspace_id", default=""),
      workspace_name=rq_json_string(session, "workspace_name", default=""),
      task_id=rq_json_string(session, "moonclaw_task_id", default=""),
      runtime_command_log_path~,
      runtime_dispatch_log_path~,
    ),
    runtime_claim_state(
      session_id,
      commands,
      next_receipts,
      workspace_id=rq_json_string(session, "workspace_id", default=""),
      workspace_name=rq_json_string(session, "workspace_name", default=""),
      task_id=rq_json_string(session, "moonclaw_task_id", default=""),
      runtime_command_log_path~,
      runtime_dispatch_log_path~,
    ),
    session,
  )
}

///|
pub fn runtime_claim_max_count(payload : Json) -> Int {
  let requested = rq_json_int(payload, "max_count", default=1)
  if requested <= 0 {
    1
  } else if requested > 50 {
    50
  } else {
    requested
  }
}

///|
fn runtime_claim_receipt(
  session : Json,
  runtime_command : Json,
  payload : Json,
  recovered_expired_claim? : Bool = false,
  previous_claim_receipt? : Json = Json::object({}),
) -> Json {
  let command_id = rq_json_string(runtime_command, "command_id", default="")
  let consumer_id = runtime_safe_id(
    rq_json_string(payload, "consumer_id", default="moonclaw-runtime"),
    fallback="moonclaw-runtime",
  )
  let claimed_at = rq_json_string(payload, "claimed_at", default="")
  let lease_id = runtime_safe_id(
    rq_json_string(payload, "claim_id", default=""),
    fallback="mooncode-runtime-claim:\{command_id}:\{consumer_id}:\{claimed_at}",
  )
  {
    "protocol": "mooncode.v1",
    "kind": "mooncode.runtime-dispatch",
    "dispatch_id": lease_id,
    "claim_id": lease_id,
    "command_id": command_id,
    "session_id": rq_json_string(runtime_command, "session_id", default=""),
    "workspace_id": rq_json_string(session, "workspace_id", default=""),
    "workspace_name": rq_json_string(session, "workspace_name", default=""),
    "task_id": rq_json_string(session, "moonclaw_task_id", default=""),
    "action": rq_json_string(runtime_command, "action", default="prompt"),
    "dispatch": rq_json_string(runtime_command, "dispatch", default="prompt"),
    "status": "runtime-claimed",
    "dispatch_mode": "mooncode-runtime-claim",
    "consumer_id": consumer_id,
    "created_at": claimed_at,
    "claimed_at": claimed_at,
    "lease_expires_at": rq_json_string(payload, "lease_expires_at", default=""),
    "recovered_expired_claim": recovered_expired_claim,
    "previous_claim_id": rq_json_string(
      previous_claim_receipt,
      "claim_id",
      default="",
    ),
    "previous_lease_expires_at": rq_json_string(
      previous_claim_receipt,
      "lease_expires_at",
      default="",
    ),
    "openseek_wire_valid": rq_json_bool(
      runtime_command,
      "openseek_wire_valid",
      default=false,
    ),
    "native_mooncode_endpoint": rq_json_string(
      runtime_command,
      "native_mooncode_endpoint",
      default="",
    ),
    "legacy_bridge_endpoint": "",
    "runtime_claim_endpoint": "/api/mooncode/sessions/\{rq_json_string(runtime_command, "session_id", default="")}/runtime-claim",
    "runtime_replay_ack_endpoint": "/api/mooncode/sessions/\{rq_json_string(runtime_command, "session_id", default="")}/runtime-replay",
    "detail": "Runtime consumer claimed command for ordered execution; completion must be reported through runtime-replay acknowledgement.",
    "runtime_command": runtime_command,
    "consumer_request": payload,
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw-or-standalone-mooncode",
      "extractable_component": "mooncode",
    },
  }
}
