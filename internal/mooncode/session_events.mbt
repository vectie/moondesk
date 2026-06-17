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
pub fn append_projected_command_event(
  session : Json,
  action~ : String,
  status~ : String,
  detail~ : String,
  created_at~ : String,
  path? : String = "",
  command_packet? : Json = Json::object({}),
) -> Json {
  append_command_event(
    session,
    action~,
    status~,
    detail~,
    created_at~,
    path~,
    command_packet~,
    event_id=projected_command_event_id(
      action~,
      status~,
      detail~,
      created_at~,
      command_packet~,
    ),
  )
}

///|
fn projected_command_event_id(
  action~ : String,
  status~ : String,
  detail~ : String,
  created_at~ : String,
  command_packet~ : Json,
) -> String {
  json_string(
    command_packet,
    "command_id",
    default=stable_event_id(
      "mooncode-command:" +
      action +
      ":" +
      status +
      ":" +
      created_at +
      ":" +
      detail,
    ),
  )
}

///|
pub fn session_with_manifest_event(
  session : Json,
  manifest_field : String,
  manifest : Json,
  event : Json,
) -> Json {
  let events = session_json_array_items(session, "mooncode_command_events")
  events.push(event)
  session_with_field(
    session_with_field(session, "mooncode_command_events", Json::array(events)),
    manifest_field,
    manifest,
  )
}

///|
pub fn session_with_review_receipt_event(
  session : Json,
  receipt : Json,
  event : Json,
) -> Json {
  session_with_manifest_event(
    session, "mooncode_last_review_receipt", receipt, event,
  )
}

///|
pub fn session_with_package_manifest_events(
  session : Json,
  manifest : Json,
  manifest_event : Json,
  index_manifest : Json,
  index_event : Json,
) -> Json {
  session_with_manifest_event(
    session_with_manifest_event(
      session, "mooncode_last_package_manifest", manifest, manifest_event,
    ),
    "mooncode_last_package_index_manifest",
    index_manifest,
    index_event,
  )
}

///|
pub fn project_session_events_for_session(
  session : Json,
  raw_events : Array[Json],
  durable_events : Array[Json],
  fallback_created_at? : String = "",
) -> Array[Json] {
  let projected : Array[Json] = []
  for event in session_json_array_items(session, "mooncode_events") {
    projected.push(event)
  }
  if raw_events.length() > 0 {
    for event in raw_events {
      match moonclaw_projected_event_record(event, fallback_created_at~) {
        Some(item) => projected.push(item)
        None => ()
      }
    }
  } else {
    for message in session_json_array_items(session, "transcript") {
      projected.push(transcript_message_projected_event(message))
    }
  }
  project_session_events(
    projected,
    session_json_array_items(session, "mooncode_command_events"),
    durable_events,
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
pub fn transcript_message_projected_event(message : Json) -> Json {
  transcript_message_event(
    message,
    fallback_id=stable_event_id("mooncode-message:" + message.stringify()),
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
