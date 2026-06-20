///|
pub fn runtime_replay_state(
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
  let replay_items : Array[Json] = []
  let pending_items : Array[Json] = []
  let decode_reports : Array[Json] = []
  let pending_jsonl_lines : Array[String] = []
  let mut valid_count = 0
  let mut invalid_count = 0
  let mut delivered_count = 0
  let mut claimed_count = 0
  let mut failed_count = 0
  let mut first_pending_index = -1
  let mut first_invalid_command_id = ""
  let mut replay_blocker_id = ""
  let mut replay_blocker_status = ""
  for index in 0..<commands.length() {
    let command = commands[index]
    let command_id = rq_json_string(command, "command_id", default="")
    let report = runtime_command_decode_report(command)
    decode_reports.push(report)
    let valid = rq_json_bool(report, "ok", default=false)
    if valid {
      valid_count += 1
    } else {
      invalid_count += 1
      if first_invalid_command_id == "" {
        first_invalid_command_id = command_id
      }
    }
    let receipt_status = receipt_statuses.get(command_id).unwrap_or("missing")
    let latest_receipt = latest_receipts
      .get(command_id)
      .unwrap_or(Json::object({}))
    let expired_claim = runtime_receipt_status_claimed(receipt_status) &&
      runtime_receipt_claim_expired(latest_receipt, lease_now)
    let delivered = runtime_receipt_status_delivered(receipt_status)
    let base_replay_status = runtime_replay_base_status(
      command, valid, receipt_status, expired_claim,
    )
    let order_blocked = replay_blocker_id != "" &&
      base_replay_status != "delivered"
    let replay_status = runtime_replay_status_with_order_blocker(
      base_replay_status, replay_blocker_id,
    )
    if delivered {
      delivered_count += 1
    } else if runtime_receipt_status_claimed(receipt_status) && !expired_claim {
      claimed_count += 1
    } else if receipt_status == "failed" {
      failed_count += 1
    }
    let protocol_command = rq_json_object_field_or_empty(
      command, "mooncode_command",
    )
    let item = runtime_replay_item(
      index, command, command_id, receipt_status, replay_status, expired_claim, order_blocked,
      replay_blocker_id, replay_blocker_status, latest_receipt, protocol_command,
      report,
    )
    replay_items.push(item)
    if runtime_replay_status_is_pending(replay_status) {
      if first_pending_index < 0 {
        first_pending_index = index
      }
      pending_items.push(item)
      pending_jsonl_lines.push(protocol_command.stringify())
    }
    if replay_blocker_id == "" &&
      runtime_replay_status_blocks_following(base_replay_status) {
      replay_blocker_id = command_id
      replay_blocker_status = base_replay_status
    }
  }
  {
    "protocol": protocol_version(),
    "kind": "mooncode-runtime-replay",
    "session_id": session_id,
    "workspace_id": workspace_id,
    "workspace_name": workspace_name,
    "runtime_session_id": runtime_session_id,
    "runtime_command_log_path": runtime_command_log_path,
    "runtime_receipt_log_path": runtime_receipt_log_path,
    "command_count": commands.length(),
    "valid_command_count": valid_count,
    "invalid_command_count": invalid_count,
    "delivered_command_count": delivered_count,
    "claimed_command_count": claimed_count,
    "failed_receipt_count": failed_count,
    "pending_command_count": pending_items.length(),
    "first_pending_index": first_pending_index,
    "first_invalid_command_id": first_invalid_command_id,
    "replay_ready": invalid_count == 0 && pending_items.length() > 0,
    "replay_policy": "consume pending MoonCode code commands in runtime-commands.jsonl order; skip delivered command ids and active leases; expired runtime-claimed leases are retryable pending work",
    "ordering_rule": "prompt, steer, and cancel records remain serialized in append order, matching the MoonCode command protocol's single ordered consumer",
    "consumer_contract": runtime_replay_consumer_contract_json(session_id),
    "decode_reports": Json::array(decode_reports),
    "replay_items": Json::array(replay_items),
    "pending_commands": Json::array(pending_items),
    "pending_mooncode_jsonl": pending_jsonl_lines.join("\n"),
    "runtime_protocol": runtime_protocol_contract_json(),
    "owner": runtime_owner_record(),
  }
}

///|
pub fn runtime_replay_state_for_session(
  session : Json,
  commands : Array[Json],
  receipts : Array[Json],
  runtime_command_log_path~ : String,
  runtime_receipt_log_path~ : String,
  lease_now? : String = "",
) -> Json {
  runtime_replay_state(
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

///|
pub fn runtime_command_jsonl(
  commands : Array[Json],
  receipts : Array[Json],
  scope~ : String,
  lease_now? : String = "",
) -> String {
  let lines : Array[String] = []
  if scope == "all" {
    for command in commands {
      let protocol_command = rq_json_object_field_or_empty(
        command, "mooncode_command",
      )
      if protocol_command_valid(protocol_command) {
        lines.push(protocol_command.stringify())
      }
    }
  } else {
    let replay = runtime_replay_state(
      "",
      commands,
      receipts,
      workspace_id="",
      workspace_name="",
      runtime_session_id="",
      runtime_command_log_path="",
      runtime_receipt_log_path="",
      lease_now~,
    )
    for item in rq_json_array_items(replay, "pending_commands") {
      let protocol_command = rq_json_object_field_or_empty(
        item, "mooncode_command",
      )
      if protocol_command_valid(protocol_command) {
        lines.push(protocol_command.stringify())
      }
    }
  }
  if lines.length() == 0 {
    ""
  } else {
    lines.join("\n") + "\n"
  }
}
