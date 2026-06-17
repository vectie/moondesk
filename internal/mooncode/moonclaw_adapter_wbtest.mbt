///|
// White-box tests for MoonClaw adapter event, endpoint, and readiness mapping.

///|
test "mooncode moonclaw adapter maps moonclaw tools to mooncode tools" {
  assert_eq(moonclaw_tool_to_mooncode_tool("execute_command"), "shell")
  assert_eq(moonclaw_tool_to_mooncode_tool("read_file"), "read")
  assert_eq(moonclaw_tool_to_mooncode_tool("write_to_file"), "write")
  assert_eq(moonclaw_tool_to_mooncode_tool("replace_in_file"), "edit")
  assert_eq(moonclaw_tool_to_mooncode_tool("unknown_tool"), "unknown_tool")
  let contract = moonclaw_adapter_contract_json()
  assert_eq(
    moonclaw_json_string(contract, "kind", default=""),
    "mooncode-moonclaw-adapter-contract",
  )
  assert_true(contract.stringify().contains("/v1/task/<task-id>/events"))
  assert_true(
    contract
    .stringify()
    .contains("/v1/mooncode/sessions?book_root=<path>&format=json"),
  )
  assert_true(
    contract
    .stringify()
    .contains("/v1/mooncode/sessions/<id>/runtime-events?book_root=<path>"),
  )
  assert_true(
    contract
    .stringify()
    .contains("/v1/mooncode/sessions/<id>/tool-exec?book_root=<path>"),
  )
  assert_true(
    contract
    .stringify()
    .contains("/v1/mooncode/sessions/<id>/eval-report?book_root=<path>"),
  )
  assert_true(
    contract
    .stringify()
    .contains(
      "read/edit/write/apply_patch/revert_patch/shell/moon_ide/moon_cmd/moon_check/finish",
    ),
  )
}

///|
test "mooncode validates moonclaw native capabilities before using runtime" {
  assert_true(
    moonclaw_native_required_endpoints().contains(
      "/v1/mooncode/sessions/<id>/runtime-turn?book_root=<path>",
    ),
  )
  assert_eq(
    moonclaw_native_required_endpoints().length(),
    native_capability_required_endpoints().length(),
  )
  assert_true(
    native_capability_required_endpoints().contains(
      "/v1/mooncode/sessions/<id>/package-result?book_root=<path>",
    ),
  )
  assert_true(moonclaw_native_required_tools().contains("moon_ide"))
  assert_true(moonclaw_native_required_tools().contains("moon_cmd"))
  assert_eq(
    moonclaw_native_required_tools().length(),
    native_capability_required_tools().length(),
  )
  assert_true(native_capability_required_tools().contains("apply_patch"))
  assert_eq(
    native_capability_contract_id(),
    "mooncode-native-capability-surface.v1",
  )
  assert_eq(
    moonclaw_native_capability_contract_id(),
    native_capability_contract_id(),
  )
  assert_eq(native_capability_surface_fingerprint().length(), 64)
  let expected_surface = native_capability_surface_json()
  assert_eq(
    moonclaw_json_string(expected_surface, "kind", default=""),
    "mooncode-native-capability-surface",
  )
  assert_eq(
    moonclaw_json_string(
      expected_surface,
      "capability_surface_fingerprint",
      default="",
    ),
    native_capability_surface_fingerprint(),
  )
  assert_eq(
    rq_json_string_array_items(expected_surface, "required_endpoints").length(),
    native_capability_required_endpoints().length(),
  )
  assert_eq(
    rq_json_string_array_items(expected_surface, "required_tools").length(),
    native_capability_required_tools().length(),
  )
  let ready : Json = {
    "component": "mooncode",
    "protocol": protocol_version(),
    "capability_contract_id": moonclaw_native_capability_contract_id(),
    "capability_surface": native_capability_surface_json(),
    "native_runtime_ready": true,
    "endpoints": moonclaw_native_required_endpoints(),
    "tools": moonclaw_native_required_tools(),
  }
  assert_true(moonclaw_native_capabilities_ready(ready))
  let report = moonclaw_native_capabilities_readiness(ready)
  assert_true(rq_json_bool(report, "ok", default=false))
  assert_eq(
    moonclaw_json_string(report, "status", default=""),
    "native-runtime-ready",
  )
  assert_true(rq_json_bool(report, "capability_contract_ok", default=false))
  assert_true(rq_json_bool(report, "capability_surface_present", default=false))
  assert_true(rq_json_bool(report, "capability_surface_ok", default=false))
  assert_true(
    rq_json_bool(report, "capability_surface_contract_ok", default=false),
  )
  assert_true(
    rq_json_bool(report, "capability_surface_fingerprint_ok", default=false),
  )
  assert_eq(
    moonclaw_json_string(report, "daemon_capability_contract_id", default=""),
    moonclaw_native_capability_contract_id(),
  )
  assert_eq(
    moonclaw_json_string(
      report,
      "daemon_capability_surface_contract_id",
      default="",
    ),
    moonclaw_native_capability_contract_id(),
  )
  assert_eq(
    moonclaw_json_string(
      report,
      "daemon_capability_surface_fingerprint",
      default="",
    ),
    native_capability_surface_fingerprint(),
  )
  assert_true(report.stringify().contains("\"expected_capability_surface\""))
  assert_true(report.stringify().contains("\"daemon_capability_surface\""))
  assert_true(
    report
    .stringify()
    .contains("\"kind\":\"mooncode-native-capability-surface\""),
  )
  assert_eq(moonclaw_json_int(report, "missing_endpoint_count", default=-1), 0)
  assert_eq(moonclaw_json_int(report, "missing_tool_count", default=-1), 0)
  assert_eq(
    moonclaw_json_int(
      report,
      "capability_surface_missing_endpoint_count",
      default=-1,
    ),
    0,
  )
  assert_eq(
    moonclaw_json_int(
      report,
      "capability_surface_missing_tool_count",
      default=-1,
    ),
    0,
  )
  let compatibility_only : Json = {
    "component": "mooncode",
    "protocol": protocol_version(),
    "capability_contract_id": moonclaw_native_capability_contract_id(),
    "native_runtime_ready": true,
    "endpoints": moonclaw_native_required_endpoints(),
    "tools": moonclaw_native_required_tools(),
  }
  assert_false(moonclaw_native_capabilities_ready(compatibility_only))
  let compatibility_report = moonclaw_native_capabilities_readiness(
    compatibility_only,
  )
  assert_false(
    rq_json_bool(
      compatibility_report,
      "capability_surface_present",
      default=true,
    ),
  )
  assert_false(
    rq_json_bool(compatibility_report, "capability_surface_ok", default=true),
  )
  let stale : Json = {
    "component": "mooncode",
    "protocol": protocol_version(),
    "native_runtime_ready": true,
    "endpoints": [
      "/v1/mooncode/capabilities", "/v1/mooncode/sessions?book_root=<path>", "/v1/mooncode/sessions/<id>/commands",
      "/v1/mooncode/sessions/<id>/runtime-turn?book_root=<path>",
    ],
    "tools": ["read", "edit", "write", "shell", "moon_check", "finish"],
  }
  assert_false(moonclaw_native_capabilities_ready(stale))
  let stale_report = moonclaw_native_capabilities_readiness(stale)
  assert_eq(
    moonclaw_json_string(stale_report, "status", default=""),
    "native-runtime-incompatible",
  )
  assert_true(
    rq_json_string_array_items(stale_report, "missing_endpoints").contains(
      "/v1/mooncode/sessions/<id>/serve-scheduler?book_root=<path>",
    ),
  )
  assert_true(
    rq_json_string_array_items(stale_report, "missing_tools").contains(
      "moon_ide",
    ),
  )
  assert_true(
    rq_json_string_array_items(stale_report, "missing_tools").contains(
      "moon_cmd",
    ),
  )
  let mismatched_contract : Json = {
    "component": "mooncode",
    "protocol": protocol_version(),
    "capability_contract_id": "mooncode-native-capability-surface.v0",
    "native_runtime_ready": true,
    "endpoints": moonclaw_native_required_endpoints(),
    "tools": moonclaw_native_required_tools(),
  }
  assert_false(moonclaw_native_capabilities_ready(mismatched_contract))
  let mismatch_report = moonclaw_native_capabilities_readiness(
    mismatched_contract,
  )
  assert_false(
    rq_json_bool(mismatch_report, "capability_contract_ok", default=true),
  )
  assert_eq(
    moonclaw_json_string(
      mismatch_report,
      "daemon_capability_contract_id",
      default="",
    ),
    "mooncode-native-capability-surface.v0",
  )
  let stale_surface : Json = {
    "component": "mooncode",
    "protocol": protocol_version(),
    "capability_contract_id": moonclaw_native_capability_contract_id(),
    "capability_surface": {
      "kind": "mooncode-native-capability-surface",
      "component": "mooncode",
      "protocol": protocol_version(),
      "capability_contract_id": "mooncode-native-capability-surface.v0",
      "required_endpoints": ["/v1/mooncode/capabilities"],
      "required_tools": ["read"],
    },
    "native_runtime_ready": true,
    "endpoints": moonclaw_native_required_endpoints(),
    "tools": moonclaw_native_required_tools(),
  }
  assert_false(moonclaw_native_capabilities_ready(stale_surface))
  let stale_surface_report = moonclaw_native_capabilities_readiness(
    stale_surface,
  )
  assert_false(
    rq_json_bool(stale_surface_report, "capability_surface_ok", default=true),
  )
  assert_false(
    rq_json_bool(
      stale_surface_report,
      "capability_surface_contract_ok",
      default=true,
    ),
  )
  assert_false(
    rq_json_bool(
      stale_surface_report,
      "capability_surface_fingerprint_ok",
      default=true,
    ),
  )
  assert_eq(
    moonclaw_json_string(
      stale_surface_report,
      "daemon_capability_surface_contract_id",
      default="",
    ),
    "mooncode-native-capability-surface.v0",
  )
  assert_true(
    rq_json_string_array_items(
      stale_surface_report, "capability_surface_missing_endpoints",
    ).contains("/v1/mooncode/sessions?book_root=<path>"),
  )
  assert_true(
    rq_json_string_array_items(
      stale_surface_report, "capability_surface_missing_tools",
    ).contains("apply_patch"),
  )
  let unavailable = moonclaw_native_capabilities_unavailable("daemon stopped")
  assert_false(rq_json_bool(unavailable, "ok", default=true))
  assert_eq(
    moonclaw_json_string(unavailable, "protocol", default=""),
    protocol_version(),
  )
  assert_eq(
    moonclaw_json_string(unavailable, "capability_contract_id", default=""),
    moonclaw_native_capability_contract_id(),
  )
  assert_false(
    rq_json_bool(unavailable, "capability_contract_ok", default=true),
  )
  assert_false(rq_json_bool(unavailable, "capability_surface_ok", default=true))
  assert_true(
    unavailable.stringify().contains("\"expected_capability_surface\""),
  )
  assert_eq(
    moonclaw_json_string(unavailable, "status", default=""),
    "native-runtime-unavailable",
  )
  assert_eq(
    moonclaw_json_string(unavailable, "error", default=""),
    "daemon stopped",
  )
}

///|
test "mooncode moonclaw adapter normalizes tool events" {
  let raw : Json = {
    "id": "evt-1",
    "created": 0,
    "desc": {
      "msg": "PreToolCall",
      "tool_call": {
        "id": "call-1",
        "function": {
          "name": "execute_command",
          "arguments": "{\"command\":\"moon test\"}",
        },
        "type": "function",
      },
      "name": "execute_command",
    },
  }
  guard moonclaw_event_to_runtime_event(
      raw,
      fallback_id="fallback",
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(event) else {
    fail("expected MoonClaw tool event")
  }
  assert_eq(moonclaw_json_string(event, "event", default=""), "tool_call")
  assert_eq(moonclaw_json_string(event, "tool_name", default=""), "shell")
  let tool_call = moonclaw_json_object_field_or_empty(event, "tool_call")
  let function = moonclaw_json_object_field_or_empty(tool_call, "function")
  assert_eq(moonclaw_json_string(function, "name", default=""), "shell")
}

///|
test "mooncode moonclaw adapter shapes legacy status events" {
  guard moonclaw_status_event_record(
      {
        "id": "evt-model",
        "created": "2026-06-16T00:00:00Z",
        "desc": { "msg": "ModelLoaded", "name": "dev-model" },
      },
      fallback_id="fallback",
    )
    is Some(event) else {
    fail("status event was not projected")
  }
  assert_eq(json_string(event, "lane", default=""), "runtime")
  assert_eq(json_string(event, "kind", default=""), "ModelLoaded")
  assert_eq(json_string(event, "title", default=""), "Model loaded: dev-model")
  assert_eq(json_string(event, "status", default=""), "running")
  guard moonclaw_status_event_record(
      { "desc": { "msg": "Failed", "error": { "message": "tool failed" } } },
      fallback_id="fallback-failed",
    )
    is Some(failed_event) else {
    fail("failed event was not projected")
  }
  assert_eq(json_string(failed_event, "id", default=""), "fallback-failed")
  assert_eq(json_string(failed_event, "title", default=""), "MoonClaw failed")
  assert_eq(json_string(failed_event, "status", default=""), "failed")
  assert_true(
    json_string(failed_event, "detail", default="").contains("tool failed"),
  )
}

///|
test "mooncode moonclaw adapter owns native runtime request bodies" {
  let loop_request = moonclaw_runtime_loop_request(
    "session-demo",
    "/tmp/book",
    consumer_id="moondesk-ui-runtime-loop",
    max_turns=5,
  )
  assert_eq(json_string(loop_request, "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(loop_request, "session_id", default=""), "session-demo")
  assert_eq(json_string(loop_request, "book_root", default=""), "/tmp/book")
  assert_eq(
    json_string(loop_request, "consumer_id", default=""),
    "moondesk-ui-runtime-loop",
  )
  assert_eq(moonclaw_json_int(loop_request, "max_turns", default=0), 5)
  let turn_request = moonclaw_runtime_turn_request(
    "session-demo",
    "/tmp/book",
    consumer_id="moondesk-ui-runtime-turn",
  )
  assert_eq(json_string(turn_request, "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(turn_request, "session_id", default=""), "session-demo")
  assert_eq(json_string(turn_request, "book_root", default=""), "/tmp/book")
  assert_eq(
    json_string(turn_request, "consumer_id", default=""),
    "moondesk-ui-runtime-turn",
  )
  assert_eq(
    moonclaw_runtime_dispatch_mode({ "kind": "mooncode-runtime-loop" }),
    "moonclaw-mooncode-runtime-loop",
  )
  assert_eq(
    moonclaw_runtime_dispatch_mode({ "kind": "mooncode-runtime-turn" }),
    "moonclaw-mooncode-runtime-turn",
  )
  assert_eq(
    moonclaw_runtime_dispatch_mode(
      { "kind": "mooncode-runtime-turn" },
      accepted=false,
    ),
    "moonclaw-mooncode-runtime",
  )
  assert_eq(
    moonclaw_native_eval_report_endpoint("session one", "/tmp/moon book"),
    "/v1/mooncode/sessions/session%20one/eval-report?book_root=%2Ftmp%2Fmoon%20book",
  )
  assert_eq(
    moonclaw_native_package_result_endpoint("session one", "/tmp/moon book"),
    "/v1/mooncode/sessions/session%20one/package-result?book_root=%2Ftmp%2Fmoon%20book",
  )
  assert_eq(
    moonclaw_native_serve_scheduler_endpoint("session one", "/tmp/moon book"),
    "/v1/mooncode/sessions/session%20one/serve-scheduler?book_root=%2Ftmp%2Fmoon%20book",
  )
  assert_eq(
    moonclaw_native_session_listing_endpoint("/tmp/moon book"),
    "/v1/mooncode/sessions?book_root=%2Ftmp%2Fmoon%20book&format=json",
  )
  assert_eq(
    moonclaw_native_command_endpoint("session one"),
    "/v1/mooncode/sessions/session%20one/commands",
  )
  assert_eq(
    moonclaw_native_runtime_loop_endpoint("session one", "/tmp/moon book"),
    "/v1/mooncode/sessions/session%20one/runtime-loop?book_root=%2Ftmp%2Fmoon%20book",
  )
  assert_eq(
    moonclaw_native_runtime_turn_endpoint("session one", "/tmp/moon book"),
    "/v1/mooncode/sessions/session%20one/runtime-turn?book_root=%2Ftmp%2Fmoon%20book",
  )
  assert_eq(
    moonclaw_native_stream_endpoint("session one", "/tmp/moon book", "sse", 7),
    "/v1/mooncode/sessions/session%20one/stream?book_root=%2Ftmp%2Fmoon%20book&format=sse&since=7",
  )
  assert_eq(
    moonclaw_native_runtime_events_endpoint("session one", "/tmp/moon book"),
    "/v1/mooncode/sessions/session%20one/runtime-events?book_root=%2Ftmp%2Fmoon%20book",
  )
  let accepted = moonclaw_native_runtime_dispatch_result(
    { "message": "queued" },
    {
      "kind": "mooncode-runtime-loop",
      "accepted": true,
      "message": "loop completed",
    },
    { "action": "run_tests" },
    queue_accepted=true,
    runtime_succeeded=true,
    runtime_error="",
  )
  assert_eq(json_string(accepted, "status", default=""), "done")
  assert_eq(json_string(accepted, "detail", default=""), "loop completed")
  assert_eq(
    json_string(accepted, "dispatch_mode", default=""),
    "moonclaw-mooncode-runtime-loop",
  )
  let failed = moonclaw_native_runtime_dispatch_result(
    { "message": "queued" },
    Json::object({}),
    { "action": "package" },
    queue_accepted=true,
    runtime_succeeded=false,
    runtime_error="network failed",
  )
  assert_eq(json_string(failed, "status", default=""), "failed")
  assert_true(
    json_string(failed, "detail", default="").contains("network failed"),
  )
  let patch = moonclaw_native_runtime_session_patch(
    accepted,
    { "action": "run_tests", "path": "tools/demo" },
    "Run tests",
    "2026-06-16T15:00:00Z",
  )
  assert_eq(
    json_string(patch, "kind", default=""),
    "mooncode-native-runtime-session-patch",
  )
  assert_eq(json_string(patch, "last_message", default=""), "Run tests")
  assert_eq(
    json_string(patch, "mooncode_dispatch_mode", default=""),
    "moonclaw-mooncode-runtime-loop",
  )
  assert_eq(
    json_string(patch, "updated_at", default=""),
    "2026-06-16T15:00:00Z",
  )
  let status_message = moonclaw_json_object_field_or_empty(
    patch, "status_message",
  )
  assert_eq(json_string(status_message, "role", default=""), "status")
  assert_eq(
    json_string(status_message, "content", default=""),
    "loop completed",
  )
  assert_eq(json_string(status_message, "status", default=""), "done")
  let packet = moonclaw_json_object_field_or_empty(
    patch, "mooncode_last_command_packet",
  )
  assert_eq(json_string(packet, "action", default=""), "run_tests")
}

///|
test "mooncode task bridge session patch and apply are MoonCode owned" {
  let command_packet : Json = { "command_id": "cmd-bridge", "action": "prompt" }
  let patch = moonclaw_task_bridge_session_patch(
    command_packet, "Build a tool", "2026-06-17T00:00:00Z",
  )
  assert_eq(
    json_string(patch, "kind", default=""),
    "mooncode-moonclaw-task-bridge-session-patch",
  )
  assert_eq(
    json_string(patch, "mooncode_dispatch_mode", default=""),
    "moonclaw-task-bridge",
  )
  let session = apply_moonclaw_runtime_session_patch(
    { "id": "agent-demo", "status": "running" },
    patch,
  )
  assert_eq(json_string(session, "id", default=""), "agent-demo")
  assert_eq(json_string(session, "status", default=""), "running")
  assert_eq(json_string(session, "last_message", default=""), "Build a tool")
  assert_eq(
    json_string(session, "mooncode_dispatch_mode", default=""),
    "moonclaw-task-bridge",
  )
  assert_eq(
    json_string(session, "updated_at", default=""),
    "2026-06-17T00:00:00Z",
  )
  let packet = moonclaw_json_object_field_or_empty(
    session, "mooncode_last_command_packet",
  )
  assert_eq(json_string(packet, "command_id", default=""), "cmd-bridge")
}

///|
test "mooncode runtime session patch apply preserves absent fields" {
  let session = apply_moonclaw_runtime_session_patch(
    {
      "id": "agent-demo",
      "last_message": "previous",
      "mooncode_dispatch_mode": "old",
    },
    {
      "kind": "mooncode-runtime-supervisor-run-session-patch",
      "mooncode_dispatch_mode": "moonclaw-mooncode-runtime-loop",
      "updated_at": "2026-06-17T00:01:00Z",
    },
  )
  assert_eq(json_string(session, "last_message", default=""), "previous")
  assert_eq(
    json_string(session, "mooncode_dispatch_mode", default=""),
    "moonclaw-mooncode-runtime-loop",
  )
  assert_eq(
    json_string(session, "updated_at", default=""),
    "2026-06-17T00:01:00Z",
  )
}

///|
test "mooncode moonclaw adapter shapes supervisor run session patch" {
  let patch = moonclaw_runtime_supervisor_run_session_patch(
    {
      "kind": "mooncode-runtime-loop",
      "accepted": true,
      "message": "runtime loop completed",
    },
    "2026-06-16T16:00:00Z",
  )
  assert_eq(
    json_string(patch, "kind", default=""),
    "mooncode-runtime-supervisor-run-session-patch",
  )
  assert_eq(json_string(patch, "status", default=""), "done")
  assert_eq(json_string(patch, "detail", default=""), "runtime loop completed")
  assert_eq(
    json_string(patch, "mooncode_dispatch_mode", default=""),
    "moonclaw-mooncode-runtime-loop",
  )
  let message = moonclaw_json_object_field_or_empty(patch, "status_message")
  assert_eq(json_string(message, "role", default=""), "status")
  assert_eq(json_string(message, "status", default=""), "done")
  assert_eq(
    json_string(message, "content", default=""),
    "runtime loop completed",
  )
  let failed = moonclaw_runtime_supervisor_run_session_patch(
    { "kind": "mooncode-runtime-turn", "accepted": false },
    "2026-06-16T16:00:01Z",
  )
  assert_eq(json_string(failed, "status", default=""), "failed")
  assert_true(
    json_string(failed, "detail", default="").contains("did not accept work"),
  )
}

///|
test "mooncode moonclaw adapter shapes legacy transcript events" {
  guard moonclaw_event_record(
      {
        "id": "evt-user",
        "created": "2026-06-16T00:00:00Z",
        "desc": { "msg": "UserMessage", "content": "Create a MoonBook tool" },
      },
      fallback_id="fallback",
    )
    is Some(user_event) else {
    fail("user event was not projected")
  }
  assert_eq(moonclaw_json_string(user_event, "lane", default=""), "transcript")
  assert_eq(moonclaw_json_string(user_event, "kind", default=""), "user")
  guard moonclaw_event_record(
      {
        "id": "evt-request",
        "desc": {
          "msg": "RequestCompleted",
          "message": {
            "content": [
              { "text": "Implemented the tool." },
              { "text": "Tests pass." },
            ],
          },
        },
      },
      fallback_id="fallback",
    )
    is Some(request_event) else {
    fail("request-completed event was not projected")
  }
  assert_eq(
    moonclaw_json_string(request_event, "detail", default=""),
    "Implemented the tool.\nTests pass.",
  )
}

///|
test "mooncode owns moonclaw projected event fallback ids" {
  let event : Json = {
    "created": "2026-06-16T00:00:00Z",
    "desc": { "msg": "UserMessage", "content": "Create a MoonBook tool" },
  }
  guard moonclaw_projected_event_record(
      event,
      fallback_created_at="2026-06-16T00:00:01Z",
    )
    is Some(projected) else {
    fail("moonclaw event was not projected")
  }
  assert_true(
    json_string(projected, "id", default="").has_prefix("mooncode-event-"),
  )
  assert_eq(json_string(projected, "lane", default=""), "transcript")
  assert_eq(json_string(projected, "kind", default=""), "user")
  guard moonclaw_projected_event_record(
      { "event": "assistant_message", "content": "done" },
      fallback_created_at="2026-06-16T00:00:02Z",
    )
    is Some(runtime_projected) else {
    fail("runtime event without moonclaw desc was not projected")
  }
  assert_eq(
    json_string(runtime_projected, "created_at", default=""),
    "2026-06-16T00:00:02Z",
  )
  assert_eq(json_string(runtime_projected, "lane", default=""), "transcript")
}

///|
test "mooncode moonclaw adapter shapes legacy tool lane events" {
  guard moonclaw_tool_event_record(
      {
        "id": "evt-diff",
        "created": "2026-06-16T00:00:00Z",
        "desc": {
          "msg": "PostToolCall",
          "name": "write_to_file",
          "result": {
            "path": "tools/demo/main.mbt",
            "diff": "\n+fn main { println(\"ok\") }",
          },
          "text": "updated tools/demo/main.mbt",
        },
      },
      fallback_id="fallback",
    )
    is Some(diff_event) else {
    fail("diff tool event was not projected")
  }
  assert_eq(json_string(diff_event, "lane", default=""), "diff")
  assert_eq(json_string(diff_event, "path", default=""), "tools/demo/main.mbt")
  assert_eq(
    json_string(diff_event, "title", default=""),
    "File changed: tools/demo/main.mbt",
  )
  guard moonclaw_tool_event_record(
      {
        "id": "evt-test",
        "desc": {
          "msg": "PostToolCall",
          "name": "execute_command",
          "tool_call": {
            "function": { "arguments": "{\"command\":\"moon test\"}" },
          },
          "result": { "status": 0, "stdout": "ok", "stderr": "" },
        },
      },
      fallback_id="fallback",
    )
    is Some(test_event) else {
    fail("test tool event was not projected")
  }
  assert_eq(json_string(test_event, "lane", default=""), "test")
  assert_eq(json_string(test_event, "command", default=""), "moon test")
  assert_eq(event_json_int(test_event, "exit_code", default=-1), 0)
}

///|
test "mooncode moonclaw adapter readiness distinguishes bridge from native" {
  let bridged = moonclaw_adapter_readiness(true, false, true, true)
  assert_eq(
    moonclaw_json_string(bridged, "status", default=""),
    "compatibility-bridge",
  )
  let native = moonclaw_adapter_readiness(true, true, true, true)
  assert_eq(moonclaw_json_string(native, "status", default=""), "native-ready")
}
