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
    .contains("/v1/mooncode/sessions/<id>/runtime-events?book_root=<path>"),
  )
  assert_true(
    contract
    .stringify()
    .contains("/v1/mooncode/sessions/<id>/tool-exec?book_root=<path>"),
  )
  assert_true(
    contract.stringify().contains("read/edit/write/shell/moon_check/finish"),
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
    moonclaw_native_command_endpoint("session one"),
    "/v1/mooncode/sessions/session%20one/commands",
  )
  assert_eq(
    moonclaw_native_runtime_loop_endpoint("session one"),
    "/v1/mooncode/sessions/session%20one/runtime-loop",
  )
  assert_eq(
    moonclaw_native_runtime_turn_endpoint("session one"),
    "/v1/mooncode/sessions/session%20one/runtime-turn",
  )
  assert_eq(
    moonclaw_native_stream_endpoint("session one", "/tmp/moon book", "sse", 7),
    "/v1/mooncode/sessions/session%20one/stream?book_root=%2Ftmp%2Fmoon%20book&format=sse&since=7",
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
