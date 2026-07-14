///|
test "mooncode backend method checks match the canonical route surface" {
  let status = @mooncode.desktop_status_endpoint()
  assert_true(mooncode_route_accepts_read(status, Get))
  assert_true(mooncode_route_accepts_read(status, Head))
  assert_false(mooncode_route_accepts_post(status, Post))

  let sessions = @mooncode.desktop_sessions_endpoint()
  assert_true(mooncode_route_accepts_read(sessions, Get))
  assert_true(mooncode_route_accepts_post(sessions, Post))

  let commands = @mooncode.desktop_session_commands_endpoint()
  assert_false(mooncode_route_accepts_read(commands, Get))
  assert_true(mooncode_route_accepts_post(commands, Post))
  assert_eq(mooncode_route_allowed_methods(commands).join(", "), "POST")

  let removed = @mooncode.desktop_session_runtime_service_endpoint()
  assert_false(mooncode_route_accepts_read(removed, Get))
  assert_false(mooncode_route_accepts_post(removed, Post))
  assert_eq(mooncode_route_allowed_methods(removed).length(), 0)
}
