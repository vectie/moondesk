///|
test "Code export includes canonical messages but omits work evidence and image bytes" {
  let session : Json = {
    "id": "session-export",
    "mooncode_conversation": {
      "kind": "mooncode-conversation",
      "session_id": "session-export",
      "turns": [
        {
          "turn_id": "turn-1",
          "status": "failed",
          "user": {
            "content": "Explain this screenshot",
            "content_parts": [
              { "type": "text", "text": "Explain this screenshot" },
              {
                "type": "image",
                "name": "private.png",
                "data": "secret-image-bytes",
              },
            ],
          },
          "work": { "detail": "secret-tool-log" },
          "assistant": { "content": "I could not read it." },
        },
      ],
    },
  }
  let exported = mooncode_export_conversation("session-export", session).unwrap()
  let text = exported.stringify()
  assert_true(text.contains("Explain this screenshot"))
  assert_true(text.contains("I could not read it."))
  assert_true(text.contains("\"image_count\":1"))
  assert_true(text.contains("\"status\":\"failed\""))
  assert_false(text.contains("secret-tool-log"))
  assert_false(text.contains("secret-image-bytes"))
  assert_false(text.contains("private.png"))
}

///|
test "Code export rejects mismatched and missing canonical conversations" {
  assert_true(
    mooncode_export_conversation("session-a", {
      "mooncode_conversation": {
        "kind": "mooncode-conversation",
        "session_id": "session-b",
        "turns": [],
      },
    })
    is Err(_),
  )
  assert_true(mooncode_export_conversation("session-a", {}) is Err(_))
}
