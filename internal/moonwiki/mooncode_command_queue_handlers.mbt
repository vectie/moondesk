///|
fn mooncode_immediate_queued_session(
  session : Json,
  action~ : String,
  message~ : String,
  context_path~ : String,
  command_packet~ : Json,
  created_at~ : String,
) -> Json {
  let with_event = @mooncode.append_projected_command_event(
    session,
    action~,
    status="queued",
    detail=message,
    created_at~,
    path=context_path,
    command_packet~,
  )
  let with_message = mooncode_session_with_field(
    with_event,
    "last_message",
    message.to_json(),
  )
  let with_status = mooncode_session_with_field(
    with_message,
    "status",
    "queued".to_json(),
  )
  mooncode_session_with_field(with_status, "updated_at", created_at.to_json())
}

///|
fn mooncode_immediate_command_response(
  workspace_root : String,
  session : Json,
  command_packet : Json,
) -> Json {
  let session_id = json_string(session, "id", default="")
  let command_id = json_string(command_packet, "command_id", default="")
  let client_turn_id = mooncode_response_text_or(
    json_string(command_packet, "client_turn_id", default=""),
    fallback=command_id,
  )
  let command_events = json_array_items(session, "mooncode_command_events")
  let projected = @mooncode.session_projection_response(
    session,
    command_events,
    event_log_path=mooncode_event_log_path(workspace_root, session_id),
    append_log_count=command_events.length(),
    command_log_path=mooncode_command_log_path(workspace_root, session_id),
    command_log_count=command_events.length(),
    runtime_command_log_path=mooncode_runtime_command_log_path(
      workspace_root, session_id,
    ),
    runtime_command_log_count=0,
    runtime_receipt_log_path=mooncode_runtime_receipt_log_path(
      workspace_root, session_id,
    ),
    runtime_receipt_log_count=0,
  )
  let conversation = json_object_field_or_empty(
    projected, "mooncode_conversation",
  )
  let turn = mooncode_conversation_turn_for_command(conversation, command_id)
  let turn_id = mooncode_response_text_or(
    json_string(turn, "turn_id", default=""),
    fallback=command_id,
  )
  let payload = mooncode_session_with_field(
    mooncode_session_with_field(
      mooncode_session_with_field(projected, "accepted", true.to_json()),
      "command_id",
      command_id.to_json(),
    ),
    "command_packet",
    command_packet,
  )
  let payload = mooncode_session_with_field(
    mooncode_session_with_field(
      mooncode_session_with_field(
        mooncode_session_with_field(
          payload,
          "client_turn_id",
          client_turn_id.to_json(),
        ),
        "turn_id",
        turn_id.to_json(),
      ),
      "mooncode_turn",
      turn,
    ),
    "mooncode_conversation",
    conversation,
  )
  let payload = mooncode_session_with_field(
    payload,
    "event_log_path",
    mooncode_event_log_path(
      workspace_root,
      json_string(session, "id", default=""),
    ).to_json(),
  )
  let response_status = json_string(session, "status", default="queued")
  api_contract_response(
    payload,
    ok=true,
    status=response_status,
    message=if response_status == "queued" {
      "MoonCode command was saved and queued"
    } else {
      "MoonCode command was saved and runtime started"
    },
    next_action="poll_mooncode_stream",
  )
}

///|
fn mooncode_conversation_turn_for_command(
  conversation : Json,
  command_id : String,
) -> Json {
  if command_id == "" {
    return Json::object({})
  }
  for turn in json_array_items(conversation, "turns") {
    if json_string(turn, "command_id", default="") == command_id {
      return turn
    }
  }
  Json::object({})
}

///|
fn mooncode_response_text_or(text : String, fallback~ : String) -> String {
  let normalized = text.trim().to_owned()
  if normalized == "" {
    fallback
  } else {
    normalized
  }
}

///|
async fn mooncode_native_runtime_ready(daemon : Json) -> Bool {
  match moonclaw_get_json(daemon, "/v1/code/capabilities") {
    Ok(capabilities) =>
      @mooncode.moonclaw_native_capabilities_ready(capabilities)
    Err(_) => false
  }
}

///|
async fn sync_mooncode_native_eval_report(
  workspace_root : String,
  session : Json,
) -> Json {
  let session_id = json_string(session, "id", default="")
  if session_id == "" {
    return session
  }
  let daemon = moonclaw_daemon_status(workspace_root)
  if !json_bool(daemon, "running", default=false) {
    return session
  }
  if !mooncode_native_runtime_ready(daemon) {
    return session
  }
  let endpoint = @mooncode.moonclaw_native_eval_report_endpoint(
    session_id, workspace_root,
  )
  match moonclaw_get_json(daemon, endpoint) {
    Ok(report) =>
      @mooncode.session_with_native_eval_report(session, report, endpoint)
    Err(_) => session
  }
}
