///|
async test "town launch agent logs resolve through owning suite for book roots" {
  let suite_root = @pathx.join(
    "/tmp",
    "moondesk-town-launch-agent-wbtest-" + @async.now().to_string(),
  )
  let book_root = @pathx.join(suite_root, "books/research-town")
  @fsx.make_directory(
    @pathx.dirname(@moonwiki.town_service_config_path(book_root)).to_owned(),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @moonwiki.town_service_config_path(book_root),
    (
      {
        "kind": "moondesk-town-service.v1",
        "cwd": "/opt/moontown",
        "daemon": {
          "command": "/usr/local/bin/moontown",
          "args": ["daemon", "run"],
        },
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  let plist = match town_daemon_launch_agent_plist(book_root) {
    Some(value) => value
    None => {
      fail("expected configured town launch agent")
      ""
    }
  }
  assert_true(
    plist.contains(
      @pathx.join(
        suite_root, ".moonsuite/products/moondesk/daemon/launch-agent.out.log",
      ),
    ),
  )
  assert_true(
    plist.contains(
      @pathx.join(
        suite_root, ".moonsuite/products/moondesk/daemon/launch-agent.err.log",
      ),
    ),
  )
  assert_false(plist.contains("/books/research-town/.moonsuite/"))
}
