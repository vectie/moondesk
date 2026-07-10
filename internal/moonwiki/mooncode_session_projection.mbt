///|
// MoonCode session event and summary projection.

///|
async fn attach_mooncode_session_projection(
  workspace_root : String,
  session : Json,
) -> Json {
  let session_id = json_string(session, "id", default="")
  let durable_events = read_mooncode_event_log(workspace_root, session_id)
  let durable_commands = read_mooncode_command_log(workspace_root, session_id)
  let durable_runtime_commands = read_mooncode_runtime_command_log(
    workspace_root, session_id,
  )
  let durable_runtime_receipts = read_mooncode_runtime_receipt_log(
    workspace_root, session_id,
  )
  let command_events = mooncode_command_log_events(durable_commands)
  let events = project_mooncode_events(session, command_events, durable_events)
  let log_path = if session_id == "" {
    ""
  } else {
    mooncode_event_log_path(workspace_root, session_id)
  }
  let command_log_path = if session_id == "" {
    ""
  } else {
    mooncode_command_log_path(workspace_root, session_id)
  }
  let runtime_command_log_path = if session_id == "" {
    ""
  } else {
    mooncode_runtime_command_log_path(workspace_root, session_id)
  }
  let runtime_receipt_log_path = if session_id == "" {
    ""
  } else {
    mooncode_runtime_receipt_log_path(workspace_root, session_id)
  }
  @mooncode.session_projection_response(
    session,
    events,
    event_log_path=log_path,
    append_log_count=durable_events.length(),
    command_log_path~,
    command_log_count=durable_commands.length(),
    runtime_command_log_path~,
    runtime_command_log_count=durable_runtime_commands.length(),
    runtime_receipt_log_path~,
    runtime_receipt_log_count=durable_runtime_receipts.length(),
  )
}

///|
fn compact_mooncode_session_command_response(
  workspace_root : String,
  session : Json,
  command_packet : Json,
) -> Json {
  let projected = mooncode_session_response_defaults(session)
  let conversation = json_object_field_or_empty(
    projected, "mooncode_conversation",
  )
  let summary = json_object_field_or_empty(projected, "mooncode_summary")
  let current_turn = compact_mooncode_current_turn(conversation, command_packet)
  let command_id = json_string(command_packet, "command_id", default="")
  let client_turn_id = json_string(command_packet, "client_turn_id", default="")
  {
    "id": json_string(projected, "id", default=""),
    "workspace_id": json_string(projected, "workspace_id", default=""),
    "workspace_name": json_string(projected, "workspace_name", default=""),
    "workspace_root": json_string(projected, "workspace_root", default=""),
    "cwd": json_string(projected, "cwd", default=workspace_root),
    "source": json_string(projected, "source", default=""),
    "mooncode_runtime_session_id": json_string(
      projected,
      "mooncode_runtime_session_id",
      default=json_string(projected, "id", default=""),
    ),
    "title": json_string(projected, "title", default="MoonCode Session"),
    "model": json_string(projected, "model", default=""),
    "status": json_string(projected, "status", default="done"),
    "queued_count": json_int(projected, "queued_count", default=0),
    "created_at": json_string(projected, "created_at", default=""),
    "updated_at": json_string(projected, "updated_at", default=""),
    "last_message": json_string(projected, "last_message", default=""),
    "component": json_string(projected, "component", default="mooncode"),
    "protocol": json_string(
      projected,
      "protocol",
      default=@mooncode.protocol_version(),
    ),
    "client_turn_id": client_turn_id,
    "turn_id": json_string(current_turn, "turn_id", default=command_id),
    "mooncode_turn": current_turn,
    "mooncode_conversation": conversation,
    "mooncode_summary": compact_mooncode_summary(summary),
  }
}

///|
fn compact_mooncode_current_turn(
  conversation : Json,
  command_packet : Json,
) -> Json {
  let client_turn_id = json_string(command_packet, "client_turn_id", default="")
  let command_id = json_string(command_packet, "command_id", default="")
  let turns = json_array_items(conversation, "turns")
  for turn in turns {
    if client_turn_id != "" &&
      json_string(turn, "client_turn_id", default="") == client_turn_id {
      return turn
    }
    if command_id != "" &&
      json_string(turn, "command_id", default="") == command_id {
      return turn
    }
  }
  if turns.length() > 0 {
    turns[turns.length() - 1]
  } else {
    Json::object({})
  }
}

///|
fn compact_mooncode_summary(summary : Json) -> Json {
  {
    "event_count": json_int(summary, "event_count", default=0),
    "verified_test_count": json_int(summary, "verified_test_count", default=0),
    "pending_diff_count": json_int(summary, "pending_diff_count", default=0),
  }
}

///|
fn project_mooncode_events(
  session : Json,
  raw_events : Array[Json],
  durable_events : Array[Json],
) -> Array[Json] {
  @mooncode.project_session_events_for_session(
    session,
    raw_events,
    durable_events,
    projected_created_at=@async.now().to_string(),
  )
}

///|
fn mooncode_command_log_events(commands : Array[Json]) -> Array[Json] {
  let events : Array[Json] = []
  for command in commands {
    let command_id = json_string(command, "command_id", default="")
    if command_id == "" {
      continue
    }
    let action = json_string(command, "action", default="prompt")
    let message = json_string(command, "message", default="")
    let created_at = json_string(command, "created_at", default="")
    let context_path = json_string(command, "context_path", default="")
    events.push(
      @mooncode.command_event(
        action~,
        status="queued",
        detail=message,
        created_at~,
        path=context_path,
        command_packet=command,
        event_id=command_id,
      ),
    )
  }
  events
}
