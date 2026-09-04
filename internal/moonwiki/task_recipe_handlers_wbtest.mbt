///|
test "task recipe schemas reject missing decisions and render a stable brief" {
  let recipe = task_recipe_by_id("document-review").unwrap()
  assert_true(task_recipe_normalize_inputs(recipe, { "inputs": {} }) is Err(_))
  let inputs = task_recipe_normalize_inputs(recipe, {
    "inputs": {
      "review_goal": "Prepare for approval",
      "risk_focus": "Unsupported claims",
      "context": "Executive audience",
    },
  }).unwrap()
  let prompt = task_recipe_prompt(recipe, inputs)
  assert_true(prompt.contains("Prepare for approval"))
  assert_true(prompt.contains("Unsupported claims"))
  assert_true(prompt.contains("proposed document changes reviewable"))
}

///|
async test "task recipe instances persist the confirmed brief" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-task-recipe-wbtest-" + @async.now().to_string(),
  )
  assert_true(prepare_moonsuite_workspace_root(root))
  let book = @pathx.join(root, "books/brief-book")
  @fsx.make_directory(book, recursive=true, exists_ok=true)
  @fsx.write_to_file(
    @pathx.join(book, "book.json"),
    "{\"book_id\":\"brief-book\",\"title\":\"Brief Book\"}\n",
    create=0o644,
  )
  let workspace_id = @desk.stable_id("book", "brief-book")
  let instance = create_task_recipe_instance(
    root,
    {
      "workspace_id": workspace_id,
      "recipe_id": "board-brief",
      "inputs": {
        "period": "Q3 2026",
        "audience": "Board",
        "source_set": "Current book",
        "tone": "Concise",
      },
    },
    "2026-09-04T13:00:00Z",
  ).unwrap()
  assert_eq(json_string(instance, "status", default=""), "ready")
  assert_true(json_string(instance, "prompt", default="").contains("Q3 2026"))
  let saved = read_json_array_file(task_recipe_instances_path(root))
  assert_eq(saved.length(), 1)
  assert_eq(json_string(saved[0], "recipe_id", default=""), "board-brief")
}
