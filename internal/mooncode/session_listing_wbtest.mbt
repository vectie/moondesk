///|
test "mooncode session listing row follows machine session picker shape" {
  let session : Json = {
    "id": "s1",
    "workspace_id": "book-a",
    "workspace_name": "Book A",
    "cwd": "/tmp/book-a",
    "title": "Fallback title",
    "updated_at": "2026-06-16T10:00:00Z",
    "status": "running",
    "model": "deepseek-v4-pro",
    "last_message": "fallback message",
    "transcript": [
      { "role": "assistant", "content": "hello" },
      { "role": "user", "content": "  build a miniapp\nwith tests" },
    ],
  }
  let row = session_listing_row(session, Json::number(1781580000000.0))
  assert_eq(json_string(row, "id", default=""), "s1")
  assert_eq(json_string(row, "title", default=""), "build a miniapp")
  assert_eq(json_string(row, "workspace_root", default=""), "/tmp/book-a")
  assert_eq(json_string(row, "status", default=""), "running")
  assert_eq(json_string(row, "protocol", default=""), "mooncode.v1")
  assert_true(row.stringify().contains("\"updated_at_ms\":1781580000000"))
  assert_true(
    json_string(row, "stream_url", default="").contains(
      "/api/mooncode/sessions/s1/stream",
    ),
  )
}

///|
test "mooncode session listing title falls back without user transcript" {
  let session : Json = {
    "id": "s2",
    "title": "Fallback title",
    "last_message": "  last message\twith spaces\nextra",
    "transcript": [],
  }
  assert_eq(session_listing_title(session), "last message with spaces")
  let title_only : Json = {
    "id": "s3",
    "title": "Title only",
    "last_message": "",
    "transcript": [],
  }
  assert_eq(session_listing_title(title_only), "Title only")
}
