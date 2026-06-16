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
    "kind": "mooncode-runtime-turn-packet",
    "protocol": "mooncode.v1",
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
      "native_commands": rq_json_string(
        plan,
        "native_command_endpoint",
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
pub fn runtime_supervisor_launch_packet(
  session_id : String,
  turn_packet : Json,
  runtime_consumer : Json,
  workspace_root~ : String,
  moonclaw_root~ : String,
  host_base_url~ : String,
  native_ready : Bool,
) -> Json {
  let command_id = rq_json_string(turn_packet, "command_id", default="")
  let status = rq_json_string(turn_packet, "status", default="idle")
  let operation = rq_json_string(turn_packet, "operation", default="wait")
  let action = rq_json_string(turn_packet, "action", default="")
  let mode = if native_ready {
    "native-mooncode-runtime"
  } else {
    "moondesk-claim-replay-bridge"
  }
  let scheduler_allows_turn = rq_json_bool(
    turn_packet,
    "scheduler_allows_turn",
    default=false,
  )
  let ready_to_execute = rq_json_bool(
    turn_packet,
    "ready_to_execute",
    default=false,
  )
  let ready_to_launch = command_id != "" &&
    ready_to_execute &&
    scheduler_allows_turn
  let endpoints = {
    "session_store": runtime_supervisor_url(
      host_base_url,
      "/api/mooncode/sessions/\{session_id}/session-store",
    ),
    "runtime_handoff": runtime_supervisor_url(
      host_base_url,
      "/api/mooncode/sessions/\{session_id}/runtime-handoff",
    ),
    "runtime_supervisor": runtime_supervisor_url(
      host_base_url,
      "/api/mooncode/sessions/\{session_id}/runtime-supervisor",
    ),
    "runtime_commands": runtime_supervisor_url(
      host_base_url,
      "/api/mooncode/sessions/\{session_id}/runtime-commands",
    ),
    "serve_scheduler": runtime_supervisor_url(
      host_base_url,
      "/api/mooncode/sessions/\{session_id}/serve-scheduler",
    ),
    "claim": runtime_supervisor_url(
      host_base_url,
      runtime_supervisor_endpoint_from_turn(turn_packet, "claim"),
    ),
    "ack": runtime_supervisor_url(
      host_base_url,
      runtime_supervisor_endpoint_from_turn(turn_packet, "ack"),
    ),
    "runtime_events": runtime_supervisor_url(
      host_base_url,
      runtime_supervisor_endpoint_from_turn(turn_packet, "runtime_events"),
    ),
    "stream": runtime_supervisor_url(
      host_base_url,
      runtime_supervisor_endpoint_from_turn(turn_packet, "stream"),
    ),
    "native_commands": runtime_supervisor_url(
      host_base_url,
      runtime_supervisor_endpoint_from_turn(turn_packet, "native_commands"),
    ),
  }
  let packet : Json = {
    "kind": "mooncode-runtime-supervisor-launch",
    "protocol": "mooncode.v1",
    "reference": "../openseek/cmd/openseek/serve.mbt",
    "session_id": session_id,
    "status": status,
    "operation": operation,
    "mode": mode,
    "native_runtime_ready": native_ready,
    "runtime_owner": "moonclaw-or-standalone-mooncode",
    "workspace_root": workspace_root,
    "moonclaw_root": moonclaw_root,
    "host_base_url": host_base_url,
    "command_id": command_id,
    "action": action,
    "scheduler_effect": rq_json_string(
      turn_packet,
      "scheduler_effect",
      default="none",
    ),
    "scheduler_allows_turn": scheduler_allows_turn,
    "ready_to_launch": ready_to_launch,
    "launch_blocked_reason": runtime_supervisor_blocked_reason(
      command_id, status, ready_to_execute, scheduler_allows_turn,
    ),
    "endpoints": endpoints,
    "launch_request": {
      "protocol": "mooncode.v1",
      "session_id": session_id,
      "command_id": command_id,
      "action": action,
      "mode": mode,
      "workspace_root": workspace_root,
      "claim_request": rq_json_object_field_or_empty(
        turn_packet, "claim_request_template",
      ),
      "ack_request": rq_json_object_field_or_empty(
        turn_packet, "ack_request_template",
      ),
      "failure_ack": rq_json_object_field_or_empty(
        turn_packet, "failure_ack_template",
      ),
      "openseek_wire_command": rq_json_object_field_or_empty(
        turn_packet, "openseek_wire_command",
      ),
      "native_mooncode_body": rq_json_object_field_or_empty(
        turn_packet, "native_mooncode_body",
      ),
      "required_events": rq_json_array_items(turn_packet, "required_events"),
      "required_outputs": rq_json_array_items(turn_packet, "required_outputs"),
    },
    "supervisor_loop": [
      {
        "id": "load-session",
        "method": "GET",
        "endpoint": runtime_supervisor_url(
          host_base_url,
          "/api/mooncode/sessions/\{session_id}/session-store",
        ),
        "purpose": "Load durable session, transcript, command log, runtime command log, dispatch receipts, and event log.",
      },
      {
        "id": "claim-command",
        "method": "POST",
        "endpoint": runtime_supervisor_url(
          host_base_url,
          runtime_supervisor_endpoint_from_turn(turn_packet, "claim"),
        ),
        "body": rq_json_object_field_or_empty(
          turn_packet, "claim_request_template",
        ),
        "purpose": "Acquire a lease before executing the command so the runtime trail is auditable.",
      },
      {
        "id": "execute-turn",
        "method": "LOCAL",
        "endpoint": "moonclaw/open-seek-compatible-tool-loop",
        "body": {
          "openseek_wire_command": rq_json_object_field_or_empty(
            turn_packet, "openseek_wire_command",
          ),
          "native_mooncode_body": rq_json_object_field_or_empty(
            turn_packet, "native_mooncode_body",
          ),
        },
        "purpose": "Run the typed MoonClaw/MoonCode agent loop with bounded read, edit, write, shell, moon_check, and finish tools.",
      },
      {
        "id": "stream-events",
        "method": "POST",
        "endpoint": runtime_supervisor_url(
          host_base_url,
          runtime_supervisor_endpoint_from_turn(turn_packet, "runtime_events"),
        ),
        "purpose": "Append assistant deltas, reasoning, tool calls/results, diffs, tests, artifacts, and terminal status.",
      },
      {
        "id": "acknowledge",
        "method": "POST",
        "endpoint": runtime_supervisor_url(
          host_base_url,
          runtime_supervisor_endpoint_from_turn(turn_packet, "ack"),
        ),
        "body": rq_json_object_field_or_empty(
          turn_packet, "ack_request_template",
        ),
        "purpose": "Record runtime-completed, runtime-acknowledged, failed, or cancelled status after proof events are persisted.",
      },
      {
        "id": "report-eval",
        "method": "POST",
        "endpoint": runtime_supervisor_url(
          host_base_url,
          "/v1/mooncode/sessions/\{session_id}/eval-report?book_root=<path>",
        ),
        "purpose": "Attach native tool/file-edit eval harness evidence when available.",
      },
    ],
    "turn_packet": turn_packet,
    "runtime_consumer": runtime_consumer,
    "tool_contract": tool_contract_json(),
    "tool_call_wire": tool_call_wire_contract_json(),
    "safety_boundary": "This launch packet is declarative. Moondesk may expose it and persist it, but MoonClaw or standalone mooncode must own model calls, tool execution, path policy, approvals, tests, diffs, packaging, cancellation, and final acknowledgement.",
    "extractable_component": "mooncode",
  }
  rq_json_with_field(
    packet,
    "readiness",
    runtime_supervisor_readiness_report(packet),
  )
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
  if rq_json_string(endpoints, "claim", default="") == "" {
    missing.push("endpoint.claim")
  }
  if rq_json_string(endpoints, "ack", default="") == "" {
    missing.push("endpoint.ack")
  }
  if rq_json_string(endpoints, "runtime_events", default="") == "" {
    missing.push("endpoint.runtime_events")
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
  let ok = missing.length() == 0
  {
    "kind": "mooncode-runtime-supervisor-readiness",
    "protocol": "mooncode.v1",
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
    rq_json_string(endpoints, "session_store", default="") != "",
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
    runtime_supervisor_has_loop_step(loop_steps, "acknowledge"),
    "safety_boundary": "Readiness means the launch packet is well formed for a MoonClaw or standalone mooncode consumer. It does not mean Moondesk may execute tools.",
  }
}

///|
fn runtime_scheduler_decision_for_command(
  serve_scheduler : Json,
  command_id : String,
) -> Json {
  if command_id == "" {
    return Json::object({})
  }
  for decision in rq_json_array_items(serve_scheduler, "decisions") {
    if rq_json_string(decision, "command_id", default="") == command_id {
      return decision
    }
  }
  Json::object({})
}

///|
fn runtime_supervisor_has_loop_step(steps : Array[Json], id : String) -> Bool {
  for step in steps {
    if rq_json_string(step, "id", default="") == id {
      return true
    }
  }
  false
}

///|
fn runtime_supervisor_endpoint_from_turn(
  turn_packet : Json,
  key : String,
) -> String {
  let endpoints = rq_json_object_field_or_empty(turn_packet, "endpoints")
  rq_json_string(endpoints, key, default="")
}

///|
fn runtime_supervisor_url(host_base_url : String, path : String) -> String {
  if host_base_url == "" || path == "" {
    path
  } else {
    "\{host_base_url}\{path}"
  }
}

///|
fn runtime_supervisor_blocked_reason(
  command_id : String,
  status : String,
  ready_to_execute : Bool,
  scheduler_allows_turn : Bool,
) -> String {
  if command_id == "" {
    "no runtime command is ready for execution"
  } else if !scheduler_allows_turn {
    "serve scheduler does not allow this turn yet"
  } else if !ready_to_execute {
    "runtime command status `\{status}` is not executable"
  } else {
    ""
  }
}
