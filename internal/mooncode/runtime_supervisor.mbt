///|
pub fn runtime_turn_packet(
  session_id : String,
  runtime_replay : Json,
  runtime_claim : Json,
  serve_scheduler : Json,
  native_ready : Bool,
) -> Json {
  let plan = runtime_consumer_execution_plan(
    session_id, runtime_replay, runtime_claim, native_ready,
  )
  let command_id = rq_json_string(plan, "command_id", default="")
  let scheduler_decision = runtime_scheduler_decision_for_command(
    serve_scheduler, command_id,
  )
  let scheduler_effect = rq_json_string(
    scheduler_decision,
    "effect",
    default="none",
  )
  let scheduler_allows_turn = scheduler_effect == "start-turn" ||
    scheduler_effect == "active-turn" ||
    scheduler_effect == "deliver-steer" ||
    scheduler_effect == "queue-steer" ||
    scheduler_effect == "cancel-active" ||
    scheduler_effect == "withdraw-pending" ||
    scheduler_effect == "queue-turn"
  {
    "kind": kind_runtime_turn_packet(),
    "protocol": protocol_version(),
    "reference": "../openseek/cmd/openseek/serve.mbt",
    "session_id": session_id,
    "status": rq_json_string(plan, "status", default="idle"),
    "operation": rq_json_string(plan, "operation", default="wait"),
    "native_runtime_ready": native_ready,
    "command_id": command_id,
    "action": rq_json_string(plan, "action", default=""),
    "ready_to_claim": rq_json_bool(plan, "ready_to_claim", default=false),
    "ready_to_execute": rq_json_bool(plan, "ready_to_execute", default=false),
    "ready_to_ack": rq_json_bool(plan, "ready_to_ack", default=false),
    "scheduler_effect": scheduler_effect,
    "scheduler_allows_turn": scheduler_allows_turn,
    "scheduler_decision": scheduler_decision,
    "openseek_wire_command": rq_json_object_field_or_empty(
      plan, "openseek_wire_command",
    ),
    "native_mooncode_body": rq_json_object_field_or_empty(
      plan, "native_mooncode_body",
    ),
    "execution_summary": rq_json_object_field_or_empty(
      plan, "execution_summary",
    ),
    "execution_checklist": rq_json_array_items(plan, "execution_checklist"),
    "required_events": rq_json_array_items(plan, "required_events"),
    "required_outputs": rq_json_array_items(plan, "required_outputs"),
    "claim_request_template": rq_json_object_field_or_empty(
      plan, "claim_request_template",
    ),
    "ack_request_template": rq_json_object_field_or_empty(
      plan, "ack_request_template",
    ),
    "failure_ack_template": rq_json_object_field_or_empty(
      plan, "failure_ack_template",
    ),
    "endpoints": {
      "claim": rq_json_string(plan, "claim_endpoint", default=""),
      "ack": rq_json_string(plan, "ack_endpoint", default=""),
      "runtime_events": rq_json_string(
        plan,
        "runtime_event_ingest_endpoint",
        default="",
      ),
      "stream": rq_json_string(plan, "stream_endpoint", default=""),
      "native_session_listing": rq_json_string(
        plan,
        "native_session_listing_endpoint",
        default="",
      ),
      "native_commands": rq_json_string(
        plan,
        "native_command_endpoint",
        default="",
      ),
      "native_serve_scheduler": rq_json_string(
        plan,
        "native_serve_scheduler_endpoint",
        default="",
      ),
      "native_eval_report": rq_json_string(
        plan,
        "native_eval_report_endpoint",
        default="",
      ),
    },
    "runtime_protocol": runtime_protocol_contract_json(),
    "tool_contract": tool_contract_json(),
    "tool_call_wire": tool_call_wire_contract_json(),
    "completion_rule": rq_json_string(plan, "completion_rule", default=""),
    "next_step": rq_json_string(plan, "next_step", default=""),
    "safety_boundary": "This packet is a self-contained turn handoff for MoonClaw or standalone mooncode. Moondesk does not execute it; the runtime must enforce the embedded scheduler, tool, approval, path, test, and package contracts, stream events, then acknowledge through runtime-replay.",
    "owner": runtime_owner_record(),
  }
}

///|
pub fn runtime_supervisor_readiness_report(supervisor : Json) -> Json {
  let endpoints = rq_json_object_field_or_empty(supervisor, "endpoints")
  let launch_request = rq_json_object_field_or_empty(
    supervisor, "launch_request",
  )
  let loop_steps = rq_json_array_items(supervisor, "supervisor_loop")
  let missing : Array[String] = []
  if rq_json_string(supervisor, "command_id", default="") == "" {
    missing.push("command_id")
  }
  if !rq_json_bool(supervisor, "scheduler_allows_turn", default=false) {
    missing.push("scheduler_allows_turn")
  }
  if !rq_json_bool(supervisor, "ready_to_launch", default=false) {
    missing.push("ready_to_launch")
  }
  if rq_json_string(endpoints, "session_store", default="") == "" {
    missing.push("endpoint.session_store")
  }
  if rq_json_string(endpoints, "production_readiness", default="") == "" {
    missing.push("endpoint.production_readiness")
  }
  if rq_json_string(endpoints, "claim", default="") == "" {
    missing.push("endpoint.claim")
  }
  if rq_json_string(endpoints, "ack", default="") == "" {
    missing.push("endpoint.ack")
  }
  if rq_json_string(endpoints, "runtime_events", default="") == "" {
    missing.push("endpoint.runtime_events")
  }
  if rq_json_string(endpoints, "stream", default="") == "" {
    missing.push("endpoint.stream")
  }
  if rq_json_string(endpoints, "native_session_listing", default="") == "" {
    missing.push("endpoint.native_session_listing")
  }
  if rq_json_string(endpoints, "native_commands", default="") == "" {
    missing.push("endpoint.native_commands")
  }
  if rq_json_string(endpoints, "native_serve_scheduler", default="") == "" {
    missing.push("endpoint.native_serve_scheduler")
  }
  if rq_json_string(endpoints, "native_eval_report", default="") == "" {
    missing.push("endpoint.native_eval_report")
  }
  if rq_json_object_field_or_empty(launch_request, "claim_request").stringify() ==
    "{}" {
    missing.push("launch_request.claim_request")
  }
  if rq_json_object_field_or_empty(launch_request, "ack_request").stringify() ==
    "{}" {
    missing.push("launch_request.ack_request")
  }
  if !runtime_supervisor_has_loop_step(loop_steps, "load-session") {
    missing.push("loop.load-session")
  }
  if !runtime_supervisor_has_loop_step(loop_steps, "claim-command") {
    missing.push("loop.claim-command")
  }
  if !runtime_supervisor_has_loop_step(loop_steps, "execute-turn") {
    missing.push("loop.execute-turn")
  }
  if !runtime_supervisor_has_loop_step(loop_steps, "stream-events") {
    missing.push("loop.stream-events")
  }
  if !runtime_supervisor_has_loop_step(loop_steps, "acknowledge") {
    missing.push("loop.acknowledge")
  }
  if !runtime_supervisor_has_loop_step(loop_steps, "report-eval") {
    missing.push("loop.report-eval")
  }
  if !runtime_supervisor_has_loop_step(loop_steps, "check-production-readiness") {
    missing.push("loop.check-production-readiness")
  }
  let ok = missing.length() == 0
  {
    "kind": "mooncode-runtime-supervisor-readiness",
    "protocol": protocol_version(),
    "ok": ok,
    "status": if ok {
      "launch-ready"
    } else {
      "blocked"
    },
    "missing_requirements": Json::array(
      [
        for item in missing => Json::string(item)
      ],
    ),
    "missing_requirement_count": missing.length(),
    "endpoint_ready": rq_json_string(endpoints, "claim", default="") != "" &&
    rq_json_string(endpoints, "ack", default="") != "" &&
    rq_json_string(endpoints, "runtime_events", default="") != "" &&
    rq_json_string(endpoints, "session_store", default="") != "" &&
    rq_json_string(endpoints, "production_readiness", default="") != "" &&
    rq_json_string(endpoints, "stream", default="") != "" &&
    rq_json_string(endpoints, "native_session_listing", default="") != "" &&
    rq_json_string(endpoints, "native_commands", default="") != "" &&
    rq_json_string(endpoints, "native_serve_scheduler", default="") != "" &&
    rq_json_string(endpoints, "native_eval_report", default="") != "",
    "launch_request_ready": rq_json_object_field_or_empty(
      launch_request, "claim_request",
    ).stringify() !=
    "{}" &&
    rq_json_object_field_or_empty(launch_request, "ack_request").stringify() !=
    "{}",
    "supervisor_loop_ready": runtime_supervisor_has_loop_step(
      loop_steps, "load-session",
    ) &&
    runtime_supervisor_has_loop_step(loop_steps, "claim-command") &&
    runtime_supervisor_has_loop_step(loop_steps, "execute-turn") &&
    runtime_supervisor_has_loop_step(loop_steps, "stream-events") &&
    runtime_supervisor_has_loop_step(loop_steps, "acknowledge") &&
    runtime_supervisor_has_loop_step(loop_steps, "report-eval") &&
    runtime_supervisor_has_loop_step(loop_steps, "check-production-readiness"),
    "safety_boundary": "Readiness means the launch packet is well formed for a MoonClaw or standalone mooncode consumer. It does not mean Moondesk may execute tools.",
  }
}
