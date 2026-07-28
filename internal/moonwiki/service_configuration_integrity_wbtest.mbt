///|
test "service configuration integrity precedence is deterministic" {
  let missing = service_configuration_integrity_from_values(false, false, false)
  assert_false(json_bool(missing, "valid", default=true))
  assert_eq(json_string(missing, "reason", default=""), "not-configured")
  let command = service_configuration_integrity_from_values(true, false, false)
  assert_false(json_bool(command, "valid", default=true))
  assert_eq(json_string(command, "reason", default=""), "command-unavailable")
  let cwd = service_configuration_integrity_from_values(true, true, false)
  assert_false(json_bool(cwd, "valid", default=true))
  assert_eq(
    json_string(cwd, "reason", default=""),
    "working-directory-unavailable",
  )
  let valid = service_configuration_integrity_from_values(true, true, true)
  assert_true(json_bool(valid, "valid", default=false))
  assert_eq(json_string(valid, "reason", default=""), "configuration-valid")
}

///|
async test "service integrity inspects executability without running fixture" {
  let root = "/tmp/moondesk-service-integrity-wbtest-" +
    @desk.stable_id("service-integrity", @async.now().to_string())
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let executable = @pathx.join(root, "service")
  let marker = @pathx.join(root, "must-not-exist")
  @fsx.write_to_file(executable, "#!/bin/sh\ntouch '\{marker}'\n", create=0o755)
  let valid = service_configuration_integrity(executable, root)
  assert_true(json_bool(valid, "valid", default=false))
  assert_false(@fsx.exists(marker))
  let relative = service_configuration_integrity("./service", root)
  assert_true(json_bool(relative, "valid", default=false))
  assert_false(@fsx.exists(marker))
  let not_executable = @pathx.join(root, "not-executable")
  @fsx.write_to_file(not_executable, "#!/bin/sh\nexit 0\n", create=0o644)
  let invalid_command = service_configuration_integrity(not_executable, root)
  assert_eq(
    json_string(invalid_command, "reason", default=""),
    "command-unavailable",
  )
  let missing_cwd = service_configuration_integrity(
    executable,
    @pathx.join(root, "missing"),
  )
  assert_eq(
    json_string(missing_cwd, "reason", default=""),
    "working-directory-unavailable",
  )
  let path_command = service_configuration_integrity("sh", root)
  assert_true(json_bool(path_command, "valid", default=false))
  assert_false(@fsx.exists(marker))
}
