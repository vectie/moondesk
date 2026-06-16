///|
test "mooncode runtime event ingest normalizes batches" {
  let events = @mooncode.runtime_ingest_events(
    {
      "events": [
        {
          "id": "tool-call-1",
          "event": "tool_call",
          "created_at": "0",
          "tool_name": "shell",
          "arguments": "{\"cmd\":[\"moon\",\"test\",\"tools/demo\"]}",
        },
        {
          "id": "assistant-1",
          "event": "assistant_message",
          "created_at": "1",
          "content": "done",
        },
        {
          "id": "test-1",
          "event": "test_result",
          "created_at": "2",
          "status": "done",
          "command": "moon test",
          "exit_code": 0,
          "detail": "Total tests: 1, passed: 1",
        },
        {
          "id": "steer-1",
          "event": "steer_applied",
          "created_at": "3",
          "content": "focus tests",
        },
        {
          "id": "steer-2",
          "event": "steer_dropped",
          "created_at": "4",
          "content": "too late",
        },
        {
          "id": "canonical-1",
          "lane": "artifact",
          "kind": "artifact",
          "title": "Packaged tool",
          "status": "done",
          "created_at": "5",
          "path": "portable/app-tool/demo.zip",
        },
      ],
    },
    ingested_at="2026-06-15T00:00:00Z",
  )
  assert_eq(events.length(), 6)
  assert_eq(json_string(events[0], "lane", default=""), "test")
  assert_eq(json_string(events[0], "kind", default=""), "shell")
  assert_eq(
    json_string(events[0], "command", default=""),
    "moon test tools/demo",
  )
  assert_eq(json_string(events[1], "lane", default=""), "transcript")
  assert_eq(json_string(events[2], "lane", default=""), "test")
  assert_eq(json_string(events[2], "command", default=""), "moon test")
  assert_eq(json_string(events[3], "kind", default=""), "steer_applied")
  assert_eq(json_string(events[3], "status", default=""), "done")
  assert_eq(json_string(events[4], "kind", default=""), "steer_dropped")
  assert_eq(json_string(events[4], "status", default=""), "failed")
  assert_eq(json_string(events[5], "lane", default=""), "artifact")
}

///|
async test "mooncode durable native tool call creates pending approval manifest" {
  let root = "/tmp/moondesk-mooncode-tool-call-" +
    @desk.stable_id("tool-call-test", @async.now().to_string())
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let session : Json = {
    "id": "agent-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "workspace_root": root,
    "moonclaw_task_id": "task-demo",
    "mooncode_last_eval_report_manifest": {
      "manifest_path": "wiki/reviews/mooncode/agent-demo/stale-eval-report.json",
      "absolute_manifest_path": "/tmp/stale-book/wiki/reviews/mooncode/agent-demo/stale-eval-report.json",
    },
    "mooncode_summary": {
      "last_moonbook_eval_report_manifest": {
        "manifest_path": "wiki/reviews/mooncode/agent-demo/stale-eval-report.json",
      },
    },
  }
  for
    event in @mooncode.runtime_ingest_events(
      {
        "event": "tool_call",
        "id": "tool-call-shell",
        "created_at": "2026-06-14T00:00:00Z",
        "tool_name": "shell",
        "arguments": "{\"cmd\":[\"npm\",\"run\",\"build\"],\"cwd\":\"apps/demo\"}",
      },
      ingested_at="2026-06-15T00:00:00Z",
    ) {
    append_mooncode_event_log(root, "agent-demo", event)
  }
  let projected = attach_mooncode_session_projection(root, session)
  let with_tool_approvals = write_mooncode_tool_approvals_if_possible(projected)
  let manifest = json_object_field_or_empty(
    with_tool_approvals, "mooncode_last_tool_approvals_manifest",
  )
  assert_eq(
    json_string(manifest, "kind", default=""),
    "mooncode-tool-approvals",
  )
  assert_eq(json_int(manifest, "pending_approval_count", default=0), 1)
  let approvals = json_array_items(manifest, "approvals")
  assert_eq(json_string(approvals[0], "tool_id", default=""), "shell")
  assert_eq(json_string(approvals[0], "approval", default=""), "policy")
  assert_eq(json_string(approvals[0], "command", default=""), "npm run build")
  assert_true(
    @fs.exists(
      @pathx.join(
        root,
        @mooncode.tool_approvals_manifest_relative_path("agent-demo"),
      ),
    ),
  )
}

///|
test "mooncode tool authorization follows approval state" {
  let session : Json = { "id": "agent-demo" }
  let preview = mooncode_tool_authorization_preview_event(
    {
      "tool_call_id": "call-build",
      "tool_name": "shell",
      "arguments": "{\"cmd\":[\"npm\",\"run\",\"build\"]}",
    },
    "2026-06-14T00:00:00Z",
  )
  let pending = mooncode_tool_authorization_response(session, preview, [preview])
  assert_eq(json_string(pending, "decision", default=""), "requires_approval")
  assert_eq(json_string(pending, "approval", default=""), "policy")
  assert_eq(json_string(pending, "approval_state", default=""), "pending")
  assert_eq(json_string(pending, "command", default=""), "npm run build")
  let approve_session = append_mooncode_command_event(
    session,
    action="approve_tool",
    status="queued",
    detail="Approve build",
    created_at="2026-06-14T00:01:00Z",
    path="tool_call:call-build",
  )
  let approved_events = project_mooncode_events(approve_session, [], [preview])
  let approved = mooncode_tool_authorization_response(
    approve_session, preview, approved_events,
  )
  assert_eq(json_string(approved, "decision", default=""), "allowed")
  assert_true(json_bool(approved, "allowed", default=false))
  let reject_session = append_mooncode_command_event(
    session,
    action="reject_tool",
    status="queued",
    detail="Reject build",
    created_at="2026-06-14T00:02:00Z",
    path="tool_call:call-build",
  )
  let rejected_events = project_mooncode_events(reject_session, [], [preview])
  let rejected = mooncode_tool_authorization_response(
    reject_session, preview, rejected_events,
  )
  assert_eq(json_string(rejected, "decision", default=""), "blocked")
  assert_true(json_bool(rejected, "blocked", default=false))
}

///|
test "mooncode tool authorization allows read tools without approval" {
  let preview = mooncode_tool_authorization_preview_event(
    {
      "tool_call_id": "call-read",
      "tool_name": "read",
      "arguments": "{\"path\":\"wiki/index.md\"}",
    },
    "2026-06-14T00:00:00Z",
  )
  let response = mooncode_tool_authorization_response(
    { "id": "agent-demo" },
    preview,
    [preview],
  )
  assert_eq(json_string(response, "decision", default=""), "allowed")
  assert_eq(json_string(response, "approval", default=""), "auto")
  assert_true(json_bool(response, "allowed", default=false))
}
