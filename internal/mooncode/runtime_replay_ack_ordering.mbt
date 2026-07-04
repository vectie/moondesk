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
        status=@mooncode_core.runtime_claim_status_invalid(),
        detail="Earlier runtime command cannot be decoded.",
      )
    }
    if runtime_command_tool_authorization_blocks(command) {
      return runtime_replay_ack_order_blocker_record(
        current_id,
        status=@mooncode_core.runtime_claim_status_blocked_tool_authorization(),
        detail=runtime_command_tool_authorization_block_reason(command),
      )
    }
    let latest = latest_receipts.get(current_id).unwrap_or(Json::object({}))
    let status = rq_json_string(
      latest,
      "status",
      default=@mooncode_core.runtime_receipt_status_missing(),
    )
    if runtime_receipt_status_delivered(status) ||
      status == @mooncode_core.runtime_receipt_status_failed() {
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
    @mooncode_core.runtime_claim_status_blocked_by_prior_command()
  } else if previous_receipt_status ==
    @mooncode_core.runtime_receipt_status_claimed() {
    if claimed_by_same_consumer {
      @mooncode_core.runtime_replay_ack_order_status_matching_claim()
    } else {
      @mooncode_core.runtime_replay_ack_order_status_consumer_mismatch()
    }
  } else if runtime_receipt_status_delivered(previous_receipt_status) {
    @mooncode_core.runtime_replay_ack_order_status_already_delivered()
  } else if previous_receipt_status ==
    @mooncode_core.runtime_receipt_status_failed() {
    @mooncode_core.runtime_replay_ack_order_status_retry_after_failed_receipt()
  } else {
    @mooncode_core.runtime_replay_ack_order_status_unclaimed_ack()
  }
}
