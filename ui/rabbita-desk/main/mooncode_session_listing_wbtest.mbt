///|
test "MoonCode typed listing preserves row order and rail fields" {
  let payload : Json = [
    {
      "id": "newer",
      "workspace_id": "book-one",
      "workspace_name": "Book One",
      "cwd": "/tmp/book-one",
      "title": "Newer title",
      "model": "codex/gpt-5.4",
      "status": "running",
      "queued_count": 1,
      "archived": false,
      "mooncode_summary": {
        "event_count": 9,
        "verified_test_count": 2,
        "pending_diff_count": 1,
      },
    },
    {
      "id": "older",
      "workspace_id": "",
      "workspace_name": "General",
      "cwd": "",
      "title": "Older title",
      "model": "",
      "status": "durable",
      "queued_count": 0,
      "archived": false,
      "mooncode_summary": {
        "event_count": 1,
        "verified_test_count": 0,
        "pending_diff_count": 0,
      },
    },
  ]
  guard decode_mooncode_session_listing(payload) is Ok(sessions) else {
    fail("expected supported listing")
  }
  assert_eq(sessions.length(), 2)
  assert_eq(sessions[0].id, "newer")
  assert_eq(sessions[1].id, "older")
  assert_eq(sessions[0].title, "Newer title")
  assert_eq(sessions[0].mooncode_summary.event_count, 9)
}

///|
test "MoonCode typed archived listing tolerates array envelope" {
  guard decode_mooncode_session_listing([
      {
        "id": "archived-one",
        "workspace_id": "",
        "workspace_name": "General",
        "cwd": "",
        "title": "Archived title",
        "model": "",
        "status": "done",
        "queued_count": 0,
        "archived": true,
        "mooncode_summary": {
          "event_count": 0,
          "verified_test_count": 0,
          "pending_diff_count": 0,
        },
      },
    ])
    is Ok([session]) else {
    fail("expected archived listing")
  }
  assert_true(session.archived)
}
