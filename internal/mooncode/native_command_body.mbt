///|
// MoonCode native command body assembly.

///|
pub fn native_command_body(
  session : Json,
  payload : Json,
  message : String,
  command_packet : Json,
) -> Json {
  let action = json_string(command_packet, "action", default="prompt")
  let context_path = json_string(command_packet, "context_path", default="")
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
  let web_search = json_bool(command_packet, "web_search", default=false)
  {
    "protocol": protocol_version(),
    "command": action,
    "text": message,
    "model": model,
    "session_id": json_string(session, "id", default=""),
    "book_root": json_string(
      session,
      "workspace_root",
      default=json_string(session, "cwd", default=""),
    ),
    "context_path": context_path,
    "payload": payload,
    "packet": command_packet,
    "web_search": web_search,
    "execution_plan": native_command_execution_plan(
      action, context_path, payload, command_packet,
    ),
    "tool_authorization": tool_authorization,
    "tool_contract": native_command_tool_contract_for_command(
      action, web_search,
    ),
    "result_contract": native_command_result_contract(action),
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "artifact": "moonbook",
      "standalone_component": "mooncode",
    },
  }
}
