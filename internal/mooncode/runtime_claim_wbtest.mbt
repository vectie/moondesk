///|
// White-box tests for MoonCode runtime claim selection, leases, and retry state.

///|
test "mooncode runtime claim blocks commands with pending tool authorization" {
  let commands : Array[Json] = [
    {
      "protocol": protocol_version(),
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-tool",
      "session_id": "session-demo",
      "action": "run_tests",
      "control": "command",
      "code_command": "prompt",
      "mooncode_command": { "command": "prompt", "text": "run tests" },
      "tool_authorization": {
        "kind": "mooncode-tool-authorization-snapshot",
        "protocol": protocol_version(),
        "enforcement_state": "requires-approval",
        "runtime_may_execute": false,
        "pending_approval_count": 1,
      },
    },
    {
      "protocol": protocol_version(),
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-later",
      "session_id": "session-demo",
      "action": "prompt",
      "control": "prompt",
      "code_command": "prompt",
      "mooncode_command": { "command": "prompt", "text": "later" },
    },
  ]
  let replay = runtime_replay_state(
    "session-demo",
    commands,
    [],
    workspace_id="book-demo",
    workspace_name="Demo",
    runtime_session_id="runtime-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/runtime-receipts.jsonl",
  )
  assert_eq(rq_json_int(replay, "pending_command_count", default=0), 0)
  assert_eq(rq_json_string(replay, "pending_mooncode_jsonl", default="x"), "")
  let replay_items = rq_json_array_items(replay, "replay_items")
  assert_eq(
    rq_json_string(replay_items[0], "replay_status", default=""),
    "blocked-tool-authorization",
  )
  assert_eq(
    rq_json_string(replay_items[1], "replay_status", default=""),
    "blocked-by-prior-command",
  )
  assert_eq(
    rq_json_string(replay_items[1], "blocked_by_command_id", default=""),
    "cmd-tool",
  )
  let state = runtime_claim_state(
    "session-demo",
    commands,
    [],
    workspace_id="book-demo",
    workspace_name="Demo",
    runtime_session_id="runtime-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/runtime-receipts.jsonl",
  )
  assert_eq(rq_json_int(state, "claimable_command_count", default=0), 0)
  assert_eq(rq_json_int(state, "invalid_command_count", default=0), 0)
  assert_eq(
    rq_json_int(state, "tool_authorization_blocked_command_count", default=0),
    1,
  )
  assert_eq(rq_json_int(state, "order_blocked_command_count", default=0), 1)
  let blocked = rq_json_array_items(
    state, "tool_authorization_blocked_commands",
  )
  assert_eq(rq_json_string(blocked[0], "command_id", default=""), "cmd-tool")
  assert_true(
    rq_json_string(blocked[0], "tool_authorization_blocked_reason", default="").contains(
      "pending",
    ),
  )
  let claimed = runtime_claim_receipts({ "id": "session-demo" }, commands, [], {
    "consumer_id": "moonclaw-runtime",
    "max_count": 10,
    "force": true,
  })
  assert_eq(claimed.length(), 0)
  assert_eq(runtime_command_jsonl(commands, [], scope="pending"), "")
}

///|
test "mooncode runtime claim response records claimed commands" {
  let runtime_command : Json = {
    "protocol": protocol_version(),
    "kind": "mooncode.runtime-command",
    "command_id": "cmd-1",
    "session_id": "session-demo",
    "action": "prompt",
  }
  let receipt : Json = {
    "protocol": protocol_version(),
    "kind": kind_runtime_receipt(),
    "command_id": "cmd-1",
    "status": "runtime-claimed",
    "runtime_command": runtime_command,
  }
  let response = runtime_claim_response(
    "session-demo",
    [receipt],
    { "kind": "mooncode-runtime-replay" },
    { "kind": "mooncode-runtime-claim-state" },
    { "id": "session-demo", "workspace_id": "book-demo" },
  )
  assert_eq(rq_json_string(response, "protocol", default=""), "mooncode.v1")
  assert_eq(
    rq_json_string(response, "kind", default=""),
    "mooncode-runtime-claim",
  )
  assert_eq(rq_json_int(response, "claimed_count", default=0), 1)
  let claimed_commands = rq_json_array_items(response, "claimed_commands")
  assert_eq(
    rq_json_string(claimed_commands[0], "command_id", default=""),
    "cmd-1",
  )
  assert_eq(
    rq_json_string(
      rq_json_object_field_or_empty(response, "consumer_contract"),
      "endpoint",
      default="",
    ),
    "/api/mooncode/sessions/session-demo/runtime-claim",
  )
  let aggregate = runtime_claim_result_response(
    "session-demo",
    [runtime_command],
    [receipt],
    [receipt],
    {
      "id": "session-demo",
      "workspace_id": "book-demo",
      "workspace_name": "Demo",
      "mooncode_runtime_session_id": "runtime-demo",
    },
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/runtime-receipts.jsonl",
  )
  assert_eq(
    rq_json_string(aggregate, "kind", default=""),
    "mooncode-runtime-claim",
  )
  assert_eq(rq_json_int(aggregate, "claimed_count", default=0), 1)
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
      rq_json_object_field_or_empty(aggregate, "claim_state"),
      "runtime_session_id",
      default="",
    ),
    "runtime-demo",
  )
}

///|
test "mooncode runtime queue classifies expired leases as claimable" {
  let commands : Array[Json] = [
    {
      "protocol": protocol_version(),
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-stale",
      "session_id": "session-demo",
      "action": "prompt",
      "control": "prompt",
      "code_command": "prompt",
      "mooncode_command": { "command": "prompt", "text": "recover me" },
    },
  ]
  let receipts : Array[Json] = [
    {
      "protocol": protocol_version(),
      "kind": kind_runtime_receipt(),
      "command_id": "cmd-stale",
      "status": "runtime-claimed",
      "claim_id": "claim-old",
      "consumer_id": "dead-runtime",
      "claimed_at": "2000-01-01T00:00:00Z",
      "lease_expires_at": "2000-01-01T00:05:00Z",
    },
  ]
  let state = runtime_claim_state(
    "session-demo",
    commands,
    receipts,
    workspace_id="book-demo",
    workspace_name="Demo",
    runtime_session_id="runtime-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/runtime-receipts.jsonl",
    lease_now="2000-01-01T00:06:00Z",
  )
  assert_eq(rq_json_int(state, "claimable_command_count", default=0), 1)
  assert_eq(rq_json_int(state, "expired_claim_command_count", default=0), 1)
  let replay = runtime_replay_state(
    "session-demo",
    commands,
    receipts,
    workspace_id="book-demo",
    workspace_name="Demo",
    runtime_session_id="runtime-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/runtime-receipts.jsonl",
    lease_now="2000-01-01T00:06:00Z",
  )
  let replay_items = rq_json_array_items(replay, "replay_items")
  assert_eq(
    rq_json_string(replay_items[0], "replay_status", default=""),
    "expired-claim-pending-retry",
  )
}

///|
test "mooncode runtime queue classifies failed runtime receipts as retryable claims" {
  let commands : Array[Json] = [
    {
      "protocol": protocol_version(),
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-failed",
      "session_id": "session-demo",
      "action": "run_tests",
      "control": "command",
      "code_command": "prompt",
      "mooncode_command": { "command": "prompt", "text": "run tests" },
    },
  ]
  let receipts : Array[Json] = [
    {
      "protocol": protocol_version(),
      "kind": kind_runtime_receipt(),
      "command_id": "cmd-failed",
      "status": "failed",
      "consumer_id": "moonclaw-runtime",
    },
  ]
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
  assert_eq(
    rq_json_string(replay_items[0], "replay_status", default=""),
    "failed-pending-retry",
  )
  let state = runtime_claim_state(
    "session-demo",
    commands,
    receipts,
    workspace_id="book-demo",
    workspace_name="Demo",
    runtime_session_id="runtime-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/runtime-receipts.jsonl",
  )
  assert_eq(rq_json_int(state, "claimable_command_count", default=0), 1)
  assert_eq(rq_json_int(state, "failed_command_count", default=0), 1)
  assert_true(rq_json_bool(state, "claim_ready", default=false))
  let claimable = rq_json_array_items(state, "claimable_commands")
  assert_eq(
    rq_json_string(claimable[0], "command_id", default=""),
    "cmd-failed",
  )
  assert_true(
    rq_json_bool(claimable[0], "previous_receipt_failed", default=false),
  )
  let failed = rq_json_array_items(state, "failed_commands")
  assert_eq(rq_json_string(failed[0], "claim_status", default=""), "claimable")
  let claimed = runtime_claim_receipts(
    { "id": "session-demo" },
    commands,
    receipts,
    {
      "consumer_id": "moonclaw-runtime",
      "max_count": 1,
      "claimed_at": "2026-06-15T00:00:00Z",
    },
  )
  assert_eq(claimed.length(), 1)
  assert_eq(rq_json_string(claimed[0], "command_id", default=""), "cmd-failed")
  let defaulted_claimed = runtime_claim_receipts_with_defaults(
    { "id": "session-demo" },
    commands,
    receipts,
    { "consumer_id": "moonclaw-runtime", "max_count": 1 },
    now="2026-06-15T00:01:00Z",
  )
  assert_eq(defaulted_claimed.length(), 1)
  assert_eq(
    rq_json_string(defaulted_claimed[0], "claimed_at", default=""),
    "2026-06-15T00:01:00Z",
  )
}

///|
test "mooncode runtime claim preserves ordering behind active leases" {
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
      "command_id": "cmd-active",
      "status": "runtime-claimed",
      "claim_id": "claim-active",
      "consumer_id": "moonclaw-runtime",
    },
  ]
  let state = runtime_claim_state(
    "session-demo",
    commands,
    receipts,
    workspace_id="book-demo",
    workspace_name="Demo",
    runtime_session_id="runtime-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/runtime-receipts.jsonl",
  )
  assert_eq(rq_json_int(state, "claimable_command_count", default=0), 0)
  assert_eq(rq_json_int(state, "claimed_command_count", default=0), 1)
  assert_eq(rq_json_int(state, "order_blocked_command_count", default=0), 1)
  let blocked = rq_json_array_items(state, "order_blocked_commands")
  assert_eq(rq_json_string(blocked[0], "command_id", default=""), "cmd-later")
  assert_eq(
    rq_json_string(blocked[0], "blocked_by_command_id", default=""),
    "cmd-active",
  )
  let claimed = runtime_claim_receipts(session, commands, receipts, {
    "consumer_id": "other-runtime",
    "max_count": 10,
  })
  assert_eq(claimed.length(), 0)
  let forced = runtime_claim_receipts(session, commands, receipts, {
    "consumer_id": "operator-recovery",
    "max_count": 10,
    "force": true,
  })
  assert_eq(forced.length(), 2)
  assert_eq(rq_json_string(forced[0], "command_id", default=""), "cmd-active")
  assert_eq(rq_json_string(forced[1], "command_id", default=""), "cmd-later")
}

///|
test "mooncode runtime claim stops at invalid earlier command" {
  let commands : Array[Json] = [
    {
      "protocol": protocol_version(),
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-invalid",
      "session_id": "session-demo",
      "mooncode_command": { "command": "prompt" },
    },
    {
      "protocol": protocol_version(),
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-later",
      "session_id": "session-demo",
      "mooncode_command": { "command": "prompt", "text": "later" },
    },
  ]
  let state = runtime_claim_state(
    "session-demo",
    commands,
    [],
    workspace_id="book-demo",
    workspace_name="Demo",
    runtime_session_id="runtime-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/runtime-receipts.jsonl",
  )
  assert_eq(rq_json_int(state, "invalid_command_count", default=0), 1)
  assert_eq(rq_json_int(state, "order_blocked_command_count", default=0), 1)
  assert_eq(rq_json_int(state, "claimable_command_count", default=0), 0)
  let blocked = rq_json_array_items(state, "order_blocked_commands")
  assert_eq(rq_json_string(blocked[0], "command_id", default=""), "cmd-later")
  assert_eq(
    rq_json_string(blocked[0], "blocked_by_command_id", default=""),
    "cmd-invalid",
  )
  let claimed = runtime_claim_receipts({ "id": "session-demo" }, commands, [], {
    "consumer_id": "moonclaw-runtime",
    "max_count": 10,
  })
  assert_eq(claimed.length(), 0)
}
