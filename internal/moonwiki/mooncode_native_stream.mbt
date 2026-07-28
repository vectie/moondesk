///|
fn mooncode_native_stream_cursor(
  text : String,
  current : @mooncode_core.MoonCodeWatchCursor,
) -> @mooncode_core.MoonCodeStreamCursorDecodeResult {
  @mooncode_core.decode_mooncode_stream_cursor(text, current~)
}

///|
fn mooncode_max_int(left : Int, right : Int) -> Int {
  if left > right {
    left
  } else {
    right
  }
}

///|
async fn mooncode_native_stream_text(
  workspace_root : String,
  session_id : String,
  format : String,
  cursor : @mooncode_core.MoonCodeWatchCursor,
  wait_ms~ : Int,
  poll_ms~ : Int,
) -> Result[String, String] {
  let daemon = moonclaw_daemon_status(workspace_root)
  if !json_bool(daemon, "running", default=false) {
    return Err("MoonClaw daemon is not running")
  }
  if !mooncode_turn_runtime_ready(daemon) {
    return Err("MoonClaw MoonCode runtime is not available")
  }
  moonclaw_get_text(
    daemon,
    @mooncode.moonclaw_native_stream_endpoint(
      session_id,
      workspace_root,
      format,
      cursor,
      wait_ms~,
      poll_ms~,
    ),
  )
}
