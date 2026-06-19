///|
fn action_plan_runtime_command_for_id(
  command_id : String,
  runtime_commands : Array[Json],
) -> Json {
  if command_id == "" {
    return Json::object({})
  }
  for command in runtime_commands {
    if json_string(command, "command_id", default="") == command_id {
      return command
    }
  }
  Json::object({})
}

///|
pub fn action_plan_runtime_state_at(
  command_id : String,
  runtime_commands : Array[Json],
  runtime_receipts : Array[Json],
  lease_now? : String = "",
) -> String {
  if command_id == "" {
    return "not-recorded"
  }
  let mut runtime_recorded = false
  for command in runtime_commands {
    if json_string(command, "command_id", default="") == command_id {
      runtime_recorded = true
    }
  }
  let statuses = runtime_receipt_statuses(runtime_receipts)
  let latest_receipts = runtime_latest_receipts(runtime_receipts)
  let receipt = statuses.get(command_id).unwrap_or("")
  if runtime_receipt_status_delivered(receipt) {
    "delivered"
  } else if runtime_receipt_status_claimed(receipt) &&
    lease_now != "" &&
    runtime_receipt_claim_expired(
      latest_receipts.get(command_id).unwrap_or(Json::object({})),
      lease_now,
    ) {
    "expired-claim"
  } else if runtime_receipt_status_claimed(receipt) {
    "claimed"
  } else if receipt == "failed" {
    "failed"
  } else if runtime_recorded {
    "pending"
  } else {
    "not-recorded"
  }
}
