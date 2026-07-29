///|
async test "town service descriptor is explicit and workspace local" {
  let root = "/tmp/moondesk-town-service-config-wbtest-" +
    @desk.stable_id("town-service", @async.now().to_string())
  let daemon = town_service_descriptor(root, "daemon")
  assert_false(json_bool(daemon, "configured", default=true))
  assert_eq(json_string(daemon, "command", default="missing"), "")
  assert_eq(
    json_string(daemon, "config_path", default=""),
    @pathx.join(root, ".moonsuite/products/moontown/service.json"),
  )

  @fsx.make_directory(
    @pathx.dirname(town_service_config_path(root)),
    recursive=true,
    exists_ok=true,
  )
  let service_command = @pathx.join(root, "moontown")
  @fsx.write_to_file(service_command, "#!/bin/sh\nexit 0\n", create=0o755)
  @fsx.write_to_file(
    town_service_config_path(root),
    (
      {
        "kind": "moondesk-town-service.v1",
        "cwd": root,
        "daemon": { "command": service_command, "args": ["daemon", "run"] },
        "tick": { "command": service_command, "args": ["daemon", "tick"] },
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )

  let configured = town_service_descriptor(root, "daemon")
  assert_true(json_bool(configured, "configured", default=false))
  assert_eq(json_string(configured, "command", default=""), service_command)
  assert_true(json_bool(configured, "configuration_valid", default=false))
  assert_eq(
    json_string(configured, "configuration_reason", default=""),
    "configuration-valid",
  )
  assert_eq(json_string(configured, "cwd", default=""), root)
  assert_true(json_string_array_items(configured, "args") == ["daemon", "run"])
  assert_eq(
    json_string(configured, "display", default=""),
    service_command + " daemon run",
  )

  let tick = town_service_descriptor(root, "tick")
  assert_true(json_string_array_items(tick, "args") == ["daemon", "tick"])
  let status = daemon_status_record(root, "status")
  let platform = json_object_field(status, "platform_evidence").unwrap()
  assert_true(json_string(platform, "platform", default="") != "")
  assert_true(json_string(platform, "architecture", default="") != "")
  let installation = json_object_field(status, "installation_evidence").unwrap()
  assert_true(json_bool(installation, "installed", default=false))
  assert_eq(
    json_string(installation, "source", default=""),
    "service-configured",
  )
  let configuration = json_object_field(status, "configuration_evidence").unwrap()
  assert_true(json_bool(configuration, "configured", default=false))
  assert_true(json_bool(configuration, "valid", default=false))
  assert_eq(
    json_string(configuration, "reason", default=""),
    "configuration-valid",
  )
}

///|
async test "managed daemon start refuses implicit source checkout fallback" {
  let root = "/tmp/moondesk-town-service-missing-wbtest-" +
    @desk.stable_id("town-service-missing", @async.now().to_string())
  @fsx.make_directory(
    @pathx.join(root, "cmd/main"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(root, "moon.mod"),
    "name = \"fake\"\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(root, "cmd/main/moon.pkg"),
    "{}\n",
    create=0o644,
  )

  let result = start_managed_daemon(root)
  assert_false(json_bool(result, "ok", default=true))
  assert_eq(json_string(result, "status", default=""), "not-configured")
  assert_false(json_bool(result, "service_configured", default=true))
  let installation = json_object_field(result, "installation_evidence").unwrap()
  assert_false(json_bool(installation, "installed", default=true))
  assert_eq(json_string(installation, "source", default=""), "none")
  let configuration = json_object_field(result, "configuration_evidence").unwrap()
  assert_false(json_bool(configuration, "configured", default=true))
  assert_true(json_bool(configuration, "valid", default=false))
  assert_eq(json_string(configuration, "reason", default=""), "not-installed")
  assert_true(json_object_field(result, "platform_evidence") is Some(_))
  assert_eq(
    json_string(result, "service_config_path", default=""),
    town_service_config_path(root),
  )
  assert_eq(json_string(result, "service_cwd", default=""), root)
  assert_true(
    json_string(result, "message", default="").contains(
      "service is not configured",
    ),
  )
}

///|
async test "managed daemon rejects unusable service before lifecycle writes" {
  let root = "/tmp/moondesk-town-service-invalid-wbtest-" +
    @desk.stable_id("town-service-invalid", @async.now().to_string())
  @fsx.make_directory(
    @pathx.dirname(town_service_config_path(root)),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    town_service_config_path(root),
    (
      {
        "kind": "moondesk-town-service.v1",
        "cwd": root,
        "daemon": {
          "command": @pathx.join(root, "missing-moontown"),
          "args": ["daemon", "run"],
        },
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  let lifecycle_dir = moondesk_daemon_dir(root)
  assert_false(@fsx.exists(lifecycle_dir))
  let result = start_managed_daemon(root)
  assert_false(json_bool(result, "ok", default=true))
  assert_eq(json_string(result, "status", default=""), "misconfigured")
  let configuration = json_object_field(result, "configuration_evidence").unwrap()
  assert_true(json_bool(configuration, "configured", default=false))
  assert_false(json_bool(configuration, "valid", default=true))
  assert_eq(
    json_string(configuration, "reason", default=""),
    "command-unavailable",
  )
  assert_false(@fsx.exists(lifecycle_dir))
}
