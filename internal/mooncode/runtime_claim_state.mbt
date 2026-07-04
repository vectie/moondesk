///|
pub fn runtime_claim_state(
  session_id : String,
  commands : Array[Json],
  receipts : Array[Json],
  workspace_id~ : String,
  workspace_name~ : String,
  runtime_session_id~ : String,
  runtime_command_log_path~ : String,
  runtime_receipt_log_path~ : String,
  lease_now? : String = "",
) -> Json {
  let receipt_statuses = runtime_receipt_statuses(receipts)
  let latest_receipts = runtime_latest_receipts(receipts)
  let claim_items : Array[Json] = []
  let claimable_items : Array[Json] = []
  let claimed_items : Array[Json] = []
  let expired_claim_items : Array[Json] = []
  let delivered_items : Array[Json] = []
  let failed_items : Array[Json] = []
  let invalid_items : Array[Json] = []
  let order_blocked_items : Array[Json] = []
  let tool_authorization_blocked_items : Array[Json] = []
  let mut order_blocker_id = ""
  let mut order_blocker_status = ""
  for index in 0..<commands.length() {
    let command = commands[index]
    let command_id = rq_json_string(command, "command_id", default="")
    let report = runtime_command_decode_report(command)
    let valid = rq_json_bool(report, "ok", default=false)
    let receipt_status = receipt_statuses
      .get(command_id)
      .unwrap_or(@mooncode_core.runtime_receipt_status_missing())
    let latest_receipt = latest_receipts
      .get(command_id)
      .unwrap_or(Json::object({}))
    let expired_claim = runtime_receipt_status_claimed(receipt_status) &&
      runtime_receipt_claim_expired(latest_receipt, lease_now)
    let previous_receipt_failed = receipt_status ==
      @mooncode_core.runtime_receipt_status_failed()
    let previous_completion_missing_proof = receipt_status ==
      @mooncode_core.runtime_receipt_status_proof_missing()
    let tool_authorization_blocked = runtime_command_tool_authorization_blocks(
      command,
    )
    let base_claim_status = runtime_claim_base_status(
      valid, receipt_status, expired_claim, tool_authorization_blocked,
    )
    let order_blocked = order_blocker_id != "" &&
      base_claim_status != @mooncode_core.runtime_claim_status_delivered()
    let claim_status = runtime_claim_status_with_order_blocker(
      base_claim_status, order_blocker_id,
    )
    let item = runtime_claim_item(
      session_id, index, command, command_id, claim_status, receipt_status, expired_claim,
      previous_receipt_failed, previous_completion_missing_proof, tool_authorization_blocked,
      order_blocked, order_blocker_id, order_blocker_status, latest_receipt, report,
    )
    claim_items.push(item)
    if expired_claim {
      expired_claim_items.push(item)
    }
    if previous_receipt_failed {
      failed_items.push(item)
    }
    if previous_completion_missing_proof {
      failed_items.push(item)
    }
    if claim_status == @mooncode_core.runtime_claim_status_claimable() {
      claimable_items.push(item)
    } else if claim_status == @mooncode_core.runtime_claim_status_claimed() {
      claimed_items.push(item)
    } else if claim_status == @mooncode_core.runtime_claim_status_delivered() {
      delivered_items.push(item)
    } else if claim_status ==
      @mooncode_core.runtime_claim_status_blocked_by_prior_command() {
      order_blocked_items.push(item)
    } else if claim_status ==
      @mooncode_core.runtime_claim_status_blocked_tool_authorization() {
      tool_authorization_blocked_items.push(item)
    } else {
      invalid_items.push(item)
    }
    if order_blocker_id == "" &&
      runtime_claim_status_blocks_following(base_claim_status) {
      order_blocker_id = command_id
      order_blocker_status = base_claim_status
    }
  }
  {
    "protocol": protocol_version(),
    "kind": @mooncode_core.runtime_claim_state_kind(),
    "session_id": session_id,
    "workspace_id": workspace_id,
    "workspace_name": workspace_name,
    "runtime_session_id": runtime_session_id,
    "runtime_command_log_path": runtime_command_log_path,
    "runtime_receipt_log_path": runtime_receipt_log_path,
    "command_count": commands.length(),
    "receipt_count": receipts.length(),
    "claimable_command_count": claimable_items.length(),
    "claimed_command_count": claimed_items.length(),
    "expired_claim_command_count": expired_claim_items.length(),
    "delivered_command_count": delivered_items.length(),
    "failed_command_count": failed_items.length(),
    "invalid_command_count": invalid_items.length(),
    "order_blocked_command_count": order_blocked_items.length(),
    "tool_authorization_blocked_command_count": tool_authorization_blocked_items.length(),
    "claim_ready": claimable_items.length() > 0,
    "claim_endpoint": @mooncode_core.runtime_claim_endpoint(session_id),
    "ack_endpoint": @mooncode_core.runtime_replay_endpoint(session_id),
    "ordering_rule": @mooncode_core.runtime_claim_ordering_rule(),
    "lease_policy": @mooncode_core.runtime_claim_lease_policy(),
    "claim_items": Json::array(claim_items),
    "claimable_commands": Json::array(claimable_items),
    "claimed_commands": Json::array(claimed_items),
    "expired_claim_commands": Json::array(expired_claim_items),
    "delivered_commands": Json::array(delivered_items),
    "failed_commands": Json::array(failed_items),
    "invalid_commands": Json::array(invalid_items),
    "order_blocked_commands": Json::array(order_blocked_items),
    "tool_authorization_blocked_commands": Json::array(
      tool_authorization_blocked_items,
    ),
    "consumer_contract": runtime_claim_consumer_contract_json(session_id),
    "owner": runtime_owner_record(),
  }
}

///|
pub fn runtime_claim_state_for_session(
  session : Json,
  commands : Array[Json],
  receipts : Array[Json],
  runtime_command_log_path~ : String,
  runtime_receipt_log_path~ : String,
  lease_now? : String = "",
) -> Json {
  runtime_claim_state(
    rq_json_string(session, "id", default=""),
    commands,
    receipts,
    workspace_id=rq_json_string(session, "workspace_id", default=""),
    workspace_name=rq_json_string(session, "workspace_name", default=""),
    runtime_session_id=session_runtime_session_id(session),
    runtime_command_log_path~,
    runtime_receipt_log_path~,
    lease_now~,
  )
}
