///|
// Runtime dispatch receipt and queue-state response surfaces for MoonCode consumers.

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
fn runtime_dispatch_receipt_fallback_id(receipt : Json, index : Int) -> String {
  let seed = "\{index}:" + receipt.stringify()
  let digest = @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding/utf8.encode(seed).to_fixedarray()),
  )
  "mooncode-runtime-dispatch-" + digest[:16].to_owned()
}
