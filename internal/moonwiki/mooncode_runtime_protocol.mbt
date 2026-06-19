///|
fn mooncode_preflight_payload_from_request(request_path : String) -> Json {
  let action = match query_value(request_path, "action") {
    Some(value) => decode_query_value(value).trim().to_owned()
    None => "package"
  }
  let context_path = match query_value(request_path, "context_path") {
    Some(value) => decode_query_value(value).trim().to_owned()
    None => ""
  }
  { "action": action, "context_path": context_path }
}

///|
fn mooncode_command_preflight(
  session : Json,
  payload : Json,
  action : String,
) -> Json {
  let events = project_mooncode_events(session, [], [])
  @mooncode.command_preflight_for_session(session, payload, events, action~)
}

///|
fn mooncode_runtime_execution_plan(
  workspace_root : String,
  session : Json,
  session_id : String,
  commands : Array[Json],
  receipts : Array[Json],
  events : Array[Json],
  moonclaw_root~ : String,
  native_ready~ : Bool,
  lease_now~ : String,
) -> Json {
  let now = if lease_now == "" { @async.now().to_string() } else { lease_now }
  @mooncode.runtime_execution_plan_response_for_session(
    session,
    commands,
    receipts,
    events,
    runtime_command_log_path=mooncode_runtime_command_log_path(
      workspace_root, session_id,
    ),
    runtime_dispatch_log_path=mooncode_runtime_dispatch_log_path(
      workspace_root, session_id,
    ),
    workspace_root~,
    moonclaw_root~,
    host_base_url="",
    native_ready~,
    lease_now=now,
  )
}

///|
fn mooncode_runtime_supervisor_launch_packet(
  workspace_root : String,
  session : Json,
  session_id : String,
  commands : Array[Json],
  receipts : Array[Json],
  events : Array[Json],
  daemon : Json,
  native_ready~ : Bool,
  lease_now~ : String,
) -> Json {
  let now = if lease_now == "" { @async.now().to_string() } else { lease_now }
  @mooncode.runtime_supervisor_response_for_session(
    session,
    commands,
    receipts,
    events,
    runtime_command_log_path=mooncode_runtime_command_log_path(
      workspace_root, session_id,
    ),
    runtime_dispatch_log_path=mooncode_runtime_dispatch_log_path(
      workspace_root, session_id,
    ),
    workspace_root~,
    moonclaw_root=json_string(daemon, "moonclaw_root", default=""),
    host_base_url="",
    native_ready~,
    lease_now=now,
  )
}
