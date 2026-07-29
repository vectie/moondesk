///|
test "town platform support normalizes explicit uname values" {
  let mac = @town.platform_evidence_from_values("Darwin", "arm64")
  assert_true(@mooncore.json_bool(mac, "supported", default=false))
  assert_eq(@mooncore.json_string(mac, "platform", default=""), "macos")
  assert_eq(@mooncore.json_string(mac, "architecture", default=""), "arm64")
  let linux = @town.platform_evidence_from_values("Linux", "amd64")
  assert_true(@mooncore.json_bool(linux, "supported", default=false))
  assert_eq(@mooncore.json_string(linux, "architecture", default=""), "x86_64")
  assert_false(
    @mooncore.json_bool(
      @town.platform_evidence_from_values("windows", "x86_64"),
      "supported",
      default=true,
    ),
  )
  assert_false(
    @mooncore.json_bool(
      @town.platform_evidence_from_values("linux", "riscv64"),
      "supported",
      default=true,
    ),
  )
}

///|
test "town installation evidence distinguishes configured supervisor and none" {
  let configured = @town.installation_evidence_from_values(true, false)
  assert_true(@mooncore.json_bool(configured, "installed", default=false))
  assert_eq(
    @mooncore.json_string(configured, "source", default=""),
    "service-configured",
  )
  let supervisor = @town.installation_evidence_from_values(false, true)
  assert_true(@mooncore.json_bool(supervisor, "installed", default=false))
  assert_eq(
    @mooncore.json_string(supervisor, "source", default=""),
    "launch-agent",
  )
  let missing = @town.installation_evidence_from_values(false, false)
  assert_false(@mooncore.json_bool(missing, "installed", default=true))
  assert_eq(@mooncore.json_string(missing, "source", default=""), "none")
}

///|
test "town configuration evidence separates absence from invalid setup" {
  let configured = @town.configuration_evidence_from_values(true, true)
  assert_true(@mooncore.json_bool(configured, "configured", default=false))
  assert_true(@mooncore.json_bool(configured, "valid", default=false))
  assert_eq(
    @mooncore.json_string(configured, "reason", default=""),
    "service-configured",
  )
  let invalid = @town.configuration_evidence_from_values(true, false)
  assert_false(@mooncore.json_bool(invalid, "configured", default=true))
  assert_false(@mooncore.json_bool(invalid, "valid", default=true))
  assert_eq(
    @mooncore.json_string(invalid, "reason", default=""),
    "service-configuration-missing",
  )
  let absent = @town.configuration_evidence_from_values(false, false)
  assert_false(@mooncore.json_bool(absent, "configured", default=true))
  assert_true(@mooncore.json_bool(absent, "valid", default=false))
  assert_eq(
    @mooncore.json_string(absent, "reason", default=""),
    "not-installed",
  )
}
