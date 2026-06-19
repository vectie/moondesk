///|
test "infer file kind and renderer" {
  let entry = @core.file_entry(
    workspace_id="research-opc",
    path="wiki/index.md",
  )
  assert_eq(entry.display_name, "index.md")
  assert_true(entry.kind == Markdown)
  assert_true(entry.source_layer == Wiki)
  assert_true(@core.renderer_for_kind(entry.kind) == Markdown)
}

///|
test "stable ids normalize paths" {
  assert_eq(
    @core.stable_id("book", "Research OPC/wiki/index.md"),
    "book-research-opc-wiki-index-md",
  )
}
