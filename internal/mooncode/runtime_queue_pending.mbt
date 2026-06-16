///|
fn runtime_dispatch_receipt_hides_command(
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
fn runtime_dispatched_command_map(
  receipts : Array[Json],
  lease_now : String,
) -> Map[String, Bool] {
  let latest_receipts = runtime_latest_receipts(receipts)
  let dispatched : Map[String, Bool] = {}
  for receipt in receipts {
    let command_id = rq_json_string(receipt, "command_id", default="")
    if runtime_dispatch_receipt_hides_command(
        receipt, latest_receipts, lease_now,
      ) {
      dispatched[command_id] = true
    }
  }
  dispatched
}

///|
fn runtime_dispatch_pending_commands(
  commands : Array[Json],
  receipts : Array[Json],
  lease_now : String,
) -> Array[Json] {
  let dispatched = runtime_dispatched_command_map(receipts, lease_now)
  let pending : Array[Json] = []
  for command in commands {
    let command_id = rq_json_string(command, "command_id", default="")
    if command_id != "" && !dispatched.get(command_id).unwrap_or(false) {
      pending.push(command)
    }
  }
  pending
}
