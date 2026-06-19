///|
// White-box tests for MoonCode runtime replay acknowledgement and proof gating.

///|
test "mooncode runtime replay ack records matching claim context" {
  let session : Json = { "id": "session-demo", "workspace_id": "book-demo" }
  let commands : Array[Json] = [
    {
      "protocol": protocol_version(),
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-claimed",
      "session_id": "session-demo",
      "action": "prompt",
      "control": "prompt",
      "code_command": "prompt",
      "mooncode_command": { "command": "prompt", "text": "build it" },
    },
  ]
  let receipts : Array[Json] = [
    {
      "protocol": protocol_version(),
      "kind": kind_runtime_receipt(),
      "receipt_id": "claim-1",
      "claim_id": "claim-1",
      "command_id": "cmd-claimed",
      "status": "runtime-claimed",
      "consumer_id": "moonclaw-runtime",
    },
  ]
  let receipts = runtime_replay_ack_receipts(
    session,
    commands,
    {
      "consumer_id": "moonclaw-runtime",
      "command_id": "cmd-claimed",
      "status": "runtime-completed",
    },
    runtime_receipts=receipts,
  )
  assert_eq(receipts.length(), 1)
  assert_eq(
    rq_json_string(receipts[0], "ack_order_status", default=""),
    "matching-claim",
  )
  assert_eq(
    rq_json_string(receipts[0], "previous_receipt_status", default=""),
    "runtime-claimed",
  )
  assert_eq(
    rq_json_string(receipts[0], "previous_claim_id", default=""),
    "claim-1",
  )
  assert_true(
    rq_json_bool(receipts[0], "claimed_by_same_consumer", default=false),
  )
  let defaulted_receipts = runtime_replay_ack_receipts_with_defaults(
    session,
    commands,
    {
      "consumer_id": "moonclaw-runtime",
      "command_id": "cmd-claimed",
      "status": "runtime-completed",
    },
    acknowledged_at="2026-06-15T00:02:00Z",
    runtime_receipts=receipts,
  )
  assert_eq(defaulted_receipts.length(), 1)
  assert_eq(
    rq_json_string(defaulted_receipts[0], "created_at", default=""),
    "2026-06-15T00:02:00Z",
  )
}

///|
test "mooncode runtime replay ack response owns accepted ack surface" {
  let session : Json = {
    "id": "session-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "mooncode_runtime_session_id": "runtime-demo",
  }
  let commands : Array[Json] = [
    {
      "protocol": protocol_version(),
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-claimed",
      "session_id": "session-demo",
      "action": "prompt",
      "control": "prompt",
      "code_command": "prompt",
      "mooncode_command": { "command": "prompt", "text": "build it" },
    },
  ]
  let receipts = runtime_replay_ack_receipts(session, commands, {
    "consumer_id": "moonclaw-runtime",
    "command_id": "cmd-claimed",
    "status": "runtime-acknowledged",
    "events": [
      {
        "event": event_tool_result(),
        "id": "evt-tool",
        "tool_name": "finish",
        "tool_call_id": "call-finish",
        "status": "done",
        "result": "Runtime recorded command completion.",
      },
    ],
  })
  let events = runtime_replay_ack_normalized_events(receipts)
  let response = runtime_replay_ack_response(
    "session-demo",
    commands,
    receipts,
    receipts,
    events,
    { "kind": "mooncode-session-runtime-evidence" },
    { "id": "session-demo", "kind": "mooncode-session" },
    workspace_id="book-demo",
    workspace_name="Demo Book",
    runtime_session_id="runtime-demo",
    runtime_command_log_path="/tmp/book/.moontown/mooncode-sessions/session-demo/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/book/.moontown/mooncode-sessions/session-demo/runtime-receipts.jsonl",
  )
  assert_eq(
    rq_json_string(response, "kind", default=""),
    "mooncode-runtime-replay-ack",
  )
  assert_eq(rq_json_int(response, "accepted_receipt_count", default=0), 1)
  assert_eq(rq_json_int(response, "accepted_event_count", default=0), 1)
  assert_eq(rq_json_array_items(response, "receipts").length(), 1)
  assert_eq(
    rq_json_string(
      rq_json_object_field_or_empty(response, "runtime_replay"),
      "kind",
      default="",
    ),
    "mooncode-runtime-replay",
  )
  assert_eq(
    rq_json_string(
      rq_json_object_field_or_empty(response, "runtime_evidence"),
      "kind",
      default="",
    ),
    "mooncode-session-runtime-evidence",
  )
  let aggregate = runtime_replay_ack_result_response(
    "session-demo",
    commands,
    receipts,
    receipts,
    events,
    { "kind": "mooncode-session-runtime-evidence" },
    session,
    runtime_command_log_path="/tmp/book/.moontown/mooncode-sessions/session-demo/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/book/.moontown/mooncode-sessions/session-demo/runtime-receipts.jsonl",
  )
  assert_eq(
    rq_json_string(aggregate, "kind", default=""),
    "mooncode-runtime-replay-ack",
  )
  assert_eq(
    rq_json_string(
      rq_json_object_field_or_empty(aggregate, "runtime_replay"),
      "workspace_id",
      default="",
    ),
    "book-demo",
  )
  assert_eq(
    rq_json_string(
      rq_json_object_field_or_empty(aggregate, "runtime_replay"),
      "runtime_session_id",
      default="",
    ),
    "runtime-demo",
  )
}

///|
test "mooncode runtime replay completion is blocked without required proof" {
  let session : Json = { "id": "session-demo", "workspace_id": "book-demo" }
  let commands : Array[Json] = [
    {
      "protocol": protocol_version(),
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-tests",
      "session_id": "session-demo",
      "action": "run_tests",
      "control": "command",
      "code_command": "prompt",
      "mooncode_command": { "command": "prompt", "text": "run tests" },
    },
  ]
  let receipts = runtime_replay_ack_receipts(session, commands, {
    "consumer_id": "moonclaw-runtime",
    "command_id": "cmd-tests",
    "status": "runtime-completed",
  })
  assert_eq(receipts.length(), 1)
  assert_eq(
    rq_json_string(receipts[0], "requested_status", default=""),
    "runtime-completed",
  )
  assert_eq(rq_json_string(receipts[0], "status", default=""), "proof-missing")
  let gate = rq_json_object_field_or_empty(receipts[0], "proof_gate")
  assert_true(rq_json_bool(gate, "completion_blocked", default=false))
  assert_eq(rq_json_string(gate, "status", default=""), "blocked")
  assert_true(
    rq_json_string_array_items(gate, "missing_required_events").contains(
      "test_result",
    ),
  )
  let replay = runtime_replay_state(
    "session-demo",
    commands,
    receipts,
    workspace_id="book-demo",
    workspace_name="Demo",
    runtime_session_id="runtime-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/runtime-receipts.jsonl",
  )
  assert_eq(rq_json_int(replay, "delivered_command_count", default=0), 0)
  assert_eq(rq_json_int(replay, "pending_command_count", default=0), 1)
  let pending = rq_json_array_items(replay, "pending_commands")
  assert_eq(
    rq_json_string(pending[0], "replay_status", default=""),
    "missing-proof-pending-retry",
  )
  let claim = runtime_claim_state(
    "session-demo",
    commands,
    receipts,
    workspace_id="book-demo",
    workspace_name="Demo",
    runtime_session_id="runtime-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/runtime-receipts.jsonl",
  )
  assert_eq(rq_json_int(claim, "claimable_command_count", default=0), 1)
  let claimable = rq_json_array_items(claim, "claimable_commands")
  assert_true(
    rq_json_bool(
      claimable[0],
      "previous_completion_missing_proof",
      default=false,
    ),
  )
}

///|
test "mooncode runtime replay completion can use prior streamed proof events" {
  let session : Json = { "id": "session-demo", "workspace_id": "book-demo" }
  let commands : Array[Json] = [
    {
      "protocol": protocol_version(),
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-tests",
      "session_id": "session-demo",
      "action": "run_tests",
      "control": "command",
      "code_command": "prompt",
      "mooncode_command": { "command": "prompt", "text": "run tests" },
    },
  ]
  let command_packet : Json = {
    "command_id": "cmd-tests",
    "action": "run_tests",
  }
  let prior_events : Array[Json] = [
    {
      "id": "evt-read-call",
      "lane": "tool",
      "kind": "read",
      "status": "running",
      "tool_call_id": "call-read",
      "command_packet": command_packet,
    },
    {
      "id": "evt-read-result",
      "lane": "tool",
      "kind": "read",
      "status": "done",
      "tool_call_id": "call-read",
      "command_packet": command_packet,
    },
    {
      "id": "evt-ide-call",
      "lane": "tool",
      "kind": "moon_ide",
      "status": "running",
      "tool_call_id": "call-ide",
      "command_packet": command_packet,
    },
    {
      "id": "evt-ide-result",
      "lane": "tool",
      "kind": "moon_ide",
      "status": "done",
      "tool_call_id": "call-ide",
      "command_packet": command_packet,
    },
    {
      "id": "evt-cmd-call",
      "lane": "tool",
      "kind": "moon_cmd",
      "status": "running",
      "tool_call_id": "call-cmd",
      "command_packet": command_packet,
    },
    {
      "id": "evt-cmd-result",
      "lane": "tool",
      "kind": "moon_cmd",
      "status": "done",
      "tool_call_id": "call-cmd",
      "command_packet": command_packet,
    },
    {
      "id": "evt-tool-call",
      "lane": "tool",
      "kind": "moon_check",
      "status": "running",
      "tool_call_id": "call-check",
      "command_packet": command_packet,
    },
    {
      "id": "evt-tool-result",
      "lane": "tool",
      "kind": "moon_check",
      "status": "done",
      "tool_call_id": "call-check",
      "command_packet": command_packet,
    },
    {
      "id": "evt-shell-call",
      "lane": "tool",
      "kind": "shell",
      "status": "running",
      "tool_call_id": "call-shell",
      "command_packet": command_packet,
    },
    {
      "id": "evt-shell-result",
      "lane": "tool",
      "kind": "shell",
      "status": "done",
      "tool_call_id": "call-shell",
      "command_packet": command_packet,
    },
    {
      "id": "evt-test",
      "lane": "test",
      "kind": "test_result",
      "status": "done",
      "command_packet": command_packet,
    },
    {
      "id": "evt-finish",
      "lane": "review",
      "kind": "finish",
      "status": "done",
      "command_packet": command_packet,
    },
  ]
  let receipts = runtime_replay_ack_receipts(
    session,
    commands,
    {
      "consumer_id": "moonclaw-runtime",
      "command_id": "cmd-tests",
      "status": "runtime-completed",
    },
    prior_events~,
  )
  assert_eq(receipts.length(), 1)
  assert_eq(json_string(receipts[0], "status", default=""), "runtime-completed")
  let gate = rq_json_object_field_or_empty(receipts[0], "proof_gate")
  assert_false(rq_json_bool(gate, "completion_blocked", default=true))
  assert_eq(rq_json_string(gate, "status", default=""), "passed")
  assert_eq(rq_json_int(gate, "prior_event_count", default=0), 12)
  assert_eq(rq_json_int(gate, "missing_required_event_count", default=-1), 0)
  assert_eq(rq_json_int(gate, "proven_required_event_count", default=0), 4)
  assert_eq(rq_json_string(gate, "tool_harness_status", default=""), "proven")
  assert_eq(rq_json_int(gate, "tool_harness_proven_tool_count", default=0), 6)
}

///|
test "mooncode runtime replay ack summarizes submitted proof events" {
  let session : Json = { "id": "session-demo", "workspace_id": "book-demo" }
  let commands : Array[Json] = [
    {
      "protocol": protocol_version(),
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-proof",
      "session_id": "session-demo",
      "action": "run_tests",
      "control": "command",
      "code_command": "prompt",
      "mooncode_command": { "command": "prompt", "text": "run tests" },
    },
  ]
  let receipts = runtime_replay_ack_receipts(session, commands, {
    "consumer_id": "moonclaw-runtime",
    "command_id": "cmd-proof",
    "status": "runtime-completed",
    "acknowledged_at": "2026-06-15T00:00:00Z",
    "events": [
      {
        "event": event_tool_call(),
        "id": "evt-tool",
        "tool_name": "shell",
        "tool_call_id": "call-shell",
        "status": "running",
        "arguments": "{\"command\":\"pwd\"}",
      },
      {
        "event": "diff",
        "id": "evt-diff",
        "path": "tools/demo/main.mbt",
        "diff": "@@ -1 +1",
      },
      {
        "event": event_test_result(),
        "id": "evt-test",
        "command": "moon test",
        "status": "passed",
        "exit_code": 0,
      },
      {
        "event": event_package_verified(),
        "id": "evt-package",
        "path": "portable/app-tool/demo",
      },
    ],
  })
  assert_eq(receipts.length(), 1)
  assert_eq(rq_json_int(receipts[0], "submitted_event_count", default=0), 4)
  assert_eq(rq_json_int(receipts[0], "normalized_event_count", default=0), 4)
  assert_eq(rq_json_int(receipts[0], "proof_event_count", default=0), 4)
  let summary = rq_json_object_field_or_empty(
    receipts[0],
    "runtime_event_summary",
  )
  assert_eq(
    rq_json_string(summary, "kind", default=""),
    "mooncode-runtime-ack-event-summary",
  )
  assert_eq(rq_json_int(summary, "tool_event_count", default=0), 1)
  assert_eq(rq_json_int(summary, "diff_event_count", default=0), 1)
  assert_eq(rq_json_int(summary, "test_event_count", default=0), 1)
  assert_eq(rq_json_int(summary, "artifact_event_count", default=0), 1)
  let proof_lanes = rq_json_string_array_items(summary, "proof_lanes")
  assert_true(runtime_string_array_contains(proof_lanes, "tool"))
  assert_true(runtime_string_array_contains(proof_lanes, "diff"))
  assert_true(runtime_string_array_contains(proof_lanes, "test"))
  assert_true(runtime_string_array_contains(proof_lanes, "artifact"))
  let normalized_events = rq_json_array_items(summary, "normalized_events")
  assert_eq(normalized_events.length(), 4)
  let event_packet = rq_json_object_field_or_empty(
    normalized_events[0],
    "command_packet",
  )
  assert_eq(rq_json_string(event_packet, "command_id", default=""), "cmd-proof")
  assert_eq(rq_json_string(event_packet, "action", default=""), "run_tests")
  assert_true(rq_json_bool(event_packet, "runtime_proof", default=false))
  let receipt_events = runtime_replay_ack_normalized_events(receipts)
  assert_eq(receipt_events.length(), 4)
  let replay = runtime_replay_state(
    "session-demo",
    commands,
    receipts,
    workspace_id="book-demo",
    workspace_name="Demo",
    runtime_session_id="runtime-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/runtime-receipts.jsonl",
  )
  let replay_items = rq_json_array_items(replay, "replay_items")
  assert_eq(rq_json_int(replay_items[0], "proof_event_count", default=0), 4)
  assert_eq(
    rq_json_string(
      rq_json_object_field_or_empty(replay_items[0], "runtime_event_summary"),
      "kind",
      default="",
    ),
    "mooncode-runtime-ack-event-summary",
  )
}

///|
test "mooncode runtime replay ack exposes prior-order blocker" {
  let session : Json = { "id": "session-demo", "workspace_id": "book-demo" }
  let commands : Array[Json] = [
    {
      "protocol": protocol_version(),
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-active",
      "session_id": "session-demo",
      "action": "prompt",
      "control": "prompt",
      "code_command": "prompt",
      "mooncode_command": { "command": "prompt", "text": "first" },
    },
    {
      "protocol": protocol_version(),
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-later",
      "session_id": "session-demo",
      "action": "steer",
      "control": "steer",
      "code_command": "steer",
      "mooncode_command": { "command": "steer", "text": "later" },
    },
  ]
  let receipts : Array[Json] = [
    {
      "protocol": protocol_version(),
      "kind": kind_runtime_receipt(),
      "receipt_id": "claim-active",
      "claim_id": "claim-active",
      "command_id": "cmd-active",
      "status": "runtime-claimed",
      "consumer_id": "moonclaw-runtime",
    },
  ]
  let receipts = runtime_replay_ack_receipts(
    session,
    commands,
    {
      "consumer_id": "other-runtime",
      "command_id": "cmd-later",
      "status": "runtime-completed",
    },
    runtime_receipts=receipts,
  )
  assert_eq(receipts.length(), 1)
  assert_eq(
    rq_json_string(receipts[0], "ack_order_status", default=""),
    "blocked-by-prior-command",
  )
  let blocker = rq_json_object_field_or_empty(receipts[0], "order_blocker")
  assert_eq(rq_json_string(blocker, "command_id", default=""), "cmd-active")
  assert_eq(rq_json_string(blocker, "status", default=""), "runtime-claimed")
}
