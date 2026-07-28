///|
test "private command decoder rejects invalid primitive field types" {
  let payload : Json = {
    "action": "prompt",
    "client_turn_id": "client-one",
    "message": "hello",
    "web_search": "yes",
  }
  assert_true(decode_mooncode_command(payload) is Err(_))
}

///|
test "private accepted command packet remains distinct from caller submission" {
  let payload : Json = { "action": "prompt", "client_turn_id": "client-one" }
  guard decode_mooncode_command(payload) is Ok(submission) else {
    fail("submission must decode")
  }
  let accepted = accept_mooncode_command(
    submission, "command-one", "2026-07-28T00:00:00Z", "session-one", "book-one",
    "Book One", "/tmp/book-one",
  )
  assert_true(accepted.status is Accepted)
  assert_eq(accepted.command_id, "command-one")
}
