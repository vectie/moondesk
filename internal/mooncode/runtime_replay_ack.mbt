///|
pub fn runtime_replay_ack_receipts(
  session : Json,
  commands : Array[Json],
  payload : Json,
  dispatch_receipts? : Array[Json] = [],
  prior_events? : Array[Json] = [],
) -> Array[Json] {
  let requests = runtime_replay_ack_requests(payload)
  let latest_receipts = runtime_latest_receipts(dispatch_receipts)
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
            previous_dispatch_receipt=latest_receipts
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
  dispatch_receipts? : Array[Json] = [],
  prior_events? : Array[Json] = [],
) -> Array[Json] {
  runtime_replay_ack_receipts(
    session,
    commands,
    rq_json_with_missing_string(payload, "acknowledged_at", acknowledged_at),
    dispatch_receipts~,
    prior_events~,
  )
}

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

///|
pub fn runtime_replay_ack_status(ack : Json) -> String {
  let status = rq_json_string(ack, "status", default="")
  match status {
    "runtime-acknowledged"
    | "runtime-completed"
    | "proof-missing"
    | "native-dispatched"
    | "legacy-bridged"
    | "failed"
    | "skipped" => status
    _ =>
      if rq_json_bool(ack, "ok", default=true) {
        "runtime-acknowledged"
      } else {
        "failed"
      }
  }
}

///|
pub fn runtime_replay_ack_detail(status : String) -> String {
  match status {
    "runtime-completed" => "Runtime replay consumer completed the command."
    "proof-missing" =>
      "Runtime replay consumer requested completion, but required command-scoped proof events are missing or failed."
    "failed" => "Runtime replay consumer reported command failure."
    "skipped" => "Runtime replay consumer skipped the command."
    _ => "Runtime replay consumer acknowledged the command."
  }
}

///|
fn runtime_replay_ack_requests(payload : Json) -> Array[Json] {
  let requests = rq_json_array_items(payload, "receipts")
  if requests.length() > 0 {
    return requests
  }
  let command_ids = rq_json_string_array_items(payload, "command_ids")
  if command_ids.length() > 0 {
    return [
      for command_id in command_ids => {
        {
          "command_id": command_id,
          "status": rq_json_string(
            payload,
            "status",
            default="runtime-acknowledged",
          ),
          "detail": rq_json_string(
            payload,
            "detail",
            default="Runtime replay consumer acknowledged command",
          ),
        }
      }
    ]
  }
  let command_id = rq_json_string(payload, "command_id", default="")
  if command_id == "" {
    []
  } else {
    [payload]
  }
}

///|
fn runtime_command_by_id(commands : Array[Json], command_id : String) -> Json? {
  if command_id == "" {
    return None
  }
  for command in commands {
    if rq_json_string(command, "command_id", default="") == command_id {
      return Some(command)
    }
  }
  None
}

///|
fn runtime_replay_ack_order_blocker(
  command_id : String,
  commands : Array[Json],
  latest_receipts : Map[String, Json],
  now : String,
) -> Json {
  for command in commands {
    let current_id = rq_json_string(command, "command_id", default="")
    if current_id == command_id {
      return Json::object({})
    }
    let report = runtime_command_decode_report(command)
    if !rq_json_bool(report, "ok", default=false) {
      return runtime_replay_ack_order_blocker_record(
        current_id,
        status="invalid",
        detail="Earlier runtime command cannot be decoded.",
      )
    }
    if runtime_command_tool_authorization_blocks(command) {
      return runtime_replay_ack_order_blocker_record(
        current_id,
        status="blocked-tool-authorization",
        detail=runtime_command_tool_authorization_block_reason(command),
      )
    }
    let latest = latest_receipts.get(current_id).unwrap_or(Json::object({}))
    let status = rq_json_string(latest, "status", default="missing")
    if runtime_receipt_status_delivered(status) || status == "failed" {
      continue
    }
    if runtime_receipt_status_claimed(status) &&
      runtime_receipt_claim_expired(latest, now) {
      continue
    }
    return runtime_replay_ack_order_blocker_record(
      current_id,
      status~,
      detail="Earlier runtime command is not delivered yet.",
    )
  }
  Json::object({})
}

///|
fn runtime_replay_ack_order_blocker_record(
  command_id : String,
  status~ : String,
  detail~ : String,
) -> Json {
  { "command_id": command_id, "status": status, "detail": detail }
}

///|
fn runtime_replay_ack_order_status(
  previous_dispatch_status : String,
  order_blocker : Json,
  claimed_by_same_consumer : Bool,
) -> String {
  if rq_json_string(order_blocker, "command_id", default="") != "" {
    "blocked-by-prior-command"
  } else if previous_dispatch_status == "runtime-claimed" {
    if claimed_by_same_consumer {
      "matching-claim"
    } else {
      "consumer-mismatch"
    }
  } else if runtime_receipt_status_delivered(previous_dispatch_status) {
    "already-delivered"
  } else if previous_dispatch_status == "failed" {
    "retry-after-failed-dispatch"
  } else {
    "unclaimed-ack"
  }
}

///|
fn runtime_replay_ack_receipt(
  session : Json,
  runtime_command : Json,
  ack : Json,
  previous_dispatch_receipt? : Json = Json::object({}),
  order_blocker? : Json = Json::object({}),
  prior_events? : Array[Json] = [],
) -> Json {
  let command_id = rq_json_string(runtime_command, "command_id", default="")
  let requested_status = runtime_replay_ack_status(ack)
  let consumer_id = runtime_safe_id(
    rq_json_string(ack, "consumer_id", default="mooncode-runtime"),
    fallback="mooncode-runtime",
  )
  let acknowledged_at = rq_json_string(ack, "acknowledged_at", default="")
  let dispatch_id = runtime_safe_id(
    rq_json_string(ack, "dispatch_id", default=""),
    fallback="mooncode-runtime-replay-ack:\{command_id}:\{consumer_id}:\{requested_status}:\{acknowledged_at}",
  )
  let previous_dispatch_status = rq_json_string(
    previous_dispatch_receipt,
    "status",
    default="missing",
  )
  let previous_consumer_id = rq_json_string(
    previous_dispatch_receipt,
    "consumer_id",
    default="",
  )
  let claimed_by_same_consumer = previous_dispatch_status == "runtime-claimed" &&
    previous_consumer_id == consumer_id
  let runtime_event_summary = runtime_replay_ack_event_summary(
    ack, runtime_command, acknowledged_at,
  )
  let proof_gate = runtime_replay_ack_proof_gate(
    runtime_command, runtime_event_summary, prior_events,
  )
  let status = runtime_replay_ack_effective_status(requested_status, proof_gate)
  {
    "protocol": "mooncode.v1",
    "kind": "mooncode.runtime-dispatch",
    "dispatch_id": dispatch_id,
    "command_id": command_id,
    "session_id": rq_json_string(runtime_command, "session_id", default=""),
    "workspace_id": rq_json_string(session, "workspace_id", default=""),
    "workspace_name": rq_json_string(session, "workspace_name", default=""),
    "task_id": rq_json_string(session, "moonclaw_task_id", default=""),
    "action": rq_json_string(runtime_command, "action", default="prompt"),
    "dispatch": rq_json_string(runtime_command, "dispatch", default="prompt"),
    "status": status,
    "requested_status": requested_status,
    "dispatch_mode": "mooncode-runtime-replay",
    "consumer_id": consumer_id,
    "created_at": acknowledged_at,
    "openseek_wire_valid": rq_json_bool(
      runtime_command,
      "openseek_wire_valid",
      default=false,
    ),
    "native_mooncode_endpoint": rq_json_string(
      runtime_command,
      "native_mooncode_endpoint",
      default="",
    ),
    "legacy_bridge_endpoint": "/v1/task/<id>/message",
    "replay_ack_endpoint": "/api/mooncode/sessions/\{rq_json_string(runtime_command, "session_id", default="")}/runtime-replay",
    "previous_dispatch_status": previous_dispatch_status,
    "previous_dispatch_id": rq_json_string(
      previous_dispatch_receipt,
      "dispatch_id",
      default="",
    ),
    "previous_claim_id": rq_json_string(
      previous_dispatch_receipt,
      "claim_id",
      default="",
    ),
    "previous_consumer_id": previous_consumer_id,
    "claimed_by_same_consumer": claimed_by_same_consumer,
    "ack_order_status": runtime_replay_ack_order_status(
      previous_dispatch_status, order_blocker, claimed_by_same_consumer,
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
      "runtime": "moonclaw-or-standalone-mooncode",
      "extractable_component": "mooncode",
    },
  }
}

///|
fn runtime_replay_ack_effective_status(
  requested_status : String,
  proof_gate : Json,
) -> String {
  if requested_status == "runtime-completed" &&
    rq_json_bool(proof_gate, "completion_blocked", default=false) {
    "proof-missing"
  } else {
    requested_status
  }
}

///|
fn runtime_replay_ack_proof_gate(
  runtime_command : Json,
  runtime_event_summary : Json,
  prior_events : Array[Json],
) -> Json {
  let action = rq_json_string(runtime_command, "action", default="prompt")
  let submitted_events = rq_json_array_items(
    runtime_event_summary, "normalized_events",
  )
  let proof_events : Array[Json] = []
  for event in prior_events {
    proof_events.push(event)
  }
  for event in submitted_events {
    proof_events.push(event)
  }
  let evidence = command_runtime_evidence(
    runtime_command, runtime_command, proof_events,
  )
  let proof_required = runtime_completion_requires_proof(action)
  let status = rq_json_string(evidence, "status", default="missing-evidence")
  let tool_harness_status = rq_json_string(
    evidence,
    "tool_harness_status",
    default="missing-evidence",
  )
  let expected_tool_count = rq_json_int(
    evidence,
    "tool_harness_expected_tool_count",
    default=0,
  )
  let tool_harness_blocked = proof_required &&
    expected_tool_count > 0 &&
    tool_harness_status != "proven" &&
    tool_harness_status != "no-tools"
  let completion_blocked = proof_required &&
    (status != "proven" || tool_harness_blocked)
  {
    "kind": "mooncode-runtime-completion-proof-gate",
    "protocol": "mooncode.v1",
    "action": action,
    "proof_required_for_completion": proof_required,
    "completion_blocked": completion_blocked,
    "status": if completion_blocked {
      "blocked"
    } else if proof_required {
      "passed"
    } else {
      "not-required"
    },
    "evidence_status": status,
    "tool_harness_status": tool_harness_status,
    "tool_harness_completion_blocked": tool_harness_blocked,
    "tool_harness_expected_tool_count": expected_tool_count,
    "tool_harness_proven_tool_count": rq_json_int(
      evidence,
      "tool_harness_proven_tool_count",
      default=0,
    ),
    "tool_harness_missing_tool_count": rq_json_int(
      evidence,
      "tool_harness_missing_tool_count",
      default=0,
    ),
    "tool_harness_failed_tool_count": rq_json_int(
      evidence,
      "tool_harness_failed_tool_count",
      default=0,
    ),
    "prior_event_count": prior_events.length(),
    "submitted_event_count": submitted_events.length(),
    "required_event_count": rq_json_int(
      evidence,
      "required_event_count",
      default=0,
    ),
    "proven_required_event_count": rq_json_int(
      evidence,
      "proven_required_event_count",
      default=0,
    ),
    "missing_required_event_count": rq_json_int(
      evidence,
      "missing_required_event_count",
      default=0,
    ),
    "failed_required_event_count": rq_json_int(
      evidence,
      "failed_required_event_count",
      default=0,
    ),
    "missing_required_events": rq_json_array_items(
      evidence, "missing_required_events",
    ),
    "failed_required_events": rq_json_array_items(
      evidence, "failed_required_events",
    ),
    "rule": "Proof-sensitive actions may not be marked runtime-completed until command-scoped required runtime events and typed tool-harness proof are present either in the prior append log or in this acknowledgement payload.",
  }
}

///|
fn runtime_completion_requires_proof(action : String) -> Bool {
  match action {
    "run_tests"
    | "run_eval"
    | "package"
    | "commit"
    | "accept"
    | "reject"
    | "apply_patch"
    | "revert_patch"
    | "approve_tool"
    | "reject_tool" => true
    _ => false
  }
}

///|
pub fn runtime_replay_ack_normalized_events(
  receipts : Array[Json],
) -> Array[Json] {
  let events : Array[Json] = []
  for receipt in receipts {
    let summary = rq_json_object_field_or_empty(
      receipt, "runtime_event_summary",
    )
    for event in rq_json_array_items(summary, "normalized_events") {
      events.push(event)
    }
  }
  events
}

///|
fn runtime_replay_ack_event_summary(
  ack : Json,
  runtime_command : Json,
  acknowledged_at : String,
) -> Json {
  let command_id = rq_json_string(runtime_command, "command_id", default="")
  let submitted = rq_json_array_items(ack, "events")
  let normalized : Array[Json] = []
  let lanes : Array[String] = []
  let proof_lanes : Array[String] = []
  let mut tool_event_count = 0
  let mut diff_event_count = 0
  let mut test_event_count = 0
  let mut artifact_event_count = 0
  let mut review_event_count = 0
  for index in 0..<submitted.length() {
    let event = submitted[index]
    let fallback_id = if command_id == "" {
      "runtime-ack-event-\{index.to_string()}"
    } else {
      "\{command_id}:runtime-ack-event:\{index.to_string()}"
    }
    match
      normalize_runtime_event(
        event,
        fallback_id~,
        fallback_created_at=acknowledged_at,
      ) {
      Some(normalized_event) => {
        let command_scoped_event = runtime_replay_ack_scoped_event(
          normalized_event, runtime_command,
        )
        normalized.push(command_scoped_event)
        let lane = rq_json_string(command_scoped_event, "lane", default="")
        if lane != "" && !runtime_string_array_contains(lanes, lane) {
          lanes.push(lane)
        }
        if runtime_lane_is_proof(lane) &&
          !runtime_string_array_contains(proof_lanes, lane) {
          proof_lanes.push(lane)
        }
        match lane {
          "tool" => tool_event_count += 1
          "diff" => diff_event_count += 1
          "test" => test_event_count += 1
          "artifact" => artifact_event_count += 1
          "review" => review_event_count += 1
          _ => ()
        }
      }
      None => ()
    }
  }
  let proof_event_count = tool_event_count +
    diff_event_count +
    test_event_count +
    artifact_event_count +
    review_event_count
  {
    "kind": "mooncode-runtime-ack-event-summary",
    "protocol": "mooncode.v1",
    "submitted_event_count": submitted.length(),
    "normalized_event_count": normalized.length(),
    "proof_event_count": proof_event_count,
    "tool_event_count": tool_event_count,
    "diff_event_count": diff_event_count,
    "test_event_count": test_event_count,
    "artifact_event_count": artifact_event_count,
    "review_event_count": review_event_count,
    "lanes": Json::array([ for lane in lanes => Json::string(lane) ]),
    "proof_lanes": Json::array(
      [
        for lane in proof_lanes => Json::string(lane)
      ],
    ),
    "normalized_events": Json::array(normalized),
    "evidence_policy": "Runtime replay acknowledgements may include streamed runtime events; Moondesk normalizes them into lanes so completed commands carry visible proof, not only a terminal receipt.",
  }
}

///|
fn runtime_replay_ack_scoped_event(
  event : Json,
  runtime_command : Json,
) -> Json {
  let packet = rq_json_object_field_or_empty(event, "command_packet")
  if rq_json_string(packet, "command_id", default="") != "" {
    event
  } else {
    rq_json_with_field(
      event,
      "command_packet",
      runtime_replay_ack_command_packet(runtime_command),
    )
  }
}

///|
fn runtime_replay_ack_command_packet(runtime_command : Json) -> Json {
  {
    "protocol": "mooncode.v1",
    "kind": "mooncode.command-ref",
    "command_id": rq_json_string(runtime_command, "command_id", default=""),
    "action": rq_json_string(runtime_command, "action", default="prompt"),
    "dispatch": rq_json_string(runtime_command, "dispatch", default="prompt"),
    "runtime_proof": true,
    "session_id": rq_json_string(runtime_command, "session_id", default=""),
    "task_id": rq_json_string(runtime_command, "task_id", default=""),
  }
}
