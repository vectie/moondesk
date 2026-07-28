///|
fn lifecycle_result_fixture(
  action : String,
  archived? : Bool = false,
  deleted? : Bool = false,
) -> Json {
  {
    "kind": "mooncode-session-lifecycle-result",
    "protocol": "mooncode.v1",
    "owner": "moonclaw",
    "action": action,
    "session_id": "session-one",
    "title": "",
    "archived": archived,
    "deleted": deleted,
  }
}

///|
test "lifecycle action codec is the runtime JSON boundary" {
  assert_true(
    @core.decode_mooncode_lifecycle_action({ "action": "archive" })
    is Ok(Archive),
  )
  assert_true(
    @core.decode_mooncode_lifecycle_action({
      "action": "rename",
      "title": " Durable title ",
    })
    is Ok(Rename("Durable title")),
  )
  assert_true(
    @core.decode_mooncode_lifecycle_action({ "action": "export" })
    is Err(UnsupportedAction("export")),
  )
  assert_true(
    @core.decode_mooncode_lifecycle_action(Json::empty_object())
    is Err(MalformedAction),
  )
  assert_true(
    @core.decode_mooncode_lifecycle_action({ "action": 1 })
    is Err(MalformedAction),
  )
  assert_true(
    @core.decode_mooncode_lifecycle_action({ "action": "rename", "title": " " })
    is Err(InvalidTitle),
  )
  let encoded = @core.encode_mooncode_lifecycle_action(
    Rename("New title"),
    book_root="/suite/root",
  )
  guard encoded
    is {
      "action": "rename",
      "title": "New title",
      "book_root": "/suite/root",
      ..
    } else {
    fail("typed action did not encode authoritatively")
  }
}

///|
test "lifecycle transition mirrors canonical archive restore and delete rules" {
  assert_true(
    @core.mooncode_lifecycle_transition(Archive, Idle, archived=false) is Ok(_),
  )
  assert_true(
    @core.mooncode_lifecycle_transition(Archive, Idle, archived=true)
    is Err(NotFound),
  )
  assert_true(
    @core.mooncode_lifecycle_transition(Restore, Done, archived=true) is Ok(_),
  )
  assert_true(
    @core.mooncode_lifecycle_transition(Restore, Done, archived=false)
    is Err(NotFound),
  )
  assert_true(
    @core.mooncode_lifecycle_transition(Delete, Done, archived=false) is Ok(_),
  )
  assert_true(
    @core.mooncode_lifecycle_transition(Delete, Done, archived=true) is Ok(_),
  )
  assert_true(
    @core.mooncode_lifecycle_transition(Delete, Running, archived=false)
    is Err(Conflict),
  )
  assert_true(
    @core.mooncode_lifecycle_transition(Archive, Queued, archived=false)
    is Err(Conflict),
  )
  assert_true(
    @core.mooncode_lifecycle_transition(
      Rename("Title"),
      Running,
      archived=false,
    )
    is Ok(_),
  )
}

///|
test "lifecycle success validates canonical fields and endpoint identity" {
  let expected = @core.MoonCodeSessionId::parse("session-one").unwrap()
  assert_true(
    @core.decode_mooncode_lifecycle_result(
      lifecycle_result_fixture("archive", archived=true),
      expected_session_id=expected,
    )
    is Ok({ archived: true, deleted: false, .. }),
  )
  let other = @core.MoonCodeSessionId::parse("session-two").unwrap()
  assert_true(
    @core.decode_mooncode_lifecycle_result(
      lifecycle_result_fixture("archive", archived=true),
      expected_session_id=other,
    )
    is Err(WrongSession(expected="session-two", actual="session-one")),
  )
  let wrong_owner : Json = {
    "kind": "mooncode-session-lifecycle-result",
    "protocol": "mooncode.v1",
    "owner": "moondesk",
    "action": "archive",
    "session_id": "session-one",
    "title": "",
    "archived": true,
    "deleted": false,
  }
  assert_true(
    @core.decode_mooncode_lifecycle_result(
      wrong_owner,
      expected_session_id=expected,
    )
    is Err(WrongOwner("moondesk")),
  )
}

///|
test "lifecycle success rejects state that contradicts the canonical action" {
  let expected = @core.MoonCodeSessionId::parse("session-one").unwrap()
  assert_true(
    @core.decode_mooncode_lifecycle_result(
      lifecycle_result_fixture("archive"),
      expected_session_id=expected,
    )
    is Err(InvalidResult(_)),
  )
  assert_true(
    @core.decode_mooncode_lifecycle_result(
      lifecycle_result_fixture("delete"),
      expected_session_id=expected,
    )
    is Err(InvalidResult(_)),
  )
}
