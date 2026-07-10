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
  let native_payload = native_command_payload(payload, action)
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
  let runtime_tool_calls = native_command_runtime_tool_calls(
    native_payload, command_packet,
  )
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
    "payload": native_payload,
    "packet": command_packet,
    "web_search": web_search,
    "runtime_tool_calls": Json::array(runtime_tool_calls),
    "execution_plan": native_command_execution_plan(
      action, context_path, native_payload, command_packet,
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

///|
fn native_command_planner_guidance(action : String) -> Json {
  {
    "kind": "mooncode-planner-guidance",
    "action": action,
    "no_match_policy": "When using shell or search commands to inspect optional source paths, make no-match or missing optional-path cases return exit 0 with a readable message. Do not let a harmless empty search abort the turn.",
    "finish_policy": "If no source files or actionable code task are present, call finish with a concise user-facing answer instead of ending after a failed lookup.",
    "tool_failure_policy": "Reserve failed tool results for real execution failures that prevent a useful answer.",
  }
}

///|
fn native_command_payload(payload : Json, action : String) -> Json {
  let with_steps = if command_json_int(payload, "planner_max_steps", default=0) >
    0 {
    payload
  } else {
    runtime_with_field(payload, "planner_max_steps", (8).to_json())
  }
  runtime_with_field(
    with_steps,
    "planner_guidance",
    native_command_planner_guidance(action),
  )
}

///|
fn native_command_runtime_tool_calls(
  payload : Json,
  command_packet : Json,
) -> Array[Json] {
  let from_payload = json_array_items(payload, "runtime_tool_calls")
  if from_payload.length() > 0 {
    from_payload
  } else {
    json_array_items(command_packet, "runtime_tool_calls")
  }
}
