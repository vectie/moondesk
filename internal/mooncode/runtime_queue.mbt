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
pub fn runtime_turn_packet(
  session_id : String,
  runtime_replay : Json,
  runtime_claim : Json,
  serve_scheduler : Json,
  native_ready : Bool,
) -> Json {
  let plan = runtime_consumer_execution_plan(
    session_id, runtime_replay, runtime_claim, native_ready,
  )
  let command_id = rq_json_string(plan, "command_id", default="")
  let scheduler_decision = runtime_scheduler_decision_for_command(
    serve_scheduler, command_id,
  )
  let scheduler_effect = rq_json_string(
    scheduler_decision,
    "effect",
    default="none",
  )
  let scheduler_allows_turn = scheduler_effect == "start-turn" ||
    scheduler_effect == "active-turn" ||
    scheduler_effect == "deliver-steer" ||
    scheduler_effect == "queue-steer" ||
    scheduler_effect == "cancel-active" ||
    scheduler_effect == "withdraw-pending" ||
    scheduler_effect == "queue-turn"
  {
    "kind": "mooncode-runtime-turn-packet",
    "protocol": "mooncode.v1",
    "reference": "../openseek/cmd/openseek/serve.mbt",
    "session_id": session_id,
    "status": rq_json_string(plan, "status", default="idle"),
    "operation": rq_json_string(plan, "operation", default="wait"),
    "native_runtime_ready": native_ready,
    "command_id": command_id,
    "action": rq_json_string(plan, "action", default=""),
    "ready_to_claim": rq_json_bool(plan, "ready_to_claim", default=false),
    "ready_to_execute": rq_json_bool(plan, "ready_to_execute", default=false),
    "ready_to_ack": rq_json_bool(plan, "ready_to_ack", default=false),
    "scheduler_effect": scheduler_effect,
    "scheduler_allows_turn": scheduler_allows_turn,
    "scheduler_decision": scheduler_decision,
    "openseek_wire_command": rq_json_object_field_or_empty(
      plan, "openseek_wire_command",
    ),
    "native_mooncode_body": rq_json_object_field_or_empty(
      plan, "native_mooncode_body",
    ),
    "execution_summary": rq_json_object_field_or_empty(
      plan, "execution_summary",
    ),
    "execution_checklist": rq_json_array_items(plan, "execution_checklist"),
    "required_events": rq_json_array_items(plan, "required_events"),
    "required_outputs": rq_json_array_items(plan, "required_outputs"),
    "claim_request_template": rq_json_object_field_or_empty(
      plan, "claim_request_template",
    ),
    "ack_request_template": rq_json_object_field_or_empty(
      plan, "ack_request_template",
    ),
    "failure_ack_template": rq_json_object_field_or_empty(
      plan, "failure_ack_template",
    ),
    "endpoints": {
      "claim": rq_json_string(plan, "claim_endpoint", default=""),
      "ack": rq_json_string(plan, "ack_endpoint", default=""),
      "runtime_events": rq_json_string(
        plan,
        "runtime_event_ingest_endpoint",
        default="",
      ),
      "stream": rq_json_string(plan, "stream_endpoint", default=""),
      "native_commands": rq_json_string(
        plan,
        "native_command_endpoint",
        default="",
      ),
    },
    "runtime_protocol": runtime_protocol_contract_json(),
    "tool_contract": tool_contract_json(),
    "tool_call_wire": tool_call_wire_contract_json(),
    "completion_rule": rq_json_string(plan, "completion_rule", default=""),
    "next_step": rq_json_string(plan, "next_step", default=""),
    "safety_boundary": "This packet is a self-contained turn handoff for MoonClaw or standalone mooncode. Moondesk does not execute it; the runtime must enforce the embedded scheduler, tool, approval, path, test, and package contracts, stream events, then acknowledge through runtime-replay.",
    "owner": runtime_owner_record(),
  }
}

///|
pub fn runtime_supervisor_launch_packet(
  session_id : String,
  turn_packet : Json,
  runtime_consumer : Json,
  workspace_root~ : String,
  moonclaw_root~ : String,
  host_base_url~ : String,
  native_ready : Bool,
) -> Json {
  let command_id = rq_json_string(turn_packet, "command_id", default="")
  let status = rq_json_string(turn_packet, "status", default="idle")
  let operation = rq_json_string(turn_packet, "operation", default="wait")
  let action = rq_json_string(turn_packet, "action", default="")
  let mode = if native_ready {
    "native-mooncode-runtime"
  } else {
    "moondesk-claim-replay-bridge"
  }
  let scheduler_allows_turn = rq_json_bool(
    turn_packet,
    "scheduler_allows_turn",
    default=false,
  )
  let ready_to_execute = rq_json_bool(
    turn_packet,
    "ready_to_execute",
    default=false,
  )
  let ready_to_launch = command_id != "" &&
    ready_to_execute &&
    scheduler_allows_turn
  let endpoints = {
    "session_store": runtime_supervisor_url(
      host_base_url,
      "/api/mooncode/sessions/\{session_id}/session-store",
    ),
    "runtime_handoff": runtime_supervisor_url(
      host_base_url,
      "/api/mooncode/sessions/\{session_id}/runtime-handoff",
    ),
    "runtime_supervisor": runtime_supervisor_url(
      host_base_url,
      "/api/mooncode/sessions/\{session_id}/runtime-supervisor",
    ),
    "runtime_commands": runtime_supervisor_url(
      host_base_url,
      "/api/mooncode/sessions/\{session_id}/runtime-commands",
    ),
    "serve_scheduler": runtime_supervisor_url(
      host_base_url,
      "/api/mooncode/sessions/\{session_id}/serve-scheduler",
    ),
    "claim": runtime_supervisor_url(
      host_base_url,
      runtime_supervisor_endpoint_from_turn(turn_packet, "claim"),
    ),
    "ack": runtime_supervisor_url(
      host_base_url,
      runtime_supervisor_endpoint_from_turn(turn_packet, "ack"),
    ),
    "runtime_events": runtime_supervisor_url(
      host_base_url,
      runtime_supervisor_endpoint_from_turn(turn_packet, "runtime_events"),
    ),
    "stream": runtime_supervisor_url(
      host_base_url,
      runtime_supervisor_endpoint_from_turn(turn_packet, "stream"),
    ),
    "native_commands": runtime_supervisor_url(
      host_base_url,
      runtime_supervisor_endpoint_from_turn(turn_packet, "native_commands"),
    ),
  }
  let packet : Json = {
    "kind": "mooncode-runtime-supervisor-launch",
    "protocol": "mooncode.v1",
    "reference": "../openseek/cmd/openseek/serve.mbt",
    "session_id": session_id,
    "status": status,
    "operation": operation,
    "mode": mode,
    "native_runtime_ready": native_ready,
    "runtime_owner": "moonclaw-or-standalone-mooncode",
    "workspace_root": workspace_root,
    "moonclaw_root": moonclaw_root,
    "host_base_url": host_base_url,
    "command_id": command_id,
    "action": action,
    "scheduler_effect": rq_json_string(
      turn_packet,
      "scheduler_effect",
      default="none",
    ),
    "scheduler_allows_turn": scheduler_allows_turn,
    "ready_to_launch": ready_to_launch,
    "launch_blocked_reason": runtime_supervisor_blocked_reason(
      command_id, status, ready_to_execute, scheduler_allows_turn,
    ),
    "endpoints": endpoints,
    "launch_request": {
      "protocol": "mooncode.v1",
      "session_id": session_id,
      "command_id": command_id,
      "action": action,
      "mode": mode,
      "workspace_root": workspace_root,
      "claim_request": rq_json_object_field_or_empty(
        turn_packet, "claim_request_template",
      ),
      "ack_request": rq_json_object_field_or_empty(
        turn_packet, "ack_request_template",
      ),
      "failure_ack": rq_json_object_field_or_empty(
        turn_packet, "failure_ack_template",
      ),
      "openseek_wire_command": rq_json_object_field_or_empty(
        turn_packet, "openseek_wire_command",
      ),
      "native_mooncode_body": rq_json_object_field_or_empty(
        turn_packet, "native_mooncode_body",
      ),
      "required_events": rq_json_array_items(turn_packet, "required_events"),
      "required_outputs": rq_json_array_items(turn_packet, "required_outputs"),
    },
    "supervisor_loop": [
      {
        "id": "load-session",
        "method": "GET",
        "endpoint": runtime_supervisor_url(
          host_base_url,
          "/api/mooncode/sessions/\{session_id}/session-store",
        ),
        "purpose": "Load durable session, transcript, command log, runtime command log, dispatch receipts, and event log.",
      },
      {
        "id": "claim-command",
        "method": "POST",
        "endpoint": runtime_supervisor_url(
          host_base_url,
          runtime_supervisor_endpoint_from_turn(turn_packet, "claim"),
        ),
        "body": rq_json_object_field_or_empty(
          turn_packet, "claim_request_template",
        ),
        "purpose": "Acquire a lease before executing the command so the runtime trail is auditable.",
      },
      {
        "id": "execute-turn",
        "method": "LOCAL",
        "endpoint": "moonclaw/open-seek-compatible-tool-loop",
        "body": {
          "openseek_wire_command": rq_json_object_field_or_empty(
            turn_packet, "openseek_wire_command",
          ),
          "native_mooncode_body": rq_json_object_field_or_empty(
            turn_packet, "native_mooncode_body",
          ),
        },
        "purpose": "Run the typed MoonClaw/MoonCode agent loop with bounded read, edit, write, shell, moon_check, and finish tools.",
      },
      {
        "id": "stream-events",
        "method": "POST",
        "endpoint": runtime_supervisor_url(
          host_base_url,
          runtime_supervisor_endpoint_from_turn(turn_packet, "runtime_events"),
        ),
        "purpose": "Append assistant deltas, reasoning, tool calls/results, diffs, tests, artifacts, and terminal status.",
      },
      {
        "id": "acknowledge",
        "method": "POST",
        "endpoint": runtime_supervisor_url(
          host_base_url,
          runtime_supervisor_endpoint_from_turn(turn_packet, "ack"),
        ),
        "body": rq_json_object_field_or_empty(
          turn_packet, "ack_request_template",
        ),
        "purpose": "Record runtime-completed, runtime-acknowledged, failed, or cancelled status after proof events are persisted.",
      },
      {
        "id": "report-eval",
        "method": "POST",
        "endpoint": runtime_supervisor_url(
          host_base_url,
          "/v1/mooncode/sessions/\{session_id}/eval-report?book_root=<path>",
        ),
        "purpose": "Attach native tool/file-edit eval harness evidence when available.",
      },
    ],
    "turn_packet": turn_packet,
    "runtime_consumer": runtime_consumer,
    "tool_contract": tool_contract_json(),
    "tool_call_wire": tool_call_wire_contract_json(),
    "safety_boundary": "This launch packet is declarative. Moondesk may expose it and persist it, but MoonClaw or standalone mooncode must own model calls, tool execution, path policy, approvals, tests, diffs, packaging, cancellation, and final acknowledgement.",
    "extractable_component": "mooncode",
  }
  rq_json_with_field(
    packet,
    "readiness",
    runtime_supervisor_readiness_report(packet),
  )
}

///|
pub fn runtime_supervisor_readiness_report(supervisor : Json) -> Json {
  let endpoints = rq_json_object_field_or_empty(supervisor, "endpoints")
  let launch_request = rq_json_object_field_or_empty(
    supervisor, "launch_request",
  )
  let loop_steps = rq_json_array_items(supervisor, "supervisor_loop")
  let missing : Array[String] = []
  if rq_json_string(supervisor, "command_id", default="") == "" {
    missing.push("command_id")
  }
  if !rq_json_bool(supervisor, "scheduler_allows_turn", default=false) {
    missing.push("scheduler_allows_turn")
  }
  if !rq_json_bool(supervisor, "ready_to_launch", default=false) {
    missing.push("ready_to_launch")
  }
  if rq_json_string(endpoints, "session_store", default="") == "" {
    missing.push("endpoint.session_store")
  }
  if rq_json_string(endpoints, "claim", default="") == "" {
    missing.push("endpoint.claim")
  }
  if rq_json_string(endpoints, "ack", default="") == "" {
    missing.push("endpoint.ack")
  }
  if rq_json_string(endpoints, "runtime_events", default="") == "" {
    missing.push("endpoint.runtime_events")
  }
  if rq_json_object_field_or_empty(launch_request, "claim_request").stringify() ==
    "{}" {
    missing.push("launch_request.claim_request")
  }
  if rq_json_object_field_or_empty(launch_request, "ack_request").stringify() ==
    "{}" {
    missing.push("launch_request.ack_request")
  }
  if !runtime_supervisor_has_loop_step(loop_steps, "load-session") {
    missing.push("loop.load-session")
  }
  if !runtime_supervisor_has_loop_step(loop_steps, "claim-command") {
    missing.push("loop.claim-command")
  }
  if !runtime_supervisor_has_loop_step(loop_steps, "execute-turn") {
    missing.push("loop.execute-turn")
  }
  if !runtime_supervisor_has_loop_step(loop_steps, "stream-events") {
    missing.push("loop.stream-events")
  }
  if !runtime_supervisor_has_loop_step(loop_steps, "acknowledge") {
    missing.push("loop.acknowledge")
  }
  let ok = missing.length() == 0
  {
    "kind": "mooncode-runtime-supervisor-readiness",
    "protocol": "mooncode.v1",
    "ok": ok,
    "status": if ok {
      "launch-ready"
    } else {
      "blocked"
    },
    "missing_requirements": Json::array(
      [
        for item in missing => Json::string(item)
      ],
    ),
    "missing_requirement_count": missing.length(),
    "endpoint_ready": rq_json_string(endpoints, "claim", default="") != "" &&
    rq_json_string(endpoints, "ack", default="") != "" &&
    rq_json_string(endpoints, "runtime_events", default="") != "" &&
    rq_json_string(endpoints, "session_store", default="") != "",
    "launch_request_ready": rq_json_object_field_or_empty(
      launch_request, "claim_request",
    ).stringify() !=
    "{}" &&
    rq_json_object_field_or_empty(launch_request, "ack_request").stringify() !=
    "{}",
    "supervisor_loop_ready": runtime_supervisor_has_loop_step(
      loop_steps, "load-session",
    ) &&
    runtime_supervisor_has_loop_step(loop_steps, "claim-command") &&
    runtime_supervisor_has_loop_step(loop_steps, "execute-turn") &&
    runtime_supervisor_has_loop_step(loop_steps, "stream-events") &&
    runtime_supervisor_has_loop_step(loop_steps, "acknowledge"),
    "safety_boundary": "Readiness means the launch packet is well formed for a MoonClaw or standalone mooncode consumer. It does not mean Moondesk may execute tools.",
  }
}

///|
fn runtime_scheduler_decision_for_command(
  serve_scheduler : Json,
  command_id : String,
) -> Json {
  if command_id == "" {
    return Json::object({})
  }
  for decision in rq_json_array_items(serve_scheduler, "decisions") {
    if rq_json_string(decision, "command_id", default="") == command_id {
      return decision
    }
  }
  Json::object({})
}

///|
fn runtime_supervisor_has_loop_step(steps : Array[Json], id : String) -> Bool {
  for step in steps {
    if rq_json_string(step, "id", default="") == id {
      return true
    }
  }
  false
}

///|
fn runtime_supervisor_endpoint_from_turn(
  turn_packet : Json,
  key : String,
) -> String {
  let endpoints = rq_json_object_field_or_empty(turn_packet, "endpoints")
  rq_json_string(endpoints, key, default="")
}

///|
fn runtime_supervisor_url(host_base_url : String, path : String) -> String {
  if host_base_url == "" || path == "" {
    path
  } else {
    "\{host_base_url}\{path}"
  }
}

///|
fn runtime_supervisor_blocked_reason(
  command_id : String,
  status : String,
  ready_to_execute : Bool,
  scheduler_allows_turn : Bool,
) -> String {
  if command_id == "" {
    "no runtime command is ready for execution"
  } else if !scheduler_allows_turn {
    "serve scheduler does not allow this turn yet"
  } else if !ready_to_execute {
    "runtime command status `\{status}` is not executable"
  } else {
    ""
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
pub fn runtime_command_lifecycle(
  session_id : String,
  commands : Array[Json],
  receipts : Array[Json],
  events : Array[Json],
  lease_now? : String = "",
) -> Json {
  let latest_receipts = runtime_latest_receipts(receipts)
  let receipt_statuses = runtime_receipt_statuses(receipts)
  let items : Array[Json] = []
  let mut pending_count = 0
  let mut running_count = 0
  let mut dispatched_count = 0
  let mut completed_count = 0
  let mut failed_count = 0
  let mut blocked_count = 0
  let mut scoped_event_count = 0
  let mut next_command_id = ""
  let mut next_action = ""
  let mut next_status = ""
  for index in 0..<commands.length() {
    let command = commands[index]
    let command_id = rq_json_string(command, "command_id", default="")
    let action = rq_json_string(command, "action", default="prompt")
    let receipt_status = receipt_statuses.get(command_id).unwrap_or("missing")
    let latest_receipt = latest_receipts
      .get(command_id)
      .unwrap_or(Json::object({}))
    let item = runtime_command_lifecycle_item(
      index,
      command,
      receipt_status,
      latest_receipt,
      events,
      lease_now~,
    )
    let status = rq_json_string(item, "status", default="pending")
    match status {
      "pending" => pending_count += 1
      "running" => running_count += 1
      "dispatched" => dispatched_count += 1
      "completed" => completed_count += 1
      "failed" => failed_count += 1
      "blocked-invalid"
      | "blocked-tool-authorization"
      | "blocked-missing-proof" => blocked_count += 1
      _ => ()
    }
    scoped_event_count += rq_json_int(item, "scoped_event_count", default=0)
    if next_command_id == "" && status != "completed" {
      next_command_id = command_id
      next_action = action
      next_status = status
    }
    items.push(item)
  }
  {
    "kind": "mooncode-runtime-command-lifecycle",
    "protocol": "mooncode.v1",
    "session_id": session_id,
    "command_count": items.length(),
    "pending_count": pending_count,
    "running_count": running_count,
    "dispatched_count": dispatched_count,
    "completed_count": completed_count,
    "failed_count": failed_count,
    "blocked_count": blocked_count,
    "scoped_event_count": scoped_event_count,
    "next_command_id": next_command_id,
    "next_action": next_action,
    "next_status": next_status,
    "commands": Json::array(items),
    "rule": "Lifecycle is computed from runtime-commands.jsonl, runtime-dispatches.jsonl, command-scoped runtime events, decode validity, tool authorization, and lease expiry. It is a read-only protocol projection for Moondesk, MoonClaw, and future standalone mooncode consumers.",
  }
}

///|
pub fn runtime_replay_ack_receipts(
  session : Json,
  commands : Array[Json],
  payload : Json,
  dispatch_receipts? : Array[Json] = [],
  prior_events? : Array[Json] = [],
) -> Array[Json] {
  let requests = runtime_replay_ack_requests(payload)
  let latest_receipts = runtime_latest_receipts(dispatch_receipts)
  let now = rq_json_string(payload, "now", default="")
  let receipts : Array[Json] = []
  for request in requests {
    let command_id = rq_json_string(request, "command_id", default="")
    match runtime_command_by_id(commands, command_id) {
      Some(command) =>
        receipts.push(
          runtime_replay_ack_receipt(
            session,
            command,
            request,
            previous_dispatch_receipt=latest_receipts
              .get(command_id)
              .unwrap_or(Json::object({})),
            order_blocker=runtime_replay_ack_order_blocker(
              command_id, commands, latest_receipts, now,
            ),
            prior_events~,
          ),
        )
      None => ()
    }
  }
  receipts
}

///|
pub fn runtime_replay_ack_receipts_with_defaults(
  session : Json,
  commands : Array[Json],
  payload : Json,
  acknowledged_at~ : String,
  dispatch_receipts? : Array[Json] = [],
  prior_events? : Array[Json] = [],
) -> Array[Json] {
  runtime_replay_ack_receipts(
    session,
    commands,
    rq_json_with_missing_string(payload, "acknowledged_at", acknowledged_at),
    dispatch_receipts~,
    prior_events~,
  )
}

///|
pub fn runtime_replay_ack_response(
  session_id : String,
  commands : Array[Json],
  next_receipts : Array[Json],
  ack_receipts : Array[Json],
  events : Array[Json],
  runtime_evidence : Json,
  session : Json,
  workspace_id~ : String,
  workspace_name~ : String,
  task_id~ : String,
  runtime_command_log_path~ : String,
  runtime_dispatch_log_path~ : String,
) -> Json {
  {
    "protocol": "mooncode.v1",
    "kind": "mooncode-runtime-replay-ack",
    "session_id": session_id,
    "accepted_receipt_count": ack_receipts.length(),
    "accepted_event_count": events.length(),
    "receipts": Json::array(ack_receipts),
    "runtime_replay": runtime_replay_state(
      session_id,
      commands,
      next_receipts,
      workspace_id~,
      workspace_name~,
      task_id~,
      runtime_command_log_path~,
      runtime_dispatch_log_path~,
    ),
    "runtime_evidence": runtime_evidence,
    "session": session,
  }
}

///|
pub fn runtime_replay_ack_result_response(
  session_id : String,
  commands : Array[Json],
  next_receipts : Array[Json],
  ack_receipts : Array[Json],
  events : Array[Json],
  runtime_evidence : Json,
  session : Json,
  runtime_command_log_path~ : String,
  runtime_dispatch_log_path~ : String,
) -> Json {
  runtime_replay_ack_response(
    session_id,
    commands,
    next_receipts,
    ack_receipts,
    events,
    runtime_evidence,
    session,
    workspace_id=rq_json_string(session, "workspace_id", default=""),
    workspace_name=rq_json_string(session, "workspace_name", default=""),
    task_id=rq_json_string(session, "moonclaw_task_id", default=""),
    runtime_command_log_path~,
    runtime_dispatch_log_path~,
  )
}

///|
pub fn runtime_claim_receipts(
  session : Json,
  commands : Array[Json],
  receipts : Array[Json],
  payload : Json,
) -> Array[Json] {
  let statuses = runtime_receipt_statuses(receipts)
  let latest_receipts = runtime_latest_receipts(receipts)
  let max_count = runtime_claim_max_count(payload)
  let force = rq_json_bool(payload, "force", default=false)
  let now = rq_json_string(payload, "now", default="")
  let claimed : Array[Json] = []
  for command in commands {
    if claimed.length() >= max_count {
      break
    }
    let command_id = rq_json_string(command, "command_id", default="")
    let status = statuses.get(command_id).unwrap_or("")
    let latest_receipt = latest_receipts
      .get(command_id)
      .unwrap_or(Json::object({}))
    let expired_claim = runtime_receipt_status_claimed(status) &&
      runtime_receipt_claim_expired(latest_receipt, now)
    if runtime_receipt_status_delivered(status) {
      continue
    }
    if command_id == "" ||
      !rq_json_bool(runtime_command_decode_report(command), "ok", default=false) {
      break
    }
    if runtime_command_tool_authorization_blocks(command) {
      break
    }
    if runtime_receipt_status_claimed(status) && !force && !expired_claim {
      break
    }
    claimed.push(
      runtime_claim_receipt(
        session,
        command,
        payload,
        recovered_expired_claim=expired_claim,
        previous_claim_receipt=latest_receipt,
      ),
    )
  }
  claimed
}

///|
pub fn runtime_claim_receipts_with_defaults(
  session : Json,
  commands : Array[Json],
  receipts : Array[Json],
  payload : Json,
  now~ : String,
) -> Array[Json] {
  runtime_claim_receipts(
    session,
    commands,
    receipts,
    rq_json_with_missing_string(
      rq_json_with_missing_string(payload, "now", now),
      "claimed_at",
      now,
    ),
  )
}

///|
pub fn runtime_claim_response(
  session_id : String,
  claim_receipts : Array[Json],
  runtime_replay : Json,
  runtime_claim : Json,
  session : Json,
) -> Json {
  {
    "protocol": "mooncode.v1",
    "kind": "mooncode-runtime-claim",
    "session_id": session_id,
    "claimed_count": claim_receipts.length(),
    "claim_receipts": Json::array(claim_receipts),
    "claimed_commands": Json::array(
      [
        for receipt in claim_receipts => {
          rq_json_object_field_or_empty(receipt, "runtime_command")
        }
      ],
    ),
    "runtime_replay": runtime_replay,
    "claim_state": runtime_claim,
    "consumer_contract": runtime_claim_consumer_contract_json(session_id),
    "session": session,
  }
}

///|
pub fn runtime_claim_result_response(
  session_id : String,
  commands : Array[Json],
  next_receipts : Array[Json],
  claim_receipts : Array[Json],
  session : Json,
  runtime_command_log_path~ : String,
  runtime_dispatch_log_path~ : String,
) -> Json {
  runtime_claim_response(
    session_id,
    claim_receipts,
    runtime_replay_state(
      session_id,
      commands,
      next_receipts,
      workspace_id=rq_json_string(session, "workspace_id", default=""),
      workspace_name=rq_json_string(session, "workspace_name", default=""),
      task_id=rq_json_string(session, "moonclaw_task_id", default=""),
      runtime_command_log_path~,
      runtime_dispatch_log_path~,
    ),
    runtime_claim_state(
      session_id,
      commands,
      next_receipts,
      workspace_id=rq_json_string(session, "workspace_id", default=""),
      workspace_name=rq_json_string(session, "workspace_name", default=""),
      task_id=rq_json_string(session, "moonclaw_task_id", default=""),
      runtime_command_log_path~,
      runtime_dispatch_log_path~,
    ),
    session,
  )
}

///|
pub fn runtime_claim_max_count(payload : Json) -> Int {
  let requested = rq_json_int(payload, "max_count", default=1)
  if requested <= 0 {
    1
  } else if requested > 50 {
    50
  } else {
    requested
  }
}

///|
pub fn runtime_replay_ack_status(ack : Json) -> String {
  let status = rq_json_string(ack, "status", default="")
  match status {
    "runtime-acknowledged"
    | "runtime-completed"
    | "proof-missing"
    | "native-dispatched"
    | "legacy-bridged"
    | "failed"
    | "skipped" => status
    _ =>
      if rq_json_bool(ack, "ok", default=true) {
        "runtime-acknowledged"
      } else {
        "failed"
      }
  }
}

///|
pub fn runtime_replay_ack_detail(status : String) -> String {
  match status {
    "runtime-completed" => "Runtime replay consumer completed the command."
    "proof-missing" =>
      "Runtime replay consumer requested completion, but required command-scoped proof events are missing or failed."
    "failed" => "Runtime replay consumer reported command failure."
    "skipped" => "Runtime replay consumer skipped the command."
    _ => "Runtime replay consumer acknowledged the command."
  }
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

///|
fn runtime_command_lifecycle_item(
  index : Int,
  command : Json,
  receipt_status : String,
  latest_receipt : Json,
  events : Array[Json],
  lease_now~ : String,
) -> Json {
  let command_id = rq_json_string(command, "command_id", default="")
  let action = rq_json_string(command, "action", default="prompt")
  let decode_report = runtime_command_decode_report(command)
  let valid = rq_json_bool(decode_report, "ok", default=false)
  let expired_claim = runtime_receipt_status_claimed(receipt_status) &&
    runtime_receipt_claim_expired(latest_receipt, lease_now)
  let event_counts = runtime_command_lifecycle_event_counts(
    command_id, action, events,
  )
  let status = runtime_command_lifecycle_status(
    valid,
    runtime_command_tool_authorization_blocks(command),
    receipt_status,
    expired_claim,
    event_counts,
  )
  {
    "index": index,
    "command_id": command_id,
    "action": action,
    "dispatch": rq_json_string(command, "dispatch", default="prompt"),
    "serve_command": rq_json_string(command, "serve_command", default="prompt"),
    "created_at": rq_json_string(command, "created_at", default=""),
    "target": rq_json_string(command, "target", default=""),
    "context_path": rq_json_string(command, "context_path", default=""),
    "status": status,
    "receipt_status": receipt_status,
    "latest_receipt": latest_receipt,
    "valid_wire": valid,
    "decode_report": decode_report,
    "tool_authorization_state": runtime_command_tool_authorization_state(
      command,
    ),
    "runtime_may_execute_tools": rq_json_bool(
      runtime_command_tool_authorization(command),
      "runtime_may_execute",
      default=true,
    ),
    "previous_claim_expired": expired_claim,
    "scoped_event_count": rq_json_int(event_counts, "event_count", default=0),
    "running_event_count": rq_json_int(
      event_counts,
      "running_event_count",
      default=0,
    ),
    "done_event_count": rq_json_int(event_counts, "done_event_count", default=0),
    "failed_event_count": rq_json_int(
      event_counts,
      "failed_event_count",
      default=0,
    ),
    "proof_event_count": rq_json_int(
      event_counts,
      "proof_event_count",
      default=0,
    ),
    "lanes": rq_json_object_field_or_empty(event_counts, "lanes"),
    "latest_event_id": rq_json_string(
      event_counts,
      "latest_event_id",
      default="",
    ),
    "latest_event_title": rq_json_string(
      event_counts,
      "latest_event_title",
      default="",
    ),
    "latest_event_status": rq_json_string(
      event_counts,
      "latest_event_status",
      default="",
    ),
    "blocking_reason": runtime_command_lifecycle_blocking_reason(
      status, command, decode_report, receipt_status, expired_claim,
    ),
    "next_step": runtime_command_lifecycle_next_step(status),
  }
}

///|
fn runtime_command_lifecycle_event_counts(
  command_id : String,
  action : String,
  events : Array[Json],
) -> Json {
  let lanes : Array[String] = []
  let mut event_count = 0
  let mut running_event_count = 0
  let mut done_event_count = 0
  let mut failed_event_count = 0
  let mut proof_event_count = 0
  let mut latest_event_id = ""
  let mut latest_event_title = ""
  let mut latest_event_status = ""
  for event in events {
    if !runtime_event_matches_command(event, command_id, action) {
      continue
    }
    event_count += 1
    let lane = rq_json_string(event, "lane", default="")
    if lane != "" && !runtime_string_array_contains(lanes, lane) {
      lanes.push(lane)
    }
    if runtime_lane_is_proof(lane) {
      proof_event_count += 1
    }
    match rq_json_string(event, "status", default="") {
      "running" => running_event_count += 1
      "failed" => failed_event_count += 1
      _ => done_event_count += 1
    }
    latest_event_id = rq_json_string(event, "id", default="")
    latest_event_title = rq_json_string(event, "title", default="")
    latest_event_status = rq_json_string(event, "status", default="")
  }
  {
    "event_count": event_count,
    "running_event_count": running_event_count,
    "done_event_count": done_event_count,
    "failed_event_count": failed_event_count,
    "proof_event_count": proof_event_count,
    "lanes": Json::array([ for lane in lanes => Json::string(lane) ]),
    "latest_event_id": latest_event_id,
    "latest_event_title": latest_event_title,
    "latest_event_status": latest_event_status,
  }
}

///|
fn runtime_event_matches_command(
  event : Json,
  command_id : String,
  action : String,
) -> Bool {
  if command_id == "" {
    return false
  }
  let packet = rq_json_object_field_or_empty(event, "command_packet")
  rq_json_string(packet, "command_id", default="") == command_id &&
  (
    rq_json_string(packet, "action", default="") == "" ||
    rq_json_string(packet, "action", default="") == action
  )
}

///|
fn runtime_command_lifecycle_status(
  valid : Bool,
  tool_authorization_blocks : Bool,
  receipt_status : String,
  expired_claim : Bool,
  event_counts : Json,
) -> String {
  if !valid {
    return "blocked-invalid"
  }
  if tool_authorization_blocks {
    return "blocked-tool-authorization"
  }
  if rq_json_int(event_counts, "failed_event_count", default=0) > 0 ||
    receipt_status == "failed" {
    return "failed"
  }
  if receipt_status == "proof-missing" {
    return "blocked-missing-proof"
  }
  if receipt_status == "runtime-completed" {
    return "completed"
  }
  if rq_json_int(event_counts, "proof_event_count", default=0) > 0 &&
    rq_json_int(event_counts, "running_event_count", default=0) == 0 {
    return "completed"
  }
  if receipt_status == "runtime-acknowledged" ||
    receipt_status == "native-dispatched" ||
    receipt_status == "legacy-bridged" {
    return "dispatched"
  }
  if receipt_status == "runtime-claimed" {
    if expired_claim {
      return "pending"
    }
    return "running"
  }
  if rq_json_int(event_counts, "running_event_count", default=0) > 0 {
    return "running"
  }
  "pending"
}

///|
fn runtime_command_lifecycle_blocking_reason(
  status : String,
  command : Json,
  decode_report : Json,
  receipt_status : String,
  expired_claim : Bool,
) -> String {
  match status {
    "blocked-invalid" =>
      rq_json_string(
        decode_report,
        "error",
        default="runtime command wire cannot be decoded",
      )
    "blocked-tool-authorization" =>
      runtime_command_tool_authorization_block_reason(command)
    "blocked-missing-proof" =>
      "runtime completion acknowledgement is missing required command-scoped proof events"
    "failed" => "runtime dispatch or command-scoped proof event failed"
    "pending" =>
      if expired_claim {
        "previous runtime claim expired; command is ready to reclaim"
      } else if receipt_status == "missing" {
        "command has no runtime receipt yet"
      } else {
        "command is waiting for runtime execution"
      }
    _ => ""
  }
}

///|
fn runtime_command_lifecycle_next_step(status : String) -> String {
  match status {
    "blocked-invalid" => "repair the command record or skip it with audit"
    "blocked-tool-authorization" => "resolve tool approvals before execution"
    "blocked-missing-proof" =>
      "append the missing command-scoped proof events or rerun the command"
    "failed" => "retry the runtime command and preserve failed proof"
    "pending" => "claim or replay this command through MoonClaw/MoonCode"
    "running" => "wait for runtime acknowledgement or recover stale lease"
    "dispatched" =>
      "wait for command-scoped proof or completion acknowledgement"
    "completed" => "no runtime action required"
    _ => "inspect runtime command"
  }
}

///|
fn runtime_claim_receipt(
  session : Json,
  runtime_command : Json,
  payload : Json,
  recovered_expired_claim? : Bool = false,
  previous_claim_receipt? : Json = Json::object({}),
) -> Json {
  let command_id = rq_json_string(runtime_command, "command_id", default="")
  let consumer_id = runtime_safe_id(
    rq_json_string(payload, "consumer_id", default="moonclaw-runtime"),
    fallback="moonclaw-runtime",
  )
  let claimed_at = rq_json_string(payload, "claimed_at", default="")
  let lease_id = runtime_safe_id(
    rq_json_string(payload, "claim_id", default=""),
    fallback="mooncode-runtime-claim:\{command_id}:\{consumer_id}:\{claimed_at}",
  )
  {
    "protocol": "mooncode.v1",
    "kind": "mooncode.runtime-dispatch",
    "dispatch_id": lease_id,
    "claim_id": lease_id,
    "command_id": command_id,
    "session_id": rq_json_string(runtime_command, "session_id", default=""),
    "workspace_id": rq_json_string(session, "workspace_id", default=""),
    "workspace_name": rq_json_string(session, "workspace_name", default=""),
    "task_id": rq_json_string(session, "moonclaw_task_id", default=""),
    "action": rq_json_string(runtime_command, "action", default="prompt"),
    "dispatch": rq_json_string(runtime_command, "dispatch", default="prompt"),
    "status": "runtime-claimed",
    "dispatch_mode": "mooncode-runtime-claim",
    "consumer_id": consumer_id,
    "created_at": claimed_at,
    "claimed_at": claimed_at,
    "lease_expires_at": rq_json_string(payload, "lease_expires_at", default=""),
    "recovered_expired_claim": recovered_expired_claim,
    "previous_claim_id": rq_json_string(
      previous_claim_receipt,
      "claim_id",
      default="",
    ),
    "previous_lease_expires_at": rq_json_string(
      previous_claim_receipt,
      "lease_expires_at",
      default="",
    ),
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
    "legacy_bridge_endpoint": "",
    "runtime_claim_endpoint": "/api/mooncode/sessions/\{rq_json_string(runtime_command, "session_id", default="")}/runtime-claim",
    "runtime_replay_ack_endpoint": "/api/mooncode/sessions/\{rq_json_string(runtime_command, "session_id", default="")}/runtime-replay",
    "detail": "Runtime consumer claimed command for ordered execution; completion must be reported through runtime-replay acknowledgement.",
    "runtime_command": runtime_command,
    "consumer_request": payload,
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw-or-standalone-mooncode",
      "extractable_component": "mooncode",
    },
  }
}

///|
fn runtime_replay_ack_requests(payload : Json) -> Array[Json] {
  let requests = rq_json_array_items(payload, "receipts")
  if requests.length() > 0 {
    return requests
  }
  let command_ids = rq_json_string_array_items(payload, "command_ids")
  if command_ids.length() > 0 {
    return [
      for command_id in command_ids => {
        {
          "command_id": command_id,
          "status": rq_json_string(
            payload,
            "status",
            default="runtime-acknowledged",
          ),
          "detail": rq_json_string(
            payload,
            "detail",
            default="Runtime replay consumer acknowledged command",
          ),
        }
      }
    ]
  }
  let command_id = rq_json_string(payload, "command_id", default="")
  if command_id == "" {
    []
  } else {
    [payload]
  }
}

///|
fn runtime_command_by_id(commands : Array[Json], command_id : String) -> Json? {
  if command_id == "" {
    return None
  }
  for command in commands {
    if rq_json_string(command, "command_id", default="") == command_id {
      return Some(command)
    }
  }
  None
}

///|
fn runtime_replay_ack_order_blocker(
  command_id : String,
  commands : Array[Json],
  latest_receipts : Map[String, Json],
  now : String,
) -> Json {
  for command in commands {
    let current_id = rq_json_string(command, "command_id", default="")
    if current_id == command_id {
      return Json::object({})
    }
    let report = runtime_command_decode_report(command)
    if !rq_json_bool(report, "ok", default=false) {
      return runtime_replay_ack_order_blocker_record(
        current_id,
        status="invalid",
        detail="Earlier runtime command cannot be decoded.",
      )
    }
    if runtime_command_tool_authorization_blocks(command) {
      return runtime_replay_ack_order_blocker_record(
        current_id,
        status="blocked-tool-authorization",
        detail=runtime_command_tool_authorization_block_reason(command),
      )
    }
    let latest = latest_receipts.get(current_id).unwrap_or(Json::object({}))
    let status = rq_json_string(latest, "status", default="missing")
    if runtime_receipt_status_delivered(status) || status == "failed" {
      continue
    }
    if runtime_receipt_status_claimed(status) &&
      runtime_receipt_claim_expired(latest, now) {
      continue
    }
    return runtime_replay_ack_order_blocker_record(
      current_id,
      status~,
      detail="Earlier runtime command is not delivered yet.",
    )
  }
  Json::object({})
}

///|
fn runtime_replay_ack_order_blocker_record(
  command_id : String,
  status~ : String,
  detail~ : String,
) -> Json {
  { "command_id": command_id, "status": status, "detail": detail }
}

///|
fn runtime_replay_ack_order_status(
  previous_dispatch_status : String,
  order_blocker : Json,
  claimed_by_same_consumer : Bool,
) -> String {
  if rq_json_string(order_blocker, "command_id", default="") != "" {
    "blocked-by-prior-command"
  } else if previous_dispatch_status == "runtime-claimed" {
    if claimed_by_same_consumer {
      "matching-claim"
    } else {
      "consumer-mismatch"
    }
  } else if runtime_receipt_status_delivered(previous_dispatch_status) {
    "already-delivered"
  } else if previous_dispatch_status == "failed" {
    "retry-after-failed-dispatch"
  } else {
    "unclaimed-ack"
  }
}

///|
fn runtime_replay_ack_receipt(
  session : Json,
  runtime_command : Json,
  ack : Json,
  previous_dispatch_receipt? : Json = Json::object({}),
  order_blocker? : Json = Json::object({}),
  prior_events? : Array[Json] = [],
) -> Json {
  let command_id = rq_json_string(runtime_command, "command_id", default="")
  let requested_status = runtime_replay_ack_status(ack)
  let consumer_id = runtime_safe_id(
    rq_json_string(ack, "consumer_id", default="mooncode-runtime"),
    fallback="mooncode-runtime",
  )
  let acknowledged_at = rq_json_string(ack, "acknowledged_at", default="")
  let dispatch_id = runtime_safe_id(
    rq_json_string(ack, "dispatch_id", default=""),
    fallback="mooncode-runtime-replay-ack:\{command_id}:\{consumer_id}:\{requested_status}:\{acknowledged_at}",
  )
  let previous_dispatch_status = rq_json_string(
    previous_dispatch_receipt,
    "status",
    default="missing",
  )
  let previous_consumer_id = rq_json_string(
    previous_dispatch_receipt,
    "consumer_id",
    default="",
  )
  let claimed_by_same_consumer = previous_dispatch_status == "runtime-claimed" &&
    previous_consumer_id == consumer_id
  let runtime_event_summary = runtime_replay_ack_event_summary(
    ack, runtime_command, acknowledged_at,
  )
  let proof_gate = runtime_replay_ack_proof_gate(
    runtime_command, runtime_event_summary, prior_events,
  )
  let status = runtime_replay_ack_effective_status(requested_status, proof_gate)
  {
    "protocol": "mooncode.v1",
    "kind": "mooncode.runtime-dispatch",
    "dispatch_id": dispatch_id,
    "command_id": command_id,
    "session_id": rq_json_string(runtime_command, "session_id", default=""),
    "workspace_id": rq_json_string(session, "workspace_id", default=""),
    "workspace_name": rq_json_string(session, "workspace_name", default=""),
    "task_id": rq_json_string(session, "moonclaw_task_id", default=""),
    "action": rq_json_string(runtime_command, "action", default="prompt"),
    "dispatch": rq_json_string(runtime_command, "dispatch", default="prompt"),
    "status": status,
    "requested_status": requested_status,
    "dispatch_mode": "mooncode-runtime-replay",
    "consumer_id": consumer_id,
    "created_at": acknowledged_at,
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
    "replay_ack_endpoint": "/api/mooncode/sessions/\{rq_json_string(runtime_command, "session_id", default="")}/runtime-replay",
    "previous_dispatch_status": previous_dispatch_status,
    "previous_dispatch_id": rq_json_string(
      previous_dispatch_receipt,
      "dispatch_id",
      default="",
    ),
    "previous_claim_id": rq_json_string(
      previous_dispatch_receipt,
      "claim_id",
      default="",
    ),
    "previous_consumer_id": previous_consumer_id,
    "claimed_by_same_consumer": claimed_by_same_consumer,
    "ack_order_status": runtime_replay_ack_order_status(
      previous_dispatch_status, order_blocker, claimed_by_same_consumer,
    ),
    "order_blocker": order_blocker,
    "submitted_event_count": rq_json_int(
      runtime_event_summary,
      "submitted_event_count",
      default=0,
    ),
    "normalized_event_count": rq_json_int(
      runtime_event_summary,
      "normalized_event_count",
      default=0,
    ),
    "proof_event_count": rq_json_int(
      runtime_event_summary,
      "proof_event_count",
      default=0,
    ),
    "runtime_event_summary": runtime_event_summary,
    "proof_gate": proof_gate,
    "required_event_count": rq_json_int(
      proof_gate,
      "required_event_count",
      default=0,
    ),
    "proven_required_event_count": rq_json_int(
      proof_gate,
      "proven_required_event_count",
      default=0,
    ),
    "missing_required_event_count": rq_json_int(
      proof_gate,
      "missing_required_event_count",
      default=0,
    ),
    "failed_required_event_count": rq_json_int(
      proof_gate,
      "failed_required_event_count",
      default=0,
    ),
    "detail": rq_json_string(
      ack,
      "detail",
      default=runtime_replay_ack_detail(status),
    ),
    "runtime_command": runtime_command,
    "consumer_result": ack,
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw-or-standalone-mooncode",
      "extractable_component": "mooncode",
    },
  }
}

///|
fn runtime_replay_ack_effective_status(
  requested_status : String,
  proof_gate : Json,
) -> String {
  if requested_status == "runtime-completed" &&
    rq_json_bool(proof_gate, "completion_blocked", default=false) {
    "proof-missing"
  } else {
    requested_status
  }
}

///|
fn runtime_replay_ack_proof_gate(
  runtime_command : Json,
  runtime_event_summary : Json,
  prior_events : Array[Json],
) -> Json {
  let action = rq_json_string(runtime_command, "action", default="prompt")
  let submitted_events = rq_json_array_items(
    runtime_event_summary, "normalized_events",
  )
  let proof_events : Array[Json] = []
  for event in prior_events {
    proof_events.push(event)
  }
  for event in submitted_events {
    proof_events.push(event)
  }
  let evidence = command_runtime_evidence(
    runtime_command, runtime_command, proof_events,
  )
  let proof_required = runtime_completion_requires_proof(action)
  let status = rq_json_string(evidence, "status", default="missing-evidence")
  let tool_harness_status = rq_json_string(
    evidence,
    "tool_harness_status",
    default="missing-evidence",
  )
  let expected_tool_count = rq_json_int(
    evidence,
    "tool_harness_expected_tool_count",
    default=0,
  )
  let tool_harness_blocked = proof_required &&
    expected_tool_count > 0 &&
    tool_harness_status != "proven" &&
    tool_harness_status != "no-tools"
  let completion_blocked = proof_required &&
    (status != "proven" || tool_harness_blocked)
  {
    "kind": "mooncode-runtime-completion-proof-gate",
    "protocol": "mooncode.v1",
    "action": action,
    "proof_required_for_completion": proof_required,
    "completion_blocked": completion_blocked,
    "status": if completion_blocked {
      "blocked"
    } else if proof_required {
      "passed"
    } else {
      "not-required"
    },
    "evidence_status": status,
    "tool_harness_status": tool_harness_status,
    "tool_harness_completion_blocked": tool_harness_blocked,
    "tool_harness_expected_tool_count": expected_tool_count,
    "tool_harness_proven_tool_count": rq_json_int(
      evidence,
      "tool_harness_proven_tool_count",
      default=0,
    ),
    "tool_harness_missing_tool_count": rq_json_int(
      evidence,
      "tool_harness_missing_tool_count",
      default=0,
    ),
    "tool_harness_failed_tool_count": rq_json_int(
      evidence,
      "tool_harness_failed_tool_count",
      default=0,
    ),
    "prior_event_count": prior_events.length(),
    "submitted_event_count": submitted_events.length(),
    "required_event_count": rq_json_int(
      evidence,
      "required_event_count",
      default=0,
    ),
    "proven_required_event_count": rq_json_int(
      evidence,
      "proven_required_event_count",
      default=0,
    ),
    "missing_required_event_count": rq_json_int(
      evidence,
      "missing_required_event_count",
      default=0,
    ),
    "failed_required_event_count": rq_json_int(
      evidence,
      "failed_required_event_count",
      default=0,
    ),
    "missing_required_events": rq_json_array_items(
      evidence, "missing_required_events",
    ),
    "failed_required_events": rq_json_array_items(
      evidence, "failed_required_events",
    ),
    "rule": "Proof-sensitive actions may not be marked runtime-completed until command-scoped required runtime events and typed tool-harness proof are present either in the prior append log or in this acknowledgement payload.",
  }
}

///|
fn runtime_completion_requires_proof(action : String) -> Bool {
  match action {
    "run_tests"
    | "run_eval"
    | "package"
    | "commit"
    | "accept"
    | "reject"
    | "apply_patch"
    | "revert_patch"
    | "approve_tool"
    | "reject_tool" => true
    _ => false
  }
}

///|
pub fn runtime_replay_ack_normalized_events(
  receipts : Array[Json],
) -> Array[Json] {
  let events : Array[Json] = []
  for receipt in receipts {
    let summary = rq_json_object_field_or_empty(
      receipt, "runtime_event_summary",
    )
    for event in rq_json_array_items(summary, "normalized_events") {
      events.push(event)
    }
  }
  events
}

///|
fn runtime_replay_ack_event_summary(
  ack : Json,
  runtime_command : Json,
  acknowledged_at : String,
) -> Json {
  let command_id = rq_json_string(runtime_command, "command_id", default="")
  let submitted = rq_json_array_items(ack, "events")
  let normalized : Array[Json] = []
  let lanes : Array[String] = []
  let proof_lanes : Array[String] = []
  let mut tool_event_count = 0
  let mut diff_event_count = 0
  let mut test_event_count = 0
  let mut artifact_event_count = 0
  let mut review_event_count = 0
  for index in 0..<submitted.length() {
    let event = submitted[index]
    let fallback_id = if command_id == "" {
      "runtime-ack-event-\{index.to_string()}"
    } else {
      "\{command_id}:runtime-ack-event:\{index.to_string()}"
    }
    match
      normalize_runtime_event(
        event,
        fallback_id~,
        fallback_created_at=acknowledged_at,
      ) {
      Some(normalized_event) => {
        let command_scoped_event = runtime_replay_ack_scoped_event(
          normalized_event, runtime_command,
        )
        normalized.push(command_scoped_event)
        let lane = rq_json_string(command_scoped_event, "lane", default="")
        if lane != "" && !runtime_string_array_contains(lanes, lane) {
          lanes.push(lane)
        }
        if runtime_lane_is_proof(lane) &&
          !runtime_string_array_contains(proof_lanes, lane) {
          proof_lanes.push(lane)
        }
        match lane {
          "tool" => tool_event_count += 1
          "diff" => diff_event_count += 1
          "test" => test_event_count += 1
          "artifact" => artifact_event_count += 1
          "review" => review_event_count += 1
          _ => ()
        }
      }
      None => ()
    }
  }
  let proof_event_count = tool_event_count +
    diff_event_count +
    test_event_count +
    artifact_event_count +
    review_event_count
  {
    "kind": "mooncode-runtime-ack-event-summary",
    "protocol": "mooncode.v1",
    "submitted_event_count": submitted.length(),
    "normalized_event_count": normalized.length(),
    "proof_event_count": proof_event_count,
    "tool_event_count": tool_event_count,
    "diff_event_count": diff_event_count,
    "test_event_count": test_event_count,
    "artifact_event_count": artifact_event_count,
    "review_event_count": review_event_count,
    "lanes": Json::array([ for lane in lanes => Json::string(lane) ]),
    "proof_lanes": Json::array(
      [
        for lane in proof_lanes => Json::string(lane)
      ],
    ),
    "normalized_events": Json::array(normalized),
    "evidence_policy": "Runtime replay acknowledgements may include streamed runtime events; Moondesk normalizes them into lanes so completed commands carry visible proof, not only a terminal receipt.",
  }
}

///|
fn runtime_replay_ack_scoped_event(
  event : Json,
  runtime_command : Json,
) -> Json {
  let packet = rq_json_object_field_or_empty(event, "command_packet")
  if rq_json_string(packet, "command_id", default="") != "" {
    event
  } else {
    rq_json_with_field(
      event,
      "command_packet",
      runtime_replay_ack_command_packet(runtime_command),
    )
  }
}

///|
fn runtime_replay_ack_command_packet(runtime_command : Json) -> Json {
  {
    "protocol": "mooncode.v1",
    "kind": "mooncode.command-ref",
    "command_id": rq_json_string(runtime_command, "command_id", default=""),
    "action": rq_json_string(runtime_command, "action", default="prompt"),
    "dispatch": rq_json_string(runtime_command, "dispatch", default="prompt"),
    "runtime_proof": true,
    "session_id": rq_json_string(runtime_command, "session_id", default=""),
    "task_id": rq_json_string(runtime_command, "task_id", default=""),
  }
}
