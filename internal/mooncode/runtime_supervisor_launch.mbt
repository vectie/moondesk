///|
// MoonCode runtime supervisor launch packet projection.

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
    "native_session_listing": runtime_supervisor_url(
      host_base_url,
      runtime_supervisor_endpoint_from_turn(
        turn_packet, "native_session_listing",
      ),
    ),
    "native_commands": runtime_supervisor_url(
      host_base_url,
      runtime_supervisor_endpoint_from_turn(turn_packet, "native_commands"),
    ),
    "native_serve_scheduler": runtime_supervisor_url(
      host_base_url,
      runtime_supervisor_endpoint_from_turn(
        turn_packet, "native_serve_scheduler",
      ),
    ),
    "native_eval_report": runtime_supervisor_url(
      host_base_url,
      runtime_supervisor_endpoint_from_turn(turn_packet, "native_eval_report"),
    ),
  }
  let packet : Json = {
    "kind": "mooncode-runtime-supervisor-launch",
    "protocol": protocol_version(),
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
      "protocol": protocol_version(),
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
          runtime_supervisor_endpoint_from_turn(
            turn_packet, "native_eval_report",
          ),
        ),
        "purpose": "Attach native tool/file-edit/patch-review/command-execution/package-output eval harness evidence when available.",
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
