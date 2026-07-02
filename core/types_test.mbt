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
test "desk file kinds cover explorer preview surface" {
  assert_true(@core.infer_entry_kind("wiki", is_directory=true) is Directory)
  assert_true(@core.infer_entry_kind("wiki/index.markdown") is Markdown)
  assert_true(@core.infer_entry_kind("docs/README.mbt.md") is Markdown)
  assert_true(@core.infer_entry_kind("site/generated/index.HTML") is Html)
  assert_true(@core.infer_entry_kind("raw/data.jsonl") is Json)
  assert_true(@core.infer_entry_kind("images/logo.SVG") is Image)
  assert_true(@core.infer_entry_kind("logs/run.log") is Text)
  assert_true(@core.infer_entry_kind("raw/archive.pdf") is Unknown)
  assert_true(@core.renderer_for_kind(Directory) is DirectoryListing)
  assert_true(@core.renderer_for_kind(Image) is Image)
  assert_true(@core.renderer_for_kind(Unknown) is Unsupported)
}

///|
test "stable ids normalize paths" {
  assert_eq(
    @core.stable_id("book", "Research OPC/wiki/index.md"),
    "book-research-opc-wiki-index-md",
  )
}

///|
test "display names handle root-like and encoded-looking paths" {
  assert_eq(@core.display_name(""), "")
  assert_eq(@core.display_name("wiki/"), "wiki")
  assert_eq(
    @core.display_name("docs with spaces/encoded # name.md"),
    "encoded # name.md",
  )
  assert_eq(@core.display_name("raw/data%3Fset.json"), "data%3Fset.json")
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

///|
test "source layer inference covers desk explorer roots" {
  assert_true(@core.infer_source_layer("wiki/history/change.md") is History)
  assert_true(@core.infer_source_layer("raw/nested/source.csv") is RawEvidence)
  assert_true(@core.infer_source_layer("inbox/imports/paste.md") is Inbox)
  assert_true(@core.infer_source_layer("apps/demo/index.html") is App)
  assert_true(@core.infer_source_layer("app/index.html") is App)
  assert_true(@core.infer_source_layer("book/outputs/report.pdf") is BookOutput)
  assert_true(
    @core.infer_source_layer(".moonsuite/products/moontown/town.json") is Config,
  )
  assert_true(
    @core.infer_source_layer(".tmp/products/mooncode/scratch") is Config,
  )
  assert_true(
    @core.infer_source_layer(
      ".moonsuite/products/moonclaw/jobs/run-1/log.jsonl",
    )
    is RunArtifact,
  )
  assert_true(
    @core.infer_source_layer("moonclaw-jobs/run-1/log.jsonl") is Workspace,
  )
  assert_true(@core.infer_source_layer("notes/local.txt") is Workspace)
}

///|
test "moonsuite internal relative path helper covers state and temp roots" {
  assert_eq(@core.moonsuite_state_display_dir(), ".moonsuite")
  assert_eq(@core.moonsuite_tmp_display_dir(), ".tmp")
  assert_true(@core.moonsuite_internal_relative_path(".moonsuite"))
  assert_true(
    @core.moonsuite_internal_relative_path(
      ".moonsuite/products/moondesk/preferences/views.json",
    ),
  )
  assert_true(@core.moonsuite_internal_relative_path(".tmp/products/mooncode"))
  assert_true(@core.moonsuite_internal_relative_path("/.tmp/products/mooncode"))
  assert_false(@core.moonsuite_internal_relative_path("wiki/.tmp-note.md"))
  assert_false(@core.moonsuite_internal_relative_path("notes/local.txt"))
}
