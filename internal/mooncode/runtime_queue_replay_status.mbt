///|
fn runtime_replay_base_status(
  command : Json,
  valid : Bool,
  receipt_status : String,
  expired_claim : Bool,
) -> String {
  @mooncode_core.runtime_replay_base_status(
    valid,
    receipt_status,
    expired_claim,
    runtime_command_tool_authorization_blocks(command),
  )
}

///|
fn runtime_replay_status_with_order_blocker(
  base_replay_status : String,
  replay_blocker_id : String,
) -> String {
  @mooncode_core.runtime_replay_status_with_order_blocker(
    base_replay_status, replay_blocker_id,
  )
}

///|
fn runtime_replay_status_is_pending(status : String) -> Bool {
  @mooncode_core.runtime_replay_status_is_pending(status)
}

///|
fn runtime_replay_status_blocks_following(status : String) -> Bool {
  @mooncode_core.runtime_replay_status_blocks_following(status)
}
