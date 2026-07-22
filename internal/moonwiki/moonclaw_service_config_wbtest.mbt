///|
async test "moonclaw service descriptor is explicit and workspace local" {
  let root = "/tmp/moondesk-moonclaw-service-config-wbtest-" +
    @desk.stable_id("moonclaw-service", @async.now().to_string())
  let missing = moonclaw_service_descriptor(root, "daemon")
  assert_false(json_bool(missing, "configured", default=true))
  assert_eq(json_string(missing, "command", default="missing"), "")
  assert_eq(
    json_string(missing, "config_path", default=""),
    @pathx.join(root, ".moonsuite/products/moonclaw/service.json"),
  )

  @fsx.make_directory(
    moonsuite_product_dir(root, "moonclaw"),
    recursive=true,
    exists_ok=true,
  )
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
  assert_false(json_bool(configured, "managed_install", default=true))
  assert_eq(json_string(configured, "version", default="missing"), "")
}

///|
test "managed MoonClaw service requires version path and installed binary" {
  let binary = "/tmp/runtime/moonclaw/0.1.3/bin/moonclaw"
  assert_true(moonclaw_managed_service_matches("0.1.3", binary, binary, true))
  assert_false(moonclaw_managed_service_matches("", binary, binary, true))
  assert_false(
    moonclaw_managed_service_matches(
      "0.1.3", "/Users/demo/Workspace/moonclaw", binary, true,
    ),
  )
  assert_false(moonclaw_managed_service_matches("0.1.3", binary, binary, false))
}

///|
async test "moonclaw service descriptor ignores implicit checkout fallback" {
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

  let result = moonclaw_service_descriptor(root, "daemon")
  assert_false(json_bool(result, "configured", default=true))
  assert_eq(json_string(result, "command", default="missing"), "")
  assert_eq(json_string(result, "source", default=""), "missing")
}

///|
test "moonclaw checkout candidates exclude stale home compatibility paths" {
  let candidates = moonclaw_checkout_candidates("")
  assert_eq(candidates.length(), 0)
}

///|
test "moonclaw checkout candidates prefer explicit environment root" {
  let candidates = moonclaw_checkout_candidates("/opt/moonclaw-runtime")
  guard candidates.get(0) is Some(first) else {
    fail("expected at least one MoonClaw candidate")
  }
  assert_eq(first.path, "/opt/moonclaw-runtime")
  assert_eq(first.source, "env-moonclaw-root")
}

///|
test "moonclaw existing daemon reachability does not require workspace service config" {
  assert_true(moonclaw_existing_daemon_reachable(true, 63907, true, true))
  assert_false(moonclaw_existing_daemon_reachable(false, 63907, true, true))
  assert_false(moonclaw_existing_daemon_reachable(true, 0, true, true))
  assert_false(moonclaw_existing_daemon_reachable(true, 63907, false, true))
  assert_false(moonclaw_existing_daemon_reachable(true, 63907, true, false))
}

///|
test "moonclaw unconfigured daemon reuse skips temporary test roots" {
  assert_true(
    moonclaw_allows_unconfigured_existing_daemon(
      workspace_context("/home/example/moonsuite"),
    ),
  )
  assert_false(
    moonclaw_allows_unconfigured_existing_daemon(
      workspace_context("/tmp/moondesk-mooncode-test"),
    ),
  )
  assert_false(
    moonclaw_allows_unconfigured_existing_daemon(
      workspace_context("/private/var/folders/demo/moondesk-test"),
    ),
  )
}

///|
async test "moonclaw daemon probe uses MoonSuite product home" {
  let suite_root = "/tmp/moondesk-moonclaw-daemon-product-home-wbtest"
  let book_root = @pathx.join(suite_root, "books/research-book")
  assert_eq(
    moonclaw_daemon_info_path(book_root),
    @pathx.join(suite_root, ".moonsuite/products/moonclaw/daemon.json"),
  )
  assert_eq(
    moonclaw_daemon_info_path("/tmp/standalone-book"),
    "/tmp/standalone-book/.moonsuite/products/moonclaw/daemon.json",
  )
  let status = moonclaw_daemon_status(book_root)
  assert_eq(
    json_string(status, "info_path", default=""),
    @pathx.join(suite_root, ".moonsuite/products/moonclaw/daemon.json"),
  )
  assert_false(json_bool(status, "managed_install", default=true))
  assert_eq(
    json_string(status, "message", default=""),
    "MoonClaw is not installed",
  )
}

///|
test "zombie MoonClaw process is not considered alive" {
  assert_false(process_status_is_alive("Z"))
  assert_false(process_status_is_alive("Z+\n"))
  assert_false(process_status_is_alive(""))
  assert_true(process_status_is_alive("S+"))
  assert_true(process_status_is_alive("R"))
}
