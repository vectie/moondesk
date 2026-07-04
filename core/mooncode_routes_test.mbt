///|
test "mooncode desktop routes live in core boundary" {
  assert_eq(@core.mooncode_sessions_url(""), "/api/mooncode/sessions")
  assert_eq(
    @core.mooncode_sessions_url("book demo/#one"),
    "/api/mooncode/sessions?workspace=book%20demo%2F%23one",
  )
  assert_eq(
    @core.mooncode_session_commands_url("session one/#2"),
    "/api/mooncode/sessions/session%20one%2F%232/commands",
  )
  assert_eq(
    @core.mooncode_session_runtime_service_url("session one/#2"),
    "/api/mooncode/sessions/session%20one%2F%232/runtime-service",
  )
  assert_eq(
    @core.mooncode_session_stream_state_url("session one/#2"),
    "/api/mooncode/sessions/session%20one%2F%232/stream-state",
  )
  assert_eq(
    @core.mooncode_session_stream_url("session one/#2", 7),
    "/api/mooncode/sessions/session%20one%2F%232/stream?format=jsonl&since=7&live=true&timeout_ms=1000&poll_ms=100",
  )
}

///|
test "url component encoding matches browser route expectations" {
  assert_eq(@core.url_component("docs/read me?#1"), "docs%2Fread%20me%3F%231")
  assert_eq(@core.url_component("safe-_.!~*'()"), "safe-_.!~*'()")
  assert_eq(@core.url_component("中文"), "%E4%B8%AD%E6%96%87")
}
