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
