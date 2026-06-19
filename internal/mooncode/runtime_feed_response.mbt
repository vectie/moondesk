///|
// MoonCode runtime feed, execution-plan, and supervisor response builders.

///|
pub fn runtime_command_feed_response(
  session_id : String,
  commands : Array[Json],
  receipts : Array[Json],
  events : Array[Json],
  workspace_id~ : String,
  workspace_name~ : String,
  runtime_session_id~ : String,
  runtime_command_log_path~ : String,
  runtime_receipt_log_path~ : String,
  workspace_root~ : String,
  moonclaw_root~ : String,
  host_base_url~ : String,
  native_ready~ : Bool,
  lease_now~ : String,
) -> Json {
  let projection = runtime_response_projection(
    session_id,
    commands,
    receipts,
    events,
    workspace_id~,
    workspace_name~,
    runtime_session_id~,
    runtime_command_log_path~,
    runtime_receipt_log_path~,
    workspace_root~,
    moonclaw_root~,
    host_base_url~,
    native_ready~,
    lease_now~,
  )
  {
    "protocol": protocol_version(),
    "kind": "mooncode-runtime-command-feed",
    "session_id": session_id,
    "workspace_id": workspace_id,
    "workspace_name": workspace_name,
    "runtime_session_id": runtime_session_id,
    "runtime_mode": "runtime-replay-receipts",
    "runtime_command_log_path": runtime_command_log_path,
    "runtime_command_count": commands.length(),
    "runtime_receipt_log_path": runtime_receipt_log_path,
    "runtime_claim_endpoint": "/api/mooncode/sessions/\{session_id}/runtime-claim",
    "runtime_receipt_count": projection.runtime_receipts.length(),
    "runtime_receipt_pending_count": runtime_receipt_pending_count(
      commands,
      projection.runtime_receipts,
      lease_now~,
    ),
    "pending_command_ids": Json::array(
      runtime_pending_command_ids(
        commands,
        projection.runtime_receipts,
        lease_now~,
      ),
    ),
    "commands": Json::array(commands),
    "runtime_receipts": Json::array(projection.runtime_receipts),
    "runtime_replay": projection.replay,
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
    "command_lifecycle": projection.lifecycle,
    "runtime_control": projection.control,
    "runtime_turn_packet": projection.turn_packet,
    "runtime_supervisor": projection.supervisor,
    "command_protocol": {
      "mooncode_code_commands": Json::array(
        [
          for command in code_command_names() => Json::string(command)
        ],
      ),
      "native_mooncode_endpoint": "/v1/code/sessions/\{session_id}/commands",
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
  runtime_receipt_log_path~ : String,
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
    runtime_session_id=session_runtime_session_id(session),
    runtime_command_log_path~,
    runtime_receipt_log_path~,
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
  runtime_session_id~ : String,
  runtime_command_log_path~ : String,
  runtime_receipt_log_path~ : String,
  workspace_root~ : String,
  moonclaw_root~ : String,
  host_base_url~ : String,
  native_ready~ : Bool,
  lease_now~ : String,
) -> Json {
  let projection = runtime_response_projection(
    session_id,
    commands,
    receipts,
    events,
    workspace_id~,
    workspace_name~,
    runtime_session_id~,
    runtime_command_log_path~,
    runtime_receipt_log_path~,
    workspace_root~,
    moonclaw_root~,
    host_base_url~,
    native_ready~,
    lease_now~,
  )
  let plan = runtime_consumer_execution_plan(
    session_id,
    projection.replay,
    projection.claim,
    native_ready,
  )
  rq_json_with_field(
    rq_json_with_field(
      rq_json_with_field(plan, "runtime_control", projection.control),
      "runtime_turn_packet",
      projection.turn_packet,
    ),
    "runtime_supervisor",
    projection.supervisor,
  )
}

///|
pub fn runtime_execution_plan_response_for_session(
  session : Json,
  commands : Array[Json],
  receipts : Array[Json],
  events : Array[Json],
  runtime_command_log_path~ : String,
  runtime_receipt_log_path~ : String,
  workspace_root~ : String,
  moonclaw_root~ : String,
  host_base_url~ : String,
  native_ready~ : Bool,
  lease_now~ : String,
) -> Json {
  runtime_execution_plan_response(
    rq_json_string(session, "id", default=""),
    commands,
    receipts,
    events,
    workspace_id=rq_json_string(session, "workspace_id", default=""),
    workspace_name=rq_json_string(session, "workspace_name", default=""),
    runtime_session_id=session_runtime_session_id(session),
    runtime_command_log_path~,
    runtime_receipt_log_path~,
    workspace_root~,
    moonclaw_root~,
    host_base_url~,
    native_ready~,
    lease_now~,
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
  runtime_session_id~ : String,
  runtime_command_log_path~ : String,
  runtime_receipt_log_path~ : String,
  workspace_root~ : String,
  moonclaw_root~ : String,
  host_base_url~ : String,
  native_ready~ : Bool,
  lease_now~ : String,
) -> Json {
  runtime_response_projection(
    session_id,
    commands,
    receipts,
    events,
    workspace_id~,
    workspace_name~,
    runtime_session_id~,
    runtime_command_log_path~,
    runtime_receipt_log_path~,
    workspace_root~,
    moonclaw_root~,
    host_base_url~,
    native_ready~,
    lease_now~,
  ).supervisor
}

///|
pub fn runtime_supervisor_response_for_session(
  session : Json,
  commands : Array[Json],
  receipts : Array[Json],
  events : Array[Json],
  runtime_command_log_path~ : String,
  runtime_receipt_log_path~ : String,
  workspace_root~ : String,
  moonclaw_root~ : String,
  host_base_url~ : String,
  native_ready~ : Bool,
  lease_now~ : String,
) -> Json {
  runtime_supervisor_response(
    rq_json_string(session, "id", default=""),
    commands,
    receipts,
    events,
    workspace_id=rq_json_string(session, "workspace_id", default=""),
    workspace_name=rq_json_string(session, "workspace_name", default=""),
    runtime_session_id=session_runtime_session_id(session),
    runtime_command_log_path~,
    runtime_receipt_log_path~,
    workspace_root~,
    moonclaw_root~,
    host_base_url~,
    native_ready~,
    lease_now~,
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
