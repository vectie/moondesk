///|
test "Code session lookup keeps the selected MoonBook root" {
  let book = @desk.workspace(
    id="book-a",
    name="Book A",
    root_path="/suite/books/a",
    kind=MoonBook,
  )
  let rows : Array[Json] = [
    { "id": "session-a", "book_root": "/suite/books/a" },
    { "id": "general", "book_root": "/suite" },
  ]
  assert_eq(
    moonclaw_runtime_session_book_root_from_rows("/suite", "session-a", rows, [
      book,
    ]),
    Ok("/suite/books/a"),
  )
  assert_eq(
    moonclaw_runtime_session_book_root_from_rows("/suite", "general", rows, [
      book,
    ]),
    Ok("/suite"),
  )
  assert_true(
    moonclaw_runtime_session_book_root_from_rows("/suite", "session-a", rows, [])
    is Err(_),
  )
  let (not_found, _) = mooncode_session_scope_error_status(
    "Unknown MoonCode session",
  )
  let (unavailable, _) = mooncode_session_scope_error_status(
    "MoonClaw GET failed",
  )
  assert_eq(not_found, 404)
  assert_eq(unavailable, 503)
}
