///|
test "mooncode protocol command decodes mooncode commands" {
  guard decode_code_command({ "command": "prompt", "text": "hi" }) is Ok(prompt) else {
    fail("prompt did not decode")
  }
  guard prompt is { "command": "prompt", "text": "hi", .. } else {
    fail("prompt decoded to unexpected payload")
  }
  guard decode_code_command({ "command": "steer", "text": "left" }) is Ok(steer) else {
    fail("steer did not decode")
  }
  guard steer is { "command": "steer", "text": "left", .. } else {
    fail("steer decoded to unexpected payload")
  }
  guard decode_code_command({ "command": "cancel" }) is Ok(cancel) else {
    fail("cancel did not decode")
  }
  guard cancel is { "command": "cancel", .. } else {
    fail("cancel decoded to unexpected payload")
  }
  assert_true(protocol_command_valid({ "command": "prompt", "text": "hi" }))
}

///|
test "mooncode protocol commands reject invalid commands with actionable errors" {
  guard decode_code_command({ "command": "prompt" }) is Err(missing_text) else {
    fail("textless prompt accepted")
  }
  assert_true(missing_text.contains("text"))
  guard decode_code_command({ "command": "reboot" }) is Err(unknown) else {
    fail("unknown command accepted")
  }
  assert_true(unknown.contains("unknown command: reboot"))
  guard decode_code_command("nonsense") is Err(not_object) else {
    fail("non-object accepted")
  }
  assert_true(not_object.contains("command"))
  assert_false(protocol_command_valid({ "command": "steer" }))
}

///|
test "mooncode tool call protocol command decodes native mooncode function calls" {
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
  assert_eq(protocol_json_string(call, "tool_call_id", default=""), "call-read")
  assert_eq(protocol_json_string(call, "tool_name", default=""), "read")
  assert_eq(
    protocol_json_string(
      protocol_json_object_field_or_empty(call, "parsed_arguments"),
      "path",
      default="",
    ),
    "tools/demo/main.mbt",
  )
  assert_false(protocol_json_bool(call, "mutates_files", default=true))
  assert_true(
    tool_call_contract_valid({
      "id": "call-shell",
      "function": {
        "name": "shell",
        "arguments": "{\"cmd\":[\"moon\",\"test\"]}",
      },
    }),
  )
}

///|
test "mooncode tool call protocol command decodes runtime event wrappers" {
  guard decode_tool_call({
      "event": event_tool_started(),
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
  assert_eq(
    protocol_json_string(call, "tool_call_id", default=""),
    "call-write",
  )
  assert_eq(protocol_json_string(call, "tool_name", default=""), "write")
  assert_true(
    protocol_json_string(call, "arguments", default="").contains("path"),
  )
  assert_true(protocol_json_bool(call, "mutates_files", default=false))
  assert_true(protocol_json_bool(call, "requires_review", default=false))
}

///|
test "mooncode tool call contract rejects unknown or malformed tools" {
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
    tool_call_contract_valid({
      "function": { "name": "delete_world", "arguments": "{}" },
    }),
  )
  let report = tool_call_decode_report({
    "tool_name": "moon_check",
    "arguments": { "target": "internal/mooncode" },
  })
  assert_true(protocol_json_bool(report, "ok", default=false))
  assert_eq(protocol_json_string(report, "tool_name", default=""), "moon_check")
}

///|
test "mooncode tool call contract accepts moonbit specific coding tools" {
  guard decode_tool_call({
      "id": "call-ide",
      "function": {
        "name": "moon_ide",
        "arguments": "{\"action\":\"outline\",\"path\":\"internal/mooncode\"}",
      },
    })
    is Ok(ide) else {
    fail("moon_ide tool call did not decode")
  }
  assert_eq(protocol_json_string(ide, "tool_name", default=""), "moon_ide")
  assert_false(protocol_json_bool(ide, "mutates_files", default=true))
  assert_false(protocol_json_bool(ide, "requires_review", default=true))
  guard decode_tool_call({
      "id": "call-cmd",
      "function": {
        "name": "moon_cmd",
        "arguments": "{\"command\":\"test\",\"path\":\"internal/mooncode\"}",
      },
    })
    is Ok(cmd) else {
    fail("moon_cmd tool call did not decode")
  }
  assert_eq(protocol_json_string(cmd, "tool_name", default=""), "moon_cmd")
  assert_true(protocol_json_bool(cmd, "mutates_files", default=false))
  assert_true(protocol_json_bool(cmd, "requires_review", default=false))
}

///|
test "mooncode tool call contract accepts patch apply and revert tools" {
  guard decode_tool_call({
      "id": "call-apply",
      "function": {
        "name": "apply_patch",
        "arguments": "{\"patch\":\"diff --git a/tool.mbt b/tool.mbt\"}",
      },
    })
    is Ok(applied) else {
    fail("apply_patch tool call did not decode")
  }
  assert_eq(
    protocol_json_string(applied, "tool_name", default=""),
    "apply_patch",
  )
  assert_true(protocol_json_bool(applied, "mutates_files", default=false))
  assert_true(protocol_json_bool(applied, "requires_review", default=false))
  guard decode_tool_call({
      "id": "call-revert",
      "function": {
        "name": "revert_patch",
        "arguments": "{\"patch\":\"diff --git a/tool.mbt b/tool.mbt\"}",
      },
    })
    is Ok(reverted) else {
    fail("revert_patch tool call did not decode")
  }
  assert_eq(
    protocol_json_string(reverted, "tool_name", default=""),
    "revert_patch",
  )
  assert_true(protocol_json_bool(reverted, "mutates_files", default=false))
  assert_true(protocol_json_bool(reverted, "requires_review", default=false))
}

///|
test "mooncode tool call contract accepts package style tool aliases" {
  guard decode_tool_call({
      "id": "call-bash",
      "function": {
        "name": "Bash",
        "arguments": "{\"command\":\"npm run build\",\"description\":\"Build frontend bundle\"}",
      },
    })
    is Ok(bash) else {
    fail("Bash alias did not decode")
  }
  assert_eq(protocol_json_string(bash, "tool_name", default=""), "shell")
  assert_eq(protocol_json_string(bash, "raw_tool_name", default=""), "Bash")
  assert_true(protocol_json_bool(bash, "requires_review", default=false))
  guard decode_tool_call({
      "id": "call-read",
      "function": {
        "name": "FileRead",
        "arguments": "{\"file_path\":\"src/main.mbt\"}",
      },
    })
    is Ok(read) else {
    fail("FileRead alias did not decode")
  }
  assert_eq(protocol_json_string(read, "tool_name", default=""), "read")
  assert_false(protocol_json_bool(read, "mutates_files", default=true))
  guard decode_tool_call({
      "id": "call-edit",
      "function": {
        "name": "FileEdit",
        "arguments": "{\"file_path\":\"src/main.mbt\",\"old_string\":\"a\",\"new_string\":\"b\"}",
      },
    })
    is Ok(edit) else {
    fail("FileEdit alias did not decode")
  }
  assert_eq(protocol_json_string(edit, "tool_name", default=""), "edit")
  assert_true(protocol_json_bool(edit, "mutates_files", default=false))
  guard decode_tool_call({
      "id": "call-todo",
      "function": {
        "name": "TodoWrite",
        "arguments": "{\"todos\":[{\"content\":\"Patch projection\",\"status\":\"in_progress\",\"activeForm\":\"Patching projection\"}]}",
      },
    })
    is Ok(todo) else {
    fail("TodoWrite alias did not decode")
  }
  assert_eq(protocol_json_string(todo, "tool_name", default=""), "todo_write")
  assert_false(protocol_json_bool(todo, "requires_review", default=true))
  guard decode_tool_call({
      "id": "call-web",
      "function": {
        "name": "WebSearch",
        "arguments": "{\"query\":\"moonbit docs\"}",
      },
    })
    is Ok(web) else {
    fail("WebSearch alias did not decode")
  }
  assert_eq(protocol_json_string(web, "tool_name", default=""), "web_search")
  assert_false(protocol_json_bool(web, "requires_review", default=true))
}

///|
fn protocol_json_bool(json : Json, key : String, default~ : Bool) -> Bool {
  match json {
    Object(object) =>
      match object.get(key) {
        Some(value) => @json.from_json(value) catch { _ => default }
        _ => default
      }
    _ => default
  }
}
