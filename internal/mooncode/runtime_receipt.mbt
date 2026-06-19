///|
// Runtime receipt and queue-state response surfaces for MoonCode consumers.

///|
pub fn runtime_receipt_status(session : Json, runtime_command : Json) -> String {
  let command_id = rq_json_string(runtime_command, "command_id", default="")
  let runtime_mode = rq_json_string(
    session,
    "mooncode_runtime_mode",
    default="runtime-not-started",
  )
  if runtime_session_command_failed(session, command_id) {
    "failed"
  } else if runtime_mode == "moonclaw-mooncode-runtime" {
    "runtime-accepted"
  } else {
    "recorded"
  }
}

///|
pub fn runtime_receipt_detail(status : String, mode : String) -> String {
  match status {
    "runtime-accepted" =>
      "Command was sent to the native MoonClaw MoonCode runtime endpoint."
    "failed" =>
      "Command runtime failed; inspect the session transcript and runtime events."
    _ =>
      "Command is recorded in the durable runtime feed but has no native runtime receipt yet. mode=\{mode}"
  }
}

///|
pub fn runtime_receipt(
  session : Json,
  runtime_command : Json,
  receipt_id~ : String,
  created_at~ : String,
) -> Json {
  let runtime_mode = rq_json_string(
    session,
    "mooncode_runtime_mode",
    default="runtime-not-started",
  )
  let status = runtime_receipt_status(session, runtime_command)
  {
    "protocol": protocol_version(),
    "kind": kind_runtime_receipt(),
    "receipt_id": receipt_id,
    "command_id": rq_json_string(runtime_command, "command_id", default=""),
    "session_id": rq_json_string(runtime_command, "session_id", default=""),
    "workspace_id": rq_json_string(session, "workspace_id", default=""),
    "workspace_name": rq_json_string(session, "workspace_name", default=""),
    "runtime_session_id": session_runtime_session_id(session),
    "action": rq_json_string(runtime_command, "action", default="prompt"),
    "control": rq_json_string(runtime_command, "control", default="prompt"),
    "status": status,
    "runtime_mode": runtime_mode,
    "created_at": created_at,
    "mooncode_command_valid": rq_json_bool(
      runtime_command,
      "mooncode_command_valid",
      default=false,
    ),
    "native_mooncode_endpoint": rq_json_string(
      runtime_command,
      "native_mooncode_endpoint",
      default="",
    ),
    "detail": runtime_receipt_detail(status, runtime_mode),
    "runtime_command": runtime_command,
    "owner": runtime_owner_record(),
  }
}

///|
pub fn projected_runtime_receipt(
  session : Json,
  runtime_command : Json,
  created_at : String,
) -> Json {
  let command_id = rq_json_string(runtime_command, "command_id", default="")
  let status = runtime_receipt_status(session, runtime_command)
  runtime_receipt(
    session,
    runtime_command,
    receipt_id=stable_runtime_receipt_id(
      command_id + ":" + status + ":" + created_at,
    ),
    created_at~,
  )
}

///|
pub fn runtime_receipt_for_response(
  receipt : Json,
  fallback_receipt_id~ : String,
) -> Json {
  let with_native = rq_json_with_missing_string(
    receipt, "native_mooncode_endpoint", "",
  )
  let with_detail = rq_json_with_missing_string(with_native, "detail", "")
  let with_receipt_id = rq_json_with_missing_string(
    with_detail, "receipt_id", fallback_receipt_id,
  )
  let with_runtime_mode = rq_json_with_missing_string(
    with_receipt_id, "runtime_mode", "unknown",
  )
  let with_created_at = rq_json_with_missing_string(
    with_runtime_mode, "created_at", "",
  )
  let with_command_valid = rq_json_with_missing_bool(
    with_created_at, "mooncode_command_valid", false,
  )
  let with_runtime_command = rq_json_with_missing_json(
    with_command_valid,
    "runtime_command",
    {},
  )
  rq_json_with_missing_json(with_runtime_command, "owner", {})
}

///|
pub fn runtime_receipts_for_response(receipts : Array[Json]) -> Array[Json] {
  [
    for index, receipt in receipts => {
      runtime_receipt_for_response(
        receipt,
        fallback_receipt_id=runtime_receipt_fallback_id(receipt, index),
      )
    }
  ]
}

///|
pub fn runtime_receipt_state_response(
  session_id : String,
  commands : Array[Json],
  runtime_receipts : Array[Json],
  pending_command_ids : Array[Json],
  workspace_id~ : String,
  workspace_name~ : String,
  runtime_session_id~ : String,
  runtime_mode~ : String,
  runtime_command_log_path~ : String,
  runtime_receipt_log_path~ : String,
) -> Json {
  {
    "protocol": protocol_version(),
    "kind": "mooncode-runtime-receipt-state",
    "session_id": session_id,
    "workspace_id": workspace_id,
    "workspace_name": workspace_name,
    "runtime_session_id": runtime_session_id,
    "runtime_mode": runtime_mode,
    "runtime_command_count": commands.length(),
    "runtime_receipt_count": runtime_receipts.length(),
    "runtime_receipt_pending_count": pending_command_ids.length(),
    "runtime_command_log_path": runtime_command_log_path,
    "runtime_receipt_log_path": runtime_receipt_log_path,
    "runtime_receipts": Json::array(runtime_receipts),
    "pending_command_ids": Json::array(pending_command_ids),
    "runtime_protocol": runtime_protocol_contract_json(),
    "owner": runtime_owner_record(),
  }
}

///|
pub fn runtime_receipt_response(
  session_id : String,
  commands : Array[Json],
  receipts : Array[Json],
  workspace_id~ : String,
  workspace_name~ : String,
  runtime_session_id~ : String,
  runtime_mode~ : String,
  runtime_command_log_path~ : String,
  runtime_receipt_log_path~ : String,
  lease_now~ : String,
) -> Json {
  let runtime_receipts = runtime_receipts_for_response(receipts)
  runtime_receipt_state_response(
    session_id,
    commands,
    runtime_receipts,
    runtime_pending_command_ids(commands, receipts, lease_now~),
    workspace_id~,
    workspace_name~,
    runtime_session_id~,
    runtime_mode~,
    runtime_command_log_path~,
    runtime_receipt_log_path~,
  )
}

///|
fn runtime_receipt_fallback_id(receipt : Json, index : Int) -> String {
  let seed = "\{index}:" + receipt.stringify()
  stable_runtime_receipt_id(seed)
}

///|
fn stable_runtime_receipt_id(seed : String) -> String {
  let digest = @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding/utf8.encode(seed).to_fixedarray()),
  )
  "mooncode-runtime-receipt-" + digest[:16].to_owned()
}
