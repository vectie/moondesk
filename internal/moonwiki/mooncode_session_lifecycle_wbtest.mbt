///|
test "mooncode session lifecycle validates actions before proxying" {
  assert_true(
    mooncode_session_lifecycle_action_error({ "action": "archive" }) is None,
  )
  assert_true(
    mooncode_session_lifecycle_action_error({
      "action": "rename",
      "title": "Durable title",
    })
    is None,
  )
  assert_eq(
    mooncode_session_lifecycle_action_error({
      "action": "rename",
      "title": "   ",
    }).unwrap_or(""),
    "A non-empty session title is required",
  )
  assert_eq(
    mooncode_session_lifecycle_action_error({ "action": "export" }).unwrap_or(
      "",
    ),
    "Unsupported MoonCode session lifecycle action",
  )
}

///|
test "mooncode session lifecycle injects the trusted workspace root" {
  let body = mooncode_session_lifecycle_native_body(
    { "action": "rename", "title": "New title", "book_root": "/untrusted" },
    "/suite/root",
  )
  assert_eq(json_string(body, "book_root", default=""), "/suite/root")
  assert_eq(json_string(body, "title", default=""), "New title")
  assert_eq(
    mooncode_session_lifecycle_error_code(
      "MoonClaw POST /lifecycle returned 409: busy",
    ),
    409,
  )
}
