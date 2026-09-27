///|
fn mooncode_export_message(message : Json) -> Json {
  let mut image_count = 0
  for part in json_array_items(message, "content_parts") {
    if json_string(part, "type", default="") == "image" {
      image_count += 1
    }
  }
  {
    "text": json_string(message, "content", default=""),
    "image_count": image_count,
  }
}

///|
fn mooncode_export_slot(message : Json?) -> Json {
  match message {
    Some(value) if value is Object(fields) && !fields.is_empty() =>
      mooncode_export_message(value)
    _ => Json::null()
  }
}

///|
fn mooncode_export_conversation(
  session_id : String,
  session : Json,
) -> Result[Json, String] {
  let conversation = json_object_field_or_empty(
    session, "mooncode_conversation",
  )
  guard json_string(conversation, "kind", default="") ==
    @mooncode.conversation_kind() &&
    json_string(conversation, "session_id", default="") == session_id else {
    return Err("Canonical Code conversation is unavailable")
  }
  let turns : Array[Json] = []
  for turn in json_array_items(conversation, "turns") {
    let user = json_object_field(turn, "user")
    let assistant = json_object_field(turn, "assistant")
    turns.push({
      "turn_id": json_string(turn, "turn_id", default=""),
      "status": json_string(turn, "status", default=""),
      "user": mooncode_export_slot(user),
      "assistant": mooncode_export_slot(assistant),
    })
  }
  Ok({
    "kind": "mooncode-conversation-export.v1",
    "session_id": session_id,
    "scope": "visible-messages-only",
    "attachments": "image bytes omitted",
    "turns": Json::array(turns),
  })
}

///|
async fn send_mooncode_export(
  conn : @http.ServerConnection,
  method_ : @http.RequestMethod,
  payload : Json,
) -> Unit {
  conn.send_response(200, "OK", extra_headers={
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
    "content-disposition": "attachment; filename=mooncode-conversation.json",
    "x-content-type-options": "nosniff",
  })
  if method_ is Head {
    conn.end_response()
    return
  }
  conn.write(payload.stringify(indent=2))
  conn.end_response()
}

///|
async fn handle_mooncode_session_export(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  if !mooncode_media_safe_segment(session_id) {
    send_api_error(conn, method_, 404, "Not Found", "Unknown Code session")
    return
  }
  let session = moonclaw_runtime_session_by_id(workspace_root, session_id)
  if json_string(session, "id", default="") != session_id {
    send_api_error(conn, method_, 404, "Not Found", "Unknown Code session")
    return
  }
  match mooncode_export_conversation(session_id, session) {
    Ok(payload) => send_mooncode_export(conn, method_, payload)
    Err(error) =>
      send_api_error(conn, method_, 503, "Service Unavailable", error)
  }
}
