///|
pub fn runtime_event_ingest_contract(session_id : String) -> Json {
  {
    "endpoint": "/api/mooncode/sessions/\{session_id}/runtime-events",
    "method": "POST",
    "consumer": "moondesk",
    "producer": "moonclaw",
    "accepted_payloads": [
      "MoonCode JSONL event object with an `event` field", "canonical MoonCode event object with lane/kind/status fields",
      "{\"events\":[...]} batch payload",
    ],
    "tool_call_contract": tool_call_contract_json(),
    "tool_call_validation": "Tool-call and tool-result events should satisfy tool_call_contract before MoonClaw executes or reports a tool; invalid tools should be reported as tool_call_decode_error.",
    "command_scope_rule": "Events intended to satisfy command runtime proof must include `command_packet` or compact `command_id` plus matching `action`; unscoped events render in transcript but do not prove execution.",
    "normalization": "Events are normalized into MoonCode lanes and appended to \{@moonsuite.product_display_artifact("mooncode", "sessions/<session-id>/events.jsonl")}.",
    "refreshes": [
      "action-plan", "runtime-evidence", "eval-report", "session-snapshot", "runtime-handoff",
    ],
    "runtime_evidence_artifact": "wiki/reviews/mooncode/<session-id>/runtime-evidence.json",
    "ordering_rule": "append in received order; event ids are used for projection dedupe",
  }
}

///|
pub fn runtime_handoff_manifest(
  session : Json,
  summary : Json,
  runtime_replay : Json,
  runtime_claim : Json,
  commands : Array[Json],
  runtime_commands : Array[Json],
  runtime_receipts : Array[Json],
  daemon : Json,
  native_ready : Bool,
  recorded_at~ : String,
  manifest_path~ : String,
  absolute_manifest_path~ : String,
  workspace_root~ : String,
  session_snapshot_path~ : String,
  command_log_path~ : String,
  runtime_command_log_path~ : String,
  runtime_receipt_log_path~ : String,
  event_log_path~ : String,
  stream_checkpoint_path~ : String,
) -> Json {
  let session_id = json_string(session, "id", default="")
  let normalized_runtime_receipts = runtime_receipts_for_response(
    runtime_receipts,
  )
  let status = if native_ready {
    "native-runtime-ready"
  } else if commands.length() > 0 {
    "replay-resumable"
  } else {
    "empty"
  }
  let lifecycle = runtime_command_lifecycle(
    session_id,
    runtime_commands,
    normalized_runtime_receipts,
    [],
    lease_now=recorded_at,
  )
  let control = runtime_control_projection(session_id, commands, lifecycle)
  let execution_plan = runtime_consumer_execution_plan(
    session_id, runtime_replay, runtime_claim, native_ready,
  )
  let turn_packet = runtime_turn_packet(
    session_id, runtime_replay, runtime_claim, control, native_ready,
  )
  let supervisor = runtime_supervisor_launch_packet(
    session_id,
    turn_packet,
    runtime_consumer_handoff(
      session_id, runtime_replay, runtime_claim, native_ready,
    ),
    workspace_root~,
    moonclaw_root=json_string(daemon, "moonclaw_root", default=""),
    host_base_url="",
    native_ready,
  )
  let daemon_running = json_bool(daemon, "running", default=false)
  {
    "kind": "mooncode-runtime-handoff",
    "protocol": protocol_version(),
    "status": status,
    "session_id": session_id,
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "workspace_root": workspace_root,
    "runtime_session_id": session_runtime_session_id(session),
    "recorded_at": recorded_at,
    "manifest_path": manifest_path,
    "absolute_manifest_path": absolute_manifest_path,
    "component_boundary": {
      "ui_owner": "moondesk",
      "runtime_owner": "moonclaw",
      "artifact_owner": "moonbook",
      "standalone_component": "mooncode",
    },
    "runtime_protocol": runtime_protocol_contract_json(),
    "tool_contract": tool_contract_json(),
    "tool_call_contract": tool_call_contract_json(),
    "resume_contract": {
      "session_snapshot_path": session_snapshot_path,
      "session_store_endpoint": "/api/mooncode/sessions/\{session_id}/session-store",
      "command_log_path": command_log_path,
      "runtime_command_log_path": runtime_command_log_path,
      "runtime_receipt_log_path": runtime_receipt_log_path,
      "event_log_path": event_log_path,
      "stream_endpoint": "/api/mooncode/sessions/\{session_id}/stream?format=jsonl&since=<sequence>",
      "stream_state_endpoint": "/api/mooncode/sessions/\{session_id}/stream-state?consumer=<consumer>&since=<sequence>",
      "stream_checkpoint_path": stream_checkpoint_path,
      "runtime_event_ingest_endpoint": "/api/mooncode/sessions/\{session_id}/runtime-events",
      "command_queue_endpoint": "/api/mooncode/sessions/\{session_id}/commands",
      "runtime_command_feed_endpoint": "/api/mooncode/sessions/\{session_id}/runtime-commands",
      "runtime_claim_endpoint": "/api/mooncode/sessions/\{session_id}/runtime-claim",
      "runtime_replay_endpoint": "/api/mooncode/sessions/\{session_id}/runtime-replay",
      "preflight_endpoint": "/api/mooncode/sessions/\{session_id}/preflight?action=<action>&context_path=<path>",
      "action_plan_endpoint": "/api/mooncode/sessions/\{session_id}/action-plan",
      "readiness_endpoint": "/api/mooncode/sessions/\{session_id}/readiness",
      "native_command_endpoint": "/v1/code/sessions/\{session_id}/commands",
      "native_runtime_control_endpoint": "/v1/code/sessions/\{session_id}/runtime-control?book_root=<path>",
      "native_eval_endpoint": "/v1/code/sessions/\{session_id}/eval-report?book_root=<path>",
      "ordering_rule": "consume runtime-commands.jsonl in append order; commands.jsonl remains the UI/operator queue; emit progress to events.jsonl or the native MoonCode stream",
    },
    "command_count": commands.length(),
    "commands": Json::array(commands),
    "runtime_command_count": runtime_commands.length(),
    "runtime_commands": Json::array(runtime_commands),
    "runtime_receipt_count": normalized_runtime_receipts.length(),
    "runtime_receipt_pending_count": runtime_receipt_pending_count(
      runtime_commands,
      normalized_runtime_receipts,
      lease_now=recorded_at,
    ),
    "runtime_receipts": Json::array(normalized_runtime_receipts),
    "runtime_replay": runtime_replay,
    "runtime_claim": runtime_claim,
    "runtime_consumer": runtime_consumer_handoff(
      session_id, runtime_replay, runtime_claim, native_ready,
    ),
    "runtime_execution_plan": execution_plan,
    "runtime_control": control,
    "runtime_turn_packet": turn_packet,
    "runtime_supervisor": supervisor,
    "runtime_event_sink": runtime_event_ingest_contract(session_id),
    "last_command_packet": summary_json_object_field_or_empty(
      session, "mooncode_last_command_packet",
    ),
    "artifact_manifests": {
      "change_set": summary_json_object_field_or_empty(
        session, "mooncode_last_change_set_manifest",
      ),
      "patch_set": summary_json_object_field_or_empty(
        session, "mooncode_last_patch_set_manifest",
      ),
      "tool_approvals": summary_json_object_field_or_empty(
        session, "mooncode_last_tool_approvals_manifest",
      ),
      "test_runs": summary_json_object_field_or_empty(
        session, "mooncode_last_test_runs_manifest",
      ),
      "action_plan": summary_json_object_field_or_empty(
        session, "mooncode_last_action_plan_manifest",
      ),
      "package_index": summary_json_object_field_or_empty(
        session, "mooncode_last_package_index_manifest",
      ),
      "eval_report": summary_json_object_field_or_empty(
        session, "mooncode_last_eval_report_manifest",
      ),
    },
    "book_output_roots": [
      "tools/", "apps/", "book/site/generated/", "portable/app-tool/", "wiki/reviews/",
      "raw/analysis-runs/",
    ],
    "engine": {
      "daemon_running": daemon_running,
      "native_runtime_ready": native_ready,
      "runtime_mode": json_string(
        session,
        "mooncode_runtime_mode",
        default="runtime-not-started",
      ),
      "daemon_status": json_string(daemon, "status", default="unknown"),
      "moonclaw_root": json_string(daemon, "moonclaw_root", default=""),
    },
    "summary": summary,
    "next_runtime_step": if native_ready {
      "MoonClaw native MoonCode can consume the command queue, emit typed stream events, run tests/builds, and package accepted output."
    } else {
      "Start or update the native MoonCode runtime before queued commands can be executed."
    },
  }
}

///|
pub fn runtime_handoff_manifest_current(manifest : Json) -> Bool {
  let contract = summary_json_object_field_or_empty(manifest, "resume_contract")
  let runtime_consumer = summary_json_object_field_or_empty(
    manifest, "runtime_consumer",
  )
  let runtime_consumer_endpoints = summary_json_object_field_or_empty(
    runtime_consumer, "endpoints",
  )
  json_string(contract, "runtime_command_feed_endpoint", default="") != "" &&
  json_string(contract, "runtime_command_log_path", default="") != "" &&
  json_string(contract, "runtime_claim_endpoint", default="") != "" &&
  json_string(contract, "runtime_receipt_log_path", default="") != "" &&
  json_string(contract, "runtime_event_ingest_endpoint", default="") != "" &&
  json_string(contract, "runtime_replay_endpoint", default="") != "" &&
  json_string(contract, "action_plan_endpoint", default="") != "" &&
  json_string(contract, "readiness_endpoint", default="") != "" &&
  json_string(contract, "native_runtime_control_endpoint", default="") != "" &&
  json_string(runtime_consumer, "status", default="") != "" &&
  json_string(runtime_consumer, "next_action", default="") != "" &&
  json_string(runtime_consumer_endpoints, "runtime_claim", default="") != "" &&
  json_string(runtime_consumer_endpoints, "runtime_replay", default="") != "" &&
  json_string(runtime_consumer_endpoints, "native_session_listing", default="") !=
  "" &&
  json_string(runtime_consumer_endpoints, "native_runtime_control", default="") !=
  ""
}
