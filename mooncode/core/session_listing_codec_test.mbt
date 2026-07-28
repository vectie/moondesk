///|
fn listing_fixture() -> Json {
  {
    "protocol": "mooncode.v1",
    "sessions": [
      {
        "id": "session-one",
        "workspace_id": "book-one",
        "workspace_name": "Book One",
        "cwd": "/tmp/book-one",
        "source": "mooncode-runtime-session-listing",
        "mooncode_runtime_session_id": "session-one",
        "title": "Fix parser",
        "updated_at": "2026-07-28T00:00:00Z",
        "model": "codex/gpt-5.4",
        "status": "running",
        "queued_count": 1,
        "last_message": "Run tests",
        "archived": false,
        "mooncode_summary": { "event_count": 9 },
      },
    ],
  }
}

///|
test "session listing codec accepts the authoritative envelope" {
  guard @core.decode_mooncode_session_listing(listing_fixture())
    is Supported([summary]) else {
    fail("expected supported listing")
  }
  assert_eq(summary.id.to_string(), "session-one")
  assert_true(summary.status is Running)
  assert_eq(summary.title, "Fix parser")
}

///|
test "session IDs preserve opaque protocol values exactly" {
  let raw_id = "session/resume:1\\branch"
  guard @core.MoonCodeSessionId::parse(raw_id) is Some(id) else {
    fail("expected opaque session ID to be accepted")
  }
  assert_eq(id.to_string(), raw_id)
  assert_true(@core.MoonCodeSessionId::parse("") is None)
  assert_true(@core.MoonCodeSessionId::parse(" \t\n") is None)
}

///|
test "session listing codec rejects malformed rows and statuses" {
  assert_true(
    @core.decode_mooncode_session_listing({ "protocol": "mooncode.v1" })
    is Malformed(_),
  )
  let invalid_status : Json = {
    "protocol": "mooncode.v1",
    "sessions": [{ "id": "session-one", "status": "future-status" }],
  }
  assert_true(
    @core.decode_mooncode_session_listing(invalid_status) is Malformed(_),
  )
}

///|
test "session listing codec distinguishes absent and malformed known fields" {
  assert_true(
    @core.decode_mooncode_session_listing({ "protocol": 1, "sessions": [] })
    is Malformed(_),
  )
  assert_true(
    @core.decode_mooncode_session_listing({ "sessions": [] }) is Supported([]),
  )
  assert_true(
    @core.decode_mooncode_session_listing([
      { "id": "session-one", "status": "idle", "updated_at": 1 },
    ])
    is Malformed(_),
  )
  guard @core.decode_mooncode_session_listing([
      { "id": "session-one", "status": "idle" },
    ])
    is Supported([summary]) else {
    fail("expected absent optional fields to retain defaults")
  }
  assert_true(summary.updated_at is None)
  assert_eq(summary.title, "session-one")
}

///|
test "session listing codec preserves unknown optional fields" {
  guard @core.decode_mooncode_session_listing(listing_fixture())
    is Supported([summary]) else {
    fail("expected supported listing")
  }
  guard @core.encode_mooncode_session_summary(summary)
    is { "mooncode_summary": { "event_count": 9 }, .. } else {
    fail("unknown optional fields were not preserved")
  }
}

///|
test "session listing codec reports unsupported explicit versions" {
  assert_true(
    @core.decode_mooncode_session_listing({
      "protocol": "mooncode.v7",
      "sessions": [],
    })
    is UnsupportedVersion(7),
  )
}

///|
test "session listing codec tolerates the legacy archived array envelope" {
  assert_true(
    @core.decode_mooncode_session_listing([
      { "id": "archived-one", "status": "done", "archived": true },
    ])
    is Supported([summary]) &&
    summary.archived,
  )
}
