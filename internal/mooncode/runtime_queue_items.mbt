///|
fn runtime_replay_item(
  index : Int,
  command : Json,
  command_id : String,
  receipt_status : String,
  replay_status : String,
  expired_claim : Bool,
  order_blocked : Bool,
  replay_blocker_id : String,
  replay_blocker_status : String,
  latest_receipt : Json,
  protocol_command : Json,
  report : Json,
) -> Json {
  {
    "index": index,
    "command_id": command_id,
    "action": rq_json_string(command, "action", default="prompt"),
    "control": rq_json_string(command, "control", default="prompt"),
    "code_command": rq_json_string(command, "code_command", default="prompt"),
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
    "mooncode_command": protocol_command,
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
}

///|
fn runtime_claim_item(
  session_id : String,
  index : Int,
  command : Json,
  command_id : String,
  claim_status : String,
  receipt_status : String,
  expired_claim : Bool,
  previous_receipt_failed : Bool,
  previous_completion_missing_proof : Bool,
  tool_authorization_blocked : Bool,
  order_blocked : Bool,
  order_blocker_id : String,
  order_blocker_status : String,
  latest_receipt : Json,
  report : Json,
) -> Json {
  {
    "index": index,
    "command_id": command_id,
    "action": rq_json_string(command, "action", default="prompt"),
    "control": rq_json_string(command, "control", default="prompt"),
    "code_command": rq_json_string(command, "code_command", default="prompt"),
    "created_at": rq_json_string(command, "created_at", default=""),
    "target": rq_json_string(command, "target", default=""),
    "context_path": rq_json_string(command, "context_path", default=""),
    "claim_status": claim_status,
    "receipt_status": receipt_status,
    "previous_claim_expired": expired_claim,
    "previous_receipt_failed": previous_receipt_failed,
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
}
