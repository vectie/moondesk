///|
test "runtime event ingest contract advertises command-scoped evidence refresh" {
  let contract = runtime_event_ingest_contract("code-demo")
  assert_eq(
    json_string(contract, "endpoint", default=""),
    "/api/mooncode/sessions/code-demo/runtime-events",
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
test "mooncode runtime handoff manifest advertises resume and review contracts" {
  let session : Json = {
    "id": "s1",
    "workspace_id": "book",
    "workspace_name": "Book",
    "mooncode_runtime_session_id": "runtime",
    "mooncode_last_command_packet": { "command_id": "cmd-1" },
    "mooncode_last_patch_set_manifest": {
      "kind": "mooncode-patch-set",
      "manifest_path": "wiki/reviews/mooncode/s1/patch-set.json",
    },
  }
  let runtime_commands : Array[Json] = [
    {
      "command_id": "cmd-1",
      "mooncode_command_valid": true,
      "mooncode_command": { "command": "prompt", "text": "build tool" },
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
    runtime_session_id="runtime",
    runtime_command_log_path="/tmp/book/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/book/runtime-dispatches.jsonl",
  )
  let runtime_claim = runtime_claim_state(
    "s1",
    runtime_commands,
    runtime_dispatches,
    workspace_id="book",
    workspace_name="Book",
    runtime_session_id="runtime",
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
    { "running": true, "status": "running", "moonclaw_root": "/opt/moonclaw" },
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
  assert_eq(json_string(manifest, "status", default=""), "replay-resumable")
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
  let tool_call_contract = summary_json_object_field_or_empty(
    manifest, "tool_call_contract",
  )
  assert_eq(
    json_string(tool_call_contract, "kind", default=""),
    "mooncode-tool-call-contract",
  )
  assert_true(tool_call_contract.stringify().contains("moon_check"))
  let runtime_event_sink = summary_json_object_field_or_empty(
    manifest, "runtime_event_sink",
  )
  assert_eq(
    json_string(
      summary_json_object_field_or_empty(
        runtime_event_sink, "tool_call_contract",
      ),
      "kind",
      default="",
    ),
    "mooncode-tool-call-contract",
  )
  let resume_contract = summary_json_object_field_or_empty(
    manifest, "resume_contract",
  )
  assert_true(
    json_string(resume_contract, "runtime_claim_endpoint", default="").contains(
      "/api/mooncode/sessions/s1/runtime-claim",
    ),
  )
  assert_eq(
    json_string(resume_contract, "native_serve_scheduler_endpoint", default=""),
    "/v1/code/sessions/s1/serve-scheduler?book_root=<path>",
  )
  assert_eq(
    json_string(resume_contract, "readiness_endpoint", default=""),
    "/api/mooncode/sessions/s1/readiness",
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
  assert_eq(
    json_string(supervisor, "moonclaw_root", default=""),
    "/opt/moonclaw",
  )
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
      "readiness_endpoint": "/api/mooncode/sessions/s1/readiness",
      "native_serve_scheduler_endpoint": "/v1/code/sessions/s1/serve-scheduler?book_root=<path>",
    },
    "runtime_consumer": {
      "status": "lease-held",
      "next_action": "execute",
      "endpoints": {
        "runtime_claim": "/api/mooncode/sessions/s1/runtime-claim",
        "runtime_replay": "/api/mooncode/sessions/s1/runtime-replay",
        "native_session_listing": "/v1/code/sessions?book_root=<path>&format=json",
        "native_serve_scheduler": "/v1/code/sessions/s1/serve-scheduler?book_root=<path>",
      },
    },
  }
  assert_true(runtime_handoff_manifest_current(current))
  let outdated : Json = {
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
  assert_false(runtime_handoff_manifest_current(outdated))
}
