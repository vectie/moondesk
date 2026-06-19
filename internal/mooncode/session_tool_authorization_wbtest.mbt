///|
test "mooncode tool authorization response follows extracted approval state" {
  let preview = event_record(
      id="tool-call-build",
      lane="tool",
      kind="shell",
      title="Tool started: shell",
      status="running",
      created_at="2026-06-15T00:00:00Z",
      detail="{\"cmd\":[\"npm\",\"run\",\"build\"]}",
      command="npm run build",
    )
    |> runtime_with_field("tool_call_id", "call-build".to_json())
  let pending = tool_authorization_response("code-demo", preview, [preview], {
    "kind": "mooncode-tool-approvals",
  })
  assert_eq(json_string(pending, "decision", default=""), "requires_approval")
  assert_eq(json_string(pending, "approval", default=""), "policy")
  assert_eq(json_string(pending, "approval_state", default=""), "pending")
  assert_eq(json_string(pending, "command", default=""), "npm run build")
  let approved = tool_authorization_response(
    "code-demo",
    preview,
    [
      preview,
      event_record(
        id="approve-build",
        lane="review",
        kind="command.approve_tool",
        title="Approve tool",
        status="queued",
        created_at="2026-06-15T00:01:00Z",
        detail="approved",
        path="tool_call:call-build",
        command="approve_tool",
      ),
    ],
    { "kind": "mooncode-tool-approvals" },
  )
  assert_eq(json_string(approved, "decision", default=""), "allowed")
  assert_true(json_bool(approved, "allowed", default=false))
  let rejected = tool_authorization_response(
    "code-demo",
    preview,
    [
      preview,
      event_record(
        id="reject-build",
        lane="review",
        kind="command.reject_tool",
        title="Reject tool",
        status="queued",
        created_at="2026-06-15T00:02:00Z",
        detail="rejected",
        path="tool_call:call-build",
        command="reject_tool",
      ),
    ],
    { "kind": "mooncode-tool-approvals" },
  )
  assert_eq(json_string(rejected, "decision", default=""), "blocked")
  assert_true(json_bool(rejected, "blocked", default=false))
}

///|
test "mooncode tool approval entries expose tool call id" {
  let approvals = tool_approval_entries([
    {
      "id": "tool-call-build",
      "tool_call_id": "call-build",
      "command_packet": {
        "protocol": protocol_version(),
        "kind": kind_command_ref(),
        "command_id": "cmd-build",
        "action": "prompt",
      },
      "lane": "tool",
      "kind": "shell",
      "title": "Tool started: shell",
      "status": "running",
      "created_at": "2026-06-15T00:00:00Z",
      "detail": "{\"cmd\":[\"npm\",\"run\",\"build\"]}",
      "command": "npm run build",
    },
  ])
  assert_eq(approvals.length(), 1)
  assert_eq(json_string(approvals[0], "tool_call_id", default=""), "call-build")
  assert_eq(json_string(approvals[0], "command_id", default=""), "cmd-build")
  assert_eq(json_string(approvals[0], "command_action", default=""), "prompt")
  let packet = summary_json_object_field_or_empty(
    approvals[0],
    "command_packet",
  )
  assert_eq(json_string(packet, "command_id", default=""), "cmd-build")
  assert_eq(
    json_string(approvals[0], "target", default=""),
    "tool_call:call-build",
  )
  assert_eq(json_string(approvals[0], "target_kind", default=""), "tool_call")
  assert_eq(
    json_string(approvals[0], "target_label", default=""),
    "npm run build",
  )
}

///|
test "mooncode tool approvals isolate repeated commands by tool call id" {
  let first = {
    "id": "tool-call-build-1",
    "tool_call_id": "call-build-1",
    "lane": "tool",
    "kind": "shell",
    "title": "Tool started: shell",
    "status": "running",
    "created_at": "2026-06-15T00:00:00Z",
    "detail": "{\"cmd\":[\"npm\",\"run\",\"build\"]}",
    "command": "npm run build",
  }
  let second = {
    "id": "tool-call-build-2",
    "tool_call_id": "call-build-2",
    "lane": "tool",
    "kind": "shell",
    "title": "Tool started: shell",
    "status": "running",
    "created_at": "2026-06-15T00:00:01Z",
    "detail": "{\"cmd\":[\"npm\",\"run\",\"build\"]}",
    "command": "npm run build",
  }
  let approvals = tool_approval_entries([
    first,
    second,
    event_record(
      id="approve-first-build",
      lane="review",
      kind="command.approve_tool",
      title="Approve tool",
      status="queued",
      created_at="2026-06-15T00:01:00Z",
      detail="approved first call only",
      path="tool_call:call-build-1",
      command="approve_tool",
    ),
  ])
  assert_eq(approvals.length(), 2)
  assert_eq(
    json_string(approvals[0], "target", default=""),
    "tool_call:call-build-1",
  )
  assert_eq(json_string(approvals[0], "approval_state", default=""), "approved")
  assert_eq(
    json_string(approvals[1], "target", default=""),
    "tool_call:call-build-2",
  )
  assert_eq(json_string(approvals[1], "approval_state", default=""), "pending")
}

///|
test "mooncode tool authorization allows auto-approved read previews" {
  let preview = event_record(
    id="tool-call-read",
    lane="tool",
    kind="read",
    title="Tool started: read",
    status="running",
    created_at="2026-06-15T00:00:00Z",
    detail="{\"path\":\"wiki/index.md\"}",
    path="wiki/index.md",
  )
  let response = tool_authorization_response("code-demo", preview, [preview], {
    "kind": "mooncode-tool-approvals",
  })
  assert_eq(json_string(response, "decision", default=""), "allowed")
  assert_eq(json_string(response, "approval", default=""), "auto")
  assert_true(json_bool(response, "allowed", default=false))
  assert_false(tool_authorization_has_target([preview], "wiki/index.md"))
}

///|
test "mooncode tool authorization records only new gated previews" {
  let shell_preview = tool_authorization_preview_projected_event(
    {
      "tool_call_id": "call-build",
      "tool_name": "shell",
      "arguments": "{\"cmd\":[\"npm\",\"run\",\"build\"]}",
    },
    "2026-06-17T00:00:00Z",
  )
  assert_true(tool_authorization_should_record(shell_preview, []))
  assert_false(tool_authorization_should_record(shell_preview, [shell_preview]))
}

///|
test "mooncode tool authorization skips auto-approved read previews" {
  let read_preview = tool_authorization_preview_projected_event(
    {
      "tool_call_id": "call-read",
      "tool_name": "read",
      "arguments": "{\"path\":\"wiki/index.md\"}",
    },
    "2026-06-17T00:00:00Z",
  )
  assert_false(tool_authorization_should_record(read_preview, []))
}
