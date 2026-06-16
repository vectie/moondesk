///|
fn runtime_replay_base_status(
  command : Json,
  valid : Bool,
  receipt_status : String,
  expired_claim : Bool,
) -> String {
  if !valid {
    "blocked-invalid"
  } else if runtime_receipt_status_delivered(receipt_status) {
    "delivered"
  } else if expired_claim {
    if runtime_command_tool_authorization_blocks(command) {
      "blocked-tool-authorization"
    } else {
      "expired-claim-pending-retry"
    }
  } else if runtime_command_tool_authorization_blocks(command) {
    "blocked-tool-authorization"
  } else if runtime_receipt_status_claimed(receipt_status) {
    "claimed"
  } else if receipt_status == "proof-missing" {
    "missing-proof-pending-retry"
  } else if receipt_status == "failed" {
    "failed-pending-retry"
  } else {
    "pending"
  }
}

///|
fn runtime_replay_status_with_order_blocker(
  base_replay_status : String,
  replay_blocker_id : String,
) -> String {
  if replay_blocker_id != "" && base_replay_status != "delivered" {
    "blocked-by-prior-command"
  } else {
    base_replay_status
  }
}

///|
fn runtime_replay_status_is_pending(status : String) -> Bool {
  status == "pending" ||
  status == "failed-pending-retry" ||
  status == "missing-proof-pending-retry" ||
  status == "expired-claim-pending-retry"
}

///|
fn runtime_replay_status_blocks_following(status : String) -> Bool {
  status == "blocked-invalid" ||
  status == "claimed" ||
  status == "blocked-tool-authorization"
}
