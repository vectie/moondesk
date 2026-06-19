///|
// MoonCode runtime-evidence HTTP handler and host-side projection assembly.

///|
async fn handle_mooncode_session_runtime_evidence(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_mooncode_session_record(workspace_root, session_id) {
    Some(session) =>
      send_json(
        conn,
        method_,
        mooncode_session_runtime_evidence_projection(workspace_root, session),
      )
    None =>
      match
        mooncode_native_session_runtime_evidence_projection(
          workspace_root, session_id,
        ) {
        Some(projection) => send_json(conn, method_, projection)
        None =>
          send_api_error(
            conn, method_, 404, "Not Found", "Unknown MoonCode session",
          )
      }
  }
}

///|
async fn mooncode_session_runtime_evidence_projection(
  workspace_root : String,
  session : Json,
) -> Json {
  let session_id = json_string(session, "id", default="")
  let durable_events = if session_id == "" {
    []
  } else {
    read_mooncode_event_log(workspace_root, session_id)
  }
  let native = if session_id == "" {
    Json::object({})
  } else {
    mooncode_native_runtime_events_state(workspace_root, session_id)
  }
  let native_report = @mooncode.runtime_native_event_report(
    native,
    session_id~,
    observed_at=@async.now().to_string(),
  )
  let native_events = @mooncode.native_runtime_events_for_projection(
    native_report,
  )
  let merged_events = @mooncode.merge_events([], native_events, durable_events)
  let events = project_mooncode_events(session, [], merged_events)
  let commands = if session_id == "" {
    []
  } else {
    read_mooncode_command_log(workspace_root, session_id)
  }
  let runtime_commands = if session_id == "" {
    []
  } else {
    read_mooncode_runtime_command_log(workspace_root, session_id)
  }
  let projection = @mooncode.session_runtime_evidence(
    session,
    commands,
    runtime_commands,
    events,
    recorded_at=@async.now().to_string(),
  )
  let relative = if session_id == "" {
    ""
  } else {
    @mooncode.runtime_evidence_manifest_relative_path(session_id)
  }
  @mooncode.session_runtime_evidence_response_with_native(
    projection,
    relative,
    if session_id == "" {
      ""
    } else {
      @pathx.join(workspace_root, relative)
    },
    if session_id == "" {
      ""
    } else {
      mooncode_command_log_path(workspace_root, session_id)
    },
    if session_id == "" {
      ""
    } else {
      mooncode_runtime_command_log_path(workspace_root, session_id)
    },
    if session_id == "" {
      ""
    } else {
      mooncode_event_log_path(workspace_root, session_id)
    },
    local_event_count=durable_events.length(),
    native_state=native,
    native_report~,
  )
}

///|
async fn mooncode_native_session_runtime_evidence_projection(
  workspace_root : String,
  session_id : String,
) -> Json? {
  let native = mooncode_native_runtime_events_state(workspace_root, session_id)
  let native_report = @mooncode.runtime_native_event_report(
    native,
    session_id~,
    observed_at=@async.now().to_string(),
  )
  let native_events = @mooncode.native_runtime_events_for_projection(
    native_report,
  )
  if !mooncode_runtime_session_known(workspace_root, session_id, native_events) {
    return None
  }
  let session = @mooncode.native_runtime_session_stub(
    workspace_root, session_id,
  )
  let runtime_commands = @mooncode.runtime_event_command_rows(
    native_events,
    source="moonclaw-native-runtime-events",
  )
  let projection = @mooncode.session_runtime_evidence(
    session,
    runtime_commands,
    runtime_commands,
    native_events,
    recorded_at=@async.now().to_string(),
  )
  let relative = @mooncode.runtime_evidence_manifest_relative_path(session_id)
  Some(
    @mooncode.session_runtime_evidence_response_with_native(
      projection,
      relative,
      @pathx.join(workspace_root, relative),
      "",
      "",
      "",
      local_event_count=0,
      native_state=native,
      native_report~,
    ),
  )
}
