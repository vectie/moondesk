///|
// White-box tests for MoonCode runtime receipt protocol and queue response surfaces.

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
  assert_true(events.contains("steer_deferred"))
  assert_true(events.contains("commit_created"))
  guard rq_json_object_field(contract, "tool_registry") is Some(registry) else {
    fail("missing tool registry contract")
  }
  guard rq_json_object_field(registry, "tool_call_contract") is Some(contract) else {
    fail("missing tool_call_contract contract")
  }
  assert_eq(
    rq_json_string(contract, "kind", default=""),
    "mooncode-tool-call-contract",
  )
  assert_true(
    rq_json_string_array_items(contract, "supported_tools").contains(
      "moon_check",
    ),
  )
}

///|
test "mooncode runtime receipt classifies runtime outcomes" {
  let runtime_command : Json = {
    "command_id": "cmd-1",
    "session_id": "session-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo",
    "runtime_session_id": "runtime-demo",
    "action": "prompt",
    "control": "prompt",
    "mooncode_command_valid": true,
    "native_mooncode_endpoint": "/v1/code/sessions/session-demo/commands",
  }
  let native_session : Json = {
    "workspace_id": "book-demo",
    "workspace_name": "Demo",
    "mooncode_runtime_session_id": "runtime-demo",
    "mooncode_runtime_mode": "moonclaw-mooncode-runtime",
  }
  let native = runtime_receipt(
    native_session,
    runtime_command,
    receipt_id="receipt-native",
    created_at="2026-06-15T00:00:00Z",
  )
  assert_eq(rq_json_string(native, "status", default=""), "runtime-accepted")
  assert_eq(
    rq_json_string(native, "runtime_mode", default=""),
    "moonclaw-mooncode-runtime",
  )
  assert_true(rq_json_bool(native, "mooncode_command_valid", default=false))
  assert_true(
    rq_json_string(native, "detail", default="").contains("native MoonClaw"),
  )
  let unsupported_session : Json = {
    "mooncode_runtime_session_id": "runtime-demo",
    "mooncode_runtime_mode": "unsupported-runtime-mode",
  }
  assert_eq(
    runtime_receipt_status(unsupported_session, runtime_command),
    "recorded",
  )
  let recorded_session : Json = {
    "mooncode_runtime_mode": "runtime-not-started",
  }
  assert_eq(
    runtime_receipt_status(recorded_session, runtime_command),
    "recorded",
  )
  let failed_session : Json = {
    "mooncode_runtime_mode": "moonclaw-mooncode-runtime",
    "mooncode_command_events": [
      { "status": "failed", "command_packet": { "command_id": "cmd-1" } },
    ],
  }
  assert_eq(runtime_receipt_status(failed_session, runtime_command), "failed")
}

///|
test "mooncode projected runtime receipt owns stable receipt ids" {
  let runtime_command : Json = {
    "command_id": "cmd-1",
    "session_id": "session-demo",
    "action": "prompt",
    "control": "prompt",
  }
  let session : Json = {
    "workspace_id": "book-demo",
    "mooncode_runtime_mode": "moonclaw-mooncode-runtime",
  }
  let first = projected_runtime_receipt(
    session, runtime_command, "2026-06-15T00:00:00Z",
  )
  let second = projected_runtime_receipt(
    session, runtime_command, "2026-06-15T00:00:00Z",
  )
  assert_eq(
    rq_json_string(first, "receipt_id", default=""),
    rq_json_string(second, "receipt_id", default=""),
  )
  assert_true(
    rq_json_string(first, "receipt_id", default="").has_prefix(
      "mooncode-runtime-receipt-",
    ),
  )
  assert_eq(rq_json_string(first, "status", default=""), "runtime-accepted")
  assert_eq(
    rq_json_string(first, "created_at", default=""),
    "2026-06-15T00:00:00Z",
  )
}

///|
test "mooncode runtime receipt response fills native defaults" {
  let response = runtime_receipt_for_response(
    { "command_id": "cmd-recorded", "status": "recorded" },
    fallback_receipt_id="receipt-fallback",
  )
  assert_eq(
    rq_json_string(response, "receipt_id", default=""),
    "receipt-fallback",
  )
  assert_eq(rq_json_string(response, "runtime_mode", default=""), "unknown")
  assert_eq(rq_json_string(response, "created_at", default="missing"), "")
  assert_false(rq_json_bool(response, "mooncode_command_valid", default=true))
  assert_true(
    rq_json_object_field(response, "runtime_command") is Some(Object(_)),
  )
  assert_true(rq_json_object_field(response, "owner") is Some(Object(_)))
  let responses = runtime_receipts_for_response([
    { "command_id": "cmd-recorded", "status": "recorded" },
    {
      "command_id": "cmd-existing",
      "status": "runtime-completed",
      "receipt_id": "receipt-existing",
    },
  ])
  assert_eq(responses.length(), 2)
  assert_true(
    rq_json_string(responses[0], "receipt_id", default="").has_prefix(
      "mooncode-runtime-receipt-",
    ),
  )
  assert_eq(
    rq_json_string(responses[1], "receipt_id", default=""),
    "receipt-existing",
  )
}

///|
test "mooncode runtime receipt state response records queue state" {
  let command : Json = {
    "protocol": protocol_version(),
    "kind": "mooncode.runtime-command",
    "command_id": "cmd-1",
  }
  let control : Json = {
    "protocol": protocol_version(),
    "kind": kind_runtime_receipt(),
    "command_id": "cmd-0",
    "status": "runtime-completed",
    "receipt_id": "receipt-0",
  }
  let response = runtime_receipt_state_response(
    "session-demo",
    [command],
    [control],
    [Json::string("cmd-1")],
    workspace_id="book-demo",
    workspace_name="Demo",
    runtime_session_id="runtime-demo",
    runtime_mode="moonclaw-mooncode-runtime",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/runtime-receipts.jsonl",
  )
  assert_eq(
    rq_json_string(response, "kind", default=""),
    "mooncode-runtime-receipt-state",
  )
  assert_eq(rq_json_int(response, "runtime_command_count", default=0), 1)
  assert_eq(rq_json_int(response, "runtime_receipt_count", default=0), 1)
  assert_eq(
    rq_json_int(response, "runtime_receipt_pending_count", default=0),
    1,
  )
  assert_eq(
    rq_json_string_array_items(response, "pending_command_ids")[0],
    "cmd-1",
  )
  assert_true(
    rq_json_object_field(response, "runtime_protocol") is Some(Object(_)),
  )
  assert_eq(
    rq_json_string(
      rq_json_object_field_or_empty(response, "owner"),
      "runtime",
      default="",
    ),
    "moonclaw",
  )
  let aggregate = runtime_receipt_response(
    "session-demo",
    [command],
    [{ "command_id": "cmd-0", "status": "runtime-completed" }],
    workspace_id="book-demo",
    workspace_name="Demo",
    runtime_session_id="runtime-demo",
    runtime_mode="moonclaw-mooncode-runtime",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/runtime-receipts.jsonl",
    lease_now="2026-06-15T00:00:00Z",
  )
  assert_eq(
    rq_json_string(aggregate, "kind", default=""),
    "mooncode-runtime-receipt-state",
  )
  assert_eq(
    rq_json_int(aggregate, "runtime_receipt_pending_count", default=0),
    1,
  )
  let aggregate_receipts = rq_json_array_items(aggregate, "runtime_receipts")
  assert_eq(aggregate_receipts.length(), 1)
  assert_true(
    rq_json_string(aggregate_receipts[0], "receipt_id", default="").has_prefix(
      "mooncode-runtime-receipt-",
    ),
  )
}
