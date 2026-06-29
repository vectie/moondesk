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
    @pathx.join(book_root, "raw/excel"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(book_root, "app"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(book_root, "raw/analysis-runs"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(book_root, "assets"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(book_root, "app/chunks"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(book_root, "media"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(book_root, "raw/analysis-runs"),
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
        "outputs": {
          "report": "book/outputs/report.txt",
          "spreadsheet": "raw/excel/results.xlsx",
        },
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
    "<!doctype html><meta charset=\"utf-8\"><link rel=\"stylesheet\" href=\"styles.css\"><script type=\"module\" src=\"/assets/root-module.js\"></script><script type=\"module\" src=\"tool.js\"></script>",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "app/styles.css"),
    ".hero{background-image:url('/media/bg.png')}\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "app/tool.js"),
    "import './chunks/side-effect.js';\nconst logo = new URL('../media/bg.png', import.meta.url).href;\nfetch('/api/books/base-types').then(r => r.json()).then(items => { document.body.dataset.baseTypeCount = String(items.length); });\nfetch('/api/workspaces/book-demo/raw?path=book/outputs/report.txt').then(r => r.text()).then(text => { document.body.dataset.report = text.trim(); });\nfetch('/api/workspaces/book-demo/file/raw/excel/results.xlsx').then(r => { document.body.dataset.workbookStatus = String(r.status); });\ndocument.body.dataset.logo = logo;\ndocument.body.dataset.ready = 'true';\ndocument.body.textContent = 'portable app ready';\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "app/chunks/side-effect.js"),
    "document.body.dataset.sideEffect = 'loaded'\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "assets/root-module.js"),
    "document.body.dataset.rootModule = 'loaded'\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "media/bg.png"),
    "fake image bytes\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "book/outputs/report.txt"),
    "accepted output\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "raw/excel/results.xlsx"),
    "fake workbook bytes\n",
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
  assert_true(
    @fs.exists(
      @pathx.join(book_root, "portable/app-tool/raw/excel/results.xlsx"),
    ),
  )
  assert_true(
    @fs.exists(
      @pathx.join(book_root, "portable/app-tool/assets/root-module.js"),
    ),
  )
  assert_true(
    @fs.exists(@pathx.join(book_root, "portable/app-tool/media/bg.png")),
  )
  assert_true(
    @fs.exists(
      @pathx.join(book_root, "portable/app-tool/app/chunks/side-effect.js"),
    ),
  )
  assert_true(@fs.exists(@pathx.join(book_root, "portable/app-tool/serve.py")))
  let server_script = @fs.read_file(
    @pathx.join(book_root, "portable/app-tool/serve.py"),
  ).text()
  assert_true(server_script.contains("def choose_port(preferred):"))
  assert_true(server_script.contains("ReusableTCPServer"))
  assert_true(
    @fs.exists(@pathx.join(book_root, "portable/app-tool/run-local.command")),
  )
  let index = @fs.read_file(
    @pathx.join(book_root, "portable/app-tool/index.html"),
  ).text()
  assert_true(index.contains("iframe src=\"app/index.html\""))
  assert_true(index.contains("run-local.command"))
  let readme = @fs.read_file(
    @pathx.join(book_root, "portable/app-tool/README.md"),
  ).text()
  assert_true(readme.contains("python3 serve.py"))
  assert_eq(json_string(result, "entrypoint", default=""), "app/index.html")
  assert_eq(
    json_string(result, "standalone_runtime", default=""),
    "served-static-bundle",
  )
  assert_eq(
    json_string(result, "run_script_path", default=""),
    "portable/app-tool/run-local.command",
  )
  assert_eq(
    json_string(result, "server_script_path", default=""),
    "portable/app-tool/serve.py",
  )
  assert_true(
    json_string_array_items(result, "api_dependency_paths").contains(
      "app/tool.js",
    ),
  )
  assert_true(
    json_string_array_items(result, "api_reference_routes").contains(
      "/api/workspaces/book-demo/raw?path=book/outputs/report.txt",
    ),
  )
  assert_true(
    json_string_array_items(result, "api_reference_routes").contains(
      "/api/workspaces/book-demo/file/raw/excel/results.xlsx",
    ),
  )
  assert_false(
    json_string_array_items(result, "api_unsupported_routes").contains(
      "/api/workspaces/book-demo/raw?path=book/outputs/report.txt",
    ),
  )
  assert_true(
    json_string_array_items(result, "copied_paths").contains(
      "assets/root-module.js",
    ),
  )
  assert_true(
    json_string_array_items(result, "copied_paths").contains("media/bg.png"),
  )
  assert_true(
    json_string_array_items(result, "api_offline_paths").contains(
      "app/index.html",
    ),
  )
  assert_eq(
    json_string_array_items(result, "api_dependency_warnings").length(),
    0,
  )
  let app_html = @fs.read_file(
    @pathx.join(book_root, "portable/app-tool/app/index.html"),
  ).text()
  assert_true(app_html.contains("src=\"../assets/root-module.js\""))
  assert_false(app_html.contains("src=\"/assets/root-module.js\""))
  match app_html.find("portable-runtime.js") {
    Some(runtime_index) =>
      match app_html.find("type=\"module\"") {
        Some(module_index) => assert_true(runtime_index < module_index)
        None => fail("expected generated app module script")
      }
    None => fail("expected generated app portable runtime")
  }
  let app_css = @fs.read_file(
    @pathx.join(book_root, "portable/app-tool/app/styles.css"),
  ).text()
  assert_true(app_css.contains("url('../media/bg.png')"))
  assert_false(app_css.contains("url('/media/bg.png')"))
  let status = app_tool_portable_status(root, book_root, book_id)
  assert_eq(json_string(status, "status", default=""), "portable_ready")
  assert_eq(json_string(status, "entrypoint", default=""), "app/index.html")
  assert_eq(
    json_string(status, "standalone_runtime", default=""),
    "served-static-bundle",
  )
  assert_true(
    json_bool(status, "operatable_without_moondesk_api", default=false),
  )
  assert_eq(json_string_array_items(status, "standalone_blockers").length(), 0)
}

///|
test "app tool portable default paths do not imply workbook output" {
  let book_json : Json = {
    "id": "research-generic",
    "type": "research-book",
    "toolbook": {
      "enabled": true,
      "manifest_path": "tool-manifest.json",
      "entrypoints": ["app/index.html"],
    },
  }
  let manifest : Json = {
    "kind": "app-tool-book-manifest",
    "template_id": "app-tool-book",
    "tool": { "entrypoints": ["app/index.html"] },
    "outputs": {},
  }
  let defaults = app_tool_portable_source_paths(book_json, manifest)
  assert_false(defaults.contains("raw/excel"))

  let workbook_manifest : Json = {
    "kind": "app-tool-book-manifest",
    "template_id": "app-tool-book",
    "tool": { "entrypoints": ["app/index.html"] },
    "outputs": { "spreadsheet": "raw/excel/results.xlsx" },
  }
  let declared = app_tool_portable_source_paths(book_json, workbook_manifest)
  assert_true(declared.contains("raw/excel/results.xlsx"))
  assert_false(declared.contains("raw/excel"))
}

///|
async test "app tool portable export supports research-book tool manifests and embeds portable api runtime" {
  let root = "/tmp/moondesk-app-tool-portable-research-wbtest"
  let book_id = "research-pdf-portable-tool"
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
  @fsx.make_directory(
    @pathx.join(book_root, "raw/analysis-runs"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "book.json"),
    (
      {
        "id": book_id,
        "title": "Research PDF Portable Tool",
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
          "id": "pdf-evidence-tool",
          "title": "PDF Evidence Tool",
          "entrypoints": ["book/site/generated/tool.html", "app/index.html"],
        },
        "outputs": {},
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "book/site/generated/tool.html"),
    "<!doctype html><meta charset=\"utf-8\"><h1>PDF Evidence Tool</h1>",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "app/index.html"),
    "<!doctype html><meta charset=\"utf-8\"><body>pending</body><script>fetch('/api/books/patterns').then(r => r.json()).then(items => { document.body.dataset.patternCount = String(items.length); document.body.textContent = 'patterns:' + items.length; }).catch(error => { document.body.dataset.error = String(error && error.message || error); });</script>",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "raw/analysis-runs/generated-output.xlsx"),
    "fake generated workbook\n",
    create=0o644,
  )

  let result = export_app_tool_portable_bundle(root, book_root, book_id)
  assert_true(json_bool(result, "ok", default=false))
  assert_eq(json_string(result, "status", default=""), "portable_ready")
  assert_eq(json_string(result, "entrypoint", default=""), "app/index.html")
  assert_true(
    @fs.exists(
      @pathx.join(
        book_root, "portable/app-tool/raw/analysis-runs/generated-output.xlsx",
      ),
    ),
  )
  assert_true(
    json_string_array_items(result, "api_dependency_paths").contains(
      "app/index.html",
    ),
  )
  assert_eq(
    json_string_array_items(result, "api_dependency_warnings").length(),
    0,
  )
  assert_true(
    json_string_array_items(result, "api_offline_paths").contains(
      "app/index.html",
    ),
  )
  assert_true(
    json_string_array_items(result, "api_snapshot_routes").contains(
      "/api/books/patterns",
    ),
  )
  assert_true(
    json_string_array_items(result, "api_reference_routes").contains(
      "/api/books/patterns",
    ),
  )
  assert_eq(
    json_string_array_items(result, "api_unsupported_routes").length(),
    0,
  )
  assert_eq(
    json_string(result, "api_offline_mode", default=""),
    "offline-snapshot-runtime",
  )
  assert_true(@fs.exists(@pathx.join(book_root, "portable/app-tool/serve.py")))
  assert_true(
    @fs.exists(@pathx.join(book_root, "portable/app-tool/run-local.command")),
  )
  let app_html = @fs.read_file(
    @pathx.join(book_root, "portable/app-tool/app/index.html"),
  ).text()
  assert_true(app_html.contains("src=\"../portable-runtime.js\""))
  let runtime = @fs.read_file(
    @pathx.join(book_root, "portable/app-tool/portable-runtime.js"),
  ).text()
  assert_true(runtime.contains("/api/books/patterns"))
  assert_true(runtime.contains("portableWorkspaceResponse"))
  assert_true(runtime.contains("contentKind(path)"))
  assert_true(runtime.contains("bundleBaseUrl"))
  assert_true(runtime.contains("new URL(clean, bundleBaseUrl).href"))
  assert_true(runtime.contains("function staticFetch(path)"))
  assert_true(runtime.contains("return target ? originalFetch(target)"))
  assert_true(runtime.contains("offline_snapshot_miss"))
  let snapshot = @fs.read_file(
    @pathx.join(book_root, "portable/app-tool/portable-api-snapshot.json"),
  ).text()
  assert_true(snapshot.contains("\"/api/books/patterns\""))
  let status = app_tool_portable_status(root, book_root, book_id)
  assert_eq(json_string(status, "status", default=""), "portable_ready")
  assert_true(
    json_bool(status, "operatable_without_moondesk_api", default=false),
  )
}

///|
async test "app tool portable export keeps unsupported api routes as warnings" {
  let root = "/tmp/moondesk-app-tool-portable-unsupported-api-wbtest"
  let book_id = "tool-unsupported-api-portable"
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
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
        "title": "Unsupported API Portable Tool",
        "book_type": "toolbook",
        "template_id": "app-tool-book",
        "tool_binding": {
          "manifest_path": "tool-manifest.json",
          "entrypoints": ["app/index.html"],
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
        "tool": { "entrypoints": ["app/index.html"] },
        "outputs": {},
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "app/index.html"),
    "<!doctype html><meta charset=\"utf-8\"><script>fetch('/api/books/external-domain-state?book_id=external-example')</script>",
    create=0o644,
  )

  let result = export_app_tool_portable_bundle(root, book_root, book_id)
  assert_true(json_bool(result, "ok", default=false))
  assert_eq(
    json_string(result, "status", default=""),
    "portable_with_api_warnings",
  )
  assert_true(
    json_string_array_items(result, "api_dependency_paths").contains(
      "app/index.html",
    ),
  )
  assert_true(
    json_string_array_items(result, "api_reference_routes").contains(
      "/api/books/external-domain-state?book_id=external-example",
    ),
  )
  assert_true(
    json_string_array_items(result, "api_unsupported_routes").contains(
      "/api/books/external-domain-state?book_id=external-example",
    ),
  )
  assert_true(
    json_string_array_items(result, "api_dependency_warnings").contains(
      "app/index.html",
    ),
  )
  assert_true(
    !json_bool(result, "operatable_without_moondesk_api", default=true),
  )
  assert_true(!json_bool(result, "standalone_launchable", default=true))
  assert_true(!json_bool(result, "auto_open_allowed", default=true))
  assert_true(
    json_string_array_items(result, "standalone_blockers").contains(
      "unsupported_moondesk_api_dependencies",
    ),
  )
}

///|
async test "app tool portable export detects generated app books without metadata" {
  let root = "/tmp/moondesk-app-tool-portable-detected-app-wbtest"
  let book_id = "research-generated-tool-portable"
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  @fsx.make_directory(
    @pathx.join(book_root, "app"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(book_root, "raw/excel"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(book_root, "raw/analysis-runs"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "book.json"),
    (
      {
        "id": book_id,
        "title": "Generated External Tool",
        "type": "research-book",
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "app/index.html"),
    "<!doctype html><meta charset=\"utf-8\"><body>generated app</body>",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "raw/excel/generated.xlsx"),
    "fake workbook bytes\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "raw/analysis-runs/result.json"),
    "{ \"ok\": true }\n",
    create=0o644,
  )

  let discovered = app_tool_book_ids_for_workspace(root)
  assert_true(discovered.contains(book_id))
  let status_before = app_tool_portable_status(root, book_root, book_id)
  assert_true(
    ["export_required", "portable_ready"].contains(
      json_string(status_before, "status", default=""),
    ),
  )
  assert_true(json_bool(status_before, "app_tool", default=false))
  assert_eq(
    json_string(status_before, "entrypoint", default=""),
    "app/index.html",
  )

  let result = export_app_tool_portable_bundle(root, book_root, book_id)
  assert_true(json_bool(result, "ok", default=false))
  assert_eq(json_string(result, "status", default=""), "portable_ready")
  assert_eq(json_string(result, "entrypoint", default=""), "app/index.html")
  assert_true(
    @fs.exists(@pathx.join(book_root, "portable/app-tool/app/index.html")),
  )
  assert_true(@fs.exists(@pathx.join(book_root, "portable/app-tool/serve.py")))
  assert_true(
    @fs.exists(@pathx.join(book_root, "portable/app-tool/run-local.command")),
  )
  assert_false(
    @fs.exists(
      @pathx.join(book_root, "portable/app-tool/raw/excel/generated.xlsx"),
    ),
  )

  let all_status = app_tool_portable_all_status(root)
  assert_eq(json_int(all_status, "app_tool_book_count", default=0), 1)
  assert_eq(json_int(all_status, "portable_ready_count", default=0), 1)
}

///|
async test "app tool portable export requires an html entrypoint" {
  let root = "/tmp/moondesk-app-tool-portable-non-html-wbtest"
  let book_id = "tool-non-html-portable"
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
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
        "title": "Non HTML Portable Tool",
        "book_type": "toolbook",
        "template_id": "app-tool-book",
        "tool_binding": {
          "manifest_path": "tool-manifest.json",
          "entrypoints": ["app/main.js"],
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
        "tool": { "entrypoints": ["app/main.js"] },
        "outputs": {},
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "app/main.js"),
    "document.body.textContent = 'not an html entrypoint'\n",
    create=0o644,
  )

  let result = export_app_tool_portable_bundle(root, book_root, book_id)
  assert_true(!json_bool(result, "ok", default=true))
  assert_eq(json_string(result, "status", default=""), "unsupported_entrypoint")
  assert_true(
    json_string_array_items(result, "existing_entrypoints").contains(
      "app/main.js",
    ),
  )
  let status = app_tool_portable_status(root, book_root, book_id)
  assert_eq(json_string(status, "status", default=""), "unsupported_entrypoint")
  assert_eq(json_string_array_items(status, "html_entrypoints").length(), 0)
  assert_true(!json_bool(status, "ok", default=true))
  let all_status = app_tool_portable_all_status(root)
  assert_eq(
    json_string(all_status, "status", default=""),
    "unsupported_entrypoint",
  )
  assert_eq(json_int(all_status, "app_tool_book_count", default=0), 1)
  assert_eq(json_int(all_status, "unsupported_entrypoint_count", default=0), 1)
  assert_true(
    !json_bool(all_status, "operatable_without_moondesk_api", default=true),
  )
  assert_true(
    json_string_array_items(all_status, "standalone_blockers").contains(
      "unsupported_non_html_entrypoint",
    ),
  )
}

///|
async test "app tool portable export all discovers every app-tool book only" {
  let root = "/tmp/moondesk-app-tool-portable-all-wbtest"
  let direct_id = "tool-direct-all-portable"
  let research_id = "research-tool-all-portable"
  let plain_id = "plain-research-not-app-tool-portable"
  let direct_root = app_tool_book_root_for_id(root, direct_id)
  let research_root = app_tool_book_root_for_id(root, research_id)
  let plain_root = app_tool_book_root_for_id(root, plain_id)
  @fsx.make_directory(
    @pathx.join(direct_root, "book/site/generated"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(research_root, "app"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(plain_root, recursive=true, exists_ok=true)
  @fsx.write_to_file(
    @pathx.join(direct_root, "book.json"),
    (
      {
        "id": direct_id,
        "title": "Direct All Portable Tool",
        "book_type": "toolbook",
        "template_id": "app-tool-book",
        "tool_binding": {
          "manifest_path": "tool-manifest.json",
          "entrypoints": ["book/site/generated/tool.html"],
        },
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(direct_root, "tool-manifest.json"),
    (
      {
        "kind": "app-tool-book-manifest",
        "template_id": "app-tool-book",
        "book_id": direct_id,
        "tool": { "entrypoints": ["book/site/generated/tool.html"] },
        "outputs": {},
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(direct_root, "book/site/generated/tool.html"),
    "<!doctype html><meta charset=\"utf-8\"><h1>Direct</h1>",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(research_root, "book.json"),
    (
      {
        "id": research_id,
        "title": "Research All Portable Tool",
        "type": "research-book",
        "toolbook": {
          "enabled": true,
          "template_id": "app-tool-book",
          "manifest_path": "tool-manifest.json",
          "entrypoints": ["app/index.html"],
        },
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(research_root, "tool-manifest.json"),
    (
      {
        "kind": "app-tool-book-manifest",
        "template_id": "app-tool-book",
        "book_id": research_id,
        "tool": { "entrypoints": ["app/index.html"] },
        "outputs": {},
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(research_root, "app/index.html"),
    "<!doctype html><meta charset=\"utf-8\"><body>pending</body><script>fetch('/api/books/patterns').then(r => r.json()).then(items => { document.body.dataset.patternCount = String(items.length); document.body.textContent = 'patterns:' + items.length; }).catch(error => { document.body.dataset.error = String(error && error.message || error); });</script>",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(plain_root, "book.json"),
    (
      {
        "id": plain_id,
        "title": "Plain Research Book",
        "type": "research-book",
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )

  let result = export_all_app_tool_portable_bundles(root)
  assert_true(json_bool(result, "ok", default=false))
  assert_eq(json_string(result, "status", default=""), "portable_ready")
  assert_eq(json_int(result, "app_tool_book_count", default=0), 2)
  assert_eq(json_int(result, "exported_count", default=0), 2)
  assert_eq(json_int(result, "failure_count", default=-1), 0)
  assert_eq(json_int(result, "api_warning_count", default=-1), 0)
  assert_eq(
    json_string(result, "standalone_runtime", default=""),
    "served-static-bundle",
  )
  assert_true(
    json_bool(result, "operatable_without_moondesk_api", default=false),
  )
  assert_eq(json_string_array_items(result, "standalone_blockers").length(), 0)
  let ids = json_string_array_items(result, "book_ids")
  assert_true(ids.contains(direct_id))
  assert_true(ids.contains(research_id))
  assert_true(!ids.contains(plain_id))
  assert_true(
    @fs.exists(@pathx.join(direct_root, "portable/app-tool/index.html")),
  )
  assert_true(
    @fs.exists(@pathx.join(research_root, "portable/app-tool/index.html")),
  )
  assert_true(
    !@fs.exists(@pathx.join(plain_root, "portable/app-tool/index.html")),
  )

  let status = app_tool_portable_all_status(root)
  assert_eq(json_string(status, "status", default=""), "portable_ready")
  assert_eq(json_int(status, "app_tool_book_count", default=0), 2)
  assert_eq(json_int(status, "portable_ready_count", default=0), 2)
  assert_eq(json_int(status, "api_warning_count", default=-1), 0)
  assert_eq(
    json_string(status, "standalone_runtime", default=""),
    "served-static-bundle",
  )
  assert_true(
    json_bool(status, "operatable_without_moondesk_api", default=false),
  )
  assert_eq(json_string_array_items(status, "standalone_blockers").length(), 0)
}
