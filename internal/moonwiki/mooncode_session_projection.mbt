///|
// MoonCode session event and summary projection.

///|
async fn attach_mooncode_session_projection(
  workspace_root : String,
  session : Json,
) -> Json {
  let raw_events : Array[Json] = []
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
  @mooncode.session_projection_response(
    session,
    events,
    event_log_path=log_path,
    append_log_count=durable_events.length(),
    command_log_path~,
    command_log_count=durable_commands.length(),
    runtime_command_log_path~,
    runtime_command_log_count=durable_runtime_commands.length(),
    runtime_dispatch_log_path~,
    runtime_dispatch_log_count=durable_runtime_dispatches.length(),
  )
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
