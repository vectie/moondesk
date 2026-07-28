///|
test "mooncode session lifecycle decodes typed actions before proxying" {
  assert_true(
    mooncode_session_lifecycle_decode_action({ "action": "archive" })
    is Ok(Archive),
  )
  assert_true(
    mooncode_session_lifecycle_decode_action({
      "action": "rename",
      "title": "Durable title",
    })
    is Ok(Rename("Durable title")),
  )
  assert_eq(
    mooncode_session_lifecycle_decode_action({
      "action": "rename",
      "title": "   ",
    }).unwrap_err(),
    "A non-empty session title is required",
  )
  assert_eq(
    mooncode_session_lifecycle_decode_action({ "action": "export" }).unwrap_err(),
    "Unsupported MoonCode session lifecycle action",
  )
  assert_eq(
    mooncode_session_lifecycle_decode_action(Json::empty_object()).unwrap_err(),
    "Unsupported MoonCode session lifecycle action",
  )
}

///|
test "mooncode session lifecycle encodes only canonical request fields" {
  let body = mooncode_session_lifecycle_native_body(
    Rename("New title"),
    "/suite/root",
  )
  guard body
    is {
      "action": "rename",
      "title": "New title",
      "book_root": "/suite/root",
      ..
    } else {
    fail("typed request did not preserve canonical fields")
  }
  assert_false(body.stringify().contains("transition"))
  assert_false(body.stringify().contains("failure"))
  assert_false(body.stringify().contains("stop_reason"))
}

///|
test "mooncode session lifecycle types 404 409 502 and 503 outcomes" {
  let conflict = mooncode_session_lifecycle_proxy_failure(
    "MoonClaw POST /lifecycle returned 409: busy",
  )
  assert_eq(conflict.code, 409)
  assert_true(conflict.failure is Conflict)
  assert_true(conflict.stop_reason is None)
  let active = mooncode_session_lifecycle_proxy_failure(
    "MoonClaw POST /lifecycle returned 409: This MoonCode session is still running; stop it before changing its storage",
  )
  assert_true(active.failure is Conflict)
  assert_true(active.stop_reason is Some(SessionActive))
  let missing = mooncode_session_lifecycle_proxy_failure(
    "MoonClaw POST /lifecycle returned 404: missing",
  )
  assert_eq(missing.code, 404)
  assert_true(missing.failure is NotFound)
  let failed = mooncode_session_lifecycle_proxy_failure("connection closed")
  assert_eq(failed.code, 502)
  assert_true(failed.failure is RuntimeFailure)
  let unavailable = mooncode_session_lifecycle_route_failure(503, "not running")
  assert_eq(unavailable.code, 503)
  assert_true(unavailable.failure is RuntimeUnavailable)
  assert_eq(unavailable.title, "Service Unavailable")
}

///|
test "mooncode session lifecycle validates canonical success ownership and identity" {
  let success : Json = {
    "kind": "mooncode-session-lifecycle-result",
    "protocol": "mooncode.v1",
    "owner": "moonclaw",
    "action": "archive",
    "session_id": "session-one",
    "title": "",
    "archived": true,
    "deleted": false,
  }
  assert_true(
    mooncode_session_lifecycle_result(success, "session-one") is Ok(_),
  )
  assert_eq(
    mooncode_session_lifecycle_result(success, "session-two").unwrap_err(),
    "MoonCode lifecycle session mismatch: expected session-two, got session-one",
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
  assert_eq(
    mooncode_session_lifecycle_result(wrong_owner, "session-one").unwrap_err(),
    "Unexpected MoonCode lifecycle owner moondesk",
  )
}
