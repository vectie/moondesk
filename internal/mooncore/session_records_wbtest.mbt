///|
test "session defaults preserve explicit fields and fill response surface" {
  let session : Json = {
    "id": "s1",
    "workspace_root": "/tmp/book",
    "title": "Existing",
    "transcript": [],
  }
  let next = session_response_defaults(session, default_title="Default")
  assert_eq(json_string(next, "cwd", default=""), "/tmp/book")
  assert_eq(json_string(next, "title", default=""), "Existing")
  assert_eq(json_string(next, "model", default="missing"), "")
  assert_eq(json_string(next, "last_message", default="missing"), "")
  assert_eq(json_array_items(next, "transcript").length(), 0)
}

///|
test "append transcript message records stable metadata" {
  let session : Json = { "id": "s1", "transcript": [] }
  let next = append_transcript_message(
    session,
    id_prefix="msg",
    role="assistant",
    content="  hello  ",
    status="done",
    created_at="2026-06-18T00:00:00Z",
  )
  let transcript = json_array_items(next, "transcript")
  assert_eq(transcript.length(), 1)
  assert_eq(json_string(transcript[0], "role", default=""), "assistant")
  assert_eq(json_string(transcript[0], "content", default=""), "hello")
  assert_eq(json_string(next, "updated_at", default=""), "2026-06-18T00:00:00Z")
}

///|
test "json field helpers coerce stable primitives" {
  let payload : Json = {
    "names": ["a", "b"],
    "count": "42",
    "enabled": true,
    "title": "Primary",
  }
  assert_eq(json_array_items(payload, "names").length(), 2)
  assert_eq(json_int(payload, "count", default=0), 42)
  assert_eq(json_bool(payload, "enabled", default=false), true)
  assert_true(json_string_opt(payload, "title") == Some("Primary"))
  assert_eq(
    json_first_string(payload, ["missing", "title"], default=""),
    "Primary",
  )
}
