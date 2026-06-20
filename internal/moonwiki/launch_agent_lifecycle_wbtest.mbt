///|
async test "LaunchAgent status is quiet when LaunchAgent is not installed" {
  let root = "/tmp/moondesk-daemon-launch-agent-status-wbtest-" +
    @desk.stable_id("launch-agent-status", @async.now().to_string())
  let record = launch_agent_record(
    root,
    action="status",
    exit_code=0,
    message="",
  )
  assert_true(json_bool(record, "ok", default=false))
  assert_false(json_bool(record, "installed", default=true))
  assert_false(json_bool(record, "loaded", default=true))
  assert_eq(
    json_string(record, "message", default=""),
    "LaunchAgent is not installed",
  )
}
