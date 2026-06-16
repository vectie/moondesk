///|
// MoonCode runtime-evidence HTTP handler and host-side projection assembly.

///|
async fn handle_mooncode_session_runtime_evidence(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) =>
      send_json(
        conn,
        method_,
        mooncode_session_runtime_evidence_projection(workspace_root, session),
      )
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
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
  let events = project_mooncode_events(session, [], durable_events)
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
  agent_session_with_field(
    agent_session_with_field(
      agent_session_with_field(
        agent_session_with_field(
          agent_session_with_field(
            projection,
            "manifest_path",
            (if session_id == "" {
              ""
            } else {
              @mooncode.runtime_evidence_manifest_relative_path(session_id)
            }).to_json(),
          ),
          "absolute_manifest_path",
          (if session_id == "" {
            ""
          } else {
            @pathx.join(
              workspace_root,
              @mooncode.runtime_evidence_manifest_relative_path(session_id),
            )
          }).to_json(),
        ),
        "command_log_path",
        (if session_id == "" {
          ""
        } else {
          mooncode_command_log_path(workspace_root, session_id)
        }).to_json(),
      ),
      "runtime_command_log_path",
      (if session_id == "" {
        ""
      } else {
        mooncode_runtime_command_log_path(workspace_root, session_id)
      }).to_json(),
    ),
    "event_log_path",
    (if session_id == "" {
      ""
    } else {
      mooncode_event_log_path(workspace_root, session_id)
    }).to_json(),
  )
}
