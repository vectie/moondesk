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
test "session listing codec rejects malformed rows IDs and statuses" {
  assert_true(
    @core.decode_mooncode_session_listing({ "protocol": "mooncode.v1" })
    is Malformed(_),
  )
  let invalid_id : Json = {
    "protocol": "mooncode.v1",
    "sessions": [{ "id": "../bad", "status": "idle" }],
  }
  assert_true(@core.decode_mooncode_session_listing(invalid_id) is Malformed(_))
  let invalid_status : Json = {
    "protocol": "mooncode.v1",
    "sessions": [{ "id": "session-one", "status": "future-status" }],
  }
  assert_true(
    @core.decode_mooncode_session_listing(invalid_status) is Malformed(_),
  )
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
