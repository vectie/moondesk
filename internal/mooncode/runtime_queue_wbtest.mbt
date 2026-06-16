///|
test "mooncode runtime protocol advertises proof event names" {
  let contract = runtime_protocol_contract_json()
  guard rq_json_object_field(contract, "event_stream") is Some(event_stream) else {
    fail("missing event_stream contract")
  }
  let events = rq_json_string_array_items(event_stream, "accepted_events")
  assert_true(events.contains("patch_applied"))
  assert_true(events.contains("patch_reverted"))
  assert_true(events.contains("package_built"))
  assert_true(events.contains("package_verified"))
  assert_true(events.contains("receipt.accept"))
  assert_true(events.contains("receipt.reject"))
  assert_true(events.contains("commit_created"))
  guard rq_json_object_field(contract, "tool_registry") is Some(registry) else {
    fail("missing tool registry contract")
  }
  guard rq_json_object_field(registry, "tool_call_wire") is Some(wire) else {
    fail("missing tool_call_wire contract")
  }
  assert_eq(
    rq_json_string(wire, "kind", default=""),
    "mooncode-tool-call-wire-contract",
  )
  assert_true(
    rq_json_string_array_items(wire, "supported_tools").contains("moon_check"),
  )
}

///|
test "mooncode runtime dispatch receipt classifies bridge outcomes" {
  let runtime_command : Json = {
    "command_id": "cmd-1",
    "session_id": "session-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo",
    "task_id": "task-demo",
    "action": "prompt",
    "dispatch": "prompt",
    "openseek_wire_valid": true,
    "native_mooncode_endpoint": "/v1/mooncode/sessions/session-demo/commands",
  }
  let native_session : Json = {
    "workspace_id": "book-demo",
    "workspace_name": "Demo",
    "moonclaw_task_id": "task-demo",
    "mooncode_dispatch_mode": "moonclaw-mooncode-runtime",
  }
  let native = runtime_dispatch_receipt(
    native_session,
    runtime_command,
    dispatch_id="dispatch-native",
    created_at="2026-06-15T00:00:00Z",
  )
  assert_eq(rq_json_string(native, "status", default=""), "native-dispatched")
  assert_eq(
    rq_json_string(native, "dispatch_mode", default=""),
    "moonclaw-mooncode-runtime",
  )
  assert_true(rq_json_bool(native, "openseek_wire_valid", default=false))
  assert_true(
    rq_json_string(native, "detail", default="").contains("native MoonClaw"),
  )
  let legacy_session : Json = {
    "moonclaw_task_id": "task-demo",
    "mooncode_dispatch_mode": "moonclaw-task-bridge",
  }
  assert_eq(
    runtime_dispatch_status(legacy_session, runtime_command),
    "legacy-bridged",
  )
  let recorded_session : Json = { "mooncode_dispatch_mode": "not-dispatched" }
  assert_eq(
    runtime_dispatch_status(recorded_session, runtime_command),
    "recorded",
  )
  let failed_session : Json = {
    "mooncode_dispatch_mode": "moonclaw-mooncode-runtime",
    "mooncode_command_events": [
      { "status": "failed", "command_packet": { "command_id": "cmd-1" } },
    ],
  }
  assert_eq(runtime_dispatch_status(failed_session, runtime_command), "failed")
}

///|
test "mooncode runtime dispatch receipt response fills legacy defaults" {
  let response = runtime_dispatch_receipt_for_response(
    { "command_id": "cmd-legacy", "status": "legacy-bridged" },
    fallback_dispatch_id="dispatch-fallback",
  )
  assert_eq(
    rq_json_string(response, "dispatch_id", default=""),
    "dispatch-fallback",
  )
  assert_eq(rq_json_string(response, "dispatch_mode", default=""), "unknown")
  assert_eq(rq_json_string(response, "created_at", default="missing"), "")
  assert_false(rq_json_bool(response, "openseek_wire_valid", default=true))
  assert_true(
    rq_json_object_field(response, "runtime_command") is Some(Json::Object(_)),
  )
  assert_true(rq_json_object_field(response, "owner") is Some(Json::Object(_)))
  let responses = runtime_dispatch_receipts_for_response([
    { "command_id": "cmd-legacy", "status": "legacy-bridged" },
    {
      "command_id": "cmd-existing",
      "status": "runtime-completed",
      "dispatch_id": "dispatch-existing",
    },
  ])
  assert_eq(responses.length(), 2)
  assert_true(
    rq_json_string(responses[0], "dispatch_id", default="").has_prefix(
      "mooncode-runtime-dispatch-",
    ),
  )
  assert_eq(
    rq_json_string(responses[1], "dispatch_id", default=""),
    "dispatch-existing",
  )
}

///|
test "mooncode runtime dispatch state response records queue state" {
  let command : Json = {
    "protocol": "mooncode.v1",
    "kind": "mooncode.runtime-command",
    "command_id": "cmd-1",
  }
  let dispatch : Json = {
    "protocol": "mooncode.v1",
    "kind": "mooncode.runtime-dispatch",
    "command_id": "cmd-0",
    "status": "runtime-completed",
    "dispatch_id": "dispatch-0",
  }
  let response = runtime_dispatch_state_response(
    "session-demo",
    [command],
    [dispatch],
    [Json::string("cmd-1")],
    workspace_id="book-demo",
    workspace_name="Demo",
    task_id="task-demo",
    dispatch_mode="moonclaw-mooncode-runtime",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
  )
  assert_eq(
    rq_json_string(response, "kind", default=""),
    "mooncode-runtime-dispatch-state",
  )
  assert_eq(rq_json_int(response, "runtime_command_count", default=0), 1)
  assert_eq(rq_json_int(response, "runtime_dispatch_count", default=0), 1)
  assert_eq(
    rq_json_int(response, "runtime_dispatch_pending_count", default=0),
    1,
  )
  assert_eq(
    rq_json_string_array_items(response, "pending_command_ids")[0],
    "cmd-1",
  )
  assert_true(
    rq_json_object_field(response, "runtime_protocol") is Some(Json::Object(_)),
  )
  assert_eq(
    rq_json_string(
      rq_json_object_field_or_empty(response, "owner"),
      "runtime",
      default="",
    ),
    "moonclaw",
  )
  let aggregate = runtime_dispatch_response(
    "session-demo",
    [command],
    [{ "command_id": "cmd-0", "status": "runtime-completed" }],
    workspace_id="book-demo",
    workspace_name="Demo",
    task_id="task-demo",
    dispatch_mode="moonclaw-mooncode-runtime",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
    lease_now="2026-06-15T00:00:00Z",
  )
  assert_eq(
    rq_json_string(aggregate, "kind", default=""),
    "mooncode-runtime-dispatch-state",
  )
  assert_eq(
    rq_json_int(aggregate, "runtime_dispatch_pending_count", default=0),
    1,
  )
  let aggregate_receipts = rq_json_array_items(aggregate, "dispatch_receipts")
  assert_eq(aggregate_receipts.length(), 1)
  assert_true(
    rq_json_string(aggregate_receipts[0], "dispatch_id", default="").has_prefix(
      "mooncode-runtime-dispatch-",
    ),
  )
}

///|
test "mooncode runtime command feed response owns runtime surface" {
  let command : Json = {
    "protocol": "mooncode.v1",
    "kind": "mooncode.runtime-command",
    "command_id": "cmd-1",
    "action": "prompt",
    "dispatch": "prompt",
    "serve_command": "prompt",
    "command_packet": {
      "protocol": "mooncode.v1",
      "kind": "mooncode.command",
      "command_id": "cmd-1",
      "action": "prompt",
      "dispatch": "prompt",
    },
    "native_mooncode_body": {
      "execution_plan": {
        "action": "prompt",
        "dispatch": "prompt",
        "approval": "auto",
      },
    },
    "openseek_wire_command": { "command": "prompt", "text": "build it" },
  }
  let raw_receipt : Json = {
    "command_id": "cmd-other",
    "status": "runtime-completed",
  }
  let response = runtime_command_feed_response(
    "session-demo",
    [command],
    [raw_receipt],
    [],
    workspace_id="book-demo",
    workspace_name="Demo",
    task_id="task-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
    workspace_root="/tmp/book",
    moonclaw_root="/tmp/moonclaw",
    host_base_url="",
    native_ready=false,
    lease_now="2026-06-15T00:00:00Z",
  )
  assert_eq(
    rq_json_string(response, "kind", default=""),
    "mooncode-runtime-command-feed",
  )
  assert_eq(rq_json_int(response, "runtime_command_count", default=0), 1)
  assert_eq(
    rq_json_int(response, "runtime_dispatch_pending_count", default=0),
    1,
  )
  assert_eq(rq_json_int(response, "runtime_dispatch_count", default=0), 1)
  let response_receipts = rq_json_array_items(response, "dispatch_receipts")
  assert_eq(response_receipts.length(), 1)
  assert_true(
    rq_json_string(response_receipts[0], "dispatch_id", default="").has_prefix(
      "mooncode-runtime-dispatch-",
    ),
  )
  assert_eq(
    rq_json_string(response, "runtime_claim_endpoint", default=""),
    "/api/mooncode/sessions/session-demo/runtime-claim",
  )
  assert_true(
    rq_json_object_field(response, "runtime_replay") is Some(Json::Object(_)),
  )
  assert_true(
    rq_json_object_field(response, "runtime_claim_contract")
    is Some(Json::Object(_)),
  )
  assert_true(
    rq_json_object_field(response, "runtime_turn_packet")
    is Some(Json::Object(_)),
  )
  assert_true(
    rq_json_object_field(response, "runtime_supervisor")
    is Some(Json::Object(_)),
  )
  let aggregate = runtime_command_feed_result_response(
    "session-demo",
    [command],
    [raw_receipt],
    [],
    {
      "id": "session-demo",
      "workspace_id": "book-demo",
      "workspace_name": "Demo",
      "moonclaw_task_id": "task-demo",
    },
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
    workspace_root="/tmp/book",
    moonclaw_root="/tmp/moonclaw",
    host_base_url="",
    native_ready=false,
    lease_now="2026-06-15T00:00:00Z",
  )
  assert_eq(
    rq_json_string(aggregate, "kind", default=""),
    "mooncode-runtime-command-feed",
  )
  assert_eq(rq_json_string(aggregate, "workspace_id", default=""), "book-demo")
  assert_eq(rq_json_string(aggregate, "workspace_name", default=""), "Demo")
  assert_eq(rq_json_string(aggregate, "task_id", default=""), "task-demo")
  let plan = runtime_execution_plan_response(
    "session-demo",
    [command],
    [],
    [],
    workspace_id="book-demo",
    workspace_name="Demo",
    task_id="task-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
    workspace_root="/tmp/book",
    moonclaw_root="/tmp/moonclaw",
    host_base_url="",
    native_ready=true,
    lease_now="2026-06-15T00:00:00Z",
  )
  assert_eq(
    rq_json_string(plan, "kind", default=""),
    "mooncode-runtime-consumer-execution-plan",
  )
  assert_true(rq_json_bool(plan, "native_runtime_ready", default=false))
  assert_true(
    rq_json_object_field(plan, "serve_scheduler") is Some(Json::Object(_)),
  )
  assert_true(
    rq_json_object_field(plan, "runtime_turn_packet") is Some(Json::Object(_)),
  )
  assert_true(
    rq_json_object_field(plan, "runtime_supervisor") is Some(Json::Object(_)),
  )
  let supervisor = runtime_supervisor_response(
    "session-demo",
    [command],
    [],
    [],
    workspace_id="book-demo",
    workspace_name="Demo",
    task_id="task-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
    workspace_root="/tmp/book",
    moonclaw_root="/tmp/moonclaw",
    host_base_url="",
    native_ready=true,
    lease_now="2026-06-15T00:00:00Z",
  )
  assert_eq(
    rq_json_string(supervisor, "kind", default=""),
    "mooncode-runtime-supervisor-launch",
  )
  assert_eq(
    rq_json_string(supervisor, "session_id", default=""),
    "session-demo",
  )
  assert_eq(rq_json_string(supervisor, "command_id", default=""), "cmd-1")
  assert_true(rq_json_bool(supervisor, "ready_to_launch", default=false))
  assert_true(
    rq_json_object_field(supervisor, "runtime_consumer")
    is Some(Json::Object(_)),
  )
  assert_true(
    rq_json_object_field(supervisor, "readiness") is Some(Json::Object(_)),
  )
  assert_eq(rq_json_array_items(response, "decode_reports").length(), 1)
  assert_eq(rq_json_array_items(response, "execution_summaries").length(), 1)
  assert_eq(
    rq_json_string(
      rq_json_object_field_or_empty(response, "owner"),
      "extractable_component",
      default="",
    ),
    "mooncode",
  )
}

///|
test "mooncode runtime queue exports pending replay state" {
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-1",
      "action": "prompt",
      "dispatch": "prompt",
      "serve_command": "prompt",
      "target": "tools/demo",
      "openseek_wire_command": { "command": "prompt", "text": "build it" },
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-2",
      "action": "steer",
      "dispatch": "steer",
      "serve_command": "steer",
      "target": "tools/demo",
      "openseek_wire_command": { "command": "steer", "text": "add tests" },
      "tool_authorization": {
        "kind": "mooncode-tool-authorization-snapshot",
        "protocol": "mooncode.v1",
        "enforcement_state": "authorized",
        "runtime_may_execute": true,
        "pending_approval_count": 0,
      },
    },
  ]
  let receipts : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
      "command_id": "cmd-1",
      "status": "runtime-completed",
    },
  ]
  let state = runtime_replay_state(
    "session-demo",
    commands,
    receipts,
    workspace_id="book-demo",
    workspace_name="Demo",
    task_id="task-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
  )
  assert_eq(
    rq_json_string(state, "kind", default=""),
    "mooncode-runtime-replay",
  )
  assert_eq(rq_json_int(state, "delivered_command_count", default=0), 1)
  assert_eq(rq_json_int(state, "pending_command_count", default=0), 1)
  assert_true(
    rq_json_string(state, "pending_openseek_jsonl", default="").contains(
      "\"steer\"",
    ),
  )
  let pending = rq_json_array_items(state, "pending_commands")
  let auth = rq_json_object_field_or_empty(pending[0], "tool_authorization")
  assert_eq(rq_json_string(auth, "enforcement_state", default=""), "authorized")
  assert_true(
    rq_json_bool(pending[0], "runtime_may_execute_tools", default=false),
  )
}

///|
test "mooncode runtime claim blocks commands with pending tool authorization" {
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-tool",
      "session_id": "session-demo",
      "action": "run_tests",
      "dispatch": "command",
      "serve_command": "prompt",
      "openseek_wire_command": { "command": "prompt", "text": "run tests" },
      "tool_authorization": {
        "kind": "mooncode-tool-authorization-snapshot",
        "protocol": "mooncode.v1",
        "enforcement_state": "requires-approval",
        "runtime_may_execute": false,
        "pending_approval_count": 1,
      },
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-later",
      "session_id": "session-demo",
      "action": "prompt",
      "dispatch": "prompt",
      "serve_command": "prompt",
      "openseek_wire_command": { "command": "prompt", "text": "later" },
    },
  ]
  let replay = runtime_replay_state(
    "session-demo",
    commands,
    [],
    workspace_id="book-demo",
    workspace_name="Demo",
    task_id="task-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
  )
  assert_eq(rq_json_int(replay, "pending_command_count", default=0), 0)
  assert_eq(rq_json_string(replay, "pending_openseek_jsonl", default="x"), "")
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
    task_id="task-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
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
  assert_eq(runtime_serve_jsonl(commands, [], scope="pending"), "")
}

///|
test "mooncode runtime claim response records claimed commands" {
  let runtime_command : Json = {
    "protocol": "mooncode.v1",
    "kind": "mooncode.runtime-command",
    "command_id": "cmd-1",
    "session_id": "session-demo",
    "action": "prompt",
  }
  let receipt : Json = {
    "protocol": "mooncode.v1",
    "kind": "mooncode.runtime-dispatch",
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
      "moonclaw_task_id": "task-demo",
    },
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
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
      "task_id",
      default="",
    ),
    "task-demo",
  )
}

///|
test "mooncode runtime queue classifies expired leases as claimable" {
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-stale",
      "session_id": "session-demo",
      "action": "prompt",
      "dispatch": "prompt",
      "serve_command": "prompt",
      "openseek_wire_command": { "command": "prompt", "text": "recover me" },
    },
  ]
  let receipts : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
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
    task_id="task-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
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
    task_id="task-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
    lease_now="2000-01-01T00:06:00Z",
  )
  let replay_items = rq_json_array_items(replay, "replay_items")
  assert_eq(
    rq_json_string(replay_items[0], "replay_status", default=""),
    "expired-claim-pending-retry",
  )
}

///|
test "mooncode runtime queue classifies failed dispatches as retryable claims" {
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-failed",
      "session_id": "session-demo",
      "action": "run_tests",
      "dispatch": "command",
      "serve_command": "prompt",
      "openseek_wire_command": { "command": "prompt", "text": "run tests" },
    },
  ]
  let receipts : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
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
    task_id="task-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
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
    task_id="task-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
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
    rq_json_bool(claimable[0], "previous_dispatch_failed", default=false),
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
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-active",
      "session_id": "session-demo",
      "action": "prompt",
      "dispatch": "prompt",
      "serve_command": "prompt",
      "openseek_wire_command": { "command": "prompt", "text": "first" },
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-later",
      "session_id": "session-demo",
      "action": "steer",
      "dispatch": "steer",
      "serve_command": "steer",
      "openseek_wire_command": { "command": "steer", "text": "later" },
    },
  ]
  let receipts : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
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
    task_id="task-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
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
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-invalid",
      "session_id": "session-demo",
      "openseek_wire_command": { "command": "prompt" },
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-later",
      "session_id": "session-demo",
      "openseek_wire_command": { "command": "prompt", "text": "later" },
    },
  ]
  let state = runtime_claim_state(
    "session-demo",
    commands,
    [],
    workspace_id="book-demo",
    workspace_name="Demo",
    task_id="task-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
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

///|
test "mooncode runtime replay ack records matching claim context" {
  let session : Json = { "id": "session-demo", "workspace_id": "book-demo" }
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-claimed",
      "session_id": "session-demo",
      "action": "prompt",
      "dispatch": "prompt",
      "serve_command": "prompt",
      "openseek_wire_command": { "command": "prompt", "text": "build it" },
    },
  ]
  let dispatches : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
      "dispatch_id": "claim-1",
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
    dispatch_receipts=dispatches,
  )
  assert_eq(receipts.length(), 1)
  assert_eq(
    rq_json_string(receipts[0], "ack_order_status", default=""),
    "matching-claim",
  )
  assert_eq(
    rq_json_string(receipts[0], "previous_dispatch_status", default=""),
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
    dispatch_receipts=dispatches,
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
    "moonclaw_task_id": "task-demo",
  }
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-claimed",
      "session_id": "session-demo",
      "action": "prompt",
      "dispatch": "prompt",
      "serve_command": "prompt",
      "openseek_wire_command": { "command": "prompt", "text": "build it" },
    },
  ]
  let receipts = runtime_replay_ack_receipts(session, commands, {
    "consumer_id": "moonclaw-runtime",
    "command_id": "cmd-claimed",
    "status": "runtime-acknowledged",
    "events": [
      {
        "event": "tool_result",
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
    task_id="task-demo",
    runtime_command_log_path="/tmp/book/.moontown/mooncode-sessions/session-demo/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/book/.moontown/mooncode-sessions/session-demo/runtime-dispatches.jsonl",
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
    runtime_dispatch_log_path="/tmp/book/.moontown/mooncode-sessions/session-demo/runtime-dispatches.jsonl",
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
      "task_id",
      default="",
    ),
    "task-demo",
  )
}

///|
test "mooncode runtime replay completion is blocked without required proof" {
  let session : Json = { "id": "session-demo", "workspace_id": "book-demo" }
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-tests",
      "session_id": "session-demo",
      "action": "run_tests",
      "dispatch": "command",
      "serve_command": "prompt",
      "openseek_wire_command": { "command": "prompt", "text": "run tests" },
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
    task_id="task-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
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
    task_id="task-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
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
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-tests",
      "session_id": "session-demo",
      "action": "run_tests",
      "dispatch": "command",
      "serve_command": "prompt",
      "openseek_wire_command": { "command": "prompt", "text": "run tests" },
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
  assert_eq(rq_json_int(gate, "prior_event_count", default=0), 8)
  assert_eq(rq_json_int(gate, "missing_required_event_count", default=-1), 0)
  assert_eq(rq_json_int(gate, "proven_required_event_count", default=0), 4)
  assert_eq(rq_json_string(gate, "tool_harness_status", default=""), "proven")
  assert_eq(rq_json_int(gate, "tool_harness_proven_tool_count", default=0), 4)
}

///|
test "mooncode runtime replay ack summarizes submitted proof events" {
  let session : Json = { "id": "session-demo", "workspace_id": "book-demo" }
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-proof",
      "session_id": "session-demo",
      "action": "run_tests",
      "dispatch": "command",
      "serve_command": "prompt",
      "openseek_wire_command": { "command": "prompt", "text": "run tests" },
    },
  ]
  let receipts = runtime_replay_ack_receipts(session, commands, {
    "consumer_id": "moonclaw-runtime",
    "command_id": "cmd-proof",
    "status": "runtime-completed",
    "acknowledged_at": "2026-06-15T00:00:00Z",
    "events": [
      {
        "event": "tool_call",
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
        "event": "test_result",
        "id": "evt-test",
        "command": "moon test",
        "status": "passed",
        "exit_code": 0,
      },
      {
        "event": "package_verified",
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
    task_id="task-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
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
test "mooncode runtime consumer execution plan exposes next claimable command" {
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-tests",
      "session_id": "s1",
      "action": "run_tests",
      "dispatch": "command",
      "target": "tools/demo/main.mbt",
      "context_path": "tools/demo/main.mbt",
      "openseek_wire_command": {
        "command": "prompt",
        "text": "Run tests for tools/demo/main.mbt",
      },
      "execution_summary": {
        "kind": "mooncode-runtime-execution-summary",
        "required_events": [
          "tool_call", "tool_result", "test_result", "agent_finished",
        ],
        "required_outputs": ["test/build log"],
        "event_sink": "/api/mooncode/sessions/s1/runtime-events",
        "ack_sink": "/api/mooncode/sessions/s1/runtime-replay",
        "execution_checklist": [
          { "id": "claim-command", "blocking": true },
          { "id": "emit-event-test_result", "blocking": true },
        ],
        "completion_rule": "Append test_result and acknowledge completion.",
      },
      "native_mooncode_body": {
        "protocol": "mooncode.v1",
        "command": "run_tests",
        "session_id": "s1",
      },
    },
  ]
  let replay = runtime_replay_state(
    "s1",
    commands,
    [],
    workspace_id="book",
    workspace_name="Book",
    task_id="task",
    runtime_command_log_path="/tmp/book/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/book/runtime-dispatches.jsonl",
  )
  let claim = runtime_claim_state(
    "s1",
    commands,
    [],
    workspace_id="book",
    workspace_name="Book",
    task_id="task",
    runtime_command_log_path="/tmp/book/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/book/runtime-dispatches.jsonl",
  )
  let plan = runtime_consumer_execution_plan("s1", replay, claim, false)
  assert_eq(
    json_string(plan, "kind", default=""),
    "mooncode-runtime-consumer-execution-plan",
  )
  assert_eq(json_string(plan, "status", default=""), "ready-to-claim")
  assert_eq(json_string(plan, "operation", default=""), "claim-command")
  assert_true(json_bool(plan, "ready_to_claim", default=false))
  assert_true(json_bool(plan, "ready_to_execute", default=false))
  assert_eq(json_string(plan, "command_id", default=""), "cmd-tests")
  assert_eq(json_string(plan, "action", default=""), "run_tests")
  assert_eq(rq_json_int(plan, "required_event_count", default=0), 4)
  assert_true(
    rq_json_string_array_items(plan, "required_events").contains("test_result"),
  )
  assert_eq(
    json_string(
      rq_json_object_field_or_empty(plan, "claim_request_template"),
      "command_id",
      default="",
    ),
    "cmd-tests",
  )
  assert_eq(
    json_string(
      rq_json_object_field_or_empty(plan, "openseek_wire_command"),
      "command",
      default="",
    ),
    "prompt",
  )
  assert_true(rq_json_array_items(plan, "execution_checklist").length() >= 2)
  let lifecycle = runtime_command_lifecycle("s1", commands, [], [])
  let scheduler = serve_scheduler_projection("s1", commands, lifecycle)
  let packet = runtime_turn_packet("s1", replay, claim, scheduler, false)
  assert_eq(
    rq_json_string(packet, "kind", default=""),
    "mooncode-runtime-turn-packet",
  )
  assert_eq(rq_json_string(packet, "command_id", default=""), "cmd-tests")
  assert_eq(
    rq_json_string(packet, "scheduler_effect", default=""),
    "start-turn",
  )
  assert_true(rq_json_bool(packet, "scheduler_allows_turn", default=false))
  assert_eq(
    rq_json_string(
      rq_json_object_field_or_empty(packet, "openseek_wire_command"),
      "command",
      default="",
    ),
    "prompt",
  )
  assert_eq(rq_json_array_items(packet, "required_events").length(), 4)
  assert_true(
    rq_json_string(packet, "safety_boundary", default="").contains(
      "Moondesk does not execute",
    ),
  )
  let supervisor = runtime_supervisor_launch_packet(
    "s1",
    packet,
    runtime_consumer_handoff("s1", replay, claim, false),
    workspace_root="/tmp/book",
    moonclaw_root="../moonclaw",
    host_base_url="http://127.0.0.1:4304",
    false,
  )
  assert_eq(
    rq_json_string(supervisor, "kind", default=""),
    "mooncode-runtime-supervisor-launch",
  )
  assert_true(rq_json_bool(supervisor, "ready_to_launch", default=false))
  assert_eq(
    rq_json_string(supervisor, "mode", default=""),
    "moondesk-claim-replay-bridge",
  )
  assert_eq(rq_json_string(supervisor, "command_id", default=""), "cmd-tests")
  assert_eq(
    rq_json_string(
      rq_json_object_field_or_empty(supervisor, "endpoints"),
      "claim",
      default="",
    ),
    "http://127.0.0.1:4304/api/mooncode/sessions/s1/runtime-claim",
  )
  assert_eq(
    rq_json_string(
      rq_json_object_field_or_empty(supervisor, "launch_request"),
      "command_id",
      default="",
    ),
    "cmd-tests",
  )
  assert_eq(rq_json_array_items(supervisor, "supervisor_loop").length(), 6)
  let readiness = rq_json_object_field_or_empty(supervisor, "readiness")
  assert_eq(
    rq_json_string(readiness, "kind", default=""),
    "mooncode-runtime-supervisor-readiness",
  )
  assert_true(rq_json_bool(readiness, "ok", default=false))
  assert_eq(rq_json_string(readiness, "status", default=""), "launch-ready")
  assert_eq(rq_json_int(readiness, "missing_requirement_count", default=-1), 0)
  assert_true(rq_json_bool(readiness, "endpoint_ready", default=false))
  assert_true(rq_json_bool(readiness, "launch_request_ready", default=false))
  assert_true(rq_json_bool(readiness, "supervisor_loop_ready", default=false))
  assert_true(
    rq_json_string(supervisor, "safety_boundary", default="").contains(
      "declarative",
    ),
  )
}

///|
test "mooncode runtime supervisor launch explains idle state" {
  let packet : Json = {
    "kind": "mooncode-runtime-turn-packet",
    "protocol": "mooncode.v1",
    "session_id": "s1",
    "status": "idle",
    "operation": "wait",
    "command_id": "",
    "action": "",
    "ready_to_execute": false,
    "scheduler_allows_turn": false,
    "endpoints": {},
  }
  let supervisor = runtime_supervisor_launch_packet(
    "s1",
    packet,
    Json::object({}),
    workspace_root="/tmp/book",
    moonclaw_root="",
    host_base_url="",
    true,
  )
  assert_eq(
    rq_json_string(supervisor, "mode", default=""),
    "native-mooncode-runtime",
  )
  assert_false(rq_json_bool(supervisor, "ready_to_launch", default=true))
  assert_eq(
    rq_json_string(supervisor, "launch_blocked_reason", default=""),
    "no runtime command is ready for execution",
  )
  assert_true(
    rq_json_string(supervisor, "extractable_component", default="").contains(
      "mooncode",
    ),
  )
  let readiness = rq_json_object_field_or_empty(supervisor, "readiness")
  assert_false(rq_json_bool(readiness, "ok", default=true))
  assert_eq(rq_json_string(readiness, "status", default=""), "blocked")
  assert_true(
    rq_json_string_array_items(readiness, "missing_requirements").contains(
      "command_id",
    ),
  )
  assert_true(
    rq_json_string_array_items(readiness, "missing_requirements").contains(
      "endpoint.claim",
    ),
  )
  assert_true(
    rq_json_string(readiness, "safety_boundary", default="").contains(
      "does not mean Moondesk may execute tools",
    ),
  )
}

///|
test "mooncode runtime replay ack exposes prior-order blocker" {
  let session : Json = { "id": "session-demo", "workspace_id": "book-demo" }
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-active",
      "session_id": "session-demo",
      "action": "prompt",
      "dispatch": "prompt",
      "serve_command": "prompt",
      "openseek_wire_command": { "command": "prompt", "text": "first" },
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-later",
      "session_id": "session-demo",
      "action": "steer",
      "dispatch": "steer",
      "serve_command": "steer",
      "openseek_wire_command": { "command": "steer", "text": "later" },
    },
  ]
  let dispatches : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
      "dispatch_id": "claim-active",
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
    dispatch_receipts=dispatches,
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

///|
test "mooncode runtime consumer handoff reports claim readiness" {
  let handoff = runtime_consumer_handoff(
    "s1",
    {
      "kind": "mooncode-runtime-replay-state",
      "pending_command_count": 1,
      "replay_ready": true,
    },
    {
      "kind": "mooncode-runtime-claim-state",
      "claimable_command_count": 1,
      "claimed_command_count": 0,
      "delivered_command_count": 0,
      "invalid_command_count": 0,
    },
    false,
  )
  assert_eq(
    rq_json_string(handoff, "kind", default=""),
    "mooncode-runtime-consumer-handoff",
  )
  assert_eq(rq_json_string(handoff, "status", default=""), "claim-ready")
  assert_true(rq_json_bool(handoff, "ready_to_claim", default=false))
  assert_true(rq_json_bool(handoff, "ready_to_replay", default=false))
  assert_true(
    rq_json_string(handoff, "next_action", default="").contains("runtime-claim"),
  )
}

///|
test "mooncode runtime command lifecycle summarizes queue state" {
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-tests",
      "session_id": "session-demo",
      "action": "run_tests",
      "dispatch": "command",
      "serve_command": "prompt",
      "openseek_wire_command": { "command": "prompt", "text": "run tests" },
      "tool_authorization": {
        "enforcement_state": "approved",
        "runtime_may_execute": true,
      },
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-package",
      "session_id": "session-demo",
      "action": "package",
      "dispatch": "command",
      "serve_command": "prompt",
      "openseek_wire_command": { "command": "prompt", "text": "package" },
      "tool_authorization": {
        "enforcement_state": "approved",
        "runtime_may_execute": true,
      },
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-shell",
      "session_id": "session-demo",
      "action": "prompt",
      "dispatch": "prompt",
      "serve_command": "prompt",
      "openseek_wire_command": { "command": "prompt", "text": "run shell" },
      "tool_authorization": {
        "enforcement_state": "requires-approval",
        "runtime_may_execute": false,
        "pending_approval_count": 1,
      },
    },
  ]
  let receipts : Array[Json] = [
    {
      "kind": "mooncode.runtime-dispatch",
      "command_id": "cmd-tests",
      "status": "runtime-completed",
    },
    {
      "kind": "mooncode.runtime-dispatch",
      "command_id": "cmd-package",
      "status": "runtime-claimed",
      "consumer_id": "moonclaw-runtime",
      "lease_expires_at": "2026-06-15T01:00:00Z",
    },
  ]
  let events : Array[Json] = [
    {
      "id": "evt-tests",
      "lane": "test",
      "kind": "test_result",
      "title": "Tests passed",
      "status": "done",
      "command_packet": { "command_id": "cmd-tests", "action": "run_tests" },
    },
    {
      "id": "evt-package",
      "lane": "artifact",
      "kind": "runtime.package_built",
      "title": "Package building",
      "status": "running",
      "command_packet": { "command_id": "cmd-package", "action": "package" },
    },
  ]
  let lifecycle = runtime_command_lifecycle(
    "session-demo",
    commands,
    receipts,
    events,
    lease_now="2026-06-15T00:30:00Z",
  )
  assert_eq(
    rq_json_string(lifecycle, "kind", default=""),
    "mooncode-runtime-command-lifecycle",
  )
  assert_eq(rq_json_int(lifecycle, "command_count", default=0), 3)
  assert_eq(rq_json_int(lifecycle, "completed_count", default=0), 1)
  assert_eq(rq_json_int(lifecycle, "running_count", default=0), 1)
  assert_eq(rq_json_int(lifecycle, "blocked_count", default=0), 1)
  assert_eq(rq_json_int(lifecycle, "scoped_event_count", default=0), 2)
  assert_eq(
    rq_json_string(lifecycle, "next_command_id", default=""),
    "cmd-package",
  )
  let rows = rq_json_array_items(lifecycle, "commands")
  assert_eq(rq_json_string(rows[0], "status", default=""), "completed")
  assert_eq(rq_json_int(rows[0], "proof_event_count", default=0), 1)
  assert_eq(rq_json_string(rows[1], "status", default=""), "running")
  assert_eq(
    rq_json_string(rows[2], "status", default=""),
    "blocked-tool-authorization",
  )
  assert_true(
    rq_json_string(rows[2], "blocking_reason", default="").contains("pending"),
  )
}
