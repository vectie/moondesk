///|
pub fn command_queue_response(
  session_id : String,
  commands : Array[Json],
  workspace_id~ : String,
  workspace_name~ : String,
  runtime_session_id~ : String,
  command_log_path~ : String,
) -> Json {
  {
    "protocol": protocol_version(),
    "kind": "mooncode-command-queue",
    "session_id": session_id,
    "workspace_id": workspace_id,
    "workspace_name": workspace_name,
    "runtime_session_id": runtime_session_id,
    "command_log_path": command_log_path,
    "command_count": commands.length(),
    "commands": Json::array(commands),
    "ordering_rule": "append-only commands.jsonl; MoonClaw consumes commands in file order",
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "standalone_component": "mooncode",
    },
  }
}

///|
pub fn command_queue_result_response(
  session_id : String,
  commands : Array[Json],
  session : Json,
  command_log_path~ : String,
) -> Json {
  command_queue_response(
    session_id,
    commands,
    workspace_id=json_string(session, "workspace_id", default=""),
    workspace_name=json_string(session, "workspace_name", default=""),
    runtime_session_id=session_runtime_session_id(session),
    command_log_path~,
  )
}
