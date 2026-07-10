///|
fn mooncode_immediate_queued_session(
  session : Json,
  action~ : String,
  message~ : String,
  context_path~ : String,
  command_packet~ : Json,
  created_at~ : String,
) -> Json {
  let with_event = @mooncode.append_projected_command_event(
    session,
    action~,
    status="queued",
    detail=message,
    created_at~,
    path=context_path,
    command_packet~,
  )
  let with_message = mooncode_session_with_field(
    with_event,
    "last_message",
    message.to_json(),
  )
  let with_status = mooncode_session_with_field(
    with_message,
    "status",
    "queued".to_json(),
  )
  mooncode_session_with_field(with_status, "updated_at", created_at.to_json())
}

///|
async fn mooncode_command_response_after_enqueue(
  workspace_root : String,
  queued : Json,
  command_packet : Json,
  payload : Json,
) -> Result[Json, Json] {
  let session_id = json_string(queued, "id", default="")
  match
    run_mooncode_runtime_service_for_session(
      workspace_root, session_id, queued, payload,
    ) {
    Ok(started) =>
      Ok(
        compact_mooncode_session_command_response(
          workspace_root, started, command_packet,
        ),
      )
    Err(error) => Err(error)
  }
}

///|
fn mooncode_session_execution_root(
  session : Json,
  fallback~ : String,
) -> String {
  let root = json_string(session, "workspace_root", default="").trim()
  if root == "" {
    fallback
  } else {
    root.to_owned()
  }
}

///|
async fn mooncode_native_runtime_ready(daemon : Json) -> Bool {
  match moonclaw_get_json(daemon, "/v1/code/capabilities") {
    Ok(capabilities) =>
      @mooncode.moonclaw_native_capabilities_ready(capabilities)
    Err(_) => false
  }
}

///|
async fn sync_mooncode_native_eval_report(
  workspace_root : String,
  session : Json,
) -> Json {
  let session_id = json_string(session, "id", default="")
  if session_id == "" {
    return session
  }
  let daemon = moonclaw_daemon_status(workspace_root)
  if !json_bool(daemon, "running", default=false) {
    return session
  }
  if !mooncode_native_runtime_ready(daemon) {
    return session
  }
  let endpoint = @mooncode.moonclaw_native_eval_report_endpoint(
    session_id, workspace_root,
  )
  match moonclaw_get_json(daemon, endpoint) {
    Ok(report) =>
      @mooncode.session_with_native_eval_report(session, report, endpoint)
    Err(_) => session
  }
}
