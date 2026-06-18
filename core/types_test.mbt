///|
test "infer file kind and renderer" {
  let entry = file_entry(workspace_id="research-opc", path="wiki/index.md")
  assert_eq(entry.display_name, "index.md")
  assert_true(entry.kind == @core.EntryKind::Markdown)
  assert_true(entry.source_layer == @core.SourceLayer::Wiki)
  assert_true(renderer_for_kind(entry.kind) == @core.PreviewRenderer::Markdown)
}

///|
test "stable ids normalize paths" {
  assert_eq(
    stable_id("book", "Research OPC/wiki/index.md"),
    "book-research-opc-wiki-index-md",
  )
}
