///|
fn runtime_replay_ack_effective_status(
  requested_status : String,
  proof_gate : Json,
) -> String {
  @mooncode_core.runtime_replay_ack_effective_status(
    requested_status,
    rq_json_bool(proof_gate, "completion_blocked", default=false),
  )
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
  @mooncode_core.runtime_completion_proof_gate(
    action,
    evidence,
    prior_events.length(),
    submitted_events.length(),
    rq_json_array_items(evidence, "missing_required_events"),
    rq_json_array_items(evidence, "failed_required_events"),
  )
}
