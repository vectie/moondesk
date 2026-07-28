///|
async test "workspace preview handles text image virtual and missing entries" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-preview-wbtest-" + @async.now().to_string(),
  )
  @fsx.make_directory(@pathx.join(root, "wiki"), recursive=true)
  @fsx.make_directory(@pathx.join(root, "images"), recursive=true)
  @fsx.write_to_file(@pathx.join(root, "wiki/index.md"), "# Desk\n")
  @fsx.write_to_file(@pathx.join(root, "images/logo.png"), "png-bytes")
  let workspace = @desk.workspace(
    id="book-demo",
    name="Demo",
    root_path=root,
    kind=MoonBook,
  )

  let markdown = workspace_file_entry(
    workspace,
    "wiki/index.md",
    @pathx.join(root, "wiki/index.md"),
  )
  let markdown_preview = @desk.preview(
    markdown,
    body=@fs.read_file(@pathx.join(root, "wiki/index.md")).text(),
  )
  assert_true(markdown_preview.renderer is Markdown)
  assert_true(markdown_preview.body.contains("# Desk"))

  let image = workspace_file_entry(
    workspace,
    "images/logo.png",
    @pathx.join(root, "images/logo.png"),
  )
  assert_true(is_binary_preview(image.kind))
  let image_preview = @desk.preview(
    image,
    body="/api/workspaces/book-demo/raw?path=images/logo.png",
  )
  assert_true(image_preview.renderer is Image)
  assert_true(image_preview.body.contains("/raw?path=images/logo.png"))

  let section = moonbook_section_for_path("schemas")
  match section {
    Some(value) => {
      let entry = moonbook_section_entry(
        workspace,
        value,
        @pathx.join(root, "schemas"),
      )
      let virtual_preview = @desk.preview(entry, body="", warnings=[
        "Virtual MoonBook section has no files yet.",
      ])
      assert_true(virtual_preview.renderer is DirectoryListing)
      assert_eq(virtual_preview.warnings.length(), 1)
    }
    None => fail("missing schemas section")
  }
}
