///|
test "mooncode serve wire decodes openseek commands" {
  guard decode_serve_command({ "command": "prompt", "text": "hi" })
    is Ok(prompt) else {
    fail("prompt did not decode")
  }
  guard prompt is { "command": "prompt", "text": "hi", .. } else {
    fail("prompt decoded to unexpected payload")
  }
  guard decode_serve_command({ "command": "steer", "text": "left" })
    is Ok(steer) else {
    fail("steer did not decode")
  }
  guard steer is { "command": "steer", "text": "left", .. } else {
    fail("steer decoded to unexpected payload")
  }
  guard decode_serve_command({ "command": "cancel" }) is Ok(cancel) else {
    fail("cancel did not decode")
  }
  guard cancel is { "command": "cancel", .. } else {
    fail("cancel decoded to unexpected payload")
  }
  assert_true(serve_wire_valid({ "command": "prompt", "text": "hi" }))
}

///|
test "mooncode serve wire rejects invalid commands with actionable errors" {
  guard decode_serve_command({ "command": "prompt" }) is Err(missing_text) else {
    fail("textless prompt accepted")
  }
  assert_true(missing_text.contains("text"))
  guard decode_serve_command({ "command": "reboot" }) is Err(unknown) else {
    fail("unknown command accepted")
  }
  assert_true(unknown.contains("unknown command: reboot"))
  guard decode_serve_command("nonsense") is Err(not_object) else {
    fail("non-object accepted")
  }
  assert_true(not_object.contains("command"))
  assert_false(serve_wire_valid({ "command": "steer" }))
}

///|
test "mooncode tool call wire decodes native openseek function calls" {
  guard decode_tool_call({
      "id": "call-read",
      "type": "function",
      "function": {
        "name": "read",
        "arguments": "{\"path\":\"tools/demo/main.mbt\"}",
      },
    })
    is Ok(call) else {
    fail("native tool call did not decode")
  }
  assert_eq(serve_json_string(call, "tool_call_id", default=""), "call-read")
  assert_eq(serve_json_string(call, "tool_name", default=""), "read")
  assert_eq(
    serve_json_string(
      serve_json_object_field_or_empty(call, "parsed_arguments"),
      "path",
      default="",
    ),
    "tools/demo/main.mbt",
  )
  assert_false(serve_json_bool(call, "mutates_files", default=true))
  assert_true(
    tool_call_wire_valid({
      "id": "call-shell",
      "function": {
        "name": "shell",
        "arguments": "{\"cmd\":[\"moon\",\"test\"]}",
      },
    }),
  )
}

///|
test "mooncode tool call wire decodes runtime event wrappers" {
  guard decode_tool_call({
      "event": "tool_started",
      "tool_call": {
        "id": "call-write",
        "function": {
          "name": "write",
          "arguments": {
            "path": "tools/demo/main.mbt",
            "content": "fn main { println(1) }",
          },
        },
      },
    })
    is Ok(call) else {
    fail("wrapped tool call did not decode")
  }
  assert_eq(serve_json_string(call, "tool_call_id", default=""), "call-write")
  assert_eq(serve_json_string(call, "tool_name", default=""), "write")
  assert_true(serve_json_string(call, "arguments", default="").contains("path"))
  assert_true(serve_json_bool(call, "mutates_files", default=false))
  assert_true(serve_json_bool(call, "requires_review", default=false))
}

///|
test "mooncode tool call wire rejects unknown or malformed tools" {
  guard decode_tool_call({
      "id": "call-bad",
      "function": { "name": "delete_world", "arguments": "{}" },
    })
    is Err(unknown) else {
    fail("unknown tool accepted")
  }
  assert_true(unknown.contains("unknown tool: delete_world"))
  guard decode_tool_call({ "id": "call-empty" }) is Err(malformed) else {
    fail("tool call without name accepted")
  }
  assert_true(malformed.contains("tool_name"))
  assert_false(
    tool_call_wire_valid({
      "function": { "name": "delete_world", "arguments": "{}" },
    }),
  )
  let report = tool_call_decode_report({
    "tool_name": "moon_check",
    "arguments": { "target": "internal/mooncode" },
  })
  assert_true(serve_json_bool(report, "ok", default=false))
  assert_eq(serve_json_string(report, "tool_name", default=""), "moon_check")
}

///|
fn serve_json_bool(json : Json, key : String, default~ : Bool) -> Bool {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(value) => @json.from_json(value) catch { _ => default }
        _ => default
      }
    _ => default
  }
}
