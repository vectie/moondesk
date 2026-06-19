///|
test "mooncode session record starts with typed coding protocol" {
  let runtime : Json = {
    "id": "runtime-demo",
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
    runtime~,
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
  assert_eq(
    json_string(session, "mooncode_runtime_session_id", default=""),
    "mooncode-demo",
  )
  assert_eq(session_runtime_session_id(session), "mooncode-demo")
  assert_eq(summary_json_int(session, "queued_count", default=0), 1)
  assert_eq(json_array_items(session, "transcript").length(), 0)
}

///|
test "mooncode projected session record owns stable session id policy" {
  let runtime : Json = {
    "id": "runtime-demo",
    "status": "created",
    "model": "default",
  }
  let first = projected_session_record(
    workspace_id="book-demo",
    workspace_name="Demo Book",
    workspace_root="/tmp/demo-book",
    runtime~,
    title="MoonCode - Demo Book",
    created_at="2026-06-17T00:00:00Z",
    updated_at="2026-06-17T00:00:00Z",
    last_message="Build a demo tool",
    initial_context_path="tools/demo/main.mbt",
    transcript=[],
  )
  let second = projected_session_record(
    workspace_id="book-demo",
    workspace_name="Demo Book",
    workspace_root="/tmp/demo-book",
    runtime~,
    title="MoonCode - Demo Book",
    created_at="2026-06-17T00:00:00Z",
    updated_at="2026-06-17T00:00:00Z",
    last_message="Build a demo tool",
    initial_context_path="tools/demo/main.mbt",
    transcript=[],
  )
  let first_id = json_string(first, "id", default="")
  assert_eq(first_id, json_string(second, "id", default=""))
  assert_eq(
    first_id,
    projected_session_id(
      "book-demo", "MoonCode - Demo Book", "2026-06-17T00:00:00Z",
    ),
  )
  assert_true(first_id.has_prefix("mooncode-"))
  assert_eq(json_string(first, "component", default=""), "mooncode")
  assert_eq(json_string(first, "protocol", default=""), "mooncode.v1")
  assert_eq(
    json_string(first, "mooncode_runtime_session_id", default=""),
    first_id,
  )
  assert_eq(session_runtime_session_id(first), first_id)
}

///|
test "mooncode owns native runtime session stub shape" {
  let session = native_runtime_session_stub("/tmp/book-root", "native-session")
  assert_eq(json_string(session, "id", default=""), "native-session")
  assert_eq(json_string(session, "workspace_id", default=""), "native-session")
  assert_eq(
    json_string(session, "workspace_root", default=""),
    "/tmp/book-root",
  )
  assert_eq(session_runtime_session_id(session), "native-session")
  assert_eq(
    json_string(session, "mooncode_runtime_session_id", default=""),
    "native-session",
  )
  assert_eq(
    json_string(session, "mooncode_runtime_mode", default=""),
    "moonclaw-native",
  )
  assert_eq(
    json_string(session, "source", default=""),
    "moonclaw-native-session",
  )
}

///|
test "mooncode owns session response defaults and transcript messages" {
  let session : Json = {
    "id": "session-defaults",
    "component": "mooncode",
    "workspace_root": "/tmp/book-root",
  }
  let with_defaults = session_response_defaults(session)
  assert_eq(json_string(with_defaults, "title", default=""), "MoonCode Session")
  assert_eq(json_string(with_defaults, "cwd", default=""), "/tmp/book-root")
  assert_eq(json_array_items(with_defaults, "transcript").length(), 0)

  let with_field = session_with_field(
    with_defaults,
    "mooncode_runtime_mode",
    "native".to_json(),
  )
  assert_eq(
    json_string(with_field, "mooncode_runtime_mode", default=""),
    "native",
  )

  let with_message = append_transcript_message(
    with_field,
    role="assistant",
    content="ready",
    status="completed",
    created_at="2026-06-19T00:00:00Z",
  )
  let transcript = json_array_items(with_message, "transcript")
  assert_eq(transcript.length(), 1)
  let first = transcript[0]
  assert_eq(json_string(first, "role", default=""), "assistant")
  assert_eq(json_string(first, "content", default=""), "ready")
  assert_eq(json_string(first, "status", default=""), "completed")
  assert_true(json_string(first, "id", default="").has_prefix("mooncode-msg-"))
}
