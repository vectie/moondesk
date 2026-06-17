///|
pub fn runtime_command_record(
  session : Json,
  payload : Json,
  message : String,
  command_packet : Json,
) -> Json {
  let serve_command = openseek_serve_command(message, command_packet)
  let session_id = json_string(session, "id", default="")
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
    "dispatch": json_string(command_packet, "dispatch", default="prompt"),
    "approval": json_string(command_packet, "approval", default="none"),
    "serve_command": json_string(serve_command, "command", default="prompt"),
    "text": json_string(serve_command, "text", default=""),
    "created_at": json_string(command_packet, "created_at", default=""),
    "session_id": session_id,
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "workspace_root": json_string(session, "workspace_root", default=""),
    "task_id": json_string(session, "moonclaw_task_id", default=""),
    "context_path": json_string(command_packet, "context_path", default=""),
    "target": json_string(command_packet, "target", default="moonbook"),
    "openseek_wire_command": serve_command,
    "openseek_wire_valid": serve_wire_valid(serve_command),
    "native_mooncode_endpoint": "/v1/mooncode/sessions/\{session_id}/commands",
    "tool_authorization": tool_authorization,
    "native_mooncode_body": native_body,
    "execution_summary": native_command_execution_summary(
      command_packet, native_body,
    ),
    "command_packet": command_packet,
    "ordering_rule": "OpenSeek-compatible serve commands and native MoonCode command bodies share the same command_id and append order.",
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "extractable_component": "mooncode",
    },
  }
}
