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
  let runtime_session_id = session_runtime_session_id(session)
  let model = command_model(session, payload)
  let web_search = json_bool(payload, "web_search", default=false)
  let runtime_tool_calls = json_array_items(payload, "runtime_tool_calls")
  {
    "protocol": protocol_version(),
    "kind": kind_command(),
    "command_id": command_id,
    "client_turn_id": trimmed_or(
      json_string(payload, "client_turn_id", default=""),
      fallback=command_id,
    ),
    "action": action,
    "control": command_control(action),
    "approval": command_approval(action),
    "created_at": created_at,
    "session_id": json_string(session, "id", default=""),
    "workspace_id": workspace_id,
    "workspace_name": json_string(session, "workspace_name", default=""),
    "workspace_root": json_string(session, "workspace_root", default=""),
    "runtime_session_id": runtime_session_id,
    "context_path": context_path,
    "target": if context_path == "" {
      "moonbook"
    } else {
      context_path
    },
    "message": message,
    "model": model,
    "web_search": web_search,
    "runtime_tool_calls": Json::array(runtime_tool_calls),
    "force_preflight": json_bool(payload, "force_preflight", default=false),
    "expected_lanes": string_array_json(command_expected_lanes(action)),
    "tool_hints": string_array_json(
      command_tool_hints_for_command(action, web_search),
    ),
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
      "standalone_component": "mooncode",
    },
  }
}

///|
fn command_tool_hints_for_command(
  action : String,
  web_search : Bool,
) -> Array[String] {
  let hints : Array[String] = []
  for hint in command_tool_hints(action) {
    hints.push(hint)
  }
  if web_search {
    if !hints.contains(@mooncode_core.runtime_tool_web_search()) {
      hints.push(@mooncode_core.runtime_tool_web_search())
    }
    if !hints.contains(@mooncode_core.runtime_tool_web_fetch()) {
      hints.push(@mooncode_core.runtime_tool_web_fetch())
    }
  }
  hints
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
pub fn projected_command_packet(
  session : Json,
  payload : Json,
  action : String,
  message : String,
  created_at : String,
  context_path : String,
) -> Json {
  command_packet(
    session,
    payload,
    action,
    message,
    created_at,
    context_path,
    command_id=stable_command_id(
      action + ":" + created_at + ":" + context_path + ":" + message,
    ),
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
