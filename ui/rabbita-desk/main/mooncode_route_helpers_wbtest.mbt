///|
test "mooncode route helpers own frontend desktop api paths" {
  assert_eq(mooncode_sessions_url(""), "/api/mooncode/sessions")
  assert_eq(
    mooncode_sessions_url("book demo/#one"),
    "/api/mooncode/sessions?workspace=book%20demo%2F%23one",
  )
  assert_eq(
    mooncode_session_commands_url("session one/#2"),
    "/api/mooncode/sessions/session%20one%2F%232/commands",
  )
  assert_eq(
    mooncode_session_runtime_service_url("session one/#2"),
    "/api/mooncode/sessions/session%20one%2F%232/runtime-service",
  )
  assert_eq(
    mooncode_session_stream_state_url("session one/#2"),
    "/api/mooncode/sessions/session%20one%2F%232/stream-state",
  )
  assert_eq(
    mooncode_session_stream_url("session one/#2", 7),
    "/api/mooncode/sessions/session%20one%2F%232/stream?format=jsonl&since=7&live=true&timeout_ms=1000&poll_ms=100",
  )
}
