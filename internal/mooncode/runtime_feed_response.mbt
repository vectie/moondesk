///|
// MoonCode runtime feed, execution-plan, and supervisor response projections.

///|
pub fn runtime_command_feed_response(
  session_id : String,
  commands : Array[Json],
  receipts : Array[Json],
  events : Array[Json],
  workspace_id~ : String,
  workspace_name~ : String,
  task_id~ : String,
  runtime_command_log_path~ : String,
  runtime_dispatch_log_path~ : String,
  workspace_root~ : String,
  moonclaw_root~ : String,
  host_base_url~ : String,
  native_ready~ : Bool,
  lease_now~ : String,
) -> Json {
  let dispatch_receipts = runtime_dispatch_receipts_for_response(receipts)
  let replay = runtime_replay_state(
    session_id,
    commands,
    dispatch_receipts,
    workspace_id~,
    workspace_name~,
    task_id~,
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
    task_id~,
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
    "protocol": "mooncode.v1",
    "kind": "mooncode-runtime-command-feed",
    "session_id": session_id,
    "workspace_id": workspace_id,
    "workspace_name": workspace_name,
    "task_id": task_id,
    "runtime_command_log_path": runtime_command_log_path,
    "runtime_command_count": commands.length(),
    "runtime_dispatch_log_path": runtime_dispatch_log_path,
    "runtime_claim_endpoint": "/api/mooncode/sessions/\{session_id}/runtime-claim",
    "runtime_dispatch_count": dispatch_receipts.length(),
    "runtime_dispatch_pending_count": runtime_dispatch_pending_count(
      commands,
      dispatch_receipts,
      lease_now~,
    ),
    "commands": Json::array(commands),
    "dispatch_receipts": Json::array(dispatch_receipts),
    "runtime_replay": replay,
    "decode_reports": Json::array(
      [
        for command in commands => runtime_command_decode_report(command)
      ],
    ),
    "execution_summaries": Json::array(
      [
        for command in commands => {
          runtime_command_execution_summary_from_record(command)
        }
      ],
    ),
    "command_lifecycle": lifecycle,
    "serve_scheduler": scheduler,
    "runtime_turn_packet": turn_packet,
    "runtime_supervisor": supervisor,
    "wire_protocol": {
      "openseek_serve_commands": Json::array(
        [
          for command in serve_command_names() => Json::string(command)
        ],
      ),
      "native_mooncode_endpoint": "/v1/mooncode/sessions/\{session_id}/commands",
      "ordering_rule": "append-only runtime-commands.jsonl; consume in file order",
    },
    "runtime_protocol": runtime_protocol_contract_json(),
    "runtime_claim_contract": runtime_claim_consumer_contract_json(session_id),
    "owner": runtime_owner_record(),
  }
}

///|
pub fn runtime_command_feed_result_response(
  session_id : String,
  commands : Array[Json],
  receipts : Array[Json],
  events : Array[Json],
  session : Json,
  runtime_command_log_path~ : String,
  runtime_dispatch_log_path~ : String,
  workspace_root~ : String,
  moonclaw_root~ : String,
  host_base_url~ : String,
  native_ready~ : Bool,
  lease_now~ : String,
) -> Json {
  runtime_command_feed_response(
    session_id,
    commands,
    receipts,
    events,
    workspace_id=rq_json_string(session, "workspace_id", default=""),
    workspace_name=rq_json_string(session, "workspace_name", default=""),
    task_id=rq_json_string(session, "moonclaw_task_id", default=""),
    runtime_command_log_path~,
    runtime_dispatch_log_path~,
    workspace_root~,
    moonclaw_root~,
    host_base_url~,
    native_ready~,
    lease_now~,
  )
}

///|
pub fn runtime_execution_plan_response(
  session_id : String,
  commands : Array[Json],
  receipts : Array[Json],
  events : Array[Json],
  workspace_id~ : String,
  workspace_name~ : String,
  task_id~ : String,
  runtime_command_log_path~ : String,
  runtime_dispatch_log_path~ : String,
  workspace_root~ : String,
  moonclaw_root~ : String,
  host_base_url~ : String,
  native_ready~ : Bool,
  lease_now~ : String,
) -> Json {
  let dispatch_receipts = runtime_dispatch_receipts_for_response(receipts)
  let replay = runtime_replay_state(
    session_id,
    commands,
    dispatch_receipts,
    workspace_id~,
    workspace_name~,
    task_id~,
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
    task_id~,
    runtime_command_log_path~,
    runtime_dispatch_log_path~,
    lease_now~,
  )
  let plan = runtime_consumer_execution_plan(
    session_id, replay, claim, native_ready,
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
  rq_json_with_field(
    rq_json_with_field(
      rq_json_with_field(plan, "serve_scheduler", scheduler),
      "runtime_turn_packet",
      turn_packet,
    ),
    "runtime_supervisor",
    runtime_supervisor_launch_packet(
      session_id,
      turn_packet,
      runtime_consumer_handoff(session_id, replay, claim, native_ready),
      workspace_root~,
      moonclaw_root~,
      host_base_url~,
      native_ready,
    ),
  )
}

///|
pub fn runtime_supervisor_response(
  session_id : String,
  commands : Array[Json],
  receipts : Array[Json],
  events : Array[Json],
  workspace_id~ : String,
  workspace_name~ : String,
  task_id~ : String,
  runtime_command_log_path~ : String,
  runtime_dispatch_log_path~ : String,
  workspace_root~ : String,
  moonclaw_root~ : String,
  host_base_url~ : String,
  native_ready~ : Bool,
  lease_now~ : String,
) -> Json {
  let dispatch_receipts = runtime_dispatch_receipts_for_response(receipts)
  let replay = runtime_replay_state(
    session_id,
    commands,
    dispatch_receipts,
    workspace_id~,
    workspace_name~,
    task_id~,
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
    task_id~,
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
  runtime_supervisor_launch_packet(
    session_id,
    turn_packet,
    runtime_consumer_handoff(session_id, replay, claim, native_ready),
    workspace_root~,
    moonclaw_root~,
    host_base_url~,
    native_ready,
  )
}

///|
fn runtime_command_execution_summary_from_record(command : Json) -> Json {
  match rq_json_object_field(command, "execution_summary") {
    Some(summary) => summary
    None =>
      native_command_execution_summary(
        rq_json_object_field_or_empty(command, "command_packet"),
        rq_json_object_field_or_empty(command, "native_mooncode_body"),
      )
  }
}
