///|
pub fn command_packet(
  session : Json,
  payload : Json,
  action : String,
  message : String,
  created_at : String,
  context_path : String,
  command_id~ : String,
) -> Json {
  let workspace_id = json_string(session, "workspace_id", default="")
  let task_id = json_string(session, "moonclaw_task_id", default="")
  {
    "protocol": "mooncode.v1",
    "kind": "mooncode.command",
    "command_id": command_id,
    "action": action,
    "dispatch": command_dispatch(action),
    "approval": command_approval(action),
    "created_at": created_at,
    "session_id": json_string(session, "id", default=""),
    "workspace_id": workspace_id,
    "workspace_name": json_string(session, "workspace_name", default=""),
    "workspace_root": json_string(session, "workspace_root", default=""),
    "task_id": task_id,
    "context_path": context_path,
    "target": if context_path == "" {
      "moonbook"
    } else {
      context_path
    },
    "message": message,
    "web_search": json_bool(payload, "web_search", default=false),
    "force_preflight": json_bool(payload, "force_preflight", default=false),
    "expected_lanes": string_array_json(command_expected_lanes(action)),
    "tool_hints": string_array_json(command_tool_hints(action)),
    "output_contract": {
      "owner": "moonbook",
      "roots": [
        "tools/", "apps/", "book/site/generated/", "portable/app-tool/", "wiki/reviews/",
        "raw/analysis-runs/",
      ],
      "review_required": command_approval(action) == "operator",
    },
    "boundary": {
      "ui_owner": "moondesk",
      "runtime_owner": "moonclaw",
      "artifact_owner": "moonbook",
      "extractable_component": "mooncode",
    },
  }
}

///|
pub fn command_event(
  action~ : String,
  status~ : String,
  detail~ : String,
  created_at~ : String,
  path~ : String,
  command_packet~ : Json,
  event_id~ : String,
) -> Json {
  event_record(
    id=event_id,
    lane=command_lane(action),
    kind="command.\{action}",
    title=command_title(action, status),
    status~,
    created_at~,
    detail~,
    path~,
    command=action,
    command_packet~,
  )
}

///|
pub fn command_runtime_message(
  message : String,
  command_packet : Json,
) -> String {
  message +
  "\n\nMoonCode command packet (JSON, protocol mooncode.v1):\n```json\n" +
  command_packet.stringify(indent=2) +
  "\n```\nUse this packet as the durable command contract. Keep all edits inside the selected MoonBook workspace, emit tool/diff/test/artifact/review events when available, and preserve the output contract."
}

///|
pub fn openseek_serve_command(message : String, command_packet : Json) -> Json {
  let dispatch = json_string(command_packet, "dispatch", default="command")
  let action = json_string(command_packet, "action", default="prompt")
  match dispatch {
    "cancel" => { "command": "cancel" }
    "steer" =>
      {
        "command": "steer",
        "text": command_runtime_message(message, command_packet),
      }
    "prompt" =>
      {
        "command": "prompt",
        "text": command_runtime_message(message, command_packet),
      }
    _ =>
      {
        "command": "prompt",
        "text": "MoonCode action `\{action}` requested.\n\n" +
        command_runtime_message(message, command_packet),
      }
  }
}

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
    "protocol": "mooncode.v1",
    "kind": "mooncode.runtime-command",
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
