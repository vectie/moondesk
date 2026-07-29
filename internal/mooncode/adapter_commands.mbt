///|
priv struct AcceptedCommandPacket {
  command : @mooncode_core.MoonCodeCommand
  status : String
  command_id : String
  created_at : String
  session_id : String
  workspace_id : String
  workspace_name : String
  workspace_root : String
}

///|
pub fn decode_command_submission(
  payload : Json,
) -> Result[@mooncode_core.MoonCodeCommand, String] {
  @mooncode_core.decode_mooncode_command(payload)
}

///|
pub fn command_action(command : @mooncode_core.MoonCodeCommand) -> String {
  command.kind.to_string()
}

///|
pub fn command_message(command : @mooncode_core.MoonCodeCommand) -> String {
  let explicit = command.message
  if explicit != "" {
    return explicit
  }
  let context_path = command_context_path(command)
  let target = if context_path == "" {
    "this MoonBook code workspace"
  } else {
    "`\{context_path}`"
  }
  match command_action(command) {
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
pub fn command_context_path(command : @mooncode_core.MoonCodeCommand) -> String {
  command.context_path
}

///|
fn command_submission_fingerprint(
  command : @mooncode_core.MoonCodeCommand,
) -> String {
  guard @mooncode_core.encode_mooncode_command(command) is Ok(payload) else {
    return ""
  }
  @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding/utf8.encode(payload.stringify()).to_fixedarray()),
  )
}

///|
fn stable_command_id(
  session_id : String,
  command : @mooncode_core.MoonCodeCommand,
) -> String {
  let seed = session_id +
    ":" +
    command.client_turn_id +
    ":" +
    command_submission_fingerprint(command)
  let digest = @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding/utf8.encode(seed).to_fixedarray()),
  )
  "mooncode-command-" + digest[:16].to_owned()
}

///|
fn accepted_command_packet(
  session : Json,
  command : @mooncode_core.MoonCodeCommand,
  created_at : String,
) -> AcceptedCommandPacket {
  {
    command,
    status: "accepted",
    command_id: stable_command_id(
      json_string(session, "id", default=""),
      command,
    ),
    created_at,
    session_id: json_string(session, "id", default=""),
    workspace_id: json_string(session, "workspace_id", default=""),
    workspace_name: json_string(session, "workspace_name", default=""),
    workspace_root: json_string(session, "workspace_root", default=""),
  }
}

///|
fn accepted_command_packet_json(
  accepted : AcceptedCommandPacket,
  session : Json,
  runtime_passthrough : Json,
) -> Json {
  let command = accepted.command
  let fields = match @mooncode_core.encode_mooncode_command(command) {
    Ok(Object(values)) => values.copy()
    _ => Map::new()
  }
  let action = command_action(command)
  fields["protocol"] = protocol_version().to_json()
  fields["kind"] = "mooncode.command".to_json()
  fields["status"] = accepted.status.to_json()
  fields["command_id"] = accepted.command_id.to_json()
  fields["created_at"] = accepted.created_at.to_json()
  fields["session_id"] = accepted.session_id.to_json()
  fields["workspace_id"] = accepted.workspace_id.to_json()
  fields["workspace_name"] = accepted.workspace_name.to_json()
  fields["workspace_root"] = accepted.workspace_root.to_json()
  fields["client_turn_id"] = command.client_turn_id.to_json()
  fields["action"] = action.to_json()
  let surface = adapter_capability_surface(@mooncode_core.mooncode_capability())
  for row in adapter_surface_command_actions(surface) {
    if json_string(row, "action", default="") == action {
      fields["control"] = json_string(row, "control", default="").to_json()
      fields["approval"] = json_string(row, "approval", default="").to_json()
      break
    }
  }
  let model = if command.model == "" {
    json_string(session, "model", default="")
  } else {
    command.model
  }
  fields["model"] = model.to_json()
  fields["web_search"] = command.web_search.to_json()
  fields["runtime_tool_calls"] = Json::array(
    json_array_items(runtime_passthrough, "runtime_tool_calls"),
  )
  Json::object(fields)
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
fn native_payload(
  command : @mooncode_core.MoonCodeCommand,
  runtime_passthrough : Json,
) -> Json {
  let fields = match runtime_passthrough {
    Object(values) => values.copy()
    _ => Map::new()
  }
  fields["planner_guidance"] = planner_guidance()
  match command.planner_max_steps {
    Some(steps) => fields["planner_max_steps"] = steps.to_json()
    None => fields.remove("planner_max_steps")
  }
  Json::object(fields)
}

///|
pub fn native_command_body(
  session : Json,
  command : @mooncode_core.MoonCodeCommand,
  created_at : String,
  runtime_passthrough : Json,
) -> Json {
  let accepted = accepted_command_packet(session, command, created_at)
  let packet = accepted_command_packet_json(
    accepted, session, runtime_passthrough,
  )
  let payload = native_payload(command, runtime_passthrough)
  let calls = json_array_items(payload, "runtime_tool_calls")
  let fields : Map[String, Json] = {
    "protocol": protocol_version().to_json(),
    "command": command_action(command).to_json(),
    "text": command_message(command).to_json(),
    "model": json_string(packet, "model", default="").to_json(),
    "session_id": json_string(session, "id", default="").to_json(),
    "book_root": json_string(
      session,
      "workspace_root",
      default=json_string(session, "cwd", default=""),
    ).to_json(),
    "context_path": command_context_path(command).to_json(),
    "payload": payload,
    "packet": packet,
    "web_search": json_bool(packet, "web_search", default=false).to_json(),
    "runtime_tool_calls": Json::array(calls),
  }
  Json::object(fields)
}
