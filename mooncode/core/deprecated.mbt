///|
#deprecated("Compatibility for document-provider. Remove in v0.3.0 on or after 2027-07-28 after document-provider migration.")
pub fn command_advertised_actions() -> Array[String] {
  [
    command_prompt(),
    command_steer(),
    command_run_tests(),
    command_run_build(),
    command_run_eval(),
    command_package(),
    command_commit(),
    command_accept(),
    command_reject(),
    command_approve_tool(),
    command_reject_tool(),
    command_apply_patch(),
    command_revert_patch(),
    command_cancel(),
  ]
}

///|
#deprecated("Compatibility for document-provider. Remove in v0.3.0 on or after 2027-07-28 after document-provider migration.")
pub fn command_action_is_supported(action : String) -> Bool {
  command_supported_actions().contains(action)
}

///|
#deprecated("Compatibility for document-provider. Remove in v0.3.0 on or after 2027-07-28 after document-provider migration.")
pub fn command_action_control(action : String) -> String {
  if action == command_prompt() {
    command_prompt()
  } else if action == command_steer() {
    command_steer()
  } else if action == command_cancel() {
    command_cancel()
  } else {
    "command"
  }
}

///|
#deprecated("Compatibility for document-provider. Remove in v0.3.0 on or after 2027-07-28 after document-provider migration.")
pub fn command_action_approval(action : String) -> String {
  if command_action_is_review_decision(action) ||
    command_action_is_package(action) ||
    command_action_is_commit(action) ||
    command_action_is_tool_approval(action) ||
    command_action_is_patch(action) ||
    command_action_is_cancel(action) {
    "operator"
  } else if command_action_is_test(action) || command_action_is_eval(action) {
    "auto"
  } else if command_action_is_prompt_or_steer(action) {
    "user"
  } else {
    "none"
  }
}

///|
/// Deprecated since 2026-07-28: use `native_stream_endpoint_for_cursor`.
#deprecated("Use native_stream_endpoint_for_cursor with MoonCodeWatchCursor")
pub fn native_stream_endpoint(
  session_id : String,
  book_root : String,
  format : String,
  since : Int,
  wait_ms? : Int = 0,
  poll_ms? : Int = 100,
) -> String {
  native_stream_endpoint_raw(
    session_id,
    book_root,
    format,
    since.to_string(),
    wait_ms~,
    poll_ms~,
  )
}
