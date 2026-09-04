///|
test "agent passport derives capabilities and bounded example tasks purely" {
  let inventory : AgentPassportInventory = {
    knowledge_count: 3,
    skill_count: 2,
    schema_count: 1,
    tool_count: 0,
    app_count: 1,
    recurring_work_count: 1,
  }
  assert_eq(agent_passport_capabilities(inventory), [
    "Evidence-backed answers", "Reviewed procedures", "Structured briefs", "Interactive workspace",
    "Recurring work",
  ])
  assert_eq(
    agent_passport_example_tasks(["One", "Two", "Three", "Four"], inventory),
    ["One", "Two", "Three"],
  )
}

///|
async test "agent catalog projects installed MoonBooks as readable passports" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-agent-library-wbtest-" + @async.now().to_string(),
  )
  assert_true(prepare_moonsuite_workspace_root(root))
  let book = @pathx.join(root, "books/research-guide")
  @fsx.make_directory(@pathx.join(book, "wiki"), recursive=true, exists_ok=true)
  @fsx.make_directory(@pathx.join(book, "raw"), recursive=true, exists_ok=true)
  @fsx.make_directory(
    @pathx.join(book, "skills"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(book, "schemas"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(book, "automations"),
    recursive=true,
    exists_ok=true,
  )
  let metadata =
    #|{"book_id":"research-guide","title":"Research Guide","summary":"Find and explain trusted evidence.","version":"2.1.0","example_tasks":["Compare sources","Prepare a brief"]}
  @fsx.write_to_file(
    @pathx.join(book, "book.json"),
    metadata + "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book, "wiki/index.md"),
    "# Guide\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book, "raw/source.md"),
    "source\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book, "skills/research.md"),
    "skill\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book, "schemas/brief.json"),
    "{}\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book, "automations/watch.json"),
    "{}\n",
    create=0o644,
  )
  let catalog = installed_agent_catalog(root)
  assert_eq(
    json_string(catalog, "contract_id", default=""),
    "moonsuite.agent-catalog.v1",
  )
  assert_eq(json_int(catalog, "agent_count", default=0), 1)
  let agents = json_array_items(catalog, "agents")
  assert_eq(json_string(agents[0], "name", default=""), "Research Guide")
  assert_eq(
    json_string(agents[0], "summary", default=""),
    "Find and explain trusted evidence.",
  )
  assert_eq(json_string(agents[0], "version", default=""), "2.1.0")
  assert_eq(json_int(agents[0], "knowledge_count", default=0), 2)
  assert_eq(json_int(agents[0], "skill_count", default=0), 1)
  assert_eq(json_int(agents[0], "recurring_work_count", default=0), 1)
  assert_eq(json_string_array_items(agents[0], "example_tasks"), [
    "Compare sources", "Prepare a brief",
  ])
}
