///|
// MoonClaw runtime session projection helpers.

///|
async fn mooncode_runtime_session_known(
  workspace_root : String,
  session_id : String,
  runtime_events : Array[Json],
) -> Bool {
  if runtime_events.length() > 0 {
    return true
  }
  for row in moonclaw_runtime_session_listing_rows(workspace_root) {
    if json_string(row, "id", default="") == session_id {
      return true
    }
  }
  false
}
