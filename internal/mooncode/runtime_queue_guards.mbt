///|
// Shared MoonCode runtime queue receipt and tool-authorization guards.

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
