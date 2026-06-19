///|
async test "moonclaw service descriptor is explicit and workspace local" {
  let root = "/tmp/moondesk-moonclaw-service-config-wbtest-" +
    @desk.stable_id("moonclaw-service", @async.now().to_string())
  let missing = moonclaw_service_descriptor(root, "daemon")
  assert_false(json_bool(missing, "configured", default=true))
  assert_eq(json_string(missing, "command", default="missing"), "")
  assert_eq(
    json_string(missing, "config_path", default=""),
    @pathx.join(root, ".moontown/moondesk-daemon/moonclaw-service.json"),
  )

  @fsx.make_directory(moondesk_daemon_dir(root), recursive=true, exists_ok=true)
  @fsx.write_to_file(
    moonclaw_service_config_path(root),
    (
      {
        "kind": "moondesk-moonclaw-service.v1",
        "cwd": "/opt/moonclaw-runtime",
        "daemon": {
          "command": "/usr/local/bin/moonclaw",
          "args": ["daemon", "--port", "0"],
        },
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )

  let configured = moonclaw_service_descriptor(root, "daemon")
  assert_true(json_bool(configured, "configured", default=false))
  assert_eq(
    json_string(configured, "command", default=""),
    "/usr/local/bin/moonclaw",
  )
  assert_eq(json_string(configured, "cwd", default=""), "/opt/moonclaw-runtime")
  assert_true(
    json_string_array_items(configured, "args") == ["daemon", "--port", "0"],
  )
  assert_eq(
    json_string(configured, "display", default=""),
    "/usr/local/bin/moonclaw daemon --port 0",
  )
}

///|
async test "moonclaw daemon start refuses implicit sibling checkout fallback" {
  let parent = "/tmp/moondesk-moonclaw-service-missing-wbtest-" +
    @desk.stable_id("moonclaw-service-missing", @async.now().to_string())
  let root = @pathx.join(parent, "workspace")
  let sibling = @pathx.join(@pathx.dirname(root).to_owned(), "moonclaw")
  @fsx.make_directory(
    @pathx.join(sibling, "cmd/main"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(sibling, "moon.mod"),
    "name = \"fake\"\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(sibling, "cmd/main/moon.pkg"),
    "{}\n",
    create=0o644,
  )

  let result = ensure_moonclaw_daemon(root)
  assert_false(json_bool(result, "ok", default=true))
  assert_false(json_bool(result, "running", default=true))
  assert_false(json_bool(result, "service_configured", default=true))
  assert_true(
    json_string(result, "message", default="").contains(
      "service is not configured",
    ),
  )
}
