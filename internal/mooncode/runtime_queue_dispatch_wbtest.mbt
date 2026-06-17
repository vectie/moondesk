///|
// White-box tests for MoonCode runtime dispatch protocol and queue response surfaces.

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
test "mooncode projected runtime dispatch receipt owns stable dispatch ids" {
  let runtime_command : Json = {
    "command_id": "cmd-1",
    "session_id": "session-demo",
    "action": "prompt",
    "dispatch": "prompt",
  }
  let session : Json = {
    "workspace_id": "book-demo",
    "mooncode_dispatch_mode": "moonclaw-mooncode-runtime",
  }
  let first = projected_runtime_dispatch_receipt(
    session, runtime_command, "2026-06-15T00:00:00Z",
  )
  let second = projected_runtime_dispatch_receipt(
    session, runtime_command, "2026-06-15T00:00:00Z",
  )
  assert_eq(
    rq_json_string(first, "dispatch_id", default=""),
    rq_json_string(second, "dispatch_id", default=""),
  )
  assert_true(
    rq_json_string(first, "dispatch_id", default="").has_prefix(
      "mooncode-runtime-dispatch-",
    ),
  )
  assert_eq(rq_json_string(first, "status", default=""), "native-dispatched")
  assert_eq(
    rq_json_string(first, "created_at", default=""),
    "2026-06-15T00:00:00Z",
  )
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
    "protocol": protocol_version(),
    "kind": "mooncode.runtime-command",
    "command_id": "cmd-1",
  }
  let dispatch : Json = {
    "protocol": protocol_version(),
    "kind": kind_runtime_dispatch(),
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
