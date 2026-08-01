///|
test "supervisor proxy accepts only canonical ids and known commands" {
  assert_true(moonclaw_supervisor_id_allowed("supervisor-ada:primary_1"))
  assert_false(moonclaw_supervisor_id_allowed(""))
  assert_false(moonclaw_supervisor_id_allowed("../supervisor"))
  assert_false(moonclaw_supervisor_id_allowed("supervisor%2Fescape"))
  assert_true(moonclaw_supervisor_command_allowed("message"))
  assert_true(moonclaw_supervisor_command_allowed("delegate"))
  assert_true(moonclaw_supervisor_command_allowed("worker-retry-resume"))
  assert_false(moonclaw_supervisor_command_allowed("worker-retry"))
  assert_true(moonclaw_supervisor_command_allowed("outcome-evidence"))
  assert_false(moonclaw_supervisor_command_allowed("accept"))
}

///|
test "supervisor event proxy rebuilds a bounded query" {
  assert_eq(
    moonclaw_supervisor_events_runtime_path(
      "supervisor-ada", "/api/moonclaw/supervisors/supervisor-ada/events?limit=25&after_cursor=7&ignored=true",
    ),
    Ok("/v1/supervisors/supervisor-ada/events?after_cursor=7&limit=25"),
  )
  assert_eq(
    moonclaw_supervisor_events_runtime_path(
      "supervisor-ada", "/api/moonclaw/supervisors/supervisor-ada/events?limit=0",
    ),
    Err("limit must be between 1 and 1000"),
  )
  assert_eq(
    moonclaw_supervisor_events_runtime_path(
      "supervisor-ada", "/api/moonclaw/supervisors/supervisor-ada/events?after_cursor=-1",
    ),
    Err("after_cursor must be a non-negative integer"),
  )
}
