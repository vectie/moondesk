///|
pub fn runtime_command_record(
  session : Json,
  payload : Json,
  message : String,
  command_packet : Json,
) -> Json {
  let code_command = mooncode_code_command(message, command_packet)
  let session_id = json_string(session, "id", default="")
  let model = trimmed_or(
    json_string(
      command_packet,
      "model",
      default=command_model(session, payload),
    ),
    fallback="",
  )
  let tool_authorization = command_tool_authorization_snapshot(
    session, command_packet,
  )
  let native_body = native_command_body(
    session, payload, message, command_packet,
  )
  {
    "protocol": protocol_version(),
    "kind": kind_runtime_command(),
    "command_id": json_string(command_packet, "command_id", default=""),
    "action": json_string(command_packet, "action", default="prompt"),
    "control": json_string(command_packet, "control", default="prompt"),
    "approval": json_string(command_packet, "approval", default="none"),
    "code_command": json_string(code_command, "command", default="prompt"),
    "text": json_string(code_command, "text", default=""),
    "model": model,
    "created_at": json_string(command_packet, "created_at", default=""),
    "session_id": session_id,
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "workspace_root": json_string(session, "workspace_root", default=""),
    "runtime_session_id": session_runtime_session_id(session),
    "context_path": json_string(command_packet, "context_path", default=""),
    "target": json_string(command_packet, "target", default="moonbook"),
    "mooncode_command": code_command,
    "mooncode_command_valid": protocol_command_valid(code_command),
    "native_mooncode_endpoint": "/v1/code/sessions/\{session_id}/commands",
    "tool_authorization": tool_authorization,
    "native_mooncode_body": native_body,
    "execution_summary": native_command_execution_summary(
      command_packet, native_body,
    ),
    "command_packet": command_packet,
    "ordering_rule": "MoonCode code commands and native MoonCode command bodies share the same command_id and append order.",
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "standalone_component": "mooncode",
    },
  }
}
