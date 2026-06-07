///|
async test "app tool portable export copies a direct toolbook bundle" {
  let root = "/tmp/moondesk-app-tool-portable-direct-wbtest"
  let book_id = "tool-registry-portable"
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  @fsx.make_directory(
    @pathx.join(book_root, "book/site/generated"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(book_root, "book/outputs"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(book_root, "app"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(book_root, "skills/tool-watch"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "book.json"),
    (
      {
        "id": book_id,
        "title": "Registry Portable Tool",
        "book_type": "toolbook",
        "template_id": "app-tool-book",
        "tool_binding": {
          "template_id": "app-tool-book",
          "manifest_path": "tool-manifest.json",
          "entrypoints": ["book/site/generated/tool.html", "app/index.html"],
        },
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "tool-manifest.json"),
    (
      {
        "kind": "app-tool-book-manifest",
        "template_id": "app-tool-book",
        "book_id": book_id,
        "tool": {
          "id": "registry-portable-tool",
          "title": "Registry Portable Tool",
          "entrypoints": ["book/site/generated/tool.html", "app/index.html"],
        },
        "outputs": { "report": "book/outputs/report.txt" },
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "book/site/generated/tool.html"),
    "<!doctype html><meta charset=\"utf-8\"><a href=\"../../outputs/report.txt\">Report</a>",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "app/index.html"),
    "<!doctype html><meta charset=\"utf-8\"><script type=\"module\" src=\"tool.js\"></script>",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "app/tool.js"),
    "document.body.dataset.ready = 'true'\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "book/outputs/report.txt"),
    "accepted output\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "skills/tool-watch/SKILL.md"),
    "---\nname: tool-watch\n---\n",
    create=0o644,
  )

  let result = export_app_tool_portable_bundle(root, book_root, book_id)
  assert_true(json_bool(result, "ok", default=false))
  assert_eq(json_string(result, "status", default=""), "portable_ready")
  assert_true(
    @fs.exists(
      @pathx.join(book_root, "portable/app-tool/book/site/generated/tool.html"),
    ),
  )
  assert_true(
    @fs.exists(
      @pathx.join(book_root, "portable/app-tool/book/outputs/report.txt"),
    ),
  )
  let index = @fs.read_file(
    @pathx.join(book_root, "portable/app-tool/index.html"),
  ).text()
  assert_true(index.contains("iframe src=\"book/site/generated/tool.html\""))
  let status = app_tool_portable_status(root, book_root, book_id)
  assert_eq(json_string(status, "status", default=""), "portable_ready")
  assert_true(
    json_bool(status, "operatable_without_moondesk_api", default=false),
  )
}

///|
async test "app tool portable export supports research-book tool manifests and flags api dependencies" {
  let root = "/tmp/moondesk-app-tool-portable-research-wbtest"
  let book_id = "research-eb-portable-tool"
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  @fsx.make_directory(
    @pathx.join(book_root, "book/site/generated"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(book_root, "app"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "book.json"),
    (
      {
        "id": book_id,
        "title": "Research EB Portable Tool",
        "type": "research-book",
        "template_id": "pdf-evidence-watch",
        "toolbook": {
          "enabled": true,
          "template_id": "app-tool-book",
          "manifest_path": "tool-manifest.json",
          "entrypoints": ["book/site/generated/tool.html", "app/index.html"],
        },
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "tool-manifest.json"),
    (
      {
        "kind": "app-tool-book-manifest",
        "template_id": "app-tool-book",
        "book_id": book_id,
        "tool": {
          "id": "eb-evidence-dashboard",
          "title": "EB Evidence Dashboard",
          "entrypoints": ["book/site/generated/tool.html", "app/index.html"],
        },
        "outputs": {},
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "book/site/generated/tool.html"),
    "<!doctype html><meta charset=\"utf-8\"><h1>EB Evidence Tool</h1>",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "app/index.html"),
    "<!doctype html><meta charset=\"utf-8\"><script>fetch('/api/books/patterns')</script>",
    create=0o644,
  )

  let result = export_app_tool_portable_bundle(root, book_root, book_id)
  assert_true(json_bool(result, "ok", default=false))
  assert_eq(
    json_string(result, "status", default=""),
    "portable_with_api_warnings",
  )
  assert_true(
    json_string_array_items(result, "api_dependency_warnings").contains(
      "app/index.html",
    ),
  )
  let status = app_tool_portable_status(root, book_root, book_id)
  assert_eq(
    json_string(status, "status", default=""),
    "portable_with_api_warnings",
  )
  assert_true(
    !json_bool(status, "operatable_without_moondesk_api", default=true),
  )
}
