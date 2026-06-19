///|
fn runtime_receipt_hides_command(
  receipt : Json,
  latest_receipts : Map[String, Json],
  lease_now : String,
) -> Bool {
  let command_id = rq_json_string(receipt, "command_id", default="")
  if command_id == "" {
    return false
  }
  let status = rq_json_string(receipt, "status", default="")
  runtime_receipt_status_delivered(status) ||
  (
    runtime_receipt_status_claimed(status) &&
    !runtime_receipt_claim_expired(
      latest_receipts.get(command_id).unwrap_or(receipt),
      lease_now,
    )
  )
}

///|
fn runtime_receipted_command_map(
  receipts : Array[Json],
  lease_now : String,
) -> Map[String, Bool] {
  let latest_receipts = runtime_latest_receipts(receipts)
  let receipted : Map[String, Bool] = {}
  for receipt in receipts {
    let command_id = rq_json_string(receipt, "command_id", default="")
    if runtime_receipt_hides_command(receipt, latest_receipts, lease_now) {
      receipted[command_id] = true
    }
  }
  receipted
}

///|
fn runtime_receipt_pending_commands(
  commands : Array[Json],
  receipts : Array[Json],
  lease_now : String,
) -> Array[Json] {
  let receipted = runtime_receipted_command_map(receipts, lease_now)
  let pending : Array[Json] = []
  for command in commands {
    let command_id = rq_json_string(command, "command_id", default="")
    if command_id != "" && !receipted.get(command_id).unwrap_or(false) {
      pending.push(command)
    }
  }
  pending
}
