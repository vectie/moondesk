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

///|
test "mooncode appends command event to durable session events" {
  let session = append_command_event(
    { "id": "agent-demo" },
    action="run_tests",
    status="queued",
    detail="Run tests",
    created_at="2026-06-16T00:00:00Z",
    path="tools/demo/main.mbt",
    command_packet={ "command_id": "cmd-run-tests", "action": "run_tests" },
    event_id="cmd-run-tests",
  )
  let events = session_json_array_items(session, "mooncode_command_events")
  assert_eq(events.length(), 1)
  assert_eq(
    json_string(session, "updated_at", default=""),
    "2026-06-16T00:00:00Z",
  )
  assert_eq(json_string(events[0], "id", default=""), "cmd-run-tests")
  assert_eq(json_string(events[0], "lane", default=""), "test")
  assert_eq(json_string(events[0], "kind", default=""), "command.run_tests")
  assert_eq(json_string(events[0], "command", default=""), "run_tests")
}
