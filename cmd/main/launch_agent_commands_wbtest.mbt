///|
async test "town launch agent template rejects workspace-controlled execution config" {
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
  assert_true(town_daemon_launch_agent_plist(book_root) is None)
}
