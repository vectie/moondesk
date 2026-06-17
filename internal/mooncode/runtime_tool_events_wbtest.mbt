///|
// White-box tests for MoonCode native runtime tool-event normalization.

///|
test "mooncode normalizes nested tool results for approval correlation" {
  guard normalize_runtime_event(
      {
        "event": event_tool_result(),
        "tool_call": {
          "id": "call-write-result",
          "function": {
            "name": "write",
            "arguments": "{\"path\":\"tools/demo/main.mbt\",\"content\":\"fn main { println(1) }\"}",
          },
        },
        "command_id": "cmd-prompt-1",
        "content": "wrote tools/demo/main.mbt",
        "diff": "--- /dev/null\n+++ b/tools/demo/main.mbt\n@@\n+fn main { println(1) }\n",
      },
      fallback_id="runtime-write-result",
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(result) else {
    fail("nested tool_result was not normalized")
  }
  assert_eq(json_string(result, "lane", default=""), "diff")
  assert_eq(json_string(result, "kind", default=""), "write")
  assert_eq(json_string(result, "path", default=""), "tools/demo/main.mbt")
  assert_true(
    json_string(result, "diff", default="").contains(
      "+++ b/tools/demo/main.mbt",
    ),
  )
  assert_eq(
    json_string(result, "tool_call_id", default=""),
    "call-write-result",
  )
  let packet = runtime_json_object_field_or_empty(result, "command_packet")
  assert_eq(json_string(packet, "command_id", default=""), "cmd-prompt-1")
  assert_eq(json_string(packet, "action", default=""), "prompt")
}

///|
test "mooncode normalizes mutating native tool calls into diff review" {
  guard normalize_runtime_event(
      {
        "event": event_tool_started(),
        "tool_call": {
          "id": "call-write",
          "function": {
            "name": "write",
            "arguments": "{\"path\":\"tools/demo/main.mbt\",\"content\":\"fn main { println(1) }\"}",
          },
        },
      },
      fallback_id="runtime-6",
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(tool_call_event) else {
    fail("tool_started was not normalized")
  }
  assert_eq(json_string(tool_call_event, "lane", default=""), "diff")
  assert_eq(json_string(tool_call_event, "kind", default=""), "write")
  assert_eq(
    json_string(tool_call_event, "path", default=""),
    "tools/demo/main.mbt",
  )
  assert_eq(
    json_string(tool_call_event, "tool_call_id", default=""),
    "call-write",
  )
}

///|
test "mooncode rejects unknown runtime tool calls during normalization" {
  guard normalize_runtime_event(
      {
        "event": event_tool_call(),
        "tool_call_id": "call-danger",
        "tool_name": "delete_everything",
        "arguments": "{\"path\":\"tools/demo/main.mbt\"}",
        "command_id": "cmd-danger",
      },
      fallback_id="runtime-danger",
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(rejected) else {
    fail("unknown tool call was not converted to a decode error")
  }
  assert_eq(json_string(rejected, "lane", default=""), "tool")
  assert_eq(json_string(rejected, "kind", default=""), "tool_call_decode_error")
  assert_eq(json_string(rejected, "status", default=""), "failed")
  assert_eq(json_string(rejected, "tool_call_id", default=""), "call-danger")
  assert_eq(json_string(rejected, "tool_name", default=""), "delete_everything")
  assert_true(
    json_string(rejected, "detail", default="").contains(
      "unknown tool: delete_everything",
    ),
  )
  let report = runtime_json_object_field_or_empty(rejected, "decode_report")
  assert_eq(json_bool(report, "ok", default=true), false)
  assert_true(
    json_string(report, "error", default="").contains(
      "unknown tool: delete_everything",
    ),
  )
  let packet = runtime_json_object_field_or_empty(rejected, "command_packet")
  assert_eq(json_string(packet, "command_id", default=""), "cmd-danger")
  assert_eq(json_string(packet, "action", default=""), "prompt")
  assert_eq(json_string(rejected, "source_event", default=""), "tool_call")
}
