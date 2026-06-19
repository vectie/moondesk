///|
// Shared MoonCode runtime response projection used by feed, plan, and supervisor
// views.

///|
priv struct RuntimeResponseProjection {
  dispatch_receipts : Array[Json]
  replay : Json
  claim : Json
  lifecycle : Json
  scheduler : Json
  turn_packet : Json
  supervisor : Json
}

///|
fn runtime_response_projection(
  session_id : String,
  commands : Array[Json],
  receipts : Array[Json],
  events : Array[Json],
  workspace_id~ : String,
  workspace_name~ : String,
  runtime_session_id~ : String,
  runtime_command_log_path~ : String,
  runtime_dispatch_log_path~ : String,
  workspace_root~ : String,
  moonclaw_root~ : String,
  host_base_url~ : String,
  native_ready~ : Bool,
  lease_now~ : String,
) -> RuntimeResponseProjection {
  let dispatch_receipts = runtime_dispatch_receipts_for_response(receipts)
  let replay = runtime_replay_state(
    session_id,
    commands,
    dispatch_receipts,
    workspace_id~,
    workspace_name~,
    runtime_session_id~,
    runtime_command_log_path~,
    runtime_dispatch_log_path~,
    lease_now~,
  )
  let claim = runtime_claim_state(
    session_id,
    commands,
    dispatch_receipts,
    workspace_id~,
    workspace_name~,
    runtime_session_id~,
    runtime_command_log_path~,
    runtime_dispatch_log_path~,
    lease_now~,
  )
  let lifecycle = runtime_command_lifecycle(
    session_id,
    commands,
    dispatch_receipts,
    events,
    lease_now~,
  )
  let scheduler = serve_scheduler_projection(session_id, commands, lifecycle)
  let turn_packet = runtime_turn_packet(
    session_id, replay, claim, scheduler, native_ready,
  )
  let supervisor = runtime_supervisor_launch_packet(
    session_id,
    turn_packet,
    runtime_consumer_handoff(session_id, replay, claim, native_ready),
    workspace_root~,
    moonclaw_root~,
    host_base_url~,
    native_ready,
  )
  {
    dispatch_receipts,
    replay,
    claim,
    lifecycle,
    scheduler,
    turn_packet,
    supervisor,
  }
}
