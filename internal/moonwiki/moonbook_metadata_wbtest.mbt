///|
test "canonical MoonBook TOML metadata exposes title and optional identity" {
  let metadata = moonbook_toml_book_metadata(
    "[book]\ntitle = \"CLI Research Book\"\nid = \"cli-research\"\nsrc = \"wiki\"\n\n[build]\nbuild-dir = \"book\"\n",
  )
  assert_eq(json_string(metadata, "title", default=""), "CLI Research Book")
  assert_eq(json_string(metadata, "id", default=""), "cli-research")
}

///|
async test "canonical MoonBook CLI folders import without fabricated book json" {
  let root = @fs.tmpdir(prefix="moondesk-canonical-book-import-")
  let source = @pathx.join(root, "source")
  let suite = @pathx.join(root, "suite")
  @fs.mkdir(@pathx.join(source, "wiki"), permission=0o755, recursive=true)
  let book_toml = "[book]\ntitle = \"CLI Research Book\"\nsrc = \"wiki\"\n\n[build]\nbuild-dir = \"book\"\n"
  let wiki_toml = "[wiki]\nsource = \"wiki\"\n"
  @fsx.write_to_file(@pathx.join(source, "book.toml"), book_toml, create=0o644)
  @fsx.write_to_file(@pathx.join(source, "wiki.toml"), wiki_toml, create=0o644)
  @fsx.write_to_file(
    @pathx.join(source, "wiki/index.md"),
    "# CLI Research Book\n",
    create=0o644,
  )
  let result = import_existing_moonbook_workspace(suite, {
    "source_path": source,
    "book_id": "cli-research",
  })
  guard result is Ok(imported) else {
    fail("canonical MoonBook import was rejected")
  }
  assert_eq(json_string(imported, "book_id", default=""), "cli-research")
  assert_eq(json_string(imported, "name", default=""), "CLI Research Book")
  let imported_root = @pathx.join(suite, "books/cli-research")
  assert_false(@fs.exists(@pathx.join(imported_root, "book.json")))
  assert_eq(
    @fs.read_file(@pathx.join(imported_root, "book.toml")).text(),
    book_toml,
  )
  assert_eq(
    @fs.read_file(@pathx.join(imported_root, "wiki.toml")).text(),
    wiki_toml,
  )
  assert_eq(
    moonbook_workspace_display_name(imported_root, "fallback"),
    "CLI Research Book",
  )
  assert_true(moonbook_workspace_status(imported_root) is Ready)
  assert_true(validated_library_root(source) is Err(_))
}
