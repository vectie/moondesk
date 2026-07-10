///|
test "mooncode backend route contract drives method checks" {
  let status = @mooncode.desktop_status_endpoint()
  assert_true(mooncode_route_accepts_read(status, Get))
  assert_true(mooncode_route_accepts_read(status, Head))
  assert_false(mooncode_route_accepts_post(status, Post))
  assert_false(mooncode_route_accepts_method(status, Delete))
  assert_eq(mooncode_route_allowed_methods(status).join(", "), "GET, HEAD")
  let session = @mooncode.desktop_session_endpoint()
  assert_true(mooncode_route_accepts_read(session, Get))
  assert_true(mooncode_route_accepts_read(session, Head))
  assert_false(mooncode_route_accepts_post(session, Post))
  assert_eq(mooncode_route_allowed_methods(session).join(", "), "GET, HEAD")
  let commands = @mooncode.desktop_session_commands_endpoint()
  assert_true(mooncode_route_accepts_read(commands, Get))
  assert_true(mooncode_route_accepts_read(commands, Head))
  assert_true(mooncode_route_accepts_post(commands, Post))
  assert_false(mooncode_route_accepts_method(commands, Put))
  assert_eq(
    mooncode_route_allowed_methods(commands).join(", "),
    "GET, HEAD, POST",
  )
  let runtime_service = @mooncode.desktop_session_runtime_service_endpoint()
  assert_false(mooncode_route_accepts_read(runtime_service, Get))
  assert_false(mooncode_route_accepts_read(runtime_service, Head))
  assert_true(mooncode_route_accepts_post(runtime_service, Post))
  assert_false(mooncode_route_accepts_method(runtime_service, Patch))
  assert_eq(mooncode_route_allowed_methods(runtime_service).join(", "), "POST")
  let command_jsonl = @mooncode.desktop_session_command_jsonl_endpoint()
  assert_eq(
    mooncode_route_allowed_methods(command_jsonl).join(", "),
    "GET, HEAD",
  )
}
