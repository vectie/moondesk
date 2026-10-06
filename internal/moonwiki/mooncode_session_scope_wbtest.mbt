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

///|
test "native live listing reopens the same session with canonical turn state" {
  let book = @desk.workspace(
    id="book-a",
    name="Book A",
    root_path="/suite/books/a",
    kind=MoonBook,
  )
  guard @mooncode.runtime_session_listing_rows({
      "protocol": "mooncode.v1",
      "sessions": [
        { "id": "session-a", "book_root": "/suite/books/a", "status": "live" },
        { "id": "saved", "book_root": "/suite", "status": "durable" },
        { "id": "unresolved", "book_root": "/suite", "status": "unknown" },
      ],
    })
    is Ok(rows) else {
    fail("producer-shaped native listing must reach existing-session lookup")
  }
  assert_eq(
    moonclaw_runtime_session_book_root_from_rows("/suite", "session-a", rows, [
      book,
    ]),
    Ok("/suite/books/a"),
  )
  for status in ["running", "queued", "done", "cancelled"] {
    let conversation : Json = {
      "kind": @mooncode.conversation_kind(),
      "session_id": "session-a",
      "turns": [{ "status": status }],
    }
    let session = moonclaw_runtime_full_session_from_record(
      "/suite",
      {
        "session_id": "session-a",
        "book_root": "/suite/books/a",
        "mooncode_conversation": conversation,
      },
      row=rows[0],
    )
    assert_eq(json_string(session, "id", default=""), "session-a")
    assert_eq(json_string(session, "status", default=""), status)
    assert_eq(
      json_string(session, "runtime_binding_status", default=""),
      "live",
    )
  }
}
