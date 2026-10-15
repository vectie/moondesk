///|
test "coding setup requires a skill entry point and unique supporting files" {
  assert_true(
    mooncode_setup_skill_files({
      "id": "review",
      "files": [{ "path": "notes.md", "content": "hi" }],
    })
    is Err(_),
  )
  assert_true(
    mooncode_setup_skill_files({
      "id": "review",
      "files": [
        { "path": "SKILL.md", "content": "hi" },
        { "path": "SKILL.md", "content": "hi" },
      ],
    })
    is Err(_),
  )
  assert_true(
    mooncode_setup_skill_files({
      "id": "review",
      "files": [
        {
          "path": "SKILL.md",
          "content": "---\nname: review\ndescription: Review changes\n---\nInstructions",
        },
        { "path": "references/example.md", "content": "example" },
      ],
    })
    is Ok(_),
  )
}

///|
async test "coding setup persists skills instructions presets and previous versions" {
  let root = "/tmp/moondesk-coding-setup-" + @async.now().to_string()
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let first = mooncode_setup_apply(root, "book", {
    "action": "save-skill",
    "id": "review",
    "files": [
      {
        "path": "SKILL.md",
        "content": "---\nname: review\ndescription: Review changes\n---\nRead changes",
      },
      { "path": "references/example.md", "content": "Example" },
    ],
  }).unwrap()
  assert_eq(json_array_items(first, "skills").length(), 1)
  let skill_path = moonsuite_product_artifact_for_workspace_root(
    root, "moonclaw", "skills/review/SKILL.md",
  )
  assert_true(@fsx.read_file(skill_path).contains("Read changes"))
  ignore(
    mooncode_setup_apply(root, "book", {
      "action": "save-skill",
      "id": "review",
      "files": [
        {
          "path": "SKILL.md",
          "content": "---\nname: review\ndescription: Review changes\n---\nUpdated instructions",
        },
      ],
    }).unwrap(),
  )
  assert_false(
    @fsx.exists(
      @pathx.join(@pathx.dirname(skill_path), "references/example.md"),
    ),
  )
  ignore(
    mooncode_setup_apply(root, "book", {
      "action": "save-instructions",
      "content": "Always explain user-visible changes.",
    }).unwrap(),
  )
  ignore(
    mooncode_setup_apply(root, "book", {
      "action": "save-presets",
      "presets": [
        {
          "name": "Review",
          "model": "moongate/example",
          "reasoning": "high",
          "task_intent": "read_only",
        },
      ],
    }).unwrap(),
  )
  ignore(
    mooncode_setup_apply(root, "book", {
      "action": "save-templates",
      "templates": [{ "name": "Review", "text": "Review the selected change." }],
    }).unwrap(),
  )
  let reopened = mooncode_setup_snapshot(root, "book")
  assert_eq(
    json_string(reopened, "instructions", default=""),
    "Always explain user-visible changes.",
  )
  assert_eq(json_array_items(reopened, "presets").length(), 1)
  assert_eq(json_array_items(reopened, "templates").length(), 1)
  let history = json_array_items(reopened, "history")
  assert_eq(history.length(), 5)
  assert_eq(json_array_items(history[3], "previous_files").length(), 2)
  let other_book = mooncode_setup_snapshot(root, "other-book")
  assert_eq(json_array_items(other_book, "presets").length(), 0)
}
