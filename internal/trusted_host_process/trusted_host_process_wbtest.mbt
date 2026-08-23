///|
test "trusted host inputs reject option and control injection" {
  assert_true(safe_absolute_path("/tmp/example"))
  assert_false(safe_absolute_path("-R"))
  assert_false(safe_absolute_path("relative/path"))
  assert_false(safe_absolute_path("/tmp/bad\npath"))
  assert_true(safe_http_url("http://127.0.0.1:4188/"))
  assert_true(safe_http_url("https://example.com/"))
  assert_false(safe_http_url("file:///tmp/index.html"))
  assert_false(safe_http_url("https://example.com/\n--new-window"))
  assert_false(safe_pid(0))
  assert_false(safe_pid(1))
  assert_true(safe_pid(2))
  assert_true(safe_user_id("501"))
  assert_true(safe_user_id("0"))
  assert_false(safe_user_id(""))
  assert_false(safe_user_id("-1"))
  assert_false(safe_user_id("501\nroot"))
}

///|
test "trusted host launch agent capability is a closed enum" {
  assert_eq(launch_agent_label(MoonDesk), "app.vectie.moondesk")
  assert_eq(launch_agent_label(MoonTown), "app.vectie.moonsuite.town")
}

///|
test "trusted host PID inspection rejects zombie process states" {
  assert_false(process_status_is_alive("Z"))
  assert_false(process_status_is_alive("Z+\n"))
  assert_false(process_status_is_alive(""))
  assert_true(process_status_is_alive("S+"))
  assert_true(process_status_is_alive("R"))
}
