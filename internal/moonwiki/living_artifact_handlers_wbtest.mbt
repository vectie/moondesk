///|
test "living artifacts validate kinds and project initial items" {
  assert_true(
    living_artifact_create(
      { "workspace_id": "book-one", "title": "Risk board", "kind": "terminal" },
      "2026-09-04T15:00:00Z",
    )
    is Err("invalid_living_artifact"),
  )
  let artifact = living_artifact_create(
    {
      "workspace_id": "book-one",
      "title": "Risk board",
      "kind": "tracker",
      "purpose": "Track decisions from the current document",
      "items": ["Confirm forecast", "Assign legal review"],
    },
    "2026-09-04T15:00:00Z",
  ).unwrap()
  assert_eq(json_string(artifact, "kind", default=""), "tracker")
  assert_eq(json_array_items(artifact, "items").length(), 2)
  assert_true(
    json_string(artifact, "path", default="").has_prefix(
      "book/site/generated/living/",
    ),
  )
}

///|
test "living artifact commands are immutable and revisioned" {
  let artifact = living_artifact_create(
    {
      "workspace_id": "book-one",
      "title": "Checklist",
      "kind": "checklist",
      "items": ["Validate totals"],
    },
    "2026-09-04T15:00:00Z",
  ).unwrap()
  let first = json_array_items(artifact, "items")[0]
  let item_id = json_string(first, "id", default="")
  let toggled = living_artifact_apply_command(
    artifact,
    { "command": "toggle-item", "item_id": item_id },
    "2026-09-04T15:05:00Z",
  ).unwrap()
  assert_true(
    json_bool(json_array_items(toggled, "items")[0], "done", default=false),
  )
  assert_false(json_bool(first, "done", default=false))
  assert_eq(json_int(toggled, "revision", default=0), 2)
  let changed = living_artifact_apply_command(
    toggled,
    { "command": "set-value", "item_id": item_id, "value": "Complete" },
    "2026-09-04T15:06:00Z",
  ).unwrap()
  assert_eq(
    json_string(json_array_items(changed, "items")[0], "value", default=""),
    "Complete",
  )
}

///|
test "living artifact shell uses a typed parent bridge without direct network" {
  let shell = living_artifact_shell("artifact-one")
  assert_true(shell.contains("moondesk.living-artifact-message.v1"))
  assert_true(shell.contains("parent.postMessage"))
  assert_false(shell.contains("fetch("))
  assert_false(shell.contains("localStorage"))
}

///|
async test "living artifacts persist state and an isolated workspace page" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-living-artifact-wbtest-" + @async.now().to_string(),
  )
  assert_true(prepare_moonsuite_workspace_root(root))
  let book = @pathx.join(root, "books/research-living")
  @fsx.make_directory(book, recursive=true, exists_ok=true)
  @fsx.write_to_file(
    @pathx.join(book, "book.json"),
    "{\"book_id\":\"research-living\",\"title\":\"Living Book\"}\n",
    create=0o644,
  )
  let workspace_id = @desk.stable_id("book", "research-living")
  let artifact = apply_living_artifact(
    root,
    {
      "workspace_id": workspace_id,
      "title": "Decision tracker",
      "kind": "tracker",
      "purpose": "Keep decisions current",
      "items": ["First decision"],
    },
    "2026-09-04T15:00:00Z",
  ).unwrap()
  let artifact_path = @pathx.join(
    book,
    json_string(artifact, "path", default=""),
  )
  assert_true(@fsx.exists(artifact_path))
  assert_true(@fsx.read_file(artifact_path).contains("parent.postMessage"))
  let records = read_json_array_file(living_artifacts_path(root))
  assert_eq(records.length(), 1)
}
