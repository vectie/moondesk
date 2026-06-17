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
    "protocol": protocol_version(),
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
