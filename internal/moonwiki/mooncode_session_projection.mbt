///|
fn mooncode_session_with_field(
  session : Json,
  key : String,
  value : Json,
) -> Json {
  @mooncode.session_with_field(session, key, value)
}

///|
fn mooncode_session_response_defaults(session : Json) -> Json {
  @mooncode.session_response_defaults(session)
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
    "archived": json_bool(projected, "archived", default=false),
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
    "canonical_revision": json_int(conversation, "revision", default=0),
    "canonical_unchanged": false,
  }
}

///|
fn compact_mooncode_session_revision_response(
  workspace_root : String,
  session : Json,
  command_packet : Json,
  since_revision : Int,
) -> Json {
  let response = compact_mooncode_session_command_response(
    workspace_root, session, command_packet,
  )
  let revision = json_int(response, "canonical_revision", default=0)
  if since_revision > 0 && revision == since_revision {
    response
    |> mooncode_session_with_field("mooncode_conversation", Json::null())
    |> mooncode_session_with_field("mooncode_turn", Json::null())
    |> mooncode_session_with_field("canonical_unchanged", true.to_json())
  } else {
    response
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
  turns.last().unwrap_or(Json::object({}))
}

///|
fn compact_mooncode_summary(summary : Json) -> Json {
  {
    "event_count": json_int(summary, "event_count", default=0),
    "verified_test_count": json_int(summary, "verified_test_count", default=0),
    "pending_diff_count": json_int(summary, "pending_diff_count", default=0),
  }
}
