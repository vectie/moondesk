///|
pub fn session_record(
  session_id~ : String,
  workspace_id~ : String,
  workspace_name~ : String,
  workspace_root~ : String,
  task~ : Json,
  title~ : String,
  created_at~ : String,
  updated_at~ : String,
  last_message~ : String,
  initial_context_path~ : String,
  transcript~ : Array[Json],
) -> Json {
  {
    "id": session_id,
    "workspace_id": workspace_id,
    "workspace_name": workspace_name,
    "workspace_root": workspace_root,
    "cwd": workspace_root,
    "moonclaw_task_id": json_string(task, "id", default=""),
    "title": title,
    "model": json_string(task, "model", default=""),
    "status": json_string(task, "status", default="created"),
    "port": summary_json_int(task, "port", default=0),
    "web_search": json_bool(task, "web_search", default=false),
    "queued_count": json_array_items(task, "queued_messages").length(),
    "created_at": created_at,
    "updated_at": updated_at,
    "last_message": last_message,
    "transcript": Json::array(transcript),
    "component": "mooncode",
    "protocol": "mooncode.v1",
    "mooncode_session_kind": "coding",
    "mooncode_initial_context_path": initial_context_path,
  }
}

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
