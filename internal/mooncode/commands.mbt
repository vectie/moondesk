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
