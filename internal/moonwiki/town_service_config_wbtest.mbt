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
    moonsuite_product_dir(root, "moontown"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    town_service_config_path(root),
    (
      {
        "kind": "moondesk-town-service.v1",
        "cwd": "/opt/moontown-runtime",
        "daemon": {
          "command": "/usr/local/bin/moontown",
          "args": ["daemon", "run"],
        },
        "tick": {
          "command": "/usr/local/bin/moontown",
          "args": ["daemon", "tick"],
        },
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )

  let configured = town_service_descriptor(root, "daemon")
  assert_true(json_bool(configured, "configured", default=false))
  assert_eq(
    json_string(configured, "command", default=""),
    "/usr/local/bin/moontown",
  )
  assert_eq(json_string(configured, "cwd", default=""), "/opt/moontown-runtime")
  assert_true(json_string_array_items(configured, "args") == ["daemon", "run"])
  assert_eq(
    json_string(configured, "display", default=""),
    "/usr/local/bin/moontown daemon run",
  )

  let tick = town_service_descriptor(root, "tick")
  assert_true(json_string_array_items(tick, "args") == ["daemon", "tick"])
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
  assert_true(
    json_string(result, "message", default="").contains(
      "service is not configured",
    ),
  )
}
