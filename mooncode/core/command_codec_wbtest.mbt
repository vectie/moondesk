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
