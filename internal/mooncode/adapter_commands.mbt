///|
pub fn command_action(payload : Json) -> String {
  trimmed_or(json_string(payload, "action", default="note"), fallback="note")
}

///|
pub fn command_context_path(payload : Json) -> String {
  trimmed_or(json_string(payload, "context_path", default=""), fallback="")
}

///|
pub fn command_is_supported(action : String) -> Bool {
  @mooncode_core.command_action_is_supported(action)
}

///|
fn command_target_label(payload : Json) -> String {
  let context_path = command_context_path(payload)
  if context_path == "" {
    "this MoonBook code workspace"
  } else {
    "`\{context_path}`"
  }
}

///|
pub fn command_message(action : String, payload : Json) -> String {
  let explicit = trimmed_or(
    json_string(payload, "message", default=""),
    fallback="",
  )
  if explicit != "" {
    return explicit
  }
  let target = command_target_label(payload)
  match action {
    "run_tests" =>
      "Run the relevant tests for \{target} and report the exact result."
    "run_build" =>
      "Run the relevant build checks for \{target} and report the exact result."
    "run_eval" =>
      "Run the MoonCode eval harnesses for \{target} and report the evidence."
    "package" =>
      "Package the accepted executable output for \{target} and report its location."
    "commit" =>
      "Commit the accepted and tested changes for \{target} and report the commit."
    "accept" => "Accept the current useful changes for \{target}."
    "reject" => "Reject the current proposed changes for \{target}."
    "approve_tool" => "Approve the selected MoonCode tool call for \{target}."
    "reject_tool" => "Reject the selected MoonCode tool call for \{target}."
    "apply_patch" => "Apply the selected reviewed patch for \{target}."
    "revert_patch" => "Revert the selected patch for \{target}."
    "cancel" => "Cancel the current MoonCode work for this session."
    "steer" => "Continue the current MoonCode session with this guidance."
    "prompt" => "Continue the current MoonCode session for this MoonBook."
    _ => "MoonCode note recorded."
  }
}

///|
fn command_model(session : Json, payload : Json) -> String {
  trimmed_or(
    json_string(
      payload,
      "model",
      default=json_string(session, "model", default=""),
    ),
    fallback="",
  )
}

///|
fn stable_command_id(seed : String) -> String {
  let digest = @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding/utf8.encode(seed).to_fixedarray()),
  )
  "mooncode-command-" + digest[:16].to_owned()
}

///|
pub fn projected_command_packet(
  session : Json,
  payload : Json,
  action : String,
  message : String,
  created_at : String,
  context_path : String,
) -> Json {
  let session_id = json_string(session, "id", default="")
  let command_id = stable_command_id(
    session_id +
    ":" +
    action +
    ":" +
    created_at +
    ":" +
    context_path +
    ":" +
    message,
  )
  let client_turn_id = trimmed_or(
    json_string(payload, "client_turn_id", default=""),
    fallback=command_id,
  )
  {
    "protocol": protocol_version(),
    "kind": "mooncode.command",
    "command_id": command_id,
    "client_turn_id": client_turn_id,
    "action": action,
    "control": @mooncode_core.command_action_control(action),
    "approval": @mooncode_core.command_action_approval(action),
    "created_at": created_at,
    "session_id": session_id,
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "workspace_root": json_string(session, "workspace_root", default=""),
    "context_path": context_path,
    "message": message,
    "model": command_model(session, payload),
    "web_search": json_bool(payload, "web_search", default=false),
    "runtime_tool_calls": Json::array(
      json_array_items(payload, "runtime_tool_calls"),
    ),
  }
}

///|
fn planner_guidance() -> Json {
  {
    "no_match_policy": "Treat an empty optional search as a useful result, not a failed turn.",
    "finish_policy": "Always finish with a concise user-facing answer when no more tool work is needed.",
    "tool_failure_policy": "Report real execution failures and continue when a bounded fallback exists.",
  }
}

///|
fn native_payload(payload : Json) -> Json {
  let with_steps = if json_int(payload, "planner_max_steps", default=0) > 0 {
    payload
  } else {
    json_with_field(payload, "planner_max_steps", (8).to_json())
  }
  json_with_field(with_steps, "planner_guidance", planner_guidance())
}

///|
pub fn native_command_body(
  session : Json,
  payload : Json,
  message : String,
  command_packet : Json,
) -> Json {
  let prepared_payload = native_payload(payload)
  let calls = json_array_items(prepared_payload, "runtime_tool_calls")
  let runtime_tool_calls = if calls.is_empty() {
    json_array_items(command_packet, "runtime_tool_calls")
  } else {
    calls
  }
  {
    "protocol": protocol_version(),
    "command": json_string(command_packet, "action", default="prompt"),
    "text": message,
    "model": json_string(
      command_packet,
      "model",
      default=command_model(session, payload),
    ),
    "session_id": json_string(session, "id", default=""),
    "book_root": json_string(
      session,
      "workspace_root",
      default=json_string(session, "cwd", default=""),
    ),
    "context_path": json_string(command_packet, "context_path", default=""),
    "payload": prepared_payload,
    "packet": command_packet,
    "web_search": json_bool(command_packet, "web_search", default=false),
    "runtime_tool_calls": Json::array(runtime_tool_calls),
  }
}
