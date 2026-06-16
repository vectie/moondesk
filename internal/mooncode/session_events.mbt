///|
pub fn append_command_event(
  session : Json,
  action~ : String,
  status~ : String,
  detail~ : String,
  created_at~ : String,
  path~ : String,
  command_packet~ : Json,
  event_id~ : String,
) -> Json {
  let events = session_json_array_items(session, "mooncode_command_events")
  events.push(
    command_event(
      action~,
      status~,
      detail~,
      created_at~,
      path~,
      command_packet~,
      event_id~,
    ),
  )
  session_with_field(
    session_with_field(session, "mooncode_command_events", Json::array(events)),
    "updated_at",
    created_at.to_json(),
  )
}

///|
pub fn transcript_message_event(message : Json, fallback_id~ : String) -> Json {
  let role = json_string(message, "role", default="status")
  let lane = match role {
    "assistant" | "user" => "transcript"
    "tool" => "tool"
    _ => "runtime"
  }
  event_record(
    id=json_string(message, "id", default=fallback_id),
    lane~,
    kind=role,
    title=transcript_role_title(role),
    status=json_string(message, "status", default="done"),
    created_at=json_string(message, "created_at", default=""),
    detail=json_string(message, "content", default=""),
  )
}

///|
fn transcript_role_title(role : String) -> String {
  match role {
    "user" => "User prompt"
    "assistant" => "Assistant response"
    "tool" => "Tool result"
    _ => "Runtime status"
  }
}

///|
fn session_with_field(base : Json, key : String, value : Json) -> Json {
  match base {
    Json::Object(fields) => {
      let next : Map[String, Json] = {}
      for item in fields {
        next[item.0] = item.1
      }
      next[key] = value
      Json::object(next)
    }
    _ => base
  }
}

///|
fn session_json_array_items(json : Json, key : String) -> Array[Json] {
  match json {
    Json::Object(fields) =>
      match fields.get(key) {
        Some(Json::Array(items)) => [ for item in items => item ]
        _ => []
      }
    _ => []
  }
}
