///|
test "mooncode tool authorization preview normalizes shell payloads" {
  let preview = tool_authorization_preview_event(
    {
      "tool_call_id": "call-build",
      "tool_name": "shell",
      "arguments": "{\"cmd\":[\"npm\",\"run\",\"build\"],\"cwd\":\"apps/demo\"}",
    },
    "2026-06-15T00:00:00Z",
    fallback_id="preview-1",
  )
  assert_eq(json_string(preview, "id", default=""), "preview-1")
  assert_eq(
    json_string(preview, "created_at", default=""),
    "2026-06-15T00:00:00Z",
  )
  assert_eq(json_string(preview, "lane", default=""), "tool")
  assert_eq(json_string(preview, "kind", default=""), "shell")
  assert_eq(json_string(preview, "command", default=""), "npm run build")
  assert_eq(json_string(preview, "tool_call_id", default=""), "call-build")
}

///|
test "mooncode tool authorization preview preserves explicit read path" {
  let preview = tool_authorization_preview_event(
    {
      "id": "read-preview",
      "created_at": "2026-06-15T00:01:00Z",
      "tool_name": "read",
      "path": "wiki/index.md",
    },
    "2026-06-15T00:00:00Z",
    fallback_id="fallback-preview",
  )
  assert_eq(json_string(preview, "id", default=""), "read-preview")
  assert_eq(
    json_string(preview, "created_at", default=""),
    "2026-06-15T00:01:00Z",
  )
  assert_eq(json_string(preview, "lane", default=""), "tool")
  assert_eq(json_string(preview, "kind", default=""), "read")
  assert_eq(json_string(preview, "path", default=""), "wiki/index.md")
}

///|
test "mooncode projected tool authorization preview owns stable fallback ids" {
  let payload : Json = {
    "tool_call_id": "call-build",
    "tool_name": "shell",
    "arguments": "{\"cmd\":[\"npm\",\"run\",\"build\"],\"cwd\":\"apps/demo\"}",
  }
  let first = tool_authorization_preview_projected_event(
    payload, "2026-06-15T00:00:00Z",
  )
  let second = tool_authorization_preview_projected_event(
    payload, "2026-06-15T00:00:00Z",
  )
  assert_eq(
    json_string(first, "id", default=""),
    json_string(second, "id", default=""),
  )
  assert_eq(
    json_string(first, "created_at", default=""),
    "2026-06-15T00:00:00Z",
  )
  assert_eq(json_string(first, "lane", default=""), "tool")
  assert_eq(json_string(first, "kind", default=""), "shell")
  assert_eq(json_string(first, "command", default=""), "npm run build")
  let later = tool_authorization_preview_projected_event(
    payload, "2026-06-15T00:00:01Z",
  )
  assert_true(
    json_string(first, "id", default="") != json_string(later, "id", default=""),
  )
}

///|
test "mooncode projected tool authorization preview preserves explicit ids" {
  let preview = tool_authorization_preview_projected_event(
    {
      "id": "explicit-preview",
      "created_at": "2026-06-15T00:01:00Z",
      "tool_name": "write",
      "path": "tools/demo/main.mbt",
    },
    "2026-06-15T00:00:00Z",
  )
  assert_eq(json_string(preview, "id", default=""), "explicit-preview")
  assert_eq(
    json_string(preview, "created_at", default=""),
    "2026-06-15T00:01:00Z",
  )
  assert_eq(json_string(preview, "lane", default=""), "diff")
  assert_eq(json_string(preview, "path", default=""), "tools/demo/main.mbt")
}

///|
test "mooncode canonical event record clamps lanes and titles" {
  let event = canonical_event_record(
    {
      "id": "event-1",
      "lane": "unknown",
      "kind": "",
      "status": "",
      "content": "hello",
    },
    fallback_id="fallback-1",
    fallback_created_at="2026-06-15T00:00:00Z",
  )
  assert_eq(json_string(event, "id", default=""), "event-1")
  assert_eq(json_string(event, "lane", default=""), "runtime")
  assert_eq(json_string(event, "kind", default=""), "runtime_update")
  assert_eq(json_string(event, "status", default=""), "done")
  assert_eq(json_string(event, "detail", default=""), "hello")
}

///|
test "mooncode canonical event record recovers native command packet" {
  let event = canonical_event_record(
    {
      "id": "native-proof",
      "protocol": protocol_version(),
      "session_id": "session-native",
      "command_id": "cmd-native",
      "lane": "tool",
      "kind": "runtime.tool_result",
      "title": "Native tool finished",
      "status": "done",
      "raw_event": {
        "command_packet": { "command_id": "cmd-native", "action": "prompt" },
      },
    },
    fallback_id="fallback-native",
    fallback_created_at="2026-06-17T00:00:00Z",
  )
  let packet = runtime_json_object_field_or_empty(event, "command_packet")
  assert_eq(json_string(packet, "command_id", default=""), "cmd-native")
  assert_eq(json_string(packet, "action", default=""), "prompt")
}
