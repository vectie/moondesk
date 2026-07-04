///|
test "mooncode session snapshot records durable queue and event state" {
  let session : Json = {
    "id": "s1",
    "workspace_id": "book",
    "workspace_name": "Book",
    "workspace_root": "/tmp/book",
    "mooncode_runtime_session_id": "runtime",
    "title": "Build tool",
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
  let runtime_receipts : Array[Json] = [
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
    runtime_receipts,
    recorded_at="2026-06-15T00:01:00Z",
    snapshot_path="/tmp/book/.moonsuite/products/mooncode/sessions/s1/session.json",
    command_log_path="/tmp/book/.moonsuite/products/mooncode/sessions/s1/commands.jsonl",
    runtime_command_log_path="/tmp/book/.moonsuite/products/mooncode/sessions/s1/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/book/.moonsuite/products/mooncode/sessions/s1/runtime-receipts.jsonl",
    event_log_path="/tmp/book/.moonsuite/products/mooncode/sessions/s1/events.jsonl",
  )
  assert_eq(
    json_string(snapshot, "kind", default=""),
    "mooncode-session-snapshot",
  )
  assert_true(summary_json_object_field(snapshot, "transcript") is None)
  assert_true(summary_json_object_field(snapshot, "transcript_count") is None)
  assert_eq(summary_json_int(snapshot, "command_count", default=0), 1)
  assert_eq(summary_json_int(snapshot, "runtime_command_count", default=0), 1)
  assert_eq(summary_json_int(snapshot, "runtime_receipt_count", default=0), 1)
  assert_eq(
    summary_json_int(snapshot, "runtime_receipt_pending_count", default=0),
    1,
  )
  let receipts = json_array_items(snapshot, "runtime_receipts")
  assert_eq(receipts.length(), 1)
  assert_true(
    json_string(receipts[0], "receipt_id", default="").has_prefix(
      "mooncode-runtime-receipt-",
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
