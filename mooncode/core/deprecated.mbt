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
