///|
pub fn runtime_protocol_contract_json() -> Json {
  {
    "protocol": "mooncode.v1",
    "reference": "../openseek/cmd/openseek/serve.mbt",
    "serve_commands": Json::array(
      [
        for command in serve_command_names() => Json::string(command)
      ],
    ),
    "tool_registry": {
      "reference": "../openseek/agent/tool_definition.mbt",
      "required_tools": Json::array(
        [
          for tool in runtime_tool_names() => Json::string(tool)
        ],
      ),
      "tool_contract": tool_contract_json(),
      "tool_call_wire": tool_call_wire_contract_json(),
      "boundary": {
        "owner": "moonclaw",
        "ui": "moondesk renders tool calls, approval state, outputs, and failures",
        "extractable_component": "mooncode",
      },
    },
    "event_stream": {
      "reference": "../openseek/cmd/tui/internal/event/decode.mbt",
      "accepted_events": [
        "agent_step", "assistant_delta", "reasoning_delta", "reasoning_message",
        "assistant_message", "runtime_update", "tool_call", "tool_started", "tool_result",
        "tool_call_decode_error", "agent_finished", "agent_aborted", "max_steps_exhausted",
        "command_error", "turn_failed", "steer_applied", "steer_dropped", "usage",
        "file_change", "diff", "patch_applied", "patch_reverted", "test_result",
        "package_manifest", "package_index", "package_built", "package_verified",
        "review_receipt", "receipt.accept", "receipt.reject", "commit_created", "artifact",
      ],
      "normalization": "MoonClaw/OpenSeek JSONL events are normalized into MoonCode lanes: transcript, runtime, tool, diff, test, artifact, and review.",
    },
    "tool_authorization": {
      "snapshot": "Every mooncode.runtime-command and native MoonCode command body carries mooncode-tool-authorization-snapshot with approval manifest path, approval counts, approval rows, enforcement_state, and runtime_may_execute.",
      "enforcement_rule": "MoonClaw or standalone MoonCode must block gated tool execution when the snapshot has pending or rejected approvals, and should recheck /tool-authorization immediately before execution. Runtime replay and claim projections exclude blocked commands from pending/claimable work and preserve queue order by blocking later non-delivered rows.",
    },
    "ordering_rule": "One ordered command queue per session; prompts, steers, cancels, turn completion, and shutdown must be serialized so steering cannot race terminal events.",
  }
}

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
  let latest_receipts = runtime_latest_receipts(receipts)
  let dispatched : Map[String, Bool] = {}
  for receipt in receipts {
    let command_id = rq_json_string(receipt, "command_id", default="")
    let status = rq_json_string(receipt, "status", default="")
    if command_id != "" &&
      (
        runtime_receipt_status_delivered(status) ||
        (
          runtime_receipt_status_claimed(status) &&
          !runtime_receipt_claim_expired(
            latest_receipts.get(command_id).unwrap_or(receipt),
            lease_now,
          )
        )
      ) {
      dispatched[command_id] = true
    }
  }
  let mut pending = 0
  for command in commands {
    let command_id = rq_json_string(command, "command_id", default="")
    if command_id != "" && !dispatched.get(command_id).unwrap_or(false) {
      pending += 1
    }
  }
  pending
}

///|
pub fn runtime_pending_command_ids(
  commands : Array[Json],
  receipts : Array[Json],
  lease_now? : String = "",
) -> Array[Json] {
  let latest_receipts = runtime_latest_receipts(receipts)
  let dispatched : Map[String, Bool] = {}
  for receipt in receipts {
    let command_id = rq_json_string(receipt, "command_id", default="")
    let status = rq_json_string(receipt, "status", default="")
    if command_id != "" &&
      (
        runtime_receipt_status_delivered(status) ||
        (
          runtime_receipt_status_claimed(status) &&
          !runtime_receipt_claim_expired(
            latest_receipts.get(command_id).unwrap_or(receipt),
            lease_now,
          )
        )
      ) {
      dispatched[command_id] = true
    }
  }
  let pending : Array[Json] = []
  for command in commands {
    let command_id = rq_json_string(command, "command_id", default="")
    if command_id != "" && !dispatched.get(command_id).unwrap_or(false) {
      pending.push(Json::string(command_id))
    }
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
    let base_replay_status = if !valid {
      "blocked-invalid"
    } else if delivered {
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
    let order_blocked = replay_blocker_id != "" &&
      base_replay_status != "delivered"
    let replay_status = if order_blocked {
      "blocked-by-prior-command"
    } else {
      base_replay_status
    }
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
    if replay_status == "pending" ||
      replay_status == "failed-pending-retry" ||
      replay_status == "missing-proof-pending-retry" ||
      replay_status == "expired-claim-pending-retry" {
      if first_pending_index < 0 {
        first_pending_index = index
      }
      pending_items.push(item)
      pending_jsonl_lines.push(wire.stringify())
    }
    if replay_blocker_id == "" &&
      (
        base_replay_status == "blocked-invalid" ||
        base_replay_status == "claimed" ||
        base_replay_status == "blocked-tool-authorization"
      ) {
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
    let base_claim_status = if !valid {
      "invalid"
    } else if runtime_receipt_status_delivered(receipt_status) {
      "delivered"
    } else if runtime_receipt_status_claimed(receipt_status) && !expired_claim {
      "claimed"
    } else if tool_authorization_blocked {
      "blocked-tool-authorization"
    } else if expired_claim {
      "claimable"
    } else if previous_dispatch_failed {
      "claimable"
    } else {
      "claimable"
    }
    let order_blocked = order_blocker_id != "" &&
      base_claim_status != "delivered"
    let claim_status = if order_blocked {
      "blocked-by-prior-command"
    } else {
      base_claim_status
    }
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
      (
        base_claim_status == "invalid" ||
        base_claim_status == "claimed" ||
        base_claim_status == "blocked-tool-authorization"
      ) {
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

///|
pub fn runtime_consumer_handoff(
  session_id : String,
  runtime_replay : Json,
  runtime_claim : Json,
  native_ready : Bool,
) -> Json {
  let invalid_count = rq_json_int(
    runtime_claim,
    "invalid_command_count",
    default=0,
  )
  let claimable_count = rq_json_int(
    runtime_claim,
    "claimable_command_count",
    default=0,
  )
  let claimed_count = rq_json_int(
    runtime_claim,
    "claimed_command_count",
    default=0,
  )
  let tool_authorization_blocked_count = rq_json_int(
    runtime_claim,
    "tool_authorization_blocked_command_count",
    default=0,
  )
  let delivered_count = rq_json_int(
    runtime_claim,
    "delivered_command_count",
    default=0,
  )
  let pending_count = rq_json_int(
    runtime_replay,
    "pending_command_count",
    default=0,
  )
  let status = if invalid_count > 0 {
    "blocked-invalid-command"
  } else if tool_authorization_blocked_count > 0 {
    "blocked-tool-authorization"
  } else if claimable_count > 0 {
    "claim-ready"
  } else if claimed_count > 0 {
    "lease-held"
  } else if pending_count > 0 {
    "replay-ready"
  } else if delivered_count > 0 {
    "delivered"
  } else {
    "idle"
  }
  {
    "kind": "mooncode-runtime-consumer-handoff",
    "protocol": "mooncode.v1",
    "session_id": session_id,
    "status": status,
    "native_runtime_ready": native_ready,
    "ready_to_claim": invalid_count == 0 && claimable_count > 0,
    "ready_to_replay": rq_json_bool(
      runtime_replay,
      "replay_ready",
      default=false,
    ),
    "claimable_command_count": claimable_count,
    "claimed_command_count": claimed_count,
    "pending_command_count": pending_count,
    "invalid_command_count": invalid_count,
    "tool_authorization_blocked_command_count": tool_authorization_blocked_count,
    "next_action": runtime_consumer_next_action(status),
    "endpoints": {
      "runtime_claim": "/api/mooncode/sessions/\{session_id}/runtime-claim",
      "runtime_replay": "/api/mooncode/sessions/\{session_id}/runtime-replay",
      "runtime_events": "/api/mooncode/sessions/\{session_id}/runtime-events",
      "runtime_commands": "/api/mooncode/sessions/\{session_id}/runtime-commands",
      "stream": "/api/mooncode/sessions/\{session_id}/stream?format=jsonl&since=<sequence>",
      "native_commands": "/v1/mooncode/sessions/\{session_id}/commands",
      "native_eval_report": "/v1/mooncode/sessions/\{session_id}/eval-report?book_root=<path>",
    },
    "required_loop": [
      "GET runtime-handoff or session-store", "GET runtime-claim", "POST runtime-claim with consumer_id before execution",
      "execute claimed OpenSeek-compatible command with MoonClaw/MoonCode tools",
      "POST runtime-events for streamed reasoning/tool/diff/test/artifact events",
      "POST runtime-replay with runtime-acknowledged or runtime-completed receipt",
      "POST eval-report when native tool/file-edit harness evidence is available",
    ],
    "safety_boundary": "Moondesk records queue, review, and display state; MoonClaw or standalone mooncode must enforce path, tool, shell, approval, test, and package policy before execution.",
  }
}

///|
pub fn runtime_consumer_execution_plan(
  session_id : String,
  runtime_replay : Json,
  runtime_claim : Json,
  native_ready : Bool,
) -> Json {
  let claimable = rq_json_array_items(runtime_claim, "claimable_commands")
  let claimed = rq_json_array_items(runtime_claim, "claimed_commands")
  let invalid = rq_json_array_items(runtime_claim, "invalid_commands")
  let tool_blocked = rq_json_array_items(
    runtime_claim, "tool_authorization_blocked_commands",
  )
  let order_blocked = rq_json_array_items(
    runtime_claim, "order_blocked_commands",
  )
  let pending = rq_json_array_items(runtime_replay, "pending_commands")
  let mut status = "idle"
  let mut operation = "wait"
  let mut item = Json::object({})
  if claimable.length() > 0 {
    status = "ready-to-claim"
    operation = "claim-command"
    item = claimable[0]
  } else if claimed.length() > 0 {
    status = "lease-held"
    operation = "execute-claimed-command"
    item = claimed[0]
  } else if invalid.length() > 0 {
    status = "blocked-invalid-command"
    operation = "repair-command-log"
    item = invalid[0]
  } else if tool_blocked.length() > 0 {
    status = "blocked-tool-authorization"
    operation = "request-tool-approval"
    item = tool_blocked[0]
  } else if order_blocked.length() > 0 {
    status = "blocked-by-prior-command"
    operation = "settle-prior-command"
    item = order_blocked[0]
  } else if pending.length() > 0 {
    status = "replay-ready"
    operation = "claim-command"
    item = pending[0]
  }
  let command = rq_json_object_field_or_empty(item, "runtime_command")
  let summary = rq_json_object_field_or_empty(command, "execution_summary")
  let native_body = rq_json_object_field_or_empty(
    command, "native_mooncode_body",
  )
  let command_id = rq_json_string(item, "command_id", default="")
  let action = rq_json_string(item, "action", default="")
  let required_events = rq_json_string_array_items(summary, "required_events")
  let required_outputs = rq_json_string_array_items(summary, "required_outputs")
  let event_sink = rq_json_string(
    summary,
    "event_sink",
    default="/api/mooncode/sessions/\{session_id}/runtime-events",
  )
  let ack_sink = rq_json_string(
    summary,
    "ack_sink",
    default="/api/mooncode/sessions/\{session_id}/runtime-replay",
  )
  {
    "kind": "mooncode-runtime-consumer-execution-plan",
    "protocol": "mooncode.v1",
    "session_id": session_id,
    "status": status,
    "operation": operation,
    "native_runtime_ready": native_ready,
    "ready_to_claim": status == "ready-to-claim",
    "ready_to_execute": status == "ready-to-claim" || status == "lease-held",
    "ready_to_ack": status == "lease-held",
    "command_id": command_id,
    "action": action,
    "target": rq_json_string(item, "target", default=""),
    "context_path": rq_json_string(item, "context_path", default=""),
    "claim_status": rq_json_string(item, "claim_status", default=""),
    "receipt_status": rq_json_string(item, "receipt_status", default=""),
    "blocked_by_command_id": rq_json_string(
      item,
      "blocked_by_command_id",
      default="",
    ),
    "blocked_by_status": rq_json_string(item, "blocked_by_status", default=""),
    "tool_authorization_state": rq_json_string(
      item,
      "tool_authorization_state",
      default="",
    ),
    "runtime_may_execute_tools": rq_json_bool(
      item,
      "runtime_may_execute_tools",
      default=false,
    ),
    "claim_endpoint": "/api/mooncode/sessions/\{session_id}/runtime-claim",
    "ack_endpoint": ack_sink,
    "runtime_event_ingest_endpoint": event_sink,
    "stream_endpoint": "/api/mooncode/sessions/\{session_id}/stream?format=jsonl&since=<sequence>",
    "native_command_endpoint": "/v1/mooncode/sessions/\{session_id}/commands",
    "claim_request_template": {
      "consumer_id": "moonclaw-or-standalone-mooncode",
      "lease_seconds": 300,
      "command_id": command_id,
    },
    "ack_request_template": {
      "consumer_id": "moonclaw-or-standalone-mooncode",
      "command_id": command_id,
      "status": "runtime-completed",
      "events": [],
    },
    "failure_ack_template": {
      "consumer_id": "moonclaw-or-standalone-mooncode",
      "command_id": command_id,
      "status": "failed",
      "detail": "execution failed",
      "events": [],
    },
    "openseek_wire_command": rq_json_object_field_or_empty(
      command, "openseek_wire_command",
    ),
    "native_mooncode_body": native_body,
    "execution_summary": summary,
    "execution_checklist": rq_json_array_items(summary, "execution_checklist"),
    "required_events": string_array_json(required_events),
    "required_event_count": required_events.length(),
    "required_outputs": string_array_json(required_outputs),
    "required_output_count": required_outputs.length(),
    "completion_rule": rq_json_string(summary, "completion_rule", default=""),
    "next_step": runtime_consumer_execution_next_step(
      status, operation, command_id, action,
    ),
    "safety_boundary": "This is an execution plan, not execution. MoonClaw or standalone mooncode must enforce the embedded tool/path/approval/test contracts before running tools, then stream events and acknowledge through the listed endpoints.",
    "owner": runtime_owner_record(),
  }
}

///|
fn runtime_consumer_execution_next_step(
  status : String,
  operation : String,
  command_id : String,
  action : String,
) -> String {
  let base = match status {
    "ready-to-claim" =>
      "POST runtime-claim for command `\{command_id}`, execute `\{action}` through the native MoonCode/OpenSeek tool loop, stream required events, then POST runtime-replay."
    "lease-held" =>
      "Resume or finish the leased command `\{command_id}`; emit any missing runtime events, then acknowledge completion or failure through runtime-replay."
    "blocked-invalid-command" =>
      "Repair or skip the invalid earlier runtime command before later commands can run."
    "blocked-tool-authorization" =>
      "Resolve tool approval state before MoonClaw executes this command."
    "blocked-by-prior-command" =>
      "Settle the prior blocking runtime command before this command can run."
    "replay-ready" =>
      "Claim the replay-ready command before execution so the lease and acknowledgement trail is durable."
    _ =>
      "No runtime command is currently ready; wait for a prompt, steer, or review command."
  }
  "\{base} Operation: \{operation}."
}

///|
pub fn runtime_dispatch_status(
  session : Json,
  runtime_command : Json,
) -> String {
  let command_id = rq_json_string(runtime_command, "command_id", default="")
  let dispatch_mode = rq_json_string(
    session,
    "mooncode_dispatch_mode",
    default="not-dispatched",
  )
  if runtime_session_command_failed(session, command_id) {
    "failed"
  } else if dispatch_mode == "moonclaw-mooncode-runtime" {
    "native-dispatched"
  } else if dispatch_mode == "moonclaw-task-bridge" {
    "legacy-bridged"
  } else {
    "recorded"
  }
}

///|
pub fn runtime_dispatch_detail(status : String, mode : String) -> String {
  match status {
    "native-dispatched" =>
      "Command was sent to the native MoonClaw MoonCode runtime endpoint."
    "legacy-bridged" =>
      "Command was sent through the legacy MoonClaw task/message bridge while native MoonCode is unavailable."
    "failed" =>
      "Command dispatch failed; inspect the session transcript and runtime events."
    _ =>
      "Command is recorded in the durable runtime feed but has no native dispatch receipt yet. mode=\{mode}"
  }
}

///|
pub fn runtime_dispatch_receipt(
  session : Json,
  runtime_command : Json,
  dispatch_id~ : String,
  created_at~ : String,
) -> Json {
  let dispatch_mode = rq_json_string(
    session,
    "mooncode_dispatch_mode",
    default="not-dispatched",
  )
  let status = runtime_dispatch_status(session, runtime_command)
  {
    "protocol": "mooncode.v1",
    "kind": "mooncode.runtime-dispatch",
    "dispatch_id": dispatch_id,
    "command_id": rq_json_string(runtime_command, "command_id", default=""),
    "session_id": rq_json_string(runtime_command, "session_id", default=""),
    "workspace_id": rq_json_string(session, "workspace_id", default=""),
    "workspace_name": rq_json_string(session, "workspace_name", default=""),
    "task_id": rq_json_string(session, "moonclaw_task_id", default=""),
    "action": rq_json_string(runtime_command, "action", default="prompt"),
    "dispatch": rq_json_string(runtime_command, "dispatch", default="prompt"),
    "status": status,
    "dispatch_mode": dispatch_mode,
    "created_at": created_at,
    "openseek_wire_valid": rq_json_bool(
      runtime_command,
      "openseek_wire_valid",
      default=false,
    ),
    "native_mooncode_endpoint": rq_json_string(
      runtime_command,
      "native_mooncode_endpoint",
      default="",
    ),
    "legacy_bridge_endpoint": "/v1/task/<id>/message",
    "detail": runtime_dispatch_detail(status, dispatch_mode),
    "runtime_command": runtime_command,
    "owner": runtime_owner_record(),
  }
}

///|
pub fn runtime_dispatch_receipt_for_response(
  receipt : Json,
  fallback_dispatch_id~ : String,
) -> Json {
  let with_native = rq_json_with_missing_string(
    receipt, "native_mooncode_endpoint", "",
  )
  let with_legacy = rq_json_with_missing_string(
    with_native, "legacy_bridge_endpoint", "",
  )
  let with_detail = rq_json_with_missing_string(with_legacy, "detail", "")
  let with_dispatch_id = rq_json_with_missing_string(
    with_detail, "dispatch_id", fallback_dispatch_id,
  )
  let with_dispatch_mode = rq_json_with_missing_string(
    with_dispatch_id, "dispatch_mode", "unknown",
  )
  let with_created_at = rq_json_with_missing_string(
    with_dispatch_mode, "created_at", "",
  )
  let with_wire_valid = rq_json_with_missing_bool(
    with_created_at, "openseek_wire_valid", false,
  )
  let with_runtime_command = rq_json_with_missing_json(
    with_wire_valid,
    "runtime_command",
    {},
  )
  rq_json_with_missing_json(with_runtime_command, "owner", {})
}

///|
pub fn runtime_dispatch_receipts_for_response(
  receipts : Array[Json],
) -> Array[Json] {
  [
    for index, receipt in receipts => {
      runtime_dispatch_receipt_for_response(
        receipt,
        fallback_dispatch_id=runtime_dispatch_receipt_fallback_id(
          receipt, index,
        ),
      )
    }
  ]
}

///|
pub fn runtime_dispatch_state_response(
  session_id : String,
  commands : Array[Json],
  dispatch_receipts : Array[Json],
  pending_command_ids : Array[Json],
  workspace_id~ : String,
  workspace_name~ : String,
  task_id~ : String,
  dispatch_mode~ : String,
  runtime_command_log_path~ : String,
  runtime_dispatch_log_path~ : String,
) -> Json {
  {
    "protocol": "mooncode.v1",
    "kind": "mooncode-runtime-dispatch-state",
    "session_id": session_id,
    "workspace_id": workspace_id,
    "workspace_name": workspace_name,
    "task_id": task_id,
    "dispatch_mode": dispatch_mode,
    "runtime_command_count": commands.length(),
    "runtime_dispatch_count": dispatch_receipts.length(),
    "runtime_dispatch_pending_count": pending_command_ids.length(),
    "runtime_command_log_path": runtime_command_log_path,
    "runtime_dispatch_log_path": runtime_dispatch_log_path,
    "dispatch_receipts": Json::array(dispatch_receipts),
    "pending_command_ids": Json::array(pending_command_ids),
    "runtime_protocol": runtime_protocol_contract_json(),
    "owner": runtime_owner_record(),
  }
}

///|
pub fn runtime_dispatch_response(
  session_id : String,
  commands : Array[Json],
  receipts : Array[Json],
  workspace_id~ : String,
  workspace_name~ : String,
  task_id~ : String,
  dispatch_mode~ : String,
  runtime_command_log_path~ : String,
  runtime_dispatch_log_path~ : String,
  lease_now~ : String,
) -> Json {
  let dispatch_receipts = runtime_dispatch_receipts_for_response(receipts)
  runtime_dispatch_state_response(
    session_id,
    commands,
    dispatch_receipts,
    runtime_pending_command_ids(commands, receipts, lease_now~),
    workspace_id~,
    workspace_name~,
    task_id~,
    dispatch_mode~,
    runtime_command_log_path~,
    runtime_dispatch_log_path~,
  )
}

///|
pub fn runtime_command_feed_response(
  session_id : String,
  commands : Array[Json],
  receipts : Array[Json],
  events : Array[Json],
  workspace_id~ : String,
  workspace_name~ : String,
  task_id~ : String,
  runtime_command_log_path~ : String,
  runtime_dispatch_log_path~ : String,
  workspace_root~ : String,
  moonclaw_root~ : String,
  host_base_url~ : String,
  native_ready~ : Bool,
  lease_now~ : String,
) -> Json {
  let dispatch_receipts = runtime_dispatch_receipts_for_response(receipts)
  let replay = runtime_replay_state(
    session_id,
    commands,
    dispatch_receipts,
    workspace_id~,
    workspace_name~,
    task_id~,
    runtime_command_log_path~,
    runtime_dispatch_log_path~,
    lease_now~,
  )
  let claim = runtime_claim_state(
    session_id,
    commands,
    dispatch_receipts,
    workspace_id~,
    workspace_name~,
    task_id~,
    runtime_command_log_path~,
    runtime_dispatch_log_path~,
    lease_now~,
  )
  let lifecycle = runtime_command_lifecycle(
    session_id,
    commands,
    dispatch_receipts,
    events,
    lease_now~,
  )
  let scheduler = serve_scheduler_projection(session_id, commands, lifecycle)
  let turn_packet = runtime_turn_packet(
    session_id, replay, claim, scheduler, native_ready,
  )
  let supervisor = runtime_supervisor_launch_packet(
    session_id,
    turn_packet,
    runtime_consumer_handoff(session_id, replay, claim, native_ready),
    workspace_root~,
    moonclaw_root~,
    host_base_url~,
    native_ready,
  )
  {
    "protocol": "mooncode.v1",
    "kind": "mooncode-runtime-command-feed",
    "session_id": session_id,
    "workspace_id": workspace_id,
    "workspace_name": workspace_name,
    "task_id": task_id,
    "runtime_command_log_path": runtime_command_log_path,
    "runtime_command_count": commands.length(),
    "runtime_dispatch_log_path": runtime_dispatch_log_path,
    "runtime_claim_endpoint": "/api/mooncode/sessions/\{session_id}/runtime-claim",
    "runtime_dispatch_count": dispatch_receipts.length(),
    "runtime_dispatch_pending_count": runtime_dispatch_pending_count(
      commands,
      dispatch_receipts,
      lease_now~,
    ),
    "commands": Json::array(commands),
    "dispatch_receipts": Json::array(dispatch_receipts),
    "runtime_replay": replay,
    "decode_reports": Json::array(
      [
        for command in commands => runtime_command_decode_report(command)
      ],
    ),
    "execution_summaries": Json::array(
      [
        for command in commands => {
          runtime_command_execution_summary_from_record(command)
        }
      ],
    ),
    "command_lifecycle": lifecycle,
    "serve_scheduler": scheduler,
    "runtime_turn_packet": turn_packet,
    "runtime_supervisor": supervisor,
    "wire_protocol": {
      "openseek_serve_commands": Json::array(
        [
          for command in serve_command_names() => Json::string(command)
        ],
      ),
      "native_mooncode_endpoint": "/v1/mooncode/sessions/\{session_id}/commands",
      "ordering_rule": "append-only runtime-commands.jsonl; consume in file order",
    },
    "runtime_protocol": runtime_protocol_contract_json(),
    "runtime_claim_contract": runtime_claim_consumer_contract_json(session_id),
    "owner": runtime_owner_record(),
  }
}

///|
pub fn runtime_command_feed_result_response(
  session_id : String,
  commands : Array[Json],
  receipts : Array[Json],
  events : Array[Json],
  session : Json,
  runtime_command_log_path~ : String,
  runtime_dispatch_log_path~ : String,
  workspace_root~ : String,
  moonclaw_root~ : String,
  host_base_url~ : String,
  native_ready~ : Bool,
  lease_now~ : String,
) -> Json {
  runtime_command_feed_response(
    session_id,
    commands,
    receipts,
    events,
    workspace_id=rq_json_string(session, "workspace_id", default=""),
    workspace_name=rq_json_string(session, "workspace_name", default=""),
    task_id=rq_json_string(session, "moonclaw_task_id", default=""),
    runtime_command_log_path~,
    runtime_dispatch_log_path~,
    workspace_root~,
    moonclaw_root~,
    host_base_url~,
    native_ready~,
    lease_now~,
  )
}

///|
pub fn runtime_execution_plan_response(
  session_id : String,
  commands : Array[Json],
  receipts : Array[Json],
  events : Array[Json],
  workspace_id~ : String,
  workspace_name~ : String,
  task_id~ : String,
  runtime_command_log_path~ : String,
  runtime_dispatch_log_path~ : String,
  workspace_root~ : String,
  moonclaw_root~ : String,
  host_base_url~ : String,
  native_ready~ : Bool,
  lease_now~ : String,
) -> Json {
  let dispatch_receipts = runtime_dispatch_receipts_for_response(receipts)
  let replay = runtime_replay_state(
    session_id,
    commands,
    dispatch_receipts,
    workspace_id~,
    workspace_name~,
    task_id~,
    runtime_command_log_path~,
    runtime_dispatch_log_path~,
    lease_now~,
  )
  let claim = runtime_claim_state(
    session_id,
    commands,
    dispatch_receipts,
    workspace_id~,
    workspace_name~,
    task_id~,
    runtime_command_log_path~,
    runtime_dispatch_log_path~,
    lease_now~,
  )
  let plan = runtime_consumer_execution_plan(
    session_id, replay, claim, native_ready,
  )
  let lifecycle = runtime_command_lifecycle(
    session_id,
    commands,
    dispatch_receipts,
    events,
    lease_now~,
  )
  let scheduler = serve_scheduler_projection(session_id, commands, lifecycle)
  let turn_packet = runtime_turn_packet(
    session_id, replay, claim, scheduler, native_ready,
  )
  rq_json_with_field(
    rq_json_with_field(
      rq_json_with_field(plan, "serve_scheduler", scheduler),
      "runtime_turn_packet",
      turn_packet,
    ),
    "runtime_supervisor",
    runtime_supervisor_launch_packet(
      session_id,
      turn_packet,
      runtime_consumer_handoff(session_id, replay, claim, native_ready),
      workspace_root~,
      moonclaw_root~,
      host_base_url~,
      native_ready,
    ),
  )
}

///|
pub fn runtime_supervisor_response(
  session_id : String,
  commands : Array[Json],
  receipts : Array[Json],
  events : Array[Json],
  workspace_id~ : String,
  workspace_name~ : String,
  task_id~ : String,
  runtime_command_log_path~ : String,
  runtime_dispatch_log_path~ : String,
  workspace_root~ : String,
  moonclaw_root~ : String,
  host_base_url~ : String,
  native_ready~ : Bool,
  lease_now~ : String,
) -> Json {
  let dispatch_receipts = runtime_dispatch_receipts_for_response(receipts)
  let replay = runtime_replay_state(
    session_id,
    commands,
    dispatch_receipts,
    workspace_id~,
    workspace_name~,
    task_id~,
    runtime_command_log_path~,
    runtime_dispatch_log_path~,
    lease_now~,
  )
  let claim = runtime_claim_state(
    session_id,
    commands,
    dispatch_receipts,
    workspace_id~,
    workspace_name~,
    task_id~,
    runtime_command_log_path~,
    runtime_dispatch_log_path~,
    lease_now~,
  )
  let lifecycle = runtime_command_lifecycle(
    session_id,
    commands,
    dispatch_receipts,
    events,
    lease_now~,
  )
  let scheduler = serve_scheduler_projection(session_id, commands, lifecycle)
  let turn_packet = runtime_turn_packet(
    session_id, replay, claim, scheduler, native_ready,
  )
  runtime_supervisor_launch_packet(
    session_id,
    turn_packet,
    runtime_consumer_handoff(session_id, replay, claim, native_ready),
    workspace_root~,
    moonclaw_root~,
    host_base_url~,
    native_ready,
  )
}

///|
fn runtime_command_execution_summary_from_record(command : Json) -> Json {
  match rq_json_object_field(command, "execution_summary") {
    Some(summary) => summary
    None =>
      native_command_execution_summary(
        rq_json_object_field_or_empty(command, "command_packet"),
        rq_json_object_field_or_empty(command, "native_mooncode_body"),
      )
  }
}

///|
fn runtime_dispatch_receipt_fallback_id(receipt : Json, index : Int) -> String {
  let seed = "\{index}:" + receipt.stringify()
  let digest = @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding/utf8.encode(seed).to_fixedarray()),
  )
  "mooncode-runtime-dispatch-" + digest[:16].to_owned()
}

///|
pub fn runtime_receipt_status_delivered(status : String) -> Bool {
  status == "native-dispatched" ||
  status == "legacy-bridged" ||
  status == "runtime-acknowledged" ||
  status == "runtime-completed"
}

///|
pub fn runtime_receipt_status_claimed(status : String) -> Bool {
  status == "runtime-claimed"
}

///|
pub fn runtime_receipt_claim_expired(receipt : Json, now : String) -> Bool {
  let expires_at = rq_json_string(receipt, "lease_expires_at", default="")
  expires_at != "" && now != "" && expires_at <= now
}

///|
fn runtime_command_tool_authorization(command : Json) -> Json {
  rq_json_object_field_or_empty(command, "tool_authorization")
}

///|
fn runtime_command_tool_authorization_state(command : Json) -> String {
  let direct = rq_json_string(command, "tool_authorization_state", default="")
  if direct != "" {
    return direct
  }
  rq_json_string(
    runtime_command_tool_authorization(command),
    "enforcement_state",
    default="",
  )
}

///|
fn runtime_command_tool_authorization_blocks(command : Json) -> Bool {
  let state = runtime_command_tool_authorization_state(command)
  let may_execute = rq_json_bool(
    runtime_command_tool_authorization(command),
    "runtime_may_execute",
    default=true,
  )
  !may_execute ||
  state == "requires-approval" ||
  state == "blocked" ||
  state == "blocked-by-rejected-tool"
}

///|
fn runtime_command_tool_authorization_block_reason(command : Json) -> String {
  let auth = runtime_command_tool_authorization(command)
  let state = runtime_command_tool_authorization_state(command)
  let pending = rq_json_int(auth, "pending_approval_count", default=0)
  let rejected = rq_json_int(auth, "rejected_approval_count", default=0)
  if rejected > 0 {
    "\{rejected} rejected tool approval(s) block runtime execution."
  } else if pending > 0 {
    "\{pending} tool approval(s) are still pending."
  } else if state != "" {
    "Tool authorization state blocks runtime execution: \{state}."
  } else {
    "Tool authorization snapshot blocks runtime execution."
  }
}

///|
pub fn runtime_claim_consumer_contract_json(session_id : String) -> Json {
  {
    "consumer": "moonclaw-or-standalone-mooncode",
    "endpoint": "/api/mooncode/sessions/\{session_id}/runtime-claim",
    "method": "POST",
    "request": {
      "consumer_id": "moonclaw-runtime",
      "max_count": 1,
      "force": false,
      "lease_expires_at": "optional ISO-8601 timestamp supplied by the consumer",
      "now": "optional ISO-8601 clock used to recover expired claims deterministically",
    },
    "claim_status": "runtime-claimed",
    "ack_endpoint": "/api/mooncode/sessions/\{session_id}/runtime-replay",
    "authorization_rule": "commands whose tool_authorization snapshot has runtime_may_execute=false, pending approvals, or rejected approvals are not claimable and block later non-delivered rows until a later command record carries an approving snapshot",
    "ordering_rule": "claim returns pending valid commands in runtime-commands.jsonl order; delivered receipts are skipped, but active claimed, invalid, or tool-authorization-blocked earlier commands block later non-delivered rows unless the active claim expires; force=true is only for lease recovery and does not bypass tool authorization",
    "duplicate_guard": "commands with delivered receipts are never claimable; active claimed receipts block later work unless force=true; expired claimed receipts and failed dispatches become claimable without force; blocked tool authorization never becomes claimable without an approving snapshot",
    "owner": runtime_owner_record(),
  }
}

///|
pub fn runtime_replay_consumer_contract_json(session_id : String) -> Json {
  {
    "consumer": "moonclaw-or-standalone-mooncode",
    "reference": "../openseek/cmd/openseek/serve.mbt",
    "stdin": "JSONL lines from pending_openseek_jsonl or pending_commands[*].openseek_wire_command",
    "stdout": "OpenSeek-compatible JSONL runtime events normalized by Moondesk into MoonCode lanes",
    "claim": "POST /api/mooncode/sessions/\{session_id}/runtime-claim with {consumer_id,max_count,force,lease_expires_at,now} to atomically mark commands as runtime-claimed before execution",
    "ack": "POST /api/mooncode/sessions/\{session_id}/runtime-replay with {consumer_id,command_id,status,detail,events[]} or {receipts:[...]} to append dispatch receipts and optional stream events",
    "session_id": session_id,
    "required_order": "one ordered queue; do not start a later prompt before earlier pending prompt/steer/cancel records are handled",
    "authorization_rule": "do not consume pending_commands whose tool_authorization snapshot has runtime_may_execute=false; resolve tool approvals first",
    "duplicate_guard": "skip command ids with native-dispatched, legacy-bridged, runtime-acknowledged, runtime-completed, active runtime-claimed receipts, or blocked tool authorization; active earlier claims, invalid earlier commands, and tool-authorization-blocked earlier commands block later non-delivered rows; expired claims and failed dispatches are retryable",
    "event_sink": ".moontown/mooncode-sessions/<session-id>/events.jsonl or /v1/mooncode/sessions/<session-id>/stream",
  }
}

///|
fn runtime_consumer_next_action(status : String) -> String {
  match status {
    "blocked-invalid-command" =>
      "repair or skip invalid runtime command records before executing the queue"
    "blocked-tool-authorization" =>
      "resolve pending or rejected tool approvals before claiming runtime commands"
    "claim-ready" =>
      "POST runtime-claim with a stable consumer_id, execute the claimed command, then acknowledge through runtime-replay"
    "lease-held" =>
      "resume the active consumer lease or use force=true only for an operator-approved stale-lease recovery"
    "replay-ready" =>
      "consume pending_openseek_jsonl from runtime-replay if single-consumer leasing is not required"
    "delivered" =>
      "wait for new runtime commands or append runtime events/eval evidence for completed work"
    _ => "wait for a prompt, steer, cancel, test, package, or review command"
  }
}
