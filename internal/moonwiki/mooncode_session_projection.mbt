///|
// MoonCode session event and summary projection.

///|
async fn attach_mooncode_session_projection(
  workspace_root : String,
  session : Json,
) -> Json {
  let raw_events = read_mooncode_raw_events(session)
  let session_id = json_string(session, "id", default="")
  let durable_events = read_mooncode_event_log(workspace_root, session_id)
  let durable_commands = read_mooncode_command_log(workspace_root, session_id)
  let durable_runtime_commands = read_mooncode_runtime_command_log(
    workspace_root, session_id,
  )
  let durable_runtime_dispatches = read_mooncode_runtime_dispatch_log(
    workspace_root, session_id,
  )
  let events = project_mooncode_events(session, raw_events, durable_events)
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
  let runtime_dispatch_log_path = if session_id == "" {
    ""
  } else {
    mooncode_runtime_dispatch_log_path(workspace_root, session_id)
  }
  let summary_session = agent_session_with_field(
    agent_session_with_field(
      agent_session_with_field(
        agent_session_with_field(
          agent_session_with_field(
            agent_session_with_field(
              agent_session_with_field(
                agent_session_with_field(
                  session,
                  "mooncode_event_log_path",
                  log_path.to_json(),
                ),
                "mooncode_runtime_dispatch_log_path",
                runtime_dispatch_log_path.to_json(),
              ),
              "mooncode_runtime_dispatch_log_count",
              durable_runtime_dispatches.length().to_json(),
            ),
            "mooncode_runtime_command_log_path",
            runtime_command_log_path.to_json(),
          ),
          "mooncode_runtime_command_log_count",
          durable_runtime_commands.length().to_json(),
        ),
        "mooncode_append_log_count",
        durable_events.length().to_json(),
      ),
      "mooncode_command_log_path",
      command_log_path.to_json(),
    ),
    "mooncode_command_log_count",
    durable_commands.length().to_json(),
  )
  let summary = @mooncode.session_summary(summary_session, events)
  let next = agent_session_with_field(
    session,
    "mooncode_events",
    Json::array(events),
  )
  agent_session_with_field(next, "mooncode_summary", summary)
}

///|
async fn read_mooncode_raw_events(session : Json) -> Array[Json] {
  let task_id = json_string(session, "moonclaw_task_id", default="")
  if task_id == "" {
    return []
  }
  let events = read_moonclaw_conversation_events(session, task_id)
  if events.length() > 0 {
    events
  } else {
    read_moonclaw_log_events(session)
  }
}

///|
fn project_mooncode_events(
  session : Json,
  raw_events : Array[Json],
  durable_events : Array[Json],
) -> Array[Json] {
  let projected : Array[Json] = []
  for event in json_array_items(session, "mooncode_events") {
    projected.push(event)
  }
  if raw_events.length() > 0 {
    for event in raw_events {
      match mooncode_event_from_moonclaw_event(event) {
        Some(item) => projected.push(item)
        None => ()
      }
    }
  } else {
    for message in json_array_items(session, "transcript") {
      projected.push(mooncode_event_from_transcript_message(message))
    }
  }
  let merged = merge_mooncode_events(
    projected,
    json_array_items(session, "mooncode_command_events"),
    durable_events,
  )
  let normalized : Array[Json] = []
  for event in merged {
    normalized.push(@mooncode.normalize_event_record(event))
  }
  normalized
}
