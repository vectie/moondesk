///|
fn runtime_claim_base_status(
  valid : Bool,
  receipt_status : String,
  expired_claim : Bool,
  tool_authorization_blocked : Bool,
) -> String {
  @mooncode_core.runtime_claim_base_status(
    valid, receipt_status, expired_claim, tool_authorization_blocked,
  )
}

///|
fn runtime_claim_status_with_order_blocker(
  base_claim_status : String,
  order_blocker_id : String,
) -> String {
  @mooncode_core.runtime_claim_status_with_order_blocker(
    base_claim_status, order_blocker_id,
  )
}

///|
fn runtime_claim_status_blocks_following(status : String) -> Bool {
  @mooncode_core.runtime_claim_status_blocks_following(status)
}
