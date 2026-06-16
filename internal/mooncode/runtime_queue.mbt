///|
pub fn runtime_command_decode_report(command : Json) -> Json {
  let wire = rq_json_object_field_or_empty(command, "openseek_wire_command")
  match decode_serve_command(wire) {
    Ok(decoded) =>
      {
        "ok": true,
        "protocol": "mooncode.v1",
        "command_id": rq_json_string(command, "command_id", default=""),
        "serve_command": decoded,
        "dispatch": rq_json_string(command, "dispatch", default="prompt"),
      }
    Err(message) =>
      {
        "ok": false,
        "protocol": "mooncode.v1",
        "command_id": rq_json_string(command, "command_id", default=""),
        "error": message,
        "wire": wire,
      }
  }
}

///|
pub fn runtime_dispatch_pending_count(
  commands : Array[Json],
  receipts : Array[Json],
  lease_now? : String = "",
) -> Int {
  runtime_dispatch_pending_commands(commands, receipts, lease_now).length()
}

///|
pub fn runtime_pending_command_ids(
  commands : Array[Json],
  receipts : Array[Json],
  lease_now? : String = "",
) -> Array[Json] {
  let pending : Array[Json] = []
  for
    command in runtime_dispatch_pending_commands(commands, receipts, lease_now) {
    let command_id = rq_json_string(command, "command_id", default="")
    pending.push(Json::string(command_id))
  }
  pending
}

///|
pub fn runtime_replay_state(
  session_id : String,
  commands : Array[Json],
  receipts : Array[Json],
  workspace_id~ : String,
  workspace_name~ : String,
  task_id~ : String,
  runtime_command_log_path~ : String,
  runtime_dispatch_log_path~ : String,
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
    let wire = rq_json_object_field_or_empty(command, "openseek_wire_command")
    let item : Json = {
      "index": index,
      "command_id": command_id,
      "action": rq_json_string(command, "action", default="prompt"),
      "dispatch": rq_json_string(command, "dispatch", default="prompt"),
      "serve_command": rq_json_string(
        command,
        "serve_command",
        default="prompt",
      ),
      "created_at": rq_json_string(command, "created_at", default=""),
      "target": rq_json_string(command, "target", default=""),
      "context_path": rq_json_string(command, "context_path", default=""),
      "receipt_status": receipt_status,
      "replay_status": replay_status,
      "previous_claim_expired": expired_claim,
      "blocked_by_command_id": if order_blocked {
        replay_blocker_id
      } else {
        ""
      },
      "blocked_by_status": if order_blocked {
        replay_blocker_status
      } else {
        ""
      },
      "latest_receipt": latest_receipt,
      "proof_event_count": rq_json_int(
        latest_receipt,
        "proof_event_count",
        default=0,
      ),
      "submitted_event_count": rq_json_int(
        latest_receipt,
        "submitted_event_count",
        default=0,
      ),
      "normalized_event_count": rq_json_int(
        latest_receipt,
        "normalized_event_count",
        default=0,
      ),
      "runtime_event_summary": rq_json_object_field_or_empty(
        latest_receipt, "runtime_event_summary",
      ),
      "openseek_wire_command": wire,
      "native_mooncode_body": rq_json_object_field_or_empty(
        command, "native_mooncode_body",
      ),
      "tool_authorization": rq_json_object_field_or_empty(
        command, "tool_authorization",
      ),
      "tool_authorization_state": rq_json_string(
        rq_json_object_field_or_empty(command, "tool_authorization"),
        "enforcement_state",
        default="",
      ),
      "runtime_may_execute_tools": rq_json_bool(
        rq_json_object_field_or_empty(command, "tool_authorization"),
        "runtime_may_execute",
        default=true,
      ),
      "tool_authorization_blocked": runtime_command_tool_authorization_blocks(
        command,
      ),
      "tool_authorization_blocked_reason": runtime_command_tool_authorization_block_reason(
        command,
      ),
      "decode_report": report,
    }
    replay_items.push(item)
    if runtime_replay_status_is_pending(replay_status) {
      if first_pending_index < 0 {
        first_pending_index = index
      }
      pending_items.push(item)
      pending_jsonl_lines.push(wire.stringify())
    }
    if replay_blocker_id == "" &&
      runtime_replay_status_blocks_following(base_replay_status) {
      replay_blocker_id = command_id
      replay_blocker_status = base_replay_status
    }
  }
  {
    "protocol": "mooncode.v1",
    "kind": "mooncode-runtime-replay",
    "session_id": session_id,
    "workspace_id": workspace_id,
    "workspace_name": workspace_name,
    "task_id": task_id,
    "runtime_command_log_path": runtime_command_log_path,
    "runtime_dispatch_log_path": runtime_dispatch_log_path,
    "command_count": commands.length(),
    "valid_command_count": valid_count,
    "invalid_command_count": invalid_count,
    "delivered_command_count": delivered_count,
    "claimed_command_count": claimed_count,
    "failed_dispatch_count": failed_count,
    "pending_command_count": pending_items.length(),
    "first_pending_index": first_pending_index,
    "first_invalid_command_id": first_invalid_command_id,
    "replay_ready": invalid_count == 0 && pending_items.length() > 0,
    "replay_policy": "consume pending OpenSeek-compatible serve commands in runtime-commands.jsonl order; skip delivered command ids and active leases; expired runtime-claimed leases are retryable pending work",
    "ordering_rule": "prompt, steer, and cancel records remain serialized in append order, matching OpenSeek serve mode's single ordered consumer",
    "consumer_contract": runtime_replay_consumer_contract_json(session_id),
    "decode_reports": Json::array(decode_reports),
    "replay_items": Json::array(replay_items),
    "pending_commands": Json::array(pending_items),
    "pending_openseek_jsonl": pending_jsonl_lines.join("\n"),
    "runtime_protocol": runtime_protocol_contract_json(),
    "owner": runtime_owner_record(),
  }
}

///|
pub fn runtime_serve_jsonl(
  commands : Array[Json],
  receipts : Array[Json],
  scope~ : String,
  lease_now? : String = "",
) -> String {
  let lines : Array[String] = []
  if scope == "all" {
    for command in commands {
      let wire = rq_json_object_field_or_empty(command, "openseek_wire_command")
      if serve_wire_valid(wire) {
        lines.push(wire.stringify())
      }
    }
  } else {
    let replay = runtime_replay_state(
      "",
      commands,
      receipts,
      workspace_id="",
      workspace_name="",
      task_id="",
      runtime_command_log_path="",
      runtime_dispatch_log_path="",
      lease_now~,
    )
    for item in rq_json_array_items(replay, "pending_commands") {
      let wire = rq_json_object_field_or_empty(item, "openseek_wire_command")
      if serve_wire_valid(wire) {
        lines.push(wire.stringify())
      }
    }
  }
  if lines.length() == 0 {
    ""
  } else {
    lines.join("\n") + "\n"
  }
}

///|
pub fn runtime_claim_state(
  session_id : String,
  commands : Array[Json],
  receipts : Array[Json],
  workspace_id~ : String,
  workspace_name~ : String,
  task_id~ : String,
  runtime_command_log_path~ : String,
  runtime_dispatch_log_path~ : String,
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
    let receipt_status = receipt_statuses.get(command_id).unwrap_or("missing")
    let latest_receipt = latest_receipts
      .get(command_id)
      .unwrap_or(Json::object({}))
    let expired_claim = runtime_receipt_status_claimed(receipt_status) &&
      runtime_receipt_claim_expired(latest_receipt, lease_now)
    let previous_dispatch_failed = receipt_status == "failed"
    let previous_completion_missing_proof = receipt_status == "proof-missing"
    let tool_authorization_blocked = runtime_command_tool_authorization_blocks(
      command,
    )
    let base_claim_status = runtime_claim_base_status(
      valid, receipt_status, expired_claim, tool_authorization_blocked,
    )
    let order_blocked = order_blocker_id != "" &&
      base_claim_status != "delivered"
    let claim_status = runtime_claim_status_with_order_blocker(
      base_claim_status, order_blocker_id,
    )
    let item : Json = {
      "index": index,
      "command_id": command_id,
      "action": rq_json_string(command, "action", default="prompt"),
      "dispatch": rq_json_string(command, "dispatch", default="prompt"),
      "serve_command": rq_json_string(
        command,
        "serve_command",
        default="prompt",
      ),
      "created_at": rq_json_string(command, "created_at", default=""),
      "target": rq_json_string(command, "target", default=""),
      "context_path": rq_json_string(command, "context_path", default=""),
      "claim_status": claim_status,
      "receipt_status": receipt_status,
      "previous_claim_expired": expired_claim,
      "previous_dispatch_failed": previous_dispatch_failed,
      "previous_completion_missing_proof": previous_completion_missing_proof,
      "tool_authorization": runtime_command_tool_authorization(command),
      "tool_authorization_state": runtime_command_tool_authorization_state(
        command,
      ),
      "runtime_may_execute_tools": !tool_authorization_blocked,
      "tool_authorization_blocked": tool_authorization_blocked,
      "tool_authorization_blocked_reason": runtime_command_tool_authorization_block_reason(
        command,
      ),
      "blocked_by_command_id": if order_blocked {
        order_blocker_id
      } else {
        ""
      },
      "blocked_by_status": if order_blocked {
        order_blocker_status
      } else {
        ""
      },
      "consumer_id": rq_json_string(latest_receipt, "consumer_id", default=""),
      "claim_id": rq_json_string(latest_receipt, "claim_id", default=""),
      "claimed_at": rq_json_string(latest_receipt, "claimed_at", default=""),
      "lease_expires_at": rq_json_string(
        latest_receipt,
        "lease_expires_at",
        default="",
      ),
      "ack_endpoint": "/api/mooncode/sessions/\{session_id}/runtime-replay",
      "runtime_command": command,
      "latest_receipt": latest_receipt,
      "decode_report": report,
    }
    claim_items.push(item)
    if expired_claim {
      expired_claim_items.push(item)
    }
    if previous_dispatch_failed {
      failed_items.push(item)
    }
    if previous_completion_missing_proof {
      failed_items.push(item)
    }
    match claim_status {
      "claimable" => claimable_items.push(item)
      "claimed" => claimed_items.push(item)
      "delivered" => delivered_items.push(item)
      "blocked-by-prior-command" => order_blocked_items.push(item)
      "blocked-tool-authorization" =>
        tool_authorization_blocked_items.push(item)
      _ => invalid_items.push(item)
    }
    if order_blocker_id == "" &&
      runtime_claim_status_blocks_following(base_claim_status) {
      order_blocker_id = command_id
      order_blocker_status = base_claim_status
    }
  }
  {
    "protocol": "mooncode.v1",
    "kind": "mooncode-runtime-claim-state",
    "session_id": session_id,
    "workspace_id": workspace_id,
    "workspace_name": workspace_name,
    "task_id": task_id,
    "runtime_command_log_path": runtime_command_log_path,
    "runtime_dispatch_log_path": runtime_dispatch_log_path,
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
    "claim_endpoint": "/api/mooncode/sessions/\{session_id}/runtime-claim",
    "ack_endpoint": "/api/mooncode/sessions/\{session_id}/runtime-replay",
    "ordering_rule": "MoonClaw or standalone MoonCode claims valid commands in runtime-commands.jsonl order before executing them; active earlier claims and invalid earlier commands block later non-delivered rows until they are acknowledged, failed, expired, forced, or repaired.",
    "lease_policy": "runtime-claimed receipts hide commands from other consumers until lease_expires_at passes; expired claims and failed dispatches become claimable retry work without force, while delivered receipts remain protected.",
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
