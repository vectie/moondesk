///|
// Native MoonClaw-only MoonCode session projection helpers.

///|
async fn mooncode_native_session_known(
  workspace_root : String,
  session_id : String,
  native_events : Array[Json],
) -> Bool {
  if native_events.length() > 0 {
    return true
  }
  for row in moonclaw_native_session_listing_rows(workspace_root) {
    if json_string(row, "id", default="") == session_id {
      return true
    }
  }
  false
}
