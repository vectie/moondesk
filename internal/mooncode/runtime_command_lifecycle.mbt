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
    "protocol": protocol_version(),
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
