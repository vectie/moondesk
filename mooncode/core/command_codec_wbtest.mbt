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
test "command decoder refuses media fields until the native turn can retain them" {
  for field in ["content", "images", "attachments"] {
    let fields : Map[String, Json] = {
      "action": "prompt".to_json(),
      "client_turn_id": "client-media".to_json(),
      "message": "Inspect this image".to_json(),
    }
    fields[field] = Json::array([])
    assert_true(decode_mooncode_command(Json::object(fields)) is Err(_))
  }
}

///|
test "ordered text and image content survives the command codec" {
  let payload : Json = {
    "action": "prompt",
    "client_turn_id": "client-media",
    "message": "Review  now",
    "content_parts": [
      { "type": "text", "text": "Review " },
      {
        "type": "image",
        "media_type": "image/png",
        "data_base64": "iVBORw0KGgo=",
        "name": "screen.png",
      },
      { "type": "text", "text": " now" },
    ],
  }
  guard decode_mooncode_command(payload) is Ok(command) else {
    fail("ordered content should decode")
  }
  assert_eq(command.content_parts.length(), 3)
  guard encode_mooncode_command(command) is Ok(encoded) else {
    fail("ordered content should encode")
  }
  guard encoded is Object(encoded_fields) && payload is Object(source_fields) else {
    fail("command objects")
  }
  assert_eq(
    encoded_fields.get("content_parts"),
    source_fields.get("content_parts"),
  )
  let invalid : Json = {
    "action": "prompt",
    "client_turn_id": "client-media",
    "message": "Missing text",
    "content_parts": [
      { "type": "text", "text": "Review " },
      {
        "type": "image",
        "media_type": "image/png",
        "data_base64": "iVBORw0KGgo=",
        "name": "screen.png",
      },
    ],
  }
  assert_true(decode_mooncode_command(invalid) is Err(_))
}
