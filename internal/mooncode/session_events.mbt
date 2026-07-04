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
  projected_created_at? : String = "",
) -> Array[Json] {
  let projected : Array[Json] = []
  let command_events = session_json_array_items(
    session, "mooncode_command_events",
  )
  for event in session_json_array_items(session, "mooncode_events") {
    projected.push(event)
  }
  if raw_events.length() > 0 {
    for event in raw_events {
      if json_string(event, "lane", default="") != "" &&
        json_string(event, "kind", default="") != "" {
        projected.push(
          canonical_event_record(
            event,
            fallback_id=runtime_event_fallback_id(event),
            fallback_created_at=projected_created_at,
          ),
        )
      } else {
        match
          normalize_runtime_event_with_defaults(
            event,
            fallback_created_at=projected_created_at,
          ) {
          Some(item) => projected.push(item)
          None => ()
        }
      }
    }
  }
  project_session_events(projected, command_events, durable_events)
}

///|
pub fn session_with_field(base : Json, key : String, value : Json) -> Json {
  match base {
    Object(fields) => {
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
    Object(fields) =>
      match fields.get(key) {
        Some(Array(items)) => [ for item in items => item ]
        _ => []
      }
    _ => []
  }
}
