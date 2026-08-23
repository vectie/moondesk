///|
test "managed MoonClaw binding rejects path and control injection" {
  assert_true(managed_moonclaw_binding("v0.1.5") is Ok(_))
  assert_false(managed_moonclaw_binding("") is Ok(_))
  assert_false(managed_moonclaw_binding("../v0.1.5") is Ok(_))
  assert_false(managed_moonclaw_binding("v0.1.5/other") is Ok(_))
  assert_false(managed_moonclaw_binding("v0.1.5\n--help") is Ok(_))
}

///|
test "managed runtime registry selection is bounded to deployment roots" {
  debug_inspect(
    managed_runtime_root_from_values(
      "/opt/moondesk", "/Applications/MoonDesk", "/Users/test",
    ),
    content="Ok(\"/opt/moondesk\")",
  )
  debug_inspect(
    managed_runtime_root_from_values(
      "", "/Applications/MoonDesk", "/Users/test",
    ),
    content="Ok(\"/Applications/MoonDesk/runtimes\")",
  )
  debug_inspect(
    managed_runtime_root_from_values("", "", "/Users/test"),
    content="Ok(\"/Users/test/Library/Application Support/app.vectie.moondesk/runtimes\")",
  )
  assert_true(managed_runtime_root_from_values("relative", "", "") is Err(_))
  assert_true(
    managed_runtime_root_from_values("/tmp/bad\nroot", "", "") is Err(_),
  )
}

///|
test "managed MoonClaw daemon command and environment are fixed" {
  debug_inspect(
    moonclaw_daemon_arguments("/srv/moonsuite"),
    content="[\"daemon\", \"--port\", \"0\", \"--serve\", \"/srv/moonsuite\"]",
  )
  let environment = moonclaw_daemon_environment("/Users/test")
  assert_eq(environment.length(), 5)
  assert_eq(environment["HOME"], "/Users/test")
  assert_eq(environment["LANG"], "C.UTF-8")
  assert_eq(environment["TMPDIR"], "/tmp")
  assert_false(environment.contains("MOONCLAW_RELEASE_MANIFEST_URL"))
  assert_false(environment.contains("OPENROUTER_API_KEY"))
}
