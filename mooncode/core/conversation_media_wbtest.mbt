///|
test "canonical user message retains ordered image references through codec" {
  let value : Json = {
    "item_id": "user-image",
    "role": "user",
    "content": "Inspect this screenshot",
    "status": "done",
    "content_parts": [
      { "type": "text", "text": "Inspect this screenshot" },
      {
        "type": "image",
        "media_type": "image/png",
        "image_index": 1,
        "name": "screen.png",
      },
    ],
  }
  let message = decode_conversation_message(value, "user")
  assert_true(message is Ok(Some(_)))
  match message {
    Ok(Some(decoded)) => {
      let encoded = encode_mooncode_message(Some(decoded))
      match encoded {
        Object(fields) =>
          assert_eq(
            fields.get("content_parts"),
            match value {
              Object(source) => source.get("content_parts")
              _ => None
            },
          )
        _ => fail("canonical message must remain an object")
      }
    }
    _ => ()
  }
}
