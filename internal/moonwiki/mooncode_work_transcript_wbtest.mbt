///|
fn work_handoff_test_record() -> Json {
  {
    "kind": "mooncode-session-record",
    "protocol": @mooncode.protocol_version(),
    "session_id": "S",
    "book_root": "/suite/books/书 with spaces/",
    "model": "later/model",
    "journal_sequence": "4",
    "mooncode_conversation": {
      "kind": @mooncode.conversation_kind(),
      "protocol": @mooncode.protocol_version(),
      "contract_id": @mooncode.conversation_contract_id(),
      "session_id": "S",
      "workspace_id": "",
      "workspace_name": "",
      "revision": "4",
      "last_sequence": "4",
      "turns": [
        {
          "kind": @mooncode.conversation_turn_kind(),
          "turn_id": "C0",
          "command_id": "C0",
          "client_turn_id": "C0",
          "ordinal": 0,
          "status": "done",
          "user": null,
          "work": {},
          "assistant": null,
        },
        {
          "kind": @mooncode.conversation_turn_kind(),
          "turn_id": "C1",
          "command_id": "C1",
          "client_turn_id": "C1",
          "ordinal": 1,
          "status": "running",
          "user": null,
          "work": {},
          "assistant": null,
        },
      ],
    },
  }
}

///|
async test "bound transcript reads canonical native history without generic auto-start routes" {
  let calls : Array[String] = []
  let (status, response) = mooncode_resolve_work_handoff(
    "/suite",
    [work_handoff_test_workspace()],
    work_handoff_test_target(),
    path => {
      calls.push(path)
      if path.contains("format=listing") {
        Ok(work_handoff_test_listing())
      } else if path.contains("runtime-claim") {
        Ok(work_handoff_test_claims())
      } else if path ==
        "/v1/code/sessions/S?book_root=%2Fsuite%2Fbooks%2F%E4%B9%A6%20with%20spaces" {
        Ok(work_handoff_test_record())
      } else {
        Err("Unexpected read: " + path)
      }
    },
    include_session=true,
  )
  assert_eq(status, 200)
  assert_eq(calls.length(), 3)
  assert_eq(json_string(response, "state", default=""), "ready")
  assert_eq(
    json_string(
      json_object_field_or_empty(response, "transcript"),
      "state",
      default="",
    ),
    "ready",
  )
  let session = json_object_field_or_empty(response, "session")
  assert_eq(json_string(session, "id", default=""), "S")
  assert_eq(json_string(session, "workspace_id", default=""), "actual-desk-id")
  assert_eq(
    json_string(session, "workspace_root", default=""),
    work_handoff_test_workspace().root_path,
  )
  assert_eq(
    json_array_items(
      json_object_field_or_empty(session, "mooncode_conversation"),
      "turns",
    ).length(),
    2,
  )
  assert_eq(
    json_string(
      json_object_field_or_empty(response, "original_command"),
      "model",
      default="",
    ),
    "moongate/C0",
  )
}

///|
async test "temporarily unavailable transcript retains exact resolved original work" {
  let (status, response) = mooncode_resolve_work_handoff(
    "/suite",
    [work_handoff_test_workspace()],
    work_handoff_test_target(),
    path => {
      if path.contains("format=listing") {
        Ok(work_handoff_test_listing())
      } else if path.contains("runtime-claim") {
        Ok(work_handoff_test_claims())
      } else {
        Err("Runtime disappeared before transcript read")
      }
    },
    include_session=true,
  )
  assert_eq(status, 200)
  assert_eq(json_string(response, "state", default=""), "ready")
  assert_eq(
    json_string(
      json_object_field_or_empty(response, "transcript"),
      "state",
      default="",
    ),
    "runtime_unavailable",
  )
  assert_eq(json_object_field(response, "session"), Some(Json::null()))
  assert_eq(
    json_string(
      json_object_field_or_empty(response, "original_command"),
      "command_id",
      default="",
    ),
    "C0",
  )
}

///|
async test "bound transcript rejects wrong root or unrelated session while retaining descriptor" {
  for mismatch in ["book_root", "session_id", "conversation"] {
    let record = work_handoff_test_record()
    guard record is Object(fields) else { fail("record") }
    if mismatch == "conversation" {
      guard json_object_field(record, "mooncode_conversation")
        is Some(Object(conversation)) else {
        fail("conversation")
      }
      conversation["session_id"] = "unrelated".to_json()
    } else {
      fields[mismatch] = "unrelated".to_json()
    }
    let (status, response) = mooncode_resolve_work_handoff(
      "/suite",
      [work_handoff_test_workspace()],
      work_handoff_test_target(),
      path => {
        if path.contains("format=listing") {
          Ok(work_handoff_test_listing())
        } else if path.contains("runtime-claim") {
          Ok(work_handoff_test_claims())
        } else {
          Ok(record)
        }
      },
      include_session=true,
    )
    assert_eq(status, 200)
    assert_eq(json_string(response, "state", default=""), "ready")
    assert_eq(
      json_string(
        json_object_field_or_empty(response, "transcript"),
        "state",
        default="",
      ),
      "identity_mismatch",
    )
    assert_eq(json_object_field(response, "session"), Some(Json::null()))
  }
}

///|
test "wrong conversation kind or missing body never becomes an empty ready transcript" {
  let (_, descriptor) = mooncode_work_command_projection(
    work_handoff_test_target(),
    work_handoff_test_workspace(),
    work_handoff_test_claims(),
  )
  for missing in [false, true] {
    let record = work_handoff_test_record()
    guard record is Object(fields) else { fail("record") }
    if missing {
      fields.remove("mooncode_conversation")
    } else {
      guard json_object_field(record, "mooncode_conversation")
        is Some(Object(conversation)) else {
        fail("conversation")
      }
      conversation["kind"] = "wrong-kind".to_json()
    }
    let (_, response) = mooncode_work_transcript_projection(
      "/suite",
      work_handoff_test_workspace(),
      work_handoff_test_target(),
      descriptor,
      record,
    )
    assert_eq(json_string(response, "state", default=""), "ready")
    assert_true(
      json_string(
        json_object_field_or_empty(response, "transcript"),
        "state",
        default="",
      ) !=
      "ready",
    )
    assert_eq(json_object_field(response, "session"), Some(Json::null()))
  }
}

///|
test "bound transcript rejects malformed canonical history and replaces stale catalog hints" {
  let (_, descriptor) = mooncode_work_command_projection(
    work_handoff_test_target(),
    work_handoff_test_workspace(),
    work_handoff_test_claims(),
  )
  let record = work_handoff_test_record()
  guard json_object_field(record, "mooncode_conversation")
    is Some(Object(conversation)) else {
    fail("conversation")
  }
  conversation["workspace_id"] = "old-catalog-id".to_json()
  let (_, response) = mooncode_work_transcript_projection(
    "/suite",
    work_handoff_test_workspace(),
    work_handoff_test_target(),
    descriptor,
    record,
  )
  assert_eq(
    json_string(
      json_object_field_or_empty(response, "session"),
      "workspace_id",
      default="",
    ),
    "actual-desk-id",
  )
  conversation["revision"] = "not-a-revision".to_json()
  let (_, invalid) = mooncode_work_transcript_projection(
    "/suite",
    work_handoff_test_workspace(),
    work_handoff_test_target(),
    descriptor,
    record,
  )
  assert_eq(json_string(invalid, "state", default=""), "ready")
  assert_eq(
    json_string(
      json_object_field_or_empty(invalid, "transcript"),
      "state",
      default="",
    ),
    "invalid_native_response",
  )
  assert_eq(json_object_field(invalid, "session"), Some(Json::null()))
}
