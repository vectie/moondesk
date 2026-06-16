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
