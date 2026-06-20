///|
pub fn runtime_command_decode_report(command : Json) -> Json {
  let protocol_command = rq_json_object_field_or_empty(
    command, "mooncode_command",
  )
  match decode_code_command(protocol_command) {
    Ok(decoded) =>
      {
        "ok": true,
        "protocol": protocol_version(),
        "command_id": rq_json_string(command, "command_id", default=""),
        "code_command": decoded,
        "control": rq_json_string(command, "control", default="prompt"),
      }
    Err(message) =>
      {
        "ok": false,
        "protocol": protocol_version(),
        "command_id": rq_json_string(command, "command_id", default=""),
        "error": message,
        "protocol_command": protocol_command,
      }
  }
}

///|
pub fn runtime_receipt_pending_count(
  commands : Array[Json],
  receipts : Array[Json],
  lease_now? : String = "",
) -> Int {
  runtime_receipt_pending_commands(commands, receipts, lease_now).length()
}

///|
pub fn runtime_pending_command_ids(
  commands : Array[Json],
  receipts : Array[Json],
  lease_now? : String = "",
) -> Array[Json] {
  let pending : Array[Json] = []
  for command in runtime_receipt_pending_commands(commands, receipts, lease_now) {
    let command_id = rq_json_string(command, "command_id", default="")
    pending.push(Json::string(command_id))
  }
  pending
}
