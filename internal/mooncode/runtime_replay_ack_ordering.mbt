///|
fn runtime_replay_ack_order_blocker(
  command_id : String,
  commands : Array[Json],
  latest_receipts : Map[String, Json],
  now : String,
) -> Json {
  for command in commands {
    let current_id = rq_json_string(command, "command_id", default="")
    if current_id == command_id {
      return Json::object({})
    }
    let report = runtime_command_decode_report(command)
    if !rq_json_bool(report, "ok", default=false) {
      return runtime_replay_ack_order_blocker_record(
        current_id,
        status="invalid",
        detail="Earlier runtime command cannot be decoded.",
      )
    }
    if runtime_command_tool_authorization_blocks(command) {
      return runtime_replay_ack_order_blocker_record(
        current_id,
        status="blocked-tool-authorization",
        detail=runtime_command_tool_authorization_block_reason(command),
      )
    }
    let latest = latest_receipts.get(current_id).unwrap_or(Json::object({}))
    let status = rq_json_string(latest, "status", default="missing")
    if runtime_receipt_status_delivered(status) || status == "failed" {
      continue
    }
    if runtime_receipt_status_claimed(status) &&
      runtime_receipt_claim_expired(latest, now) {
      continue
    }
    return runtime_replay_ack_order_blocker_record(
      current_id,
      status~,
      detail="Earlier runtime command is not delivered yet.",
    )
  }
  Json::object({})
}

///|
fn runtime_replay_ack_order_blocker_record(
  command_id : String,
  status~ : String,
  detail~ : String,
) -> Json {
  { "command_id": command_id, "status": status, "detail": detail }
}

///|
fn runtime_replay_ack_order_status(
  previous_receipt_status : String,
  order_blocker : Json,
  claimed_by_same_consumer : Bool,
) -> String {
  if rq_json_string(order_blocker, "command_id", default="") != "" {
    "blocked-by-prior-command"
  } else if previous_receipt_status == "runtime-claimed" {
    if claimed_by_same_consumer {
      "matching-claim"
    } else {
      "consumer-mismatch"
    }
  } else if runtime_receipt_status_delivered(previous_receipt_status) {
    "already-delivered"
  } else if previous_receipt_status == "failed" {
    "retry-after-failed-receipt"
  } else {
    "unclaimed-ack"
  }
}
