///|
// Native MoonClaw MoonCode endpoint builders and query encoding.

///|
pub fn moonclaw_native_command_endpoint(session_id : String) -> String {
  @mooncode_core.native_session_commands_endpoint(session_id)
}

///|
pub fn moonclaw_native_runtime_loop_endpoint(
  session_id : String,
  book_root : String,
) -> String {
  @mooncode_core.native_runtime_loop_endpoint(session_id, book_root)
}

///|
pub fn moonclaw_native_runtime_service_endpoint(
  session_id : String,
  book_root : String,
) -> String {
  @mooncode_core.native_runtime_service_endpoint(session_id, book_root)
}

///|
pub fn moonclaw_native_runtime_turn_endpoint(
  session_id : String,
  book_root : String,
) -> String {
  @mooncode_core.native_runtime_turn_endpoint(session_id, book_root)
}

///|
pub fn moonclaw_native_eval_report_endpoint(
  session_id : String,
  book_root : String,
) -> String {
  @mooncode_core.native_eval_report_endpoint(session_id, book_root)
}

///|
pub fn moonclaw_native_package_result_endpoint(
  session_id : String,
  book_root : String,
) -> String {
  @mooncode_core.native_package_result_endpoint(session_id, book_root)
}

///|
pub fn moonclaw_native_runtime_control_endpoint(
  session_id : String,
  book_root : String,
) -> String {
  @mooncode_core.native_runtime_control_endpoint(session_id, book_root)
}

///|
pub fn moonclaw_native_session_listing_endpoint(book_root : String) -> String {
  @mooncode_core.native_session_listing_endpoint(book_root)
}

///|
pub fn moonclaw_native_stream_endpoint(
  session_id : String,
  book_root : String,
  format : String,
  since : Int,
  wait_ms? : Int = 0,
  poll_ms? : Int = 100,
) -> String {
  @mooncode_core.native_stream_endpoint(
    session_id,
    book_root,
    format,
    since,
    wait_ms~,
    poll_ms~,
  )
}

///|
pub fn moonclaw_native_runtime_events_endpoint(
  session_id : String,
  book_root : String,
) -> String {
  @mooncode_core.native_runtime_events_endpoint(session_id, book_root)
}
