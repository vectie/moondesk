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

///|
test "infer executable book source layers" {
  assert_true(@core.infer_source_layer("wiki/reviews") is Review)
  assert_true(@core.infer_source_layer("skills") is Skill)
  assert_true(@core.infer_source_layer("skills/pdf-watch/SKILL.md") is Skill)
  assert_true(@core.infer_source_layer("schemas") is Schema)
  assert_true(@core.infer_source_layer("schemas/report.schema.md") is Schema)
  assert_true(@core.infer_source_layer("tools") is Tool)
  assert_true(@core.infer_source_layer("tools/demo/main.mbt") is Tool)
  assert_true(@core.infer_source_layer("apps") is App)
  assert_true(@core.infer_source_layer("apps/demo/index.html") is App)
  assert_true(@core.infer_source_layer("app/index.html") is App)
  assert_true(@core.infer_source_layer("portable/app-tool") is PortableAppTool)
  assert_true(
    @core.infer_source_layer("portable/app-tool/demo/index.html")
    is PortableAppTool,
  )
  assert_true(
    @core.infer_source_layer("portable/app-tool/app/index.html")
    is PortableAppTool,
  )
  assert_true(@core.infer_source_layer("site/generated") is GeneratedSite)
  assert_true(@core.infer_source_layer("book/site/generated") is GeneratedSite)
}
