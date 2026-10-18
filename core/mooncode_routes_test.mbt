///|
test "mooncode desktop routes live in core boundary" {
  assert_eq(@core.mooncode_sessions_url(""), "/api/mooncode/sessions")
  assert_eq(
    @core.mooncode_sessions_url("book demo/#one"),
    "/api/mooncode/sessions?workspace=book%20demo%2F%23one",
  )
  assert_eq(
    @core.mooncode_session_listing_url(""),
    "/api/mooncode/sessions?format=listing",
  )
  assert_eq(
    @core.mooncode_session_listing_url("book demo/#one"),
    "/api/mooncode/sessions?workspace=book%20demo%2F%23one&format=listing",
  )
  assert_eq(
    @core.mooncode_archived_session_listing_url(),
    "/api/mooncode/sessions?format=listing&scope=archived",
  )
  assert_eq(
    @core.mooncode_session_chat_url("session one/#2", 0),
    "/api/mooncode/sessions/session%20one%2F%232?format=chat",
  )
  assert_eq(
    @core.mooncode_session_chat_url("session one/#2", 7),
    "/api/mooncode/sessions/session%20one%2F%232?format=chat&since_revision=7",
  )
  assert_eq(
    @core.mooncode_session_commands_url("session one/#2"),
    "/api/mooncode/sessions/session%20one%2F%232/commands",
  )
  assert_eq(
    @core.mooncode_session_lifecycle_url("session one/#2"),
    "/api/mooncode/sessions/session%20one%2F%232/lifecycle",
  )
  assert_eq(
    @core.mooncode_session_runtime_service_url("session one/#2"),
    "/api/mooncode/sessions/session%20one%2F%232/runtime-service",
  )
  assert_eq(
    @core.mooncode_session_watch_url("session one/#2", "7", "11"),
    "/api/mooncode/sessions/session%20one%2F%232/watch?since_revision=7&since_sequence=11&wait_ms=15000&poll_ms=100",
  )
  assert_eq(
    @core.mooncode_sandbox_promotion_url(),
    "/api/mooncode/execution-sandbox/promote",
  )
  assert_eq(
    @core.mooncode_sandbox_promotion_receipt_url(),
    "/api/mooncode/execution-sandbox/promotion-receipt",
  )
}

///|
test "url component encoding matches browser route expectations" {
  assert_eq(@core.url_component("docs/read me?#1"), "docs%2Fread%20me%3F%231")
  assert_eq(@core.url_component("safe-_.!~*'()"), "safe-_.!~*'()")
  assert_eq(@core.url_component("中文"), "%E4%B8%AD%E6%96%87")
}

///|
test "media and work handoff URLs retain route identity and browser query encoding" {
  assert_eq(
    @core.mooncode_session_media_url("session-one", "command-two", 3),
    "/api/mooncode/sessions/session-one/media/command-two/3",
  )
  assert_eq(
    @core.mooncode_session_media_url("session/书", "command?two", 3),
    "/api/mooncode/sessions/session%2F%E4%B9%A6/media/command%3Ftwo/3",
  )
  assert_eq(
    @core.mooncode_work_continuations_url(),
    "/api/mooncode/work-handoff/continuations",
  )
  assert_eq(
    @core.mooncode_work_human_revisions_url(),
    "/api/mooncode/work-handoff/human-revisions",
  )
  assert_eq(
    @core.mooncode_work_handoff_url("S/书", "C?0", "/book with space/"),
    "/api/mooncode/work-handoff?session_id=S%2F%E4%B9%A6&command_id=C%3F0&book_root=%2Fbook+with+space%2F&include_session=true&include_context=true",
  )
  assert_eq(
    @core.mooncode_work_handoff_url("!~'()+*", "", ""),
    "/api/mooncode/work-handoff?session_id=%21%7E%27%28%29%2B*&command_id=&book_root=&include_session=true&include_context=true",
  )
}
