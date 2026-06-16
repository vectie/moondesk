///|
test "mooncode new session record starts with typed coding protocol" {
  let workspace = @desk.workspace(
    id="book-demo",
    name="Demo Book",
    root_path="/tmp/demo-book",
    kind=@desk.WorkspaceKind::MoonBook,
  )
  let task : Json = {
    "id": "task-demo",
    "status": "created",
    "model": "default",
    "web_search": true,
  }
  let payload : Json = {
    "context_path": "tools/demo/main.mbt",
    "web_search": true,
  }
  let session = mooncode_new_session_record(
    workspace, task, "MoonCode - Demo Book", "2026-06-15T00:00:00Z", "Build a demo tool",
    payload,
  )
  assert_true(json_string(session, "id", default="").has_prefix("mooncode-"))
  assert_eq(json_string(session, "component", default=""), "mooncode")
  assert_eq(json_string(session, "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(session, "mooncode_session_kind", default=""), "coding")
  assert_eq(
    json_string(session, "mooncode_initial_context_path", default=""),
    "tools/demo/main.mbt",
  )
  assert_eq(json_string(session, "workspace_id", default=""), "book-demo")
  assert_eq(json_string(session, "moonclaw_task_id", default=""), "task-demo")
  assert_eq(json_array_items(session, "transcript").length(), 0)
}

///|
test "mooncode prompt command packet seeds durable session creation" {
  let session : Json = {
    "id": "mooncode-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "workspace_root": "/tmp/demo-book",
    "moonclaw_task_id": "task-demo",
  }
  let payload : Json = {
    "context_path": "tools/demo/main.mbt",
    "web_search": false,
  }
  let packet = mooncode_command_packet(
    session, payload, "prompt", "Build a demo tool", "2026-06-15T00:00:00Z", "tools/demo/main.mbt",
  )
  assert_eq(json_string(packet, "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(packet, "action", default=""), "prompt")
  assert_eq(json_string(packet, "dispatch", default=""), "prompt")
  assert_eq(json_string(packet, "approval", default=""), "user")
  assert_eq(
    json_string(packet, "context_path", default=""),
    "tools/demo/main.mbt",
  )
  assert_true(
    json_string_array_items(packet, "expected_lanes").contains("diff"),
  )
  assert_true(json_string_array_items(packet, "tool_hints").contains("write"))
  let queued = append_mooncode_command_event(
    session,
    action="prompt",
    status="queued",
    detail="Build a demo tool",
    created_at="2026-06-15T00:00:00Z",
    path="tools/demo/main.mbt",
    command_packet=packet,
  )
  let events = project_mooncode_events(queued, [], [])
  let summary = @mooncode.session_summary(queued, events)
  assert_eq(json_int(summary, "command_packet_count", default=0), 1)
  assert_eq(json_int(summary, "event_count", default=0), 1)
  assert_eq(json_string(events[0], "lane", default=""), "runtime")
}

///|
test "mooncode summary and eval report use extracted protocol" {
  let event = @mooncode.event_record(
    id="d1",
    lane="diff",
    kind="tool.write",
    title="Write file",
    status="done",
    created_at="1",
    detail="updated file",
    path="tools/demo/main.mbt",
    diff="+fn main { println(\"ok\") }",
  )
  let session : Json = {
    "id": "s1",
    "workspace_id": "book-demo",
    "moonclaw_task_id": "task-demo",
    "mooncode_append_log_count": 1,
    "mooncode_command_log_count": 1,
    "mooncode_runtime_command_log_count": 1,
  }
  let extracted_summary = @mooncode.session_summary(session, [event])
  assert_eq(json_int(extracted_summary, "diff_count", default=0), 1)
  assert_eq(
    json_string(extracted_summary, "review_state", default=""),
    "pending",
  )
  let with_summary = agent_session_with_field(
    session, "mooncode_summary", extracted_summary,
  )
  let extracted_report = @mooncode.eval_report_projection(with_summary)
  assert_eq(
    json_string(extracted_report, "kind", default=""),
    "mooncode-eval-report",
  )
  assert_eq(
    json_string(extracted_report, "extractable_component", default=""),
    "mooncode",
  )
}
