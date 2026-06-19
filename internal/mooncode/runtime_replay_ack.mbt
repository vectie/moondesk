///|
pub fn runtime_replay_ack_receipts(
  session : Json,
  commands : Array[Json],
  payload : Json,
  runtime_receipts? : Array[Json] = [],
  prior_events? : Array[Json] = [],
) -> Array[Json] {
  let requests = runtime_replay_ack_requests(payload)
  let latest_receipts = runtime_latest_receipts(runtime_receipts)
  let now = rq_json_string(payload, "now", default="")
  let receipts : Array[Json] = []
  for request in requests {
    let command_id = rq_json_string(request, "command_id", default="")
    match runtime_command_by_id(commands, command_id) {
      Some(command) =>
        receipts.push(
          runtime_replay_ack_receipt(
            session,
            command,
            request,
            previous_runtime_receipt=latest_receipts
              .get(command_id)
              .unwrap_or(Json::object({})),
            order_blocker=runtime_replay_ack_order_blocker(
              command_id, commands, latest_receipts, now,
            ),
            prior_events~,
          ),
        )
      None => ()
    }
  }
  receipts
}

///|
pub fn runtime_replay_ack_receipts_with_defaults(
  session : Json,
  commands : Array[Json],
  payload : Json,
  acknowledged_at~ : String,
  runtime_receipts? : Array[Json] = [],
  prior_events? : Array[Json] = [],
) -> Array[Json] {
  runtime_replay_ack_receipts(
    session,
    commands,
    rq_json_with_missing_string(payload, "acknowledged_at", acknowledged_at),
    runtime_receipts~,
    prior_events~,
  )
}

///|
fn runtime_replay_ack_receipt(
  session : Json,
  runtime_command : Json,
  ack : Json,
  previous_runtime_receipt~ : Json,
  order_blocker~ : Json,
  prior_events~ : Array[Json],
) -> Json {
  let command_id = rq_json_string(runtime_command, "command_id", default="")
  let requested_status = runtime_replay_ack_status(ack)
  let consumer_id = runtime_safe_id(
    rq_json_string(ack, "consumer_id", default="mooncode-runtime"),
    fallback="mooncode-runtime",
  )
  let acknowledged_at = rq_json_string(ack, "acknowledged_at", default="")
  let receipt_id = runtime_safe_id(
    rq_json_string(ack, "receipt_id", default=""),
    fallback="mooncode-runtime-replay-ack:\{command_id}:\{consumer_id}:\{requested_status}:\{acknowledged_at}",
  )
  let previous_receipt_status = rq_json_string(
    previous_runtime_receipt,
    "status",
    default="missing",
  )
  let previous_consumer_id = rq_json_string(
    previous_runtime_receipt,
    "consumer_id",
    default="",
  )
  let claimed_by_same_consumer = previous_receipt_status == "runtime-claimed" &&
    previous_consumer_id == consumer_id
  let runtime_event_summary = runtime_replay_ack_event_summary(
    ack, runtime_command, acknowledged_at,
  )
  let proof_gate = runtime_replay_ack_proof_gate(
    runtime_command, runtime_event_summary, prior_events,
  )
  let status = runtime_replay_ack_effective_status(requested_status, proof_gate)
  {
    "protocol": protocol_version(),
    "kind": kind_runtime_receipt(),
    "receipt_id": receipt_id,
    "command_id": command_id,
    "session_id": rq_json_string(runtime_command, "session_id", default=""),
    "workspace_id": rq_json_string(session, "workspace_id", default=""),
    "workspace_name": rq_json_string(session, "workspace_name", default=""),
    "runtime_session_id": session_runtime_session_id(session),
    "action": rq_json_string(runtime_command, "action", default="prompt"),
    "control": rq_json_string(runtime_command, "control", default="prompt"),
    "status": status,
    "requested_status": requested_status,
    "runtime_mode": "mooncode-runtime-replay",
    "consumer_id": consumer_id,
    "created_at": acknowledged_at,
    "mooncode_command_valid": rq_json_bool(
      runtime_command,
      "mooncode_command_valid",
      default=false,
    ),
    "native_mooncode_endpoint": rq_json_string(
      runtime_command,
      "native_mooncode_endpoint",
      default="",
    ),
    "replay_ack_endpoint": "/api/mooncode/sessions/\{rq_json_string(runtime_command, "session_id", default="")}/runtime-replay",
    "previous_receipt_status": previous_receipt_status,
    "previous_receipt_id": rq_json_string(
      previous_runtime_receipt,
      "receipt_id",
      default="",
    ),
    "previous_claim_id": rq_json_string(
      previous_runtime_receipt,
      "claim_id",
      default="",
    ),
    "previous_consumer_id": previous_consumer_id,
    "claimed_by_same_consumer": claimed_by_same_consumer,
    "ack_order_status": runtime_replay_ack_order_status(
      previous_receipt_status, order_blocker, claimed_by_same_consumer,
    ),
    "order_blocker": order_blocker,
    "submitted_event_count": rq_json_int(
      runtime_event_summary,
      "submitted_event_count",
      default=0,
    ),
    "normalized_event_count": rq_json_int(
      runtime_event_summary,
      "normalized_event_count",
      default=0,
    ),
    "proof_event_count": rq_json_int(
      runtime_event_summary,
      "proof_event_count",
      default=0,
    ),
    "runtime_event_summary": runtime_event_summary,
    "proof_gate": proof_gate,
    "required_event_count": rq_json_int(
      proof_gate,
      "required_event_count",
      default=0,
    ),
    "proven_required_event_count": rq_json_int(
      proof_gate,
      "proven_required_event_count",
      default=0,
    ),
    "missing_required_event_count": rq_json_int(
      proof_gate,
      "missing_required_event_count",
      default=0,
    ),
    "failed_required_event_count": rq_json_int(
      proof_gate,
      "failed_required_event_count",
      default=0,
    ),
    "detail": rq_json_string(
      ack,
      "detail",
      default=runtime_replay_ack_detail(status),
    ),
    "runtime_command": runtime_command,
    "consumer_result": ack,
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "standalone_component": "mooncode",
    },
  }
}
