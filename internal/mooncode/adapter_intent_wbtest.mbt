///|
test "Desk typed task intent reaches native payload and packet" {
  for intent in ["read_only", "workspace_change"] {
    guard decode_command_submission({
        "action": "prompt",
        "client_turn_id": "intent-" + intent,
        "message": "Review this code; do not edit or fix any files",
        "task_intent": intent,
      })
      is Ok(command) else {
      fail("task intent command must decode")
    }
    guard @mooncode_core.encode_mooncode_command(command) is Ok(encoded) else {
      fail("must encode")
    }
    assert_eq(json_string(encoded, "task_intent", default=""), intent)
    let body = native_command_body(
      {
        "id": "session-intent",
        "workspace_id": "book",
        "workspace_root": "/tmp/book",
      },
      command,
      "2026-10-02T00:00:00Z",
      Json::empty_object(),
    )
    assert_eq(
      json_string(
        json_object_field_or_empty(body, "payload"),
        "task_intent",
        default="",
      ),
      intent,
    )
    assert_eq(
      json_string(
        json_object_field_or_empty(body, "packet"),
        "task_intent",
        default="",
      ),
      intent,
    )
  }
}

///|
test "Desk absent intent remains auto and invalid intent is rejected" {
  for value in [Json::string("automatic"), Json::number(3), true.to_json()] {
    assert_true(
      decode_command_submission({
        "action": "prompt",
        "client_turn_id": "invalid-intent",
        "task_intent": value,
      })
      is Err(_),
    )
  }
  guard decode_command_submission({
      "action": "prompt",
      "client_turn_id": "auto-intent",
    })
    is Ok(command) else {
    fail("auto must decode")
  }
  guard @mooncode_core.encode_mooncode_command(command) is Ok(Object(fields)) else {
    fail("must encode")
  }
  assert_true(fields.get("task_intent") is None)
}

///|
test "typed task purpose owns native passthrough and fingerprints submissions" {
  let session : Json = {
    "id": "intent-session",
    "workspace_id": "book",
    "workspace_root": "/tmp/book",
  }
  guard decode_command_submission({
      "action": "prompt",
      "client_turn_id": "same-intent-turn",
      "message": "Review code",
      "task_intent": "read_only",
    })
    is Ok(read_only_command) else {
    fail("must decode")
  }
  guard decode_command_submission({
      "action": "prompt",
      "client_turn_id": "same-intent-turn",
      "message": "Review code",
      "task_intent": "workspace_change",
    })
    is Ok(coding) else {
    fail("must decode")
  }
  guard decode_command_submission({
      "action": "prompt",
      "client_turn_id": "same-intent-turn",
      "message": "Review code",
    })
    is Ok(auto) else {
    fail("must decode")
  }
  let readonly_body = native_command_body(
    session,
    read_only_command,
    "2026-10-02T00:00:00Z",
    { "task_intent": "workspace_change" },
  )
  let coding_body = native_command_body(
    session,
    coding,
    "2026-10-02T00:00:00Z",
    Json::empty_object(),
  )
  let auto_body = native_command_body(session, auto, "2026-10-02T00:00:00Z", {
    "task_intent": "workspace_change",
  })
  assert_eq(
    json_string(
      json_object_field_or_empty(readonly_body, "payload"),
      "task_intent",
      default="",
    ),
    "read_only",
  )
  assert_eq(
    json_string(
      json_object_field_or_empty(auto_body, "payload"),
      "task_intent",
      default="",
    ),
    "",
  )
  assert_true(
    json_string(
      json_object_field_or_empty(readonly_body, "packet"),
      "command_id",
      default="",
    ) !=
    json_string(
      json_object_field_or_empty(coding_body, "packet"),
      "command_id",
      default="",
    ),
  )
}
