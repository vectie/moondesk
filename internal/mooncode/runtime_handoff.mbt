///|
pub fn runtime_event_ingest_contract(session_id : String) -> Json {
  {
    "endpoint": "/api/mooncode/sessions/\{session_id}/runtime-events",
    "method": "POST",
    "consumer": "moondesk",
    "producer": "moonclaw-or-standalone-mooncode",
    "accepted_payloads": [
      "OpenSeek-style JSONL event object with an `event` field", "legacy MoonClaw event object with desc.msg",
      "canonical MoonCode event object with lane/kind/status fields", "{\"events\":[...]} batch payload",
    ],
    "tool_call_wire": tool_call_wire_contract_json(),
    "tool_call_validation": "Tool-call and tool-result events should satisfy tool_call_wire before MoonClaw executes or reports a tool; invalid tools should be reported as tool_call_decode_error.",
    "command_scope_rule": "Events intended to satisfy command runtime proof must include `command_packet` or compact `command_id` plus matching `action`; unscoped events render in transcript but do not prove execution.",
    "normalization": "Events are normalized into MoonCode lanes and appended to .moontown/mooncode-sessions/<session-id>/events.jsonl.",
    "refreshes": [
      "action-plan", "runtime-evidence", "eval-report", "session-snapshot", "runtime-handoff",
    ],
    "runtime_evidence_artifact": "wiki/reviews/mooncode/<session-id>/runtime-evidence.json",
    "ordering_rule": "append in received order; event ids are used for projection dedupe",
  }
}

///|
test "runtime event ingest contract advertises command-scoped evidence refresh" {
  let contract = runtime_event_ingest_contract("agent-demo")
  assert_eq(
    json_string(contract, "endpoint", default=""),
    "/api/mooncode/sessions/agent-demo/runtime-events",
  )
  assert_true(
    json_string(contract, "command_scope_rule", default="").contains(
      "command_id",
    ),
  )
  assert_true(
    json_string(contract, "runtime_evidence_artifact", default="").contains(
      "runtime-evidence.json",
    ),
  )
  let encoded = contract.stringify()
  assert_true(encoded.contains("runtime-evidence"))
  assert_true(encoded.contains("session-snapshot"))
}

///|
pub fn runtime_handoff_manifest(
  session : Json,
  summary : Json,
  runtime_replay : Json,
  runtime_claim : Json,
  commands : Array[Json],
  runtime_commands : Array[Json],
  runtime_dispatches : Array[Json],
  daemon : Json,
  native_ready : Bool,
  recorded_at~ : String,
  manifest_path~ : String,
  absolute_manifest_path~ : String,
  workspace_root~ : String,
  session_snapshot_path~ : String,
  command_log_path~ : String,
  runtime_command_log_path~ : String,
  runtime_dispatch_log_path~ : String,
  event_log_path~ : String,
  stream_checkpoint_path~ : String,
) -> Json {
  let session_id = json_string(session, "id", default="")
  let normalized_runtime_dispatches = runtime_dispatch_receipts_for_response(
    runtime_dispatches,
  )
  let status = if native_ready {
    "native-runtime-ready"
  } else if commands.length() > 0 {
    "bridge-resumable"
  } else {
    "empty"
  }
  let lifecycle = runtime_command_lifecycle(
    session_id,
    runtime_commands,
    normalized_runtime_dispatches,
    [],
    lease_now=recorded_at,
  )
  let scheduler = serve_scheduler_projection(session_id, commands, lifecycle)
  let execution_plan = runtime_consumer_execution_plan(
    session_id, runtime_replay, runtime_claim, native_ready,
  )
  let turn_packet = runtime_turn_packet(
    session_id, runtime_replay, runtime_claim, scheduler, native_ready,
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
    "protocol": "mooncode.v1",
    "status": status,
    "session_id": session_id,
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "workspace_root": workspace_root,
    "task_id": json_string(session, "moonclaw_task_id", default=""),
    "recorded_at": recorded_at,
    "manifest_path": manifest_path,
    "absolute_manifest_path": absolute_manifest_path,
    "component_boundary": {
      "ui_owner": "moondesk",
      "runtime_owner": "moonclaw",
      "artifact_owner": "moonbook",
      "extractable_component": "mooncode",
    },
    "runtime_protocol": runtime_protocol_contract_json(),
    "tool_contract": tool_contract_json(),
    "tool_call_wire": tool_call_wire_contract_json(),
    "resume_contract": {
      "session_snapshot_path": session_snapshot_path,
      "session_store_endpoint": "/api/mooncode/sessions/\{session_id}/session-store",
      "command_log_path": command_log_path,
      "runtime_command_log_path": runtime_command_log_path,
      "runtime_dispatch_log_path": runtime_dispatch_log_path,
      "event_log_path": event_log_path,
      "stream_endpoint": "/api/mooncode/sessions/\{session_id}/stream?format=jsonl&since=<sequence>",
      "stream_state_endpoint": "/api/mooncode/sessions/\{session_id}/stream-state?consumer=<consumer>&since=<sequence>",
      "stream_checkpoint_path": stream_checkpoint_path,
      "runtime_event_ingest_endpoint": "/api/mooncode/sessions/\{session_id}/runtime-events",
      "command_queue_endpoint": "/api/mooncode/sessions/\{session_id}/commands",
      "runtime_command_feed_endpoint": "/api/mooncode/sessions/\{session_id}/runtime-commands",
      "runtime_claim_endpoint": "/api/mooncode/sessions/\{session_id}/runtime-claim",
      "runtime_dispatch_endpoint": "/api/mooncode/sessions/\{session_id}/runtime-dispatch",
      "runtime_replay_endpoint": "/api/mooncode/sessions/\{session_id}/runtime-replay",
      "preflight_endpoint": "/api/mooncode/sessions/\{session_id}/preflight?action=<action>&context_path=<path>",
      "action_plan_endpoint": "/api/mooncode/sessions/\{session_id}/action-plan",
      "native_command_endpoint": "/v1/mooncode/sessions/\{session_id}/commands",
      "native_eval_endpoint": "/v1/mooncode/sessions/\{session_id}/eval-report?book_root=<path>",
      "ordering_rule": "consume runtime-commands.jsonl in append order; commands.jsonl remains the UI/operator queue; emit progress to events.jsonl or the compatible native MoonCode stream",
    },
    "command_count": commands.length(),
    "commands": Json::array(commands),
    "runtime_command_count": runtime_commands.length(),
    "runtime_commands": Json::array(runtime_commands),
    "runtime_dispatch_count": normalized_runtime_dispatches.length(),
    "runtime_dispatch_pending_count": runtime_dispatch_pending_count(
      runtime_commands,
      normalized_runtime_dispatches,
      lease_now=recorded_at,
    ),
    "runtime_dispatches": Json::array(normalized_runtime_dispatches),
    "runtime_replay": runtime_replay,
    "runtime_claim": runtime_claim,
    "runtime_consumer": runtime_consumer_handoff(
      session_id, runtime_replay, runtime_claim, native_ready,
    ),
    "runtime_execution_plan": execution_plan,
    "serve_scheduler": scheduler,
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
      "dispatch_mode": json_string(
        session,
        "mooncode_dispatch_mode",
        default="moonclaw-task-bridge",
      ),
      "bridge_status": json_string(daemon, "status", default="unknown"),
      "moonclaw_root": json_string(daemon, "moonclaw_root", default=""),
    },
    "summary": summary,
    "next_runtime_step": if native_ready {
      "MoonClaw native MoonCode can consume the command queue, emit typed stream events, run tests/builds, and package accepted output."
    } else {
      "MoonClaw or a standalone mooncode runtime should consume this handoff, execute queued commands with OpenSeek-style tools, emit typed events, and write native eval evidence."
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
  json_string(contract, "runtime_dispatch_endpoint", default="") != "" &&
  json_string(contract, "runtime_dispatch_log_path", default="") != "" &&
  json_string(contract, "runtime_event_ingest_endpoint", default="") != "" &&
  json_string(contract, "runtime_replay_endpoint", default="") != "" &&
  json_string(contract, "action_plan_endpoint", default="") != "" &&
  json_string(runtime_consumer, "status", default="") != "" &&
  json_string(runtime_consumer, "next_action", default="") != "" &&
  json_string(runtime_consumer_endpoints, "runtime_claim", default="") != "" &&
  json_string(runtime_consumer_endpoints, "runtime_replay", default="") != ""
}

///|
test "mooncode runtime handoff manifest advertises resume and review contracts" {
  let session : Json = {
    "id": "s1",
    "workspace_id": "book",
    "workspace_name": "Book",
    "moonclaw_task_id": "task",
    "mooncode_last_command_packet": { "command_id": "cmd-1" },
    "mooncode_last_patch_set_manifest": {
      "kind": "mooncode-patch-set",
      "manifest_path": "wiki/reviews/mooncode/s1/patch-set.json",
    },
  }
  let runtime_commands : Array[Json] = [
    {
      "command_id": "cmd-1",
      "openseek_wire_valid": true,
      "openseek_wire_command": { "command": "prompt", "text": "build tool" },
    },
  ]
  let runtime_dispatches : Array[Json] = [
    { "command_id": "cmd-other", "status": "runtime-completed" },
  ]
  let runtime_replay = runtime_replay_state(
    "s1",
    runtime_commands,
    runtime_dispatches,
    workspace_id="book",
    workspace_name="Book",
    task_id="task",
    runtime_command_log_path="/tmp/book/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/book/runtime-dispatches.jsonl",
  )
  let runtime_claim = runtime_claim_state(
    "s1",
    runtime_commands,
    runtime_dispatches,
    workspace_id="book",
    workspace_name="Book",
    task_id="task",
    runtime_command_log_path="/tmp/book/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/book/runtime-dispatches.jsonl",
  )
  let manifest = runtime_handoff_manifest(
    session,
    session_summary(session, []),
    runtime_replay,
    runtime_claim,
    [{ "command_id": "cmd-1", "action": "prompt" }],
    runtime_commands,
    runtime_dispatches,
    { "running": true, "status": "running", "moonclaw_root": "../moonclaw" },
    false,
    recorded_at="2026-06-15T00:00:00Z",
    manifest_path="wiki/reviews/mooncode/s1/runtime-handoff.json",
    absolute_manifest_path="/tmp/book/wiki/reviews/mooncode/s1/runtime-handoff.json",
    workspace_root="/tmp/book",
    session_snapshot_path="/tmp/book/.moontown/mooncode-sessions/s1/session.json",
    command_log_path="/tmp/book/.moontown/mooncode-sessions/s1/commands.jsonl",
    runtime_command_log_path="/tmp/book/.moontown/mooncode-sessions/s1/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/book/.moontown/mooncode-sessions/s1/runtime-dispatches.jsonl",
    event_log_path="/tmp/book/.moontown/mooncode-sessions/s1/events.jsonl",
    stream_checkpoint_path="/tmp/book/.moontown/mooncode-sessions/s1/stream-checkpoints/moondesk-ui.json",
  )
  assert_eq(
    json_string(manifest, "kind", default=""),
    "mooncode-runtime-handoff",
  )
  assert_eq(json_string(manifest, "status", default=""), "bridge-resumable")
  assert_eq(
    summary_json_int(manifest, "runtime_dispatch_pending_count", default=0),
    1,
  )
  assert_eq(summary_json_int(manifest, "runtime_dispatch_count", default=0), 1)
  let dispatches = json_array_items(manifest, "runtime_dispatches")
  assert_eq(dispatches.length(), 1)
  assert_true(
    json_string(dispatches[0], "dispatch_id", default="").has_prefix(
      "mooncode-runtime-dispatch-",
    ),
  )
  let tool_call_wire = summary_json_object_field_or_empty(
    manifest, "tool_call_wire",
  )
  assert_eq(
    json_string(tool_call_wire, "kind", default=""),
    "mooncode-tool-call-wire-contract",
  )
  assert_true(tool_call_wire.stringify().contains("moon_check"))
  let runtime_event_sink = summary_json_object_field_or_empty(
    manifest, "runtime_event_sink",
  )
  assert_eq(
    json_string(
      summary_json_object_field_or_empty(runtime_event_sink, "tool_call_wire"),
      "kind",
      default="",
    ),
    "mooncode-tool-call-wire-contract",
  )
  let resume_contract = summary_json_object_field_or_empty(
    manifest, "resume_contract",
  )
  assert_true(
    json_string(resume_contract, "runtime_claim_endpoint", default="").contains(
      "/api/mooncode/sessions/s1/runtime-claim",
    ),
  )
  let consumer = summary_json_object_field_or_empty(
    manifest, "runtime_consumer",
  )
  assert_eq(json_string(consumer, "status", default=""), "claim-ready")
  assert_true(json_bool(consumer, "ready_to_claim", default=false))
  let execution_plan = summary_json_object_field_or_empty(
    manifest, "runtime_execution_plan",
  )
  assert_eq(
    json_string(execution_plan, "kind", default=""),
    "mooncode-runtime-consumer-execution-plan",
  )
  assert_eq(json_string(execution_plan, "status", default=""), "ready-to-claim")
  assert_eq(json_string(execution_plan, "command_id", default=""), "cmd-1")
  assert_true(json_bool(execution_plan, "ready_to_execute", default=false))
  let scheduler = summary_json_object_field_or_empty(
    manifest, "serve_scheduler",
  )
  assert_eq(
    json_string(scheduler, "kind", default=""),
    "mooncode-serve-scheduler-state",
  )
  let turn_packet = summary_json_object_field_or_empty(
    manifest, "runtime_turn_packet",
  )
  assert_eq(
    json_string(turn_packet, "kind", default=""),
    "mooncode-runtime-turn-packet",
  )
  assert_eq(json_string(turn_packet, "command_id", default=""), "cmd-1")
  assert_eq(
    json_string(turn_packet, "scheduler_effect", default=""),
    "start-turn",
  )
  assert_true(json_bool(turn_packet, "scheduler_allows_turn", default=false))
  let supervisor = summary_json_object_field_or_empty(
    manifest, "runtime_supervisor",
  )
  assert_eq(
    json_string(supervisor, "kind", default=""),
    "mooncode-runtime-supervisor-launch",
  )
  assert_eq(json_string(supervisor, "command_id", default=""), "cmd-1")
  assert_true(json_bool(supervisor, "ready_to_launch", default=false))
  assert_eq(json_string(supervisor, "moonclaw_root", default=""), "../moonclaw")
  let readiness = summary_json_object_field_or_empty(supervisor, "readiness")
  assert_eq(
    json_string(readiness, "kind", default=""),
    "mooncode-runtime-supervisor-readiness",
  )
  assert_true(json_bool(readiness, "ok", default=false))
  assert_eq(
    summary_json_int(readiness, "missing_requirement_count", default=-1),
    0,
  )
  let artifacts = summary_json_object_field_or_empty(
    manifest, "artifact_manifests",
  )
  assert_eq(
    json_string(
      summary_json_object_field_or_empty(artifacts, "patch_set"),
      "manifest_path",
      default="",
    ),
    "wiki/reviews/mooncode/s1/patch-set.json",
  )
}

///|
test "mooncode runtime handoff currency requires consumer endpoints" {
  let current : Json = {
    "kind": "mooncode-runtime-handoff",
    "resume_contract": {
      "runtime_command_feed_endpoint": "/api/mooncode/sessions/s1/runtime-commands",
      "runtime_command_log_path": "runtime-commands.jsonl",
      "runtime_claim_endpoint": "/api/mooncode/sessions/s1/runtime-claim",
      "runtime_dispatch_endpoint": "/api/mooncode/sessions/s1/runtime-dispatch",
      "runtime_dispatch_log_path": "runtime-dispatches.jsonl",
      "runtime_event_ingest_endpoint": "/api/mooncode/sessions/s1/runtime-events",
      "runtime_replay_endpoint": "/api/mooncode/sessions/s1/runtime-replay",
      "action_plan_endpoint": "/api/mooncode/sessions/s1/action-plan",
    },
    "runtime_consumer": {
      "status": "lease-held",
      "next_action": "execute",
      "endpoints": {
        "runtime_claim": "/api/mooncode/sessions/s1/runtime-claim",
        "runtime_replay": "/api/mooncode/sessions/s1/runtime-replay",
      },
    },
  }
  assert_true(runtime_handoff_manifest_current(current))
  let legacy : Json = {
    "kind": "mooncode-runtime-handoff",
    "resume_contract": {
      "runtime_command_feed_endpoint": "/api/mooncode/sessions/s1/runtime-commands",
      "runtime_command_log_path": "runtime-commands.jsonl",
      "runtime_claim_endpoint": "/api/mooncode/sessions/s1/runtime-claim",
      "runtime_dispatch_endpoint": "/api/mooncode/sessions/s1/runtime-dispatch",
      "runtime_dispatch_log_path": "runtime-dispatches.jsonl",
      "runtime_event_ingest_endpoint": "/api/mooncode/sessions/s1/runtime-events",
      "runtime_replay_endpoint": "/api/mooncode/sessions/s1/runtime-replay",
      "action_plan_endpoint": "/api/mooncode/sessions/s1/action-plan",
    },
  }
  assert_false(runtime_handoff_manifest_current(legacy))
}
