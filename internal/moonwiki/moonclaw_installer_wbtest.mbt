///|
test "platform support is explicit and independent of string validity" {
  let macos = moonclaw_platform_support_from_values("macos", "arm64")
  assert_true(macos.supported)
  assert_eq(macos.platform, "macos")
  assert_eq(macos.architecture, "arm64")
  assert_false(
    moonclaw_platform_support_from_values("linux", "arm64").supported,
  )
  assert_false(
    moonclaw_platform_support_from_values("linux", "x86_64").supported,
  )
  assert_false(
    moonclaw_platform_support_from_values("macos", "x86_64").supported,
  )
  assert_false(
    moonclaw_platform_support_from_values("unsupported", "x86_64").supported,
  )
  assert_false(
    moonclaw_platform_support_from_values("macos", "unsupported").supported,
  )
  assert_false(
    moonclaw_platform_support_from_values("windows", "x86_64").supported,
  )
  let json = moonclaw_platform_support_json(macos)
  assert_true(json_bool(json, "supported", default=false))
  assert_eq(json_string(json, "platform", default=""), "macos")
  assert_eq(json_string(json, "architecture", default=""), "arm64")
}

///|
async test "supported updater fails closed without a host fallback" {
  let result = install_moonclaw_release_for_platform(
    "/tmp/moondesk-moonclaw-updater-refusal-wbtest",
    moonclaw_platform_support_from_values("macos", "arm64"),
  )
  assert_false(json_bool(result, "ok", default=true))
  assert_false(json_bool(result, "repair_available", default=true))
  assert_eq(
    json_string(result, "status", default=""),
    "updater_sandbox_unavailable",
  )
  assert_eq(
    json_string(result, "next_action", default=""),
    "configure_execution_sandbox",
  )
  assert_true(
    json_string(result, "message", default="").contains(
      "refused to run the MoonClaw updater on the host",
    ),
  )
  let boundary = json_object_field(result, "updater_boundary").unwrap()
  assert_eq(
    json_string(boundary, "kind", default=""),
    "execution-sandbox-updater.v1",
  )
  assert_false(json_bool(boundary, "available", default=true))
  assert_eq(json_string(boundary, "fallback", default=""), "deny")
  assert_false(json_bool(boundary, "host_process_fallback", default=true))
}

///|
async test "unsupported platform keeps its specific refusal" {
  let result = install_moonclaw_release_for_platform(
    "/tmp/moondesk-moonclaw-unsupported-install-wbtest",
    moonclaw_platform_support_from_values("unsupported", "unsupported"),
  )
  assert_false(json_bool(result, "ok", default=true))
  assert_eq(json_string(result, "status", default=""), "platform_unsupported")
  assert_eq(
    json_string(result, "next_action", default=""),
    "review_supported_platforms",
  )
  assert_true(
    json_string(result, "message", default="").contains(
      "not supported for unsupported unsupported",
    ),
  )
  let boundary = json_object_field(result, "updater_boundary").unwrap()
  assert_false(json_bool(boundary, "available", default=true))
  assert_eq(json_string(boundary, "fallback", default=""), "deny")
}

///|
test "moonclaw runtime root follows the packaged app data directory" {
  assert_eq(
    moonclaw_runtime_root_from_environment(
      "", "/tmp/MoonDesk Application Support", "/Users/demo",
    ),
    "/tmp/MoonDesk Application Support/runtimes",
  )
  assert_eq(
    moonclaw_runtime_root_from_environment(
      "/tmp/explicit-runtime", "/tmp/app-data", "/Users/demo",
    ),
    "/tmp/explicit-runtime",
  )
  assert_eq(moonclaw_runtime_root_from_environment("", "", ""), "")
}

///|
test "managed release version rejects path and control injection" {
  assert_true(moonclaw_release_segment_valid("0.1.5"))
  assert_true(moonclaw_release_segment_valid("moonclaw-0.1.5_arm64"))
  assert_false(moonclaw_release_segment_valid("../moonclaw"))
  assert_false(moonclaw_release_segment_valid("moonclaw/runtime"))
  assert_false(moonclaw_release_segment_valid("moonclaw\n0.1.5"))
  assert_false(moonclaw_release_segment_valid(""))
}
