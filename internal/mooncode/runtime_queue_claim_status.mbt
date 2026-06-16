///|
fn runtime_claim_base_status(
  valid : Bool,
  receipt_status : String,
  expired_claim : Bool,
  tool_authorization_blocked : Bool,
) -> String {
  if !valid {
    "invalid"
  } else if runtime_receipt_status_delivered(receipt_status) {
    "delivered"
  } else if runtime_receipt_status_claimed(receipt_status) && !expired_claim {
    "claimed"
  } else if tool_authorization_blocked {
    "blocked-tool-authorization"
  } else {
    "claimable"
  }
}

///|
fn runtime_claim_status_with_order_blocker(
  base_claim_status : String,
  order_blocker_id : String,
) -> String {
  if order_blocker_id != "" && base_claim_status != "delivered" {
    "blocked-by-prior-command"
  } else {
    base_claim_status
  }
}

///|
fn runtime_claim_status_blocks_following(status : String) -> Bool {
  status == "invalid" ||
  status == "claimed" ||
  status == "blocked-tool-authorization"
}
