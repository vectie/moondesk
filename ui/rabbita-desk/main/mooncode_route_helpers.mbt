///|
fn mooncode_sessions_url(workspace_id : String) -> String {
  if workspace_id == "" {
    "/api/mooncode/sessions"
  } else {
    "/api/mooncode/sessions?workspace=\{encode_component(workspace_id)}"
  }
}

///|
fn mooncode_session_url(session_id : String) -> String {
  "/api/mooncode/sessions/\{encode_component(session_id)}"
}

///|
fn mooncode_session_stream_url(session_id : String, since : Int) -> String {
  mooncode_session_url(session_id) +
  "/stream?format=jsonl&since=\{since}&live=true&timeout_ms=1000&poll_ms=100"
}

///|
fn mooncode_session_stream_state_url(session_id : String) -> String {
  mooncode_session_url(session_id) + "/stream-state"
}

///|
fn mooncode_session_commands_url(session_id : String) -> String {
  mooncode_session_url(session_id) + "/commands"
}

///|
fn mooncode_session_runtime_service_url(session_id : String) -> String {
  mooncode_session_url(session_id) + "/runtime-service"
}
