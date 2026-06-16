///|
pub fn runtime_replay_ack_response(
  session_id : String,
  commands : Array[Json],
  next_receipts : Array[Json],
  ack_receipts : Array[Json],
  events : Array[Json],
  runtime_evidence : Json,
  session : Json,
  workspace_id~ : String,
  workspace_name~ : String,
  task_id~ : String,
  runtime_command_log_path~ : String,
  runtime_dispatch_log_path~ : String,
) -> Json {
  {
    "protocol": "mooncode.v1",
    "kind": "mooncode-runtime-replay-ack",
    "session_id": session_id,
    "accepted_receipt_count": ack_receipts.length(),
    "accepted_event_count": events.length(),
    "receipts": Json::array(ack_receipts),
    "runtime_replay": runtime_replay_state(
      session_id,
      commands,
      next_receipts,
      workspace_id~,
      workspace_name~,
      task_id~,
      runtime_command_log_path~,
      runtime_dispatch_log_path~,
    ),
    "runtime_evidence": runtime_evidence,
    "session": session,
  }
}

///|
pub fn runtime_replay_ack_result_response(
  session_id : String,
  commands : Array[Json],
  next_receipts : Array[Json],
  ack_receipts : Array[Json],
  events : Array[Json],
  runtime_evidence : Json,
  session : Json,
  runtime_command_log_path~ : String,
  runtime_dispatch_log_path~ : String,
) -> Json {
  runtime_replay_ack_response(
    session_id,
    commands,
    next_receipts,
    ack_receipts,
    events,
    runtime_evidence,
    session,
    workspace_id=rq_json_string(session, "workspace_id", default=""),
    workspace_name=rq_json_string(session, "workspace_name", default=""),
    task_id=rq_json_string(session, "moonclaw_task_id", default=""),
    runtime_command_log_path~,
    runtime_dispatch_log_path~,
  )
}
