///|
test "mooncode session record starts with typed coding protocol" {
  let task : Json = {
    "id": "task-demo",
    "status": "created",
    "model": "default",
    "web_search": true,
    "queued_messages": [{ "id": "queued-1" }],
  }
  let session = session_record(
    session_id="mooncode-demo",
    workspace_id="book-demo",
    workspace_name="Demo Book",
    workspace_root="/tmp/demo-book",
    task~,
    title="MoonCode - Demo Book",
    created_at="2026-06-15T00:00:00Z",
    updated_at="2026-06-15T00:00:00Z",
    last_message="Build a demo tool",
    initial_context_path="tools/demo/main.mbt",
    transcript=[],
  )
  assert_eq(json_string(session, "id", default=""), "mooncode-demo")
  assert_eq(json_string(session, "component", default=""), "mooncode")
  assert_eq(json_string(session, "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(session, "mooncode_session_kind", default=""), "coding")
  assert_eq(
    json_string(session, "mooncode_initial_context_path", default=""),
    "tools/demo/main.mbt",
  )
  assert_eq(json_string(session, "workspace_id", default=""), "book-demo")
  assert_eq(json_string(session, "moonclaw_task_id", default=""), "task-demo")
  assert_eq(summary_json_int(session, "queued_count", default=0), 1)
  assert_eq(json_array_items(session, "transcript").length(), 0)
}
