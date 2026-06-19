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
    "protocol": protocol_version(),
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
    "protocol": protocol_version(),
    "kind": kind_command_ref(),
    "command_id": rq_json_string(runtime_command, "command_id", default=""),
    "action": rq_json_string(runtime_command, "action", default="prompt"),
    "dispatch": rq_json_string(runtime_command, "dispatch", default="prompt"),
    "runtime_proof": true,
    "session_id": rq_json_string(runtime_command, "session_id", default=""),
    "runtime_session_id": rq_json_string(
      runtime_command,
      "runtime_session_id",
      default="",
    ),
  }
}
