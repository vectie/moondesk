///|
test "mooncode session snapshot records durable queue and event state" {
  let session : Json = {
    "id": "s1",
    "workspace_id": "book",
    "workspace_name": "Book",
    "workspace_root": "/tmp/book",
    "mooncode_runtime_session_id": "runtime",
    "title": "Build tool",
    "transcript": [
      { "role": "user", "content": "create a tool" },
      { "role": "assistant", "content": "working" },
    ],
    "mooncode_last_command_packet": {
      "command_id": "cmd-1",
      "action": "prompt",
    },
  }
  let commands : Array[Json] = [{ "command_id": "cmd-1", "action": "prompt" }]
  let runtime_commands : Array[Json] = [
    {
      "command_id": "cmd-1",
      "mooncode_command_valid": true,
      "mooncode_command": { "type": "prompt", "prompt": "create a tool" },
    },
  ]
  let runtime_dispatches : Array[Json] = [
    { "command_id": "cmd-other", "status": "runtime-completed" },
  ]
  let snapshot = session_snapshot(
    session,
    [
      event_record(
        id="evt-1",
        lane="transcript",
        kind="assistant_delta",
        title="Assistant",
        status="done",
        created_at="2026-06-15T00:00:00Z",
        detail="working",
      ),
    ],
    commands,
    runtime_commands,
    runtime_dispatches,
    recorded_at="2026-06-15T00:01:00Z",
    snapshot_path="/tmp/book/.moontown/mooncode-sessions/s1/session.json",
    command_log_path="/tmp/book/.moontown/mooncode-sessions/s1/commands.jsonl",
    runtime_command_log_path="/tmp/book/.moontown/mooncode-sessions/s1/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/book/.moontown/mooncode-sessions/s1/runtime-dispatches.jsonl",
    event_log_path="/tmp/book/.moontown/mooncode-sessions/s1/events.jsonl",
  )
  assert_eq(
    json_string(snapshot, "kind", default=""),
    "mooncode-session-snapshot",
  )
  assert_eq(summary_json_int(snapshot, "transcript_count", default=0), 2)
  assert_eq(summary_json_int(snapshot, "command_count", default=0), 1)
  assert_eq(summary_json_int(snapshot, "runtime_command_count", default=0), 1)
  assert_eq(summary_json_int(snapshot, "runtime_dispatch_count", default=0), 1)
  assert_eq(
    summary_json_int(snapshot, "runtime_dispatch_pending_count", default=0),
    1,
  )
  let dispatches = json_array_items(snapshot, "runtime_dispatches")
  assert_eq(dispatches.length(), 1)
  assert_true(
    json_string(dispatches[0], "dispatch_id", default="").has_prefix(
      "mooncode-runtime-dispatch-",
    ),
  )
  assert_eq(summary_json_int(snapshot, "event_count", default=0), 1)
  let tool_call_contract = summary_json_object_field_or_empty(
    snapshot, "tool_call_contract",
  )
  assert_eq(
    json_string(tool_call_contract, "kind", default=""),
    "mooncode-tool-call-contract",
  )
  assert_true(tool_call_contract.stringify().contains("moon_check"))
  let event_normalization = summary_json_object_field_or_empty(
    snapshot, "event_normalization",
  )
  assert_eq(
    json_string(event_normalization, "function", default=""),
    "normalize_event_record",
  )
  assert_eq(json_string(event_normalization, "owner", default=""), "mooncode")
  assert_eq(
    json_string(
      summary_json_object_field_or_empty(snapshot, "last_command_packet"),
      "command_id",
      default="",
    ),
    "cmd-1",
  )
  let resume_endpoints = summary_json_object_field_or_empty(
    snapshot, "resume_endpoints",
  )
  assert_eq(
    json_string(resume_endpoints, "session_store", default=""),
    "/api/mooncode/sessions/s1/session-store",
  )
  assert_eq(
    json_string(resume_endpoints, "runtime_handoff", default=""),
    "/api/mooncode/sessions/s1/runtime-handoff",
  )
  assert_eq(
    json_string(resume_endpoints, "readiness", default=""),
    "/api/mooncode/sessions/s1/readiness",
  )
}
