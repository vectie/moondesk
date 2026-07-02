///|
test "resolve request path rejects traversal" {
  assert_true(
    resolve_request_path("/tmp/moondesk", "/")
    is Some("/tmp/moondesk/index.html"),
  )
  assert_true(resolve_request_path("/tmp/moondesk", "/../secret") is None)
}

///|
test "api path helpers handle queries and traversal" {
  assert_eq(
    strip_query("/api/workspaces/book/entries?path=wiki"),
    "/api/workspaces/book/entries",
  )
  assert_true(
    query_value("/api?path=wiki%2Findex.md&other=1", "path")
    is Some("wiki%2Findex.md"),
  )
  assert_eq(encode_query_value("/tmp/moon book"), "%2Ftmp%2Fmoon%20book")
  assert_eq(
    decode_query_value(encode_query_value("/tmp/moon book")),
    "/tmp/moon book",
  )
  assert_eq(decode_query_value("wiki%2Findex.md"), "wiki/index.md")
  assert_eq(
    decode_query_value("wiki%2Fsources%2Freport.md"),
    "wiki/sources/report.md",
  )
  assert_true(path_segments("/api/workspaces") == ["api", "workspaces"])
  assert_true(
    clean_relative_path("wiki/../raw/README.md") is Some("raw/README.md"),
  )
  assert_true(
    resolve_workspace_path("/tmp/book", "docs%20with%20spaces")
    is Some(("/tmp/book/docs%20with%20spaces", "docs%20with%20spaces")),
  )
  assert_true(clean_relative_path("../secret") is None)
  assert_true(clean_relative_path("/tmp/secret") is None)
  assert_true(clean_relative_path("%2e%2e/secret") is Some("%2e%2e/secret"))
  assert_true(
    resolve_workspace_path("/tmp/book", decode_query_value("%2e%2e/secret"))
    is None,
  )
}

///|
test "workspace path resolver maps MoonClaw job paths to owning suite" {
  let suite_root = "/tmp/moondesk-resolve-suite"
  let book_root = @pathx.join(suite_root, "books/research-resolve")
  match
    resolve_workspace_path(
      book_root, ".moonsuite/products/moonclaw/jobs/run-001/result.json",
    ) {
    Some((absolute, clean)) => {
      assert_eq(
        absolute,
        @pathx.join(
          suite_root, ".moonsuite/products/moonclaw/jobs/run-001/result.json",
        ),
      )
      assert_eq(clean, ".moonsuite/products/moonclaw/jobs/run-001/result.json")
    }
    None => fail("expected product-home MoonClaw run artifact path")
  }
  match resolve_workspace_path(book_root, ".moonsuite/products/moonclaw/jobs") {
    Some((absolute, clean)) => {
      assert_eq(
        absolute,
        @pathx.join(suite_root, ".moonsuite/products/moonclaw/jobs"),
      )
      assert_eq(clean, ".moonsuite/products/moonclaw/jobs")
    }
    None => fail("expected product-home MoonClaw jobs path")
  }
  assert_true(
    resolve_workspace_path(book_root, ".moonsuite/products/moonclaw/../secret")
    is None,
  )
}

///|
test "Moondesk product paths use owning suite for book workspaces" {
  let suite_root = "/tmp/moondesk-product-paths-suite"
  let book_root = @pathx.join(suite_root, "books/research-desk")
  assert_eq(
    moondesk_daemon_dir(book_root),
    @pathx.join(suite_root, ".moonsuite/products/moondesk/daemon"),
  )
  assert_eq(
    daemon_lifecycle_state_path(book_root),
    @pathx.join(suite_root, ".moonsuite/products/moondesk/daemon/state.json"),
  )
  assert_eq(
    daemon_policy_path(book_root),
    @pathx.join(suite_root, ".moonsuite/products/moondesk/daemon/policy.json"),
  )
  assert_eq(
    saved_views_path(book_root),
    @pathx.join(
      suite_root, ".moonsuite/products/moondesk/preferences/views.json",
    ),
  )
  assert_eq(
    tags_path(book_root),
    @pathx.join(
      suite_root, ".moonsuite/products/moondesk/preferences/tags.json",
    ),
  )
  assert_eq(
    desk_trash_files_root(book_root),
    @pathx.join(suite_root, ".moonsuite/products/moondesk/trash/files"),
  )
  assert_eq(
    desk_trash_receipts_root(book_root),
    @pathx.join(suite_root, ".moonsuite/products/moondesk/trash/receipts"),
  )
  match
    resolve_desk_trash_path(
      book_root, ".moonsuite/products/moondesk/trash/files/trash-1/note.md",
    ) {
    Some(absolute) =>
      assert_eq(
        absolute,
        @pathx.join(
          suite_root, ".moonsuite/products/moondesk/trash/files/trash-1/note.md",
        ),
      )
    None => fail("expected suite-level trash file path")
  }
  assert_false(
    moondesk_daemon_dir(book_root).contains("/books/research-desk/.moonsuite/"),
  )
}

///|
async test "workspace discovery ignores plain folders" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-plain-folder-wbtest-" + @async.now().to_string(),
  )
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let workspaces = discover_workspaces(root)
  assert_eq(workspaces.length(), 0)
}

///|
async test "workspace discovery only exposes suite roots and moonbooks" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-suite-root-wbtest-" + @async.now().to_string(),
  )
  @fsx.make_directory(moonsuite_state_dir(root), recursive=true, exists_ok=true)
  let suite_workspaces = discover_workspaces(root)
  assert_eq(suite_workspaces.length(), 1)
  assert_true(suite_workspaces[0].kind is SuiteRoot)

  @fsx.make_directory(
    @pathx.join(root, "books"),
    recursive=true,
    exists_ok=true,
  )
  let empty_book_library_workspaces = discover_workspaces(root)
  assert_eq(empty_book_library_workspaces.length(), 0)

  let book_root = @pathx.join(root, "books/research-demo")
  @fsx.make_directory(book_root, recursive=true, exists_ok=true)
  @fsx.make_directory(
    @pathx.join(root, "books/research-alpha"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(root, "books/research-alpha/book.json"),
    "{\"name\":\"Alpha Field Notes\"}\n",
  )
  @fsx.make_directory(
    @pathx.join(root, "books/research-zeta"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(root, "books/research-zeta/book.json"),
    "{\"title\":\"Zeta Evidence Review\",\"name\":\"Ignored Name\"}\n",
  )
  let book_workspaces = discover_workspaces(root)
  assert_eq(book_workspaces.length(), 3)
  let names = book_workspaces.map(workspace => workspace.name)
  assert_eq(names[0], "Alpha Field Notes")
  assert_eq(names[1], "research-demo")
  assert_eq(names[2], "Zeta Evidence Review")
  assert_true(book_workspaces[0].status is Ready)
  assert_true(book_workspaces[1].status is NeedsAttention)
  assert_true(book_workspaces[2].status is Ready)
  for workspace in book_workspaces {
    assert_true(workspace.kind is MoonBook)
  }
}

///|
async test "fresh suite exposes rabbita moonbook projections through desk workspace discovery" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-rabbita-projection-wbtest-" + @async.now().to_string(),
  )
  assert_true(prepare_moonsuite_workspace_root(root))
  let book_id = "wenyu-social-square"
  let book_root = @pathx.join(moonsuite_books_root(root), book_id)
  @fsx.make_directory(
    @pathx.join(book_root, "book/site/generated"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(book_root, "wiki"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "book.json"),
    "{\"id\":\"wenyu-social-square\",\"name\":\"Wenyu Social Square\"}\n",
  )
  @fsx.write_to_file(@pathx.join(book_root, "wiki/index.md"), "# Social\n")
  @fsx.write_to_file(
    @pathx.join(book_root, "book/moonbook-ui-state.json"),
    "{\"title\":\"Wenyu Social Square\",\"projection_scope\":\"public\"}\n",
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "book/site/generated/index.html"),
    "<main>Wenyu Social Square</main>",
  )

  let workspaces = discover_workspaces(root)
  assert_eq(workspaces.length(), 1)
  let workspace = workspaces[0]
  assert_eq(workspace.id, @desk.stable_id("book", book_id))
  assert_eq(workspace.name, "Wenyu Social Square")
  assert_eq(workspace.root_path, book_root)
  assert_true(workspace.kind is MoonBook)
  assert_true(workspace.status is Ready)

  let root_entries = list_workspace_entries(workspace, "", book_root)
  assert_true(find_test_entry(root_entries, "wiki") is Some(_))
  assert_true(find_test_entry(root_entries, "book/site/generated") is Some(_))
  assert_true(find_test_entry(root_entries, "book") is None)
  match resolve_workspace_path(book_root, "book/moonbook-ui-state.json") {
    Some((absolute, clean_relative)) => {
      assert_eq(clean_relative, "book/moonbook-ui-state.json")
      assert_eq(
        @fs.read_file(absolute).text(),
        "{\"title\":\"Wenyu Social Square\",\"projection_scope\":\"public\"}\n",
      )
    }
    None => fail("expected Rabbita projection path to resolve under book root")
  }
  assert_false(@fs.exists(@pathx.join(book_root, ".moonsuite")))
}

///|
async test "workspace metadata exposes dedicated MoonBook library path" {
  let metadata = workspace_library_metadata("/tmp/moondesk-workspace")
  assert_eq(
    json_string(metadata, "root_path", default=""),
    "/tmp/moondesk-workspace",
  )
  assert_eq(
    json_string(metadata, "library_path", default=""),
    "/tmp/moondesk-workspace/books",
  )
  assert_eq(
    json_string(metadata, "suite_root", default=""),
    "/tmp/moondesk-workspace",
  )
  let products = json_array_items(metadata, "products")
  assert_true(products.length() >= 13)
  assert_eq(json_string(products[0], "id", default=""), "moondesk")
  assert_eq(json_string(products[0], "status", default=""), "installed")
}

///|
async test "moonsuite layout facade normalizes suite-hosted book roots" {
  let suite_root = @pathx.join(
    "/tmp",
    "moondesk-layout-facade-book-root-wbtest-" + @async.now().to_string(),
  )
  let book_root = @pathx.join(suite_root, "books/research-facade")
  assert_eq(moonsuite_root(book_root), suite_root)
  assert_eq(moonsuite_books_root(book_root), @pathx.join(suite_root, "books"))
  assert_eq(
    moonsuite_state_dir(book_root),
    @pathx.join(suite_root, ".moonsuite"),
  )
  assert_eq(moonsuite_tmp_root(book_root), @pathx.join(suite_root, ".tmp"))
  assert_eq(
    moonsuite_products_root(book_root),
    @pathx.join(suite_root, ".moonsuite/products"),
  )
  assert_eq(
    moonsuite_product_dir(book_root, "moondesk"),
    @pathx.join(suite_root, ".moonsuite/products/moondesk"),
  )
  assert_eq(
    moonsuite_product_registry_path(book_root),
    @pathx.join(suite_root, ".moonsuite/product-registry.json"),
  )
  assert_false(
    moonsuite_product_dir(book_root, "moondesk").contains(
      "books/research-facade/.moonsuite",
    ),
  )
}

///|
async test "workspace metadata maps book roots back to owning suite" {
  let suite_root = @pathx.join(
    "/tmp",
    "moondesk-workspace-metadata-book-root-wbtest-" + @async.now().to_string(),
  )
  assert_true(prepare_moonsuite_workspace_root(suite_root))
  let book_root = @pathx.join(suite_root, "books/research-metadata")
  @fsx.make_directory(book_root, recursive=true, exists_ok=true)
  let metadata = workspace_library_metadata(book_root)
  assert_eq(json_string(metadata, "root_path", default=""), book_root)
  assert_eq(json_string(metadata, "suite_root", default=""), suite_root)
  assert_eq(
    json_string(metadata, "library_path", default=""),
    @pathx.join(suite_root, "books"),
  )
  assert_eq(
    json_string(metadata, "suite_path", default=""),
    @pathx.join(suite_root, ".moonsuite"),
  )
  assert_eq(
    json_string(metadata, "product_registry_path", default=""),
    @pathx.join(suite_root, ".moonsuite/product-registry.json"),
  )
  assert_eq(
    json_string(metadata, "tmp_path", default=""),
    @pathx.join(suite_root, ".tmp"),
  )
  guard metadata is Object(metadata_obj) else {
    fail("expected metadata object")
  }
  guard metadata_obj["workspace_context"] is Object(context) else {
    fail("expected workspace context object")
  }
  assert_true(context["requested_root"] == Json::string(book_root))
  assert_true(context["suite_root"] == Json::string(suite_root))
  assert_true(
    context["books_root"] == Json::string(@pathx.join(suite_root, "books")),
  )
  assert_false(
    json_string(metadata, "suite_path", default="").contains(
      "books/research-metadata/.moonsuite",
    ),
  )
}

///|
async test "workspace metadata reads installed products from registry file" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-product-registry-metadata-wbtest-" + @async.now().to_string(),
  )
  assert_true(prepare_moonsuite_workspace_root(root))
  let registry =
    #|{"kind":"moonsuite-product-registry.v1","products":[{"id":"moonrobo","name":"MoonRobo","kind":"moon-suite-product","state_path":".moonsuite/products/moonrobo","service_path":".moonsuite/products/moonrobo/service.json","repo_path":"","status":"installed","capabilities":[]}]}
  @fsx.write_to_file(
    moonsuite_product_registry_path(root),
    registry + "\n",
    create=0o644,
  )
  let metadata = workspace_library_metadata(root)
  let products = json_array_items(metadata, "products")
  assert_eq(products.length(), 1)
  assert_eq(json_string(products[0], "id", default=""), "moonrobo")
  assert_eq(json_int(metadata, "product_count", default=0), 1)
}

///|
async test "blank moonbook creation writes into dedicated books root" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-create-book-wbtest-" + @async.now().to_string(),
  )
  let result = create_blank_moonbook_workspace(root, {
    "name": "Desk Created Book",
    "book_id": "Research Desk Created",
  })
  let created = match result {
    Ok(json) => json
    Err(error) => {
      fail(error.stringify())
      Json::object({})
    }
  }
  assert_eq(
    json_string(created, "book_id", default=""),
    "research-desk-created",
  )
  assert_eq(
    json_string(created, "workspace_id", default=""),
    @desk.stable_id("book", "research-desk-created"),
  )
  let book_root = @pathx.join(root, "books/research-desk-created")
  assert_true(@fs.exists(@pathx.join(book_root, "book.json")))
  assert_true(@fs.exists(@pathx.join(book_root, "wiki/index.md")))
  assert_true(@fs.exists(@pathx.join(book_root, "raw")))
  assert_false(@fs.exists(@pathx.join(book_root, ".moonsuite")))
  assert_true(@fs.exists(moonclaw_jobs_root(book_root)))
  assert_false(@fs.exists(@pathx.join(root, "research-desk-created")))
  let workspaces = discover_workspaces(root)
  assert_eq(workspaces.length(), 1)
  assert_eq(workspaces[0].name, "Desk Created Book")
  match
    create_blank_moonbook_workspace(root, {
      "name": "Again",
      "book_id": "research-desk-created",
    }) {
    Ok(_) => fail("expected duplicate rejection")
    Err(error) => assert_eq(json_int(error, "code", default=0), 409)
  }
}

///|
async test "blank moonbook creation maps selected book roots to owning suite" {
  let suite_root = @pathx.join(
    "/tmp",
    "moondesk-create-book-from-selected-root-wbtest-" + @async.now().to_string(),
  )
  let selected_book_root = @pathx.join(suite_root, "books/research-selected")
  let result = create_blank_moonbook_workspace(selected_book_root, {
    "name": "Created From Selected Book",
    "book_id": "created-from-selected",
  })
  let created = match result {
    Ok(json) => json
    Err(error) => {
      fail(error.stringify())
      Json::object({})
    }
  }
  let created_root = @pathx.join(suite_root, "books/created-from-selected")
  assert_eq(json_string(created, "root_path", default=""), created_root)
  assert_true(@fs.exists(@pathx.join(created_root, "book.json")))
  assert_false(
    @fs.exists(
      @pathx.join(
        selected_book_root, ".moonsuite/products/moondesk/books/created-from-selected",
      ),
    ),
  )
  assert_false(@fs.exists(@pathx.join(selected_book_root, "books")))
}

///|
async test "moonbook import copies existing folder into dedicated books root" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-import-book-wbtest-" + @async.now().to_string(),
  )
  let source = @pathx.join(
    "/tmp",
    "moondesk-import-source-" + @async.now().to_string(),
  )
  @fsx.make_directory(
    @pathx.join(source, "wiki"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(source, "raw"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(source, ".git"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(source, "book.json"),
    "{\"id\":\"field-notes\",\"name\":\"Field Notes\"}\n",
  )
  @fsx.write_to_file(@pathx.join(source, "wiki/index.md"), "# Imported\n")
  @fsx.write_to_file(@pathx.join(source, "raw/evidence.txt"), "copied\n")
  @fsx.write_to_file(@pathx.join(source, ".git/config"), "skip\n")
  @fsx.write_to_file(@pathx.join(source, ".DS_Store"), "skip\n")

  let result = import_existing_moonbook_workspace(root, {
    "source_path": source,
  })
  let imported = match result {
    Ok(json) => json
    Err(error) => {
      fail(error.stringify())
      Json::object({})
    }
  }
  assert_eq(json_string(imported, "book_id", default=""), "field-notes")
  assert_eq(json_string(imported, "path", default=""), "wiki/index.md")
  let book_root = @pathx.join(root, "books/field-notes")
  assert_true(@fs.exists(@pathx.join(book_root, "book.json")))
  assert_true(@fs.exists(@pathx.join(book_root, "wiki/index.md")))
  assert_true(@fs.exists(@pathx.join(book_root, "raw/evidence.txt")))
  assert_false(@fs.exists(@pathx.join(book_root, ".git/config")))
  assert_false(@fs.exists(@pathx.join(book_root, ".DS_Store")))
  assert_true(@fs.exists(@pathx.join(source, "wiki/index.md")))
  let workspaces = discover_workspaces(root)
  assert_eq(workspaces.length(), 1)
  assert_eq(workspaces[0].name, "Field Notes")
  match import_existing_moonbook_workspace(root, { "source_path": source }) {
    Ok(_) => fail("expected duplicate import rejection")
    Err(error) => assert_eq(json_int(error, "code", default=0), 409)
  }
}

///|
async test "moonbook import stages picked folder files into dedicated books root" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-import-picked-folder-wbtest-" + @async.now().to_string(),
  )
  let result = import_existing_moonbook_workspace(root, {
    "files": Json::array([
      {
        "filename": "book.json",
        "relative_path": "Picked Book/book.json",
        "content": "{\"id\":\"picked-folder\",\"name\":\"Picked Folder\"}\n",
      },
      {
        "filename": "index.md",
        "relative_path": "Picked Book/wiki/index.md",
        "content": "# Picked Folder\n",
      },
      {
        "filename": "evidence.txt",
        "relative_path": "Picked Book/raw/evidence.txt",
        "content": "picked evidence\n",
      },
      {
        "filename": "config",
        "relative_path": "Picked Book/.git/config",
        "content": "skip\n",
      },
    ]),
  })
  let imported = match result {
    Ok(json) => json
    Err(error) => {
      fail(error.stringify())
      Json::object({})
    }
  }
  assert_eq(json_string(imported, "book_id", default=""), "picked-folder")
  let book_root = @pathx.join(root, "books/picked-folder")
  assert_true(@fs.exists(@pathx.join(book_root, "book.json")))
  assert_true(@fs.exists(@pathx.join(book_root, "wiki/index.md")))
  assert_eq(
    @fs.read_file(@pathx.join(book_root, "raw/evidence.txt")).text(),
    "picked evidence\n",
  )
  assert_false(@fs.exists(@pathx.join(book_root, ".git/config")))
  match
    import_existing_moonbook_workspace(root, {
      "files": Json::array([
        {
          "filename": "bad.txt",
          "relative_path": "../bad.txt",
          "content": "bad\n",
        },
      ]),
    }) {
    Ok(_) => fail("expected picked folder traversal rejection")
    Err(error) => assert_eq(json_int(error, "code", default=0), 400)
  }
}

///|
async test "moonbook archive helpers find root folder and default id name" {
  let extract_root = @pathx.join(
    "/tmp",
    "moondesk-archive-helper-wbtest-" + @async.now().to_string(),
  )
  @fsx.make_directory(
    @pathx.join(extract_root, "__MACOSX"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(extract_root, "Archived Desk/wiki"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(extract_root, "Archived Desk/book.json"),
    "{\"name\":\"Archived Desk\"}\n",
  )
  guard import_archive_source_dir(extract_root) is Some(source_dir) else {
    fail("expected archived MoonBook root")
  }
  assert_eq(source_dir, @pathx.join(extract_root, "Archived Desk"))
  assert_true(import_is_zip_archive("/tmp/Desk Book.ZIP"))
  assert_false(import_is_zip_archive("/tmp/Desk Book.tar"))
  assert_eq(import_archive_default_name("/tmp/Desk Book.zip"), "Desk Book")
  assert_eq(
    import_archive_upload_filename("/Users/demo/Desk Book.zip"),
    "Desk Book.zip",
  )
  assert_eq(import_archive_upload_filename("Desk Book"), "Desk Book.zip")
  assert_eq(import_archive_upload_filename(""), "moonbook-upload.zip")
  match
    import_uploaded_moonbook_file_path({
      "filename": "book.json",
      "relative_path": "Book/book.json",
    }) {
    Ok(path) => assert_eq(path, "Book/book.json")
    Err(error) => fail(error)
  }
}

///|
async test "moonbook import requires a valid book manifest" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-import-invalid-wbtest-" + @async.now().to_string(),
  )
  let source = @pathx.join(
    "/tmp",
    "moondesk-import-invalid-source-" + @async.now().to_string(),
  )
  @fsx.make_directory(source, recursive=true, exists_ok=true)
  match import_existing_moonbook_workspace(root, { "source_path": source }) {
    Ok(_) => fail("expected invalid MoonBook rejection")
    Err(error) => assert_eq(json_int(error, "code", default=0), 400)
  }
}

///|
async test "desk entry creation writes folders and markdown inside workspace" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-create-entry-wbtest-" + @async.now().to_string(),
  )
  let book_root = @pathx.join(root, "books/research-entry")
  @fsx.make_directory(
    @pathx.join(book_root, "wiki"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "book.json"),
    "{\"name\":\"Entry\"}\n",
  )
  let workspace = @desk.workspace(
    id=@desk.stable_id("book", "research-entry"),
    name="research-entry",
    root_path=book_root,
    kind=MoonBook,
  )
  let folder = create_workspace_entry(workspace, {
    "kind": "folder",
    "directory": "wiki",
    "name": "notes",
  })
  let folder_json = match folder {
    Ok(json) => json
    Err(error) => {
      fail(error.stringify())
      Json::object({})
    }
  }
  assert_eq(json_string(folder_json, "path", default=""), "wiki/notes")
  assert_true(@fs.exists(@pathx.join(book_root, "wiki/notes")))
  let note = create_workspace_entry(workspace, {
    "kind": "markdown",
    "directory": "wiki/notes",
    "name": "alpha",
  })
  let note_json = match note {
    Ok(json) => json
    Err(error) => {
      fail(error.stringify())
      Json::object({})
    }
  }
  assert_eq(json_string(note_json, "path", default=""), "wiki/notes/alpha.md")
  assert_true(@fs.exists(@pathx.join(book_root, "wiki/notes/alpha.md")))
  assert_false(@fs.exists(@pathx.join(root, "wiki/notes/alpha.md")))
  let renamed_note = rename_workspace_entry(workspace, {
    "path": "wiki/notes/alpha.md",
    "name": "beta",
  })
  let renamed_note_json = match renamed_note {
    Ok(json) => json
    Err(error) => {
      fail(error.stringify())
      Json::object({})
    }
  }
  assert_eq(
    json_string(renamed_note_json, "path", default=""),
    "wiki/notes/beta.md",
  )
  assert_true(@fs.exists(@pathx.join(book_root, "wiki/notes/beta.md")))
  assert_false(@fs.exists(@pathx.join(book_root, "wiki/notes/alpha.md")))
  let renamed_folder = rename_workspace_entry(workspace, {
    "path": "wiki/notes",
    "name": "renamed-notes",
  })
  let renamed_folder_json = match renamed_folder {
    Ok(json) => json
    Err(error) => {
      fail(error.stringify())
      Json::object({})
    }
  }
  assert_eq(
    json_string(renamed_folder_json, "path", default=""),
    "wiki/renamed-notes",
  )
  assert_true(@fs.exists(@pathx.join(book_root, "wiki/renamed-notes")))
  assert_true(@fs.exists(@pathx.join(book_root, "wiki/renamed-notes/beta.md")))
  assert_false(@fs.exists(@pathx.join(book_root, "wiki/notes")))
  @fsx.write_to_file(
    @pathx.join(book_root, "wiki/renamed-notes/existing.md"),
    "already here\n",
  )
  match rename_workspace_entry(workspace, { "path": "wiki", "name": "docs" }) {
    Ok(_) => fail("expected section rename rejection")
    Err(error) => assert_eq(json_int(error, "code", default=0), 400)
  }
  match
    rename_workspace_entry(workspace, {
      "path": "wiki/renamed-notes/beta.md",
      "name": "existing",
    }) {
    Ok(_) => fail("expected duplicate rename rejection")
    Err(error) => assert_eq(json_int(error, "code", default=0), 409)
  }
  let moved_note = move_workspace_entry(workspace, {
    "path": "wiki/renamed-notes/beta.md",
    "directory": "wiki",
  })
  let moved_note_json = match moved_note {
    Ok(json) => json
    Err(error) => {
      fail(error.stringify())
      Json::object({})
    }
  }
  assert_eq(json_string(moved_note_json, "path", default=""), "wiki/beta.md")
  assert_true(@fs.exists(@pathx.join(book_root, "wiki/beta.md")))
  assert_false(@fs.exists(@pathx.join(book_root, "wiki/renamed-notes/beta.md")))
  let moved_folder = move_workspace_entry(workspace, {
    "path": "wiki/renamed-notes",
    "directory": "raw",
  })
  let moved_folder_json = match moved_folder {
    Ok(json) => json
    Err(error) => {
      fail(error.stringify())
      Json::object({})
    }
  }
  assert_eq(
    json_string(moved_folder_json, "path", default=""),
    "raw/renamed-notes",
  )
  assert_true(@fs.exists(@pathx.join(book_root, "raw/renamed-notes")))
  assert_true(
    @fs.exists(@pathx.join(book_root, "raw/renamed-notes/existing.md")),
  )
  assert_false(@fs.exists(@pathx.join(book_root, "wiki/renamed-notes")))
  @fsx.make_directory(
    @pathx.join(book_root, "raw/renamed-notes/child"),
    recursive=true,
    exists_ok=true,
  )
  match
    move_workspace_entry(workspace, {
      "path": "raw/renamed-notes",
      "directory": "raw/renamed-notes/child",
    }) {
    Ok(_) => fail("expected self move rejection")
    Err(error) => assert_eq(json_int(error, "code", default=0), 400)
  }
  @fsx.write_to_file(@pathx.join(book_root, "wiki/existing.md"), "conflict\n")
  match
    move_workspace_entry(workspace, {
      "path": "raw/renamed-notes/existing.md",
      "directory": "wiki",
    }) {
    Ok(_) => fail("expected duplicate move rejection")
    Err(error) => assert_eq(json_int(error, "code", default=0), 409)
  }
  match
    move_workspace_entry(workspace, { "path": "wiki", "directory": "raw" }) {
    Ok(_) => fail("expected section move rejection")
    Err(error) => assert_eq(json_int(error, "code", default=0), 400)
  }
  @fsx.make_directory(
    @pathx.join(book_root, "wiki/batch-target"),
    recursive=true,
  )
  @fsx.write_to_file(@pathx.join(book_root, "wiki/move-a.md"), "move a\n")
  @fsx.write_to_file(@pathx.join(book_root, "wiki/move-b.md"), "move b\n")
  let batch_move = move_workspace_entry(workspace, {
    "paths": Json::array([
      "wiki/move-a.md".to_json(),
      "wiki/move-b.md".to_json(),
    ]),
    "directory": "wiki/batch-target",
  })
  let batch_move_json = match batch_move {
    Ok(json) => json
    Err(error) => {
      fail(error.stringify())
      Json::object({})
    }
  }
  assert_eq(json_int(batch_move_json, "moved_count", default=0), 2)
  assert_true(@fs.exists(@pathx.join(book_root, "wiki/batch-target/move-a.md")))
  assert_true(@fs.exists(@pathx.join(book_root, "wiki/batch-target/move-b.md")))
  assert_false(@fs.exists(@pathx.join(book_root, "wiki/move-a.md")))
  assert_false(@fs.exists(@pathx.join(book_root, "wiki/move-b.md")))
  @fsx.make_directory(
    @pathx.join(book_root, "wiki/parent/child"),
    recursive=true,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "wiki/parent/child/nested.md"),
    "nested\n",
  )
  match
    move_workspace_entry(workspace, {
      "paths": Json::array([
        "wiki/parent".to_json(),
        "wiki/parent/child/nested.md".to_json(),
      ]),
      "directory": "raw",
    }) {
    Ok(_) => fail("expected overlapping batch move rejection")
    Err(error) => assert_eq(json_int(error, "code", default=0), 400)
  }
  assert_true(@fs.exists(@pathx.join(book_root, "wiki/parent/child/nested.md")))
  assert_false(@fs.exists(@pathx.join(book_root, "raw/parent")))
  @fsx.write_to_file(@pathx.join(book_root, "wiki/copy-me.md"), "copy me\n")
  let copied_note = copy_workspace_entry(workspace, {
    "path": "wiki/copy-me.md",
  })
  let copied_note_json = match copied_note {
    Ok(json) => json
    Err(error) => {
      fail(error.stringify())
      Json::object({})
    }
  }
  assert_eq(
    json_string(copied_note_json, "path", default=""),
    "wiki/copy-me copy.md",
  )
  assert_eq(json_int(copied_note_json, "copied_count", default=0), 1)
  assert_true(@fs.exists(@pathx.join(book_root, "wiki/copy-me.md")))
  assert_true(@fs.exists(@pathx.join(book_root, "wiki/copy-me copy.md")))
  assert_eq(
    @fs.read_file(@pathx.join(book_root, "wiki/copy-me copy.md")).text(),
    "copy me\n",
  )
  let copied_note_again = copy_workspace_entry(workspace, {
    "path": "wiki/copy-me.md",
  })
  let copied_note_again_json = match copied_note_again {
    Ok(json) => json
    Err(error) => {
      fail(error.stringify())
      Json::object({})
    }
  }
  assert_eq(
    json_string(copied_note_again_json, "path", default=""),
    "wiki/copy-me copy 2.md",
  )
  @fsx.make_directory(
    @pathx.join(book_root, "wiki/copy-folder/child"),
    recursive=true,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "wiki/copy-folder/child/file.txt"),
    "folder copy\n",
  )
  let copied_folder = copy_workspace_entry(workspace, {
    "path": "wiki/copy-folder",
  })
  let copied_folder_json = match copied_folder {
    Ok(json) => json
    Err(error) => {
      fail(error.stringify())
      Json::object({})
    }
  }
  assert_eq(
    json_string(copied_folder_json, "path", default=""),
    "wiki/copy-folder copy",
  )
  assert_true(
    @fs.exists(@pathx.join(book_root, "wiki/copy-folder copy/child/file.txt")),
  )
  @fsx.write_to_file(@pathx.join(book_root, "wiki/batch-copy-a.md"), "a\n")
  @fsx.write_to_file(@pathx.join(book_root, "wiki/batch-copy-b.md"), "b\n")
  let batch_copy = copy_workspace_entry(workspace, {
    "paths": Json::array([
      "wiki/batch-copy-a.md".to_json(),
      "wiki/batch-copy-b.md".to_json(),
    ]),
  })
  let batch_copy_json = match batch_copy {
    Ok(json) => json
    Err(error) => {
      fail(error.stringify())
      Json::object({})
    }
  }
  assert_eq(json_int(batch_copy_json, "copied_count", default=0), 2)
  assert_true(@fs.exists(@pathx.join(book_root, "wiki/batch-copy-a copy.md")))
  assert_true(@fs.exists(@pathx.join(book_root, "wiki/batch-copy-b copy.md")))
  @fsx.make_directory(
    @pathx.join(book_root, "wiki/paste-target"),
    recursive=true,
  )
  let pasted_note = copy_workspace_entry(workspace, {
    "path": "wiki/copy-me.md",
    "directory": "wiki/paste-target",
  })
  let pasted_note_json = match pasted_note {
    Ok(json) => json
    Err(error) => {
      fail(error.stringify())
      Json::object({})
    }
  }
  assert_eq(
    json_string(pasted_note_json, "path", default=""),
    "wiki/paste-target/copy-me.md",
  )
  assert_true(@fs.exists(@pathx.join(book_root, "wiki/copy-me.md")))
  assert_true(
    @fs.exists(@pathx.join(book_root, "wiki/paste-target/copy-me.md")),
  )
  assert_eq(
    @fs.read_file(@pathx.join(book_root, "wiki/paste-target/copy-me.md")).text(),
    "copy me\n",
  )
  let pasted_note_again = copy_workspace_entry(workspace, {
    "path": "wiki/copy-me.md",
    "directory": "wiki/paste-target",
  })
  let pasted_note_again_json = match pasted_note_again {
    Ok(json) => json
    Err(error) => {
      fail(error.stringify())
      Json::object({})
    }
  }
  assert_eq(
    json_string(pasted_note_again_json, "path", default=""),
    "wiki/paste-target/copy-me copy.md",
  )
  @fsx.make_directory(@pathx.join(book_root, "wiki/same-a"), recursive=true)
  @fsx.make_directory(@pathx.join(book_root, "wiki/same-b"), recursive=true)
  @fsx.write_to_file(@pathx.join(book_root, "wiki/same-a/name.md"), "a\n")
  @fsx.write_to_file(@pathx.join(book_root, "wiki/same-b/name.md"), "b\n")
  let same_name_paste = copy_workspace_entry(workspace, {
    "paths": Json::array([
      "wiki/same-a/name.md".to_json(),
      "wiki/same-b/name.md".to_json(),
    ]),
    "directory": "wiki/paste-target",
  })
  let same_name_paste_json = match same_name_paste {
    Ok(json) => json
    Err(error) => {
      fail(error.stringify())
      Json::object({})
    }
  }
  assert_eq(json_int(same_name_paste_json, "copied_count", default=0), 2)
  assert_true(@fs.exists(@pathx.join(book_root, "wiki/paste-target/name.md")))
  assert_true(
    @fs.exists(@pathx.join(book_root, "wiki/paste-target/name copy.md")),
  )
  match copy_workspace_entry(workspace, { "path": "book/site/generated" }) {
    Ok(_) => fail("expected generated path copy rejection")
    Err(error) => assert_eq(json_int(error, "code", default=0), 400)
  }
  let trashed_note = trash_workspace_entry(workspace, { "path": "wiki/beta.md" })
  let trashed_note_json = match trashed_note {
    Ok(json) => json
    Err(error) => {
      fail(error.stringify())
      Json::object({})
    }
  }
  let trash_path = json_string(trashed_note_json, "trash_path", default="")
  assert_eq(json_string(trashed_note_json, "path", default=""), "wiki/beta.md")
  assert_true(
    trash_path.has_prefix(".moonsuite/products/moondesk/trash/files/"),
  )
  let trash_absolute = match resolve_desk_trash_path(book_root, trash_path) {
    Some(path) => path
    None => {
      fail("expected suite-level trash path")
      ""
    }
  }
  assert_true(@fs.exists(trash_absolute))
  assert_false(@fs.exists(@pathx.join(book_root, "wiki/beta.md")))
  assert_true(@fs.exists(desk_trash_receipts_root(book_root)))
  assert_false(@fs.exists(@pathx.join(book_root, ".moonsuite")))
  let trash_entries = list_workspace_trash_entries(workspace)
  assert_eq(trash_entries.length(), 1)
  assert_eq(
    json_string(trash_entries[0], "original_path", default=""),
    "wiki/beta.md",
  )
  assert_eq(json_string(trash_entries[0], "trash_path", default=""), trash_path)
  let root_entries_after_trash = list_workspace_entries(
    workspace, "", book_root,
  )
  assert_true(find_test_entry(root_entries_after_trash, ".moonsuite") is None)
  let restored_note = restore_workspace_entry(workspace, {
    "trash_path": trash_path,
  })
  let restored_note_json = match restored_note {
    Ok(json) => json
    Err(error) => {
      fail(error.stringify())
      Json::object({})
    }
  }
  assert_eq(json_string(restored_note_json, "path", default=""), "wiki/beta.md")
  assert_true(@fs.exists(@pathx.join(book_root, "wiki/beta.md")))
  assert_false(@fs.exists(trash_absolute))
  assert_eq(list_workspace_trash_entries(workspace).length(), 0)
  match trash_workspace_entry(workspace, { "path": "wiki" }) {
    Ok(_) => fail("expected section trash rejection")
    Err(error) => assert_eq(json_int(error, "code", default=0), 400)
  }
  match restore_workspace_entry(workspace, { "trash_path": "wiki/beta.md" }) {
    Ok(_) => fail("expected invalid trash restore rejection")
    Err(error) => assert_eq(json_int(error, "code", default=0), 400)
  }
  @fsx.write_to_file(@pathx.join(book_root, "wiki/batch-a.md"), "a\n")
  @fsx.write_to_file(@pathx.join(book_root, "wiki/batch-b.md"), "b\n")
  let batch_trash = trash_workspace_entry(workspace, {
    "paths": Json::array([
      "wiki/batch-a.md".to_json(),
      "wiki/batch-b.md".to_json(),
    ]),
  })
  let batch_trash_json = match batch_trash {
    Ok(json) => json
    Err(error) => {
      fail(error.stringify())
      Json::object({})
    }
  }
  assert_eq(json_int(batch_trash_json, "trashed_count", default=0), 2)
  assert_false(@fs.exists(@pathx.join(book_root, "wiki/batch-a.md")))
  assert_false(@fs.exists(@pathx.join(book_root, "wiki/batch-b.md")))
  assert_eq(list_workspace_trash_entries(workspace).length(), 2)
  assert_false(@fs.exists(@pathx.join(book_root, ".moonsuite")))
  match
    create_workspace_entry(workspace, {
      "kind": "folder",
      "directory": "wiki",
      "name": "../escape",
    }) {
    Ok(_) => fail("expected invalid name rejection")
    Err(error) => assert_eq(json_int(error, "code", default=0), 400)
  }
  match
    create_workspace_entry(workspace, {
      "kind": "markdown",
      "directory": "book/site/generated",
      "name": "generated",
    }) {
    Ok(_) => fail("expected generated path rejection")
    Err(error) => assert_eq(json_int(error, "code", default=0), 400)
  }
}

///|
async test "desk file import writes picked files into current directory" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-import-files-wbtest-" + @async.now().to_string(),
  )
  let book_root = @pathx.join(root, "books/research-import-files")
  @fsx.make_directory(
    @pathx.join(book_root, "wiki/drop-target"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(book_root, "book/site/generated"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "book.json"),
    "{\"name\":\"Import Files\"}\n",
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "wiki/drop-target/report.txt"),
    "old\n",
  )
  let workspace = @desk.workspace(
    id=@desk.stable_id("book", "research-import-files"),
    name="research-import-files",
    root_path=book_root,
    kind=MoonBook,
  )
  let imported = import_workspace_files(workspace, {
    "directory": "wiki/drop-target",
    "files": Json::array([
      {
        "filename": "report.txt",
        "content": "new report\n",
        "content_type": "text/plain",
      },
      {
        "filename": "logo.png",
        "data_url": "data:image/png;base64,cG5nLWJ5dGVz",
        "content_type": "image/png",
      },
      {
        "filename": "evidence.txt",
        "relative_path": "local-folder/nested/evidence.txt",
        "content": "nested evidence\n",
        "content_type": "text/plain",
      },
    ]),
  })
  let imported_json = match imported {
    Ok(json) => json
    Err(error) => {
      fail(error.stringify())
      Json::object({})
    }
  }
  assert_eq(json_int(imported_json, "imported_count", default=0), 3)
  assert_eq(
    json_string(imported_json, "path", default=""),
    "wiki/drop-target/report copy.txt",
  )
  assert_eq(
    @fs.read_file(@pathx.join(book_root, "wiki/drop-target/report.txt")).text(),
    "old\n",
  )
  assert_eq(
    @fs.read_file(@pathx.join(book_root, "wiki/drop-target/report copy.txt")).text(),
    "new report\n",
  )
  assert_eq(
    @fs.read_file(@pathx.join(book_root, "wiki/drop-target/logo.png")).text(),
    "png-bytes",
  )
  assert_eq(
    @fs.read_file(
      @pathx.join(
        book_root, "wiki/drop-target/local-folder/nested/evidence.txt",
      ),
    ).text(),
    "nested evidence\n",
  )
  match
    import_workspace_files(workspace, {
      "directory": "wiki/drop-target",
      "files": Json::array([
        { "filename": "escape.txt", "relative_path": "../escape.txt" },
      ]),
    }) {
    Ok(_) => fail("expected traversal import rejection")
    Err(error) => assert_eq(json_int(error, "code", default=0), 400)
  }
  match
    import_workspace_files(workspace, {
      "directory": "wiki/drop-target",
      "files": Json::array([
        { "filename": "config", "relative_path": ".git/config" },
      ]),
    }) {
    Ok(_) => fail("expected hidden folder import rejection")
    Err(error) => assert_eq(json_int(error, "code", default=0), 400)
  }
  match
    import_workspace_files(workspace, {
      "directory": "book/site/generated",
      "files": Json::array([{ "filename": "bad.txt", "content": "bad" }]),
    }) {
    Ok(_) => fail("expected generated import rejection")
    Err(error) => assert_eq(json_int(error, "code", default=0), 400)
  }
}

///|
async test "workspace entries expose virtual filesystem metadata" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-entry-metadata-wbtest-" + @async.now().to_string(),
  )
  let wiki_root = @pathx.join(root, "wiki")
  @fsx.make_directory(wiki_root, recursive=true, exists_ok=true)
  @fsx.write_to_file(@pathx.join(wiki_root, "index.md"), "hello desk\n")
  @fsx.make_directory(@pathx.join(wiki_root, "sources"), recursive=true)
  let workspace = @desk.workspace(
    id="book-demo",
    name="Demo",
    root_path=root,
    kind=MoonBook,
  )
  let entries = list_workspace_entries(workspace, "wiki", wiki_root)
  let index = find_test_entry(entries, "wiki/index.md")
  match index {
    Some(entry) => {
      assert_true(entry.size_bytes is Some(11))
      match entry.modified_at {
        Some(value) => assert_true(value.contains("T"))
        None => fail("missing modified_at")
      }
      assert_true(entry.readable)
      assert_true(entry.writable)
    }
    None => fail("missing index.md entry")
  }
  let sources = find_test_entry(entries, "wiki/sources")
  match sources {
    Some(entry) => {
      assert_true(entry.kind is Directory)
      assert_true(entry.size_bytes is None)
      assert_true(entry.modified_at is Some(_))
    }
    None => fail("missing sources directory entry")
  }
}

///|
async test "workspace entries use explorer ordering and hide host noise" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-entry-order-wbtest-" + @async.now().to_string(),
  )
  let wiki_root = @pathx.join(root, "wiki")
  @fsx.make_directory(@pathx.join(wiki_root, "sources"), recursive=true)
  @fsx.make_directory(@pathx.join(wiki_root, "Reviews"), recursive=true)
  @fsx.write_to_file(@pathx.join(wiki_root, "a-note.md"), "a\n")
  @fsx.write_to_file(@pathx.join(wiki_root, "z-note.md"), "z\n")
  @fsx.write_to_file(@pathx.join(wiki_root, ".DS_Store"), "noise\n")
  let workspace = @desk.workspace(
    id="book-demo",
    name="Demo",
    root_path=root,
    kind=MoonBook,
  )
  let entries = list_workspace_entries(workspace, "wiki", wiki_root)
  assert_eq(entries.length(), 4)
  assert_eq(entries[0].path, "wiki/Reviews")
  assert_true(entries[0].kind is Directory)
  assert_eq(entries[1].path, "wiki/sources")
  assert_true(entries[1].kind is Directory)
  assert_eq(entries[2].path, "wiki/a-note.md")
  assert_eq(entries[3].path, "wiki/z-note.md")
  assert_true(find_test_entry(entries, "wiki/.DS_Store") is None)
}

///|
async test "moonbook root entries project canonical virtual sections" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-virtual-root-wbtest-" + @async.now().to_string(),
  )
  @fsx.make_directory(@pathx.join(root, "wiki/history"), recursive=true)
  @fsx.make_directory(@pathx.join(root, "raw"), recursive=true)
  @fsx.make_directory(@pathx.join(root, "book/site/generated"), recursive=true)
  @fsx.write_to_file(@pathx.join(root, "book.json"), "{\"name\":\"Demo\"}\n")
  let workspace = @desk.workspace(
    id="book-demo",
    name="Demo",
    root_path=root,
    kind=MoonBook,
  )
  let entries = list_workspace_entries(workspace, "", root)
  assert_eq(entries[0].path, "wiki")
  assert_eq(entries[0].display_name, "Wiki")
  assert_true(entries[0].source_layer is Wiki)
  assert_eq(entries[1].path, "raw")
  assert_eq(entries[1].display_name, "Raw Evidence")
  assert_true(entries[1].source_layer is RawEvidence)
  assert_true(find_test_entry(entries, "wiki/history") is Some(_))
  assert_true(find_test_entry(entries, "book/site/generated") is Some(_))
  assert_true(find_test_entry(entries, "book.json") is Some(_))
  assert_true(find_test_entry(entries, "book") is None)
}

///|
async test "moonbook root keeps canonical sections before sorted host leftovers" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-root-leftover-order-wbtest-" + @async.now().to_string(),
  )
  @fsx.make_directory(@pathx.join(root, "zz-extra"), recursive=true)
  @fsx.write_to_file(@pathx.join(root, "aa-note.txt"), "note\n")
  @fsx.write_to_file(@pathx.join(root, ".DS_Store"), "noise\n")
  let workspace = @desk.workspace(
    id="book-demo",
    name="Demo",
    root_path=root,
    kind=MoonBook,
  )
  let entries = list_workspace_entries(workspace, "", root)
  assert_eq(entries[0].path, "wiki")
  assert_eq(entries[1].path, "raw")
  match find_test_entry_index(entries, "zz-extra") {
    Some(extra_index) =>
      match find_test_entry_index(entries, "aa-note.txt") {
        Some(note_index) => assert_true(extra_index < note_index)
        None => fail("missing leftover note")
      }
    None => fail("missing leftover directory")
  }
  assert_true(find_test_entry(entries, ".DS_Store") is None)
}

///|
async test "moonbook root projects missing canonical sections as virtual directories" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-missing-virtual-root-wbtest-" + @async.now().to_string(),
  )
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  @fsx.write_to_file(@pathx.join(root, "book.json"), "{\"name\":\"Demo\"}\n")
  let workspace = @desk.workspace(
    id="book-demo",
    name="Demo",
    root_path=root,
    kind=MoonBook,
  )
  let entries = list_workspace_entries(workspace, "", root)
  match find_test_entry(entries, "skills") {
    Some(entry) => {
      assert_eq(entry.display_name, "Skills")
      assert_true(entry.kind is Directory)
      assert_true(entry.source_layer is Skill)
      assert_true(entry.readable)
      assert_false(entry.writable)
      assert_true(entry.size_bytes is None)
      assert_true(entry.modified_at is None)
    }
    None => fail("missing virtual skills section")
  }
  assert_true(find_test_entry(entries, "tools") is Some(_))
  assert_true(find_test_entry(entries, "portable/app-tool") is Some(_))
  assert_eq(
    list_workspace_entries(workspace, "skills", @pathx.join(root, "skills")).length(),
    0,
  )
  assert_true(is_virtual_moonbook_section(workspace, "skills"))
}

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

///|
async test "review item collection includes source files and decision receipts" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-review-items-wbtest-" + @async.now().to_string(),
  )
  let book_root = @pathx.join(root, "books/research-review")
  @fsx.make_directory(@pathx.join(book_root, "wiki/reviews"), recursive=true)
  @fsx.write_to_file(
    @pathx.join(book_root, "book.json"),
    "{\"name\":\"Research Review\"}\n",
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "wiki/reviews/pending.md"),
    "# Pending\n",
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "wiki/reviews/rejected.md"),
    "# Rejected\n",
  )
  let workspace_id = @desk.stable_id("book", "research-review")
  let accepted = write_review_item_decision(root, {
    "workspace_id": workspace_id,
    "path": "wiki/reviews/pending.md",
    "decision": "accepted",
    "note": "accepted",
  })
  let rejected = write_review_item_decision(root, {
    "workspace_id": workspace_id,
    "path": "wiki/reviews/rejected.md",
    "decision": "rejected",
    "note": "rejected",
  })
  let accepted_path = match accepted {
    Ok(json) => json_string(json, "receipt_path", default="")
    Err(message) => {
      fail(message)
      ""
    }
  }
  let rejected_path = match rejected {
    Ok(json) => json_string(json, "receipt_path", default="")
    Err(message) => {
      fail(message)
      ""
    }
  }
  let items = collect_review_items(root, Some(workspace_id), 120)
  let text = Json::array(items).stringify()
  assert_true(text.contains("wiki/reviews/pending.md"))
  assert_true(text.contains("wiki/reviews/rejected.md"))
  assert_true(text.contains(accepted_path))
  assert_true(text.contains(rejected_path))
}

///|
async test "desk server routes work end to end and reject path escapes" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-desk-server-wbtest-" + @async.now().to_string(),
  )
  let ui_root = @pathx.join(root, "ui")
  let book_root = @pathx.join(root, "books/research-desk")
  let import_source = @pathx.join(root, "existing-import-source")
  @fsx.make_directory(ui_root, recursive=true, exists_ok=true)
  @fsx.make_directory(@pathx.join(book_root, "wiki/notes"), recursive=true)
  @fsx.make_directory(@pathx.join(book_root, "raw"), recursive=true)
  @fsx.make_directory(
    @pathx.join(book_root, "book/site/generated/assets"),
    recursive=true,
  )
  @fsx.make_directory(@pathx.join(book_root, "images"), recursive=true)
  @fsx.write_to_file(@pathx.join(ui_root, "index.html"), "<main>ui</main>")
  @fsx.write_to_file(
    @pathx.join(book_root, "book.json"),
    "{\"name\":\"Research Desk\"}\n",
  )
  @fsx.write_to_file(@pathx.join(book_root, "wiki/index.md"), "# Desk\n")
  @fsx.write_to_file(@pathx.join(book_root, "wiki/notes/alpha.md"), "alpha\n")
  @fsx.write_to_file(@pathx.join(book_root, "raw/evidence.txt"), "evidence\n")
  @fsx.write_to_file(
    @pathx.join(book_root, "book/site/generated/index.html"),
    "<html><link rel=\"stylesheet\" href=\"assets/site.css\"></html>",
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "book/site/generated/assets/site.css"),
    "body { color: black; }\n",
  )
  @fsx.write_to_file(@pathx.join(book_root, "images/logo.png"), "png-bytes")
  @fsx.make_directory(@pathx.join(import_source, "wiki"), recursive=true)
  @fsx.write_to_file(
    @pathx.join(import_source, "book.json"),
    "{\"id\":\"desk-imported\",\"name\":\"Desk Imported\"}\n",
  )
  @fsx.write_to_file(
    @pathx.join(import_source, "wiki/index.md"),
    "# Imported HTTP\n",
  )
  @fsx.write_to_file(@pathx.join(root, "outside.txt"), "outside-secret\n")

  let server = Server::new("127.0.0.1", 0, reuse_addr=true)
  defer server.close()
  @async.with_task_group(group => {
    group.spawn_bg(
      () => server.serve_desk(ui_root, root),
      no_wait=true,
      allow_failure=true,
    )
    @async.sleep(20)
    let base = "http://127.0.0.1:\{server.port()}"
    let workspace_id = @desk.stable_id("book", "research-desk")

    let workspaces = test_http_get_json(base + "/api/workspaces", 200)
    assert_true(workspaces.stringify().contains("\"id\":\"\{workspace_id}\""))
    let created = test_http_post_json(
      base + "/api/workspaces",
      { "name": "Desk HTTP Book", "book_id": "desk-http-book" },
      200,
    )
    let created_workspace_id = @desk.stable_id("book", "desk-http-book")
    assert_eq(
      json_string(created, "workspace_id", default=""),
      created_workspace_id,
    )
    assert_true(
      @fs.exists(@pathx.join(root, "books/desk-http-book/wiki/index.md")),
    )
    let refreshed_workspaces = test_http_get_json(base + "/api/workspaces", 200)
    assert_true(
      refreshed_workspaces
      .stringify()
      .contains("\"id\":\"\{created_workspace_id}\""),
    )
    let imported = test_http_post_json(
      base + "/api/workspaces/import",
      { "source_path": import_source },
      200,
    )
    let imported_workspace_id = @desk.stable_id("book", "desk-imported")
    assert_eq(
      json_string(imported, "workspace_id", default=""),
      imported_workspace_id,
    )
    assert_true(
      @fs.exists(@pathx.join(root, "books/desk-imported/wiki/index.md")),
    )
    let workspaces_after_import = test_http_get_json(
      base + "/api/workspaces",
      200,
    )
    assert_true(
      workspaces_after_import
      .stringify()
      .contains("\"id\":\"\{imported_workspace_id}\""),
    )

    let root_entries = test_http_get_json(
      base + "/api/workspaces/\{workspace_id}/entries?path=",
      200,
    )
    let root_text = root_entries.stringify()
    assert_true(root_text.contains("\"path\":\"wiki\""))
    assert_true(root_text.contains("\"path\":\"raw\""))
    assert_false(root_text.contains(".git"))

    let wiki_entries = test_http_get_json(
      base + "/api/workspaces/\{workspace_id}/entries?path=wiki",
      200,
    )
    let wiki_text = wiki_entries.stringify()
    assert_true(wiki_text.contains("\"path\":\"wiki/notes\""))
    assert_true(wiki_text.contains("\"path\":\"wiki/index.md\""))

    let created_folder = test_http_post_json(
      base + "/api/workspaces/\{workspace_id}/entries",
      { "kind": "folder", "directory": "wiki", "name": "http-notes" },
      200,
    )
    assert_eq(
      json_string(created_folder, "path", default=""),
      "wiki/http-notes",
    )
    assert_true(@fs.exists(@pathx.join(book_root, "wiki/http-notes")))
    let created_note = test_http_post_json(
      base + "/api/workspaces/\{workspace_id}/entries",
      { "kind": "markdown", "directory": "wiki/http-notes", "name": "daily" },
      200,
    )
    assert_eq(
      json_string(created_note, "path", default=""),
      "wiki/http-notes/daily.md",
    )
    assert_true(@fs.exists(@pathx.join(book_root, "wiki/http-notes/daily.md")))
    let renamed_note = test_http_post_json(
      base + "/api/workspaces/\{workspace_id}/rename",
      { "path": "wiki/http-notes/daily.md", "name": "renamed-daily" },
      200,
    )
    assert_eq(
      json_string(renamed_note, "path", default=""),
      "wiki/http-notes/renamed-daily.md",
    )
    assert_true(
      @fs.exists(@pathx.join(book_root, "wiki/http-notes/renamed-daily.md")),
    )
    assert_false(@fs.exists(@pathx.join(book_root, "wiki/http-notes/daily.md")))
    let created_archive = test_http_post_json(
      base + "/api/workspaces/\{workspace_id}/entries",
      { "kind": "folder", "directory": "wiki", "name": "http-archive" },
      200,
    )
    assert_eq(
      json_string(created_archive, "path", default=""),
      "wiki/http-archive",
    )
    let moved_note = test_http_post_json(
      base + "/api/workspaces/\{workspace_id}/move",
      {
        "path": "wiki/http-notes/renamed-daily.md",
        "directory": "wiki/http-archive",
      },
      200,
    )
    assert_eq(
      json_string(moved_note, "path", default=""),
      "wiki/http-archive/renamed-daily.md",
    )
    assert_true(
      @fs.exists(@pathx.join(book_root, "wiki/http-archive/renamed-daily.md")),
    )
    assert_false(
      @fs.exists(@pathx.join(book_root, "wiki/http-notes/renamed-daily.md")),
    )
    let trashed_note = test_http_post_json(
      base + "/api/workspaces/\{workspace_id}/trash",
      { "path": "wiki/http-archive/renamed-daily.md" },
      200,
    )
    let trash_path = json_string(trashed_note, "trash_path", default="")
    assert_true(
      trash_path.has_prefix(".moonsuite/products/moondesk/trash/files/"),
    )
    let trash_absolute = match resolve_desk_trash_path(book_root, trash_path) {
      Some(path) => path
      None => {
        fail("expected suite-level trash path")
        ""
      }
    }
    assert_true(@fs.exists(trash_absolute))
    assert_false(@fs.exists(@pathx.join(book_root, ".moonsuite")))
    assert_false(
      @fs.exists(@pathx.join(book_root, "wiki/http-archive/renamed-daily.md")),
    )
    let restored_note = test_http_post_json(
      base + "/api/workspaces/\{workspace_id}/restore",
      { "trash_path": trash_path },
      200,
    )
    assert_eq(
      json_string(restored_note, "path", default=""),
      "wiki/http-archive/renamed-daily.md",
    )
    assert_true(
      @fs.exists(@pathx.join(book_root, "wiki/http-archive/renamed-daily.md")),
    )
    assert_false(@fs.exists(trash_absolute))

    let preview = test_http_get_json(
      base + "/api/workspaces/\{workspace_id}/preview?path=wiki%2Findex.md",
      200,
    )
    assert_true(preview.stringify().contains("# Desk"))

    let image_preview = test_http_get_json(
      base + "/api/workspaces/\{workspace_id}/preview?path=images%2Flogo.png",
      200,
    )
    assert_true(
      image_preview
      .stringify()
      .contains("/api/workspaces/\{workspace_id}/raw?path=images/logo.png"),
    )

    let (_, raw_body) = test_http_get(
      base + "/api/workspaces/\{workspace_id}/raw?path=raw%2Fevidence.txt",
      200,
    )
    assert_eq(raw_body, "evidence\n")

    let (_, file_body) = test_http_get(
      base + "/api/workspaces/\{workspace_id}/file/images/logo.png",
      200,
    )
    assert_eq(file_body, "png-bytes")

    let (_, site_body) = test_http_get(
      base + "/api/workspaces/\{workspace_id}/site/assets/site.css",
      200,
    )
    assert_true(site_body.contains("color: black"))

    ignore(
      test_http_get(
        base +
        "/api/workspaces/\{workspace_id}/entries?path=%2e%2e%2Foutside.txt",
        400,
      ),
    )
    ignore(
      test_http_get(
        base + "/api/workspaces/\{workspace_id}/raw?path=%2Ftmp%2Foutside.txt",
        400,
      ),
    )
  })
}

///|
async test "wiki server routes cover forward and backward book runs" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-wiki-server-wbtest-" + @async.now().to_string(),
  )
  let ui_root = @pathx.join(root, "ui")
  let book_root = @pathx.join(root, "books/research-wiki")
  @fsx.make_directory(ui_root, recursive=true, exists_ok=true)
  @fsx.make_directory(@pathx.join(book_root, "wiki/findings"), recursive=true)
  @fsx.make_directory(@pathx.join(book_root, "wiki/reviews"), recursive=true)
  @fsx.make_directory(@pathx.join(book_root, "raw/sources"), recursive=true)
  @fsx.make_directory(
    @pathx.join(book_root, "book/site/generated/assets"),
    recursive=true,
  )
  @fsx.make_directory(
    @pathx.join(moonclaw_jobs_root(book_root), "run-forward-001/artifacts"),
    recursive=true,
  )
  @fsx.write_to_file(@pathx.join(ui_root, "index.html"), "<main>wiki ui</main>")
  @fsx.write_to_file(
    @pathx.join(book_root, "book.json"),
    "{\"name\":\"Research Wiki\"}\n",
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "wiki/index.md"),
    "# Accepted\n\nbaseline\n",
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "wiki/findings/open.md.base"),
    "# Finding\n\nold line\n",
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "wiki/findings/open.md"),
    "# Finding\n\nnew line\n",
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "wiki/reviews/pending.md"),
    "# Review\n\nNeeds acceptance.\n",
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "wiki/reviews/rejected.md"),
    "# Review\n\nNeeds rejection.\n",
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "raw/sources/source-a.txt"),
    "primary evidence\n",
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "book/site/generated/findings.html"),
    "<html><body>Generated finding links back to wiki/findings/open.md</body></html>",
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "book/site/generated/assets/site.css"),
    "main { color: black; }\n",
  )
  @fsx.write_to_file(
    @pathx.join(moonclaw_jobs_root(book_root), "run-forward-001/events.jsonl"),
    "{\"type\":\"review\",\"title\":\"Forward review\",\"message\":\"complete review ready\"}\n",
  )
  @fsx.write_to_file(
    @pathx.join(moonclaw_jobs_root(book_root), "run-forward-001/result.json"),
    "{\"status\":\"complete\",\"summary\":\"forward run complete\"}\n",
  )
  @fsx.write_to_file(
    @pathx.join(
      moonclaw_jobs_root(book_root),
      "run-forward-001/artifacts/generated-summary.md",
    ),
    "# Generated Summary\n\nnew line\n",
  )
  assert_false(@fs.exists(@pathx.join(book_root, ".moonsuite")))
  @fsx.write_to_file(@pathx.join(root, "outside.md"), "outside\n")

  let server = Server::new("127.0.0.1", 0, reuse_addr=true)
  defer server.close()
  @async.with_task_group(group => {
    group.spawn_bg(
      () => server.serve_desk(ui_root, root),
      no_wait=true,
      allow_failure=true,
    )
    @async.sleep(20)
    let base = "http://127.0.0.1:\{server.port()}"
    let workspace_id = @desk.stable_id("book", "research-wiki")

    let inbox_created = test_http_post_json(
      base + "/api/workspaces/\{workspace_id}/inbox",
      {
        "title": "Forward seed",
        "content": "Promote this into Wiki knowledge.",
      },
      200,
    )
    let inbox_path = json_string(inbox_created, "path", default="")
    assert_true(inbox_path.has_prefix("inbox/"))
    assert_true(@fs.exists(@pathx.join(book_root, inbox_path)))
    assert_true(
      @fs.read_file(@pathx.join(book_root, inbox_path))
      .text()
      .contains("Promote this into Wiki knowledge."),
    )

    let import_created = test_http_post_json(
      base + "/api/workspaces/\{workspace_id}/import",
      {
        "kind": "url",
        "title": "Source import",
        "url": "https://example.invalid/source",
        "note": "offline source fixture",
        "data_url": "data:text/plain;base64,c291cmNl",
      },
      200,
    )
    let import_path = json_string(import_created, "path", default="")
    let data_path = json_string(import_created, "data_path", default="")
    assert_true(import_path.has_prefix("inbox/imports/"))
    assert_true(data_path.has_suffix(".data-url.txt"))
    assert_true(@fs.exists(@pathx.join(book_root, import_path)))
    assert_true(@fs.exists(@pathx.join(book_root, data_path)))

    let markdown_saved = test_http_post_json(
      base + "/api/workspaces/\{workspace_id}/markdown",
      {
        "path": "wiki/findings/forward-seed.md",
        "content": "# Forward Seed\n\nPromote this into Wiki knowledge.\n",
      },
      200,
    )
    assert_eq(
      json_string(markdown_saved, "path", default=""),
      "wiki/findings/forward-seed.md",
    )
    assert_eq(
      @fs.read_file(@pathx.join(book_root, "wiki/findings/forward-seed.md")).text(),
      "# Forward Seed\n\nPromote this into Wiki knowledge.\n",
    )

    let search_hits = test_http_get_json(
      base +
      "/api/search?workspace=\{workspace_id}&query=Promote%20this%20into%20Wiki%20knowledge",
      200,
    )
    let search_text = search_hits.stringify()
    assert_true(search_text.contains("wiki/findings/forward-seed.md"))
    assert_true(search_text.contains("\"source_layer\":\"Wiki\""))

    let review_diff = test_http_get_json(
      base +
      "/api/workspaces/\{workspace_id}/review-diff?path=wiki%2Ffindings%2Fopen.md",
      200,
    )
    assert_true(json_bool(review_diff, "changed", default=false))
    assert_eq(json_int(review_diff, "added", default=0), 1)
    assert_eq(json_int(review_diff, "removed", default=0), 1)
    assert_eq(
      json_string(review_diff, "base_path", default=""),
      "wiki/findings/open.md.base",
    )

    let accepted_decision = test_http_post_json(
      base + "/api/review/items/decision",
      {
        "workspace_id": workspace_id,
        "path": "wiki/reviews/pending.md",
        "decision": "accepted",
        "note": "Bookkeeper accepted this fixture.",
      },
      200,
    )
    assert_eq(
      json_string(accepted_decision, "decision", default=""),
      "accepted",
    )
    assert_eq(
      json_string(accepted_decision, "source_path", default=""),
      "wiki/reviews/pending.md",
    )
    let accepted_receipt_path = json_string(
      accepted_decision,
      "receipt_path",
      default="",
    )
    assert_true(accepted_receipt_path.has_prefix("wiki/reviews/decisions/"))
    assert_true(@fs.exists(@pathx.join(book_root, accepted_receipt_path)))
    assert_true(
      @fs.read_file(@pathx.join(book_root, accepted_receipt_path))
      .text()
      .contains("Bookkeeper accepted this fixture."),
    )

    let before_reject_index = @fs.read_file(
      @pathx.join(book_root, "wiki/index.md"),
    ).text()
    let rejected_decision = test_http_post_json(
      base + "/api/review/items/decision",
      {
        "workspace_id": workspace_id,
        "path": "wiki/reviews/rejected.md",
        "decision": "rejected",
        "note": "Bookkeeper rejected this fixture.",
      },
      200,
    )
    assert_eq(
      json_string(rejected_decision, "decision", default=""),
      "rejected",
    )
    assert_eq(
      @fs.read_file(@pathx.join(book_root, "wiki/index.md")).text(),
      before_reject_index,
    )
    let rejected_receipt_path = json_string(
      rejected_decision,
      "receipt_path",
      default="",
    )
    assert_true(@fs.exists(@pathx.join(book_root, rejected_receipt_path)))

    let review_items = test_http_get_json(
      base + "/api/review/items?workspace=\{workspace_id}",
      200,
    )
    let review_text = review_items.stringify()
    assert_true(review_text.contains("wiki/reviews/pending.md"))
    assert_true(review_text.contains(accepted_receipt_path))
    assert_true(review_text.contains(rejected_receipt_path))

    ignore(
      test_http_post_json(
        base + "/api/review/items/decision",
        {
          "workspace_id": workspace_id,
          "path": "../outside.md",
          "decision": "accepted",
          "note": "invalid",
        },
        400,
      ),
    )

    let town_request = test_http_post_json(
      base + "/api/town/requests",
      {
        "title": "Forward Wiki run",
        "prompt": "Summarize source-a into accepted Wiki knowledge.",
        "book_id": "research-wiki",
      },
      200,
    )
    assert_eq(json_string(town_request, "status", default=""), "staged")
    let request_path = json_string(town_request, "path", default="")
    assert_true(
      request_path.has_prefix(".moonsuite/products/moontown/moondesk-requests/"),
    )
    let request_path_parts = request_path.split("/").to_array()
    assert_true(
      @fs.exists(
        town_moondesk_request_path(
          root,
          request_path_parts[request_path_parts.length() - 1].to_owned(),
        ),
      ),
    )

    let requests = test_http_get_json(base + "/api/town/requests", 200)
    assert_true(requests.stringify().contains("Forward Wiki run"))
    let town_events = test_http_get_json(base + "/api/town/events", 200)
    assert_true(town_events.stringify().contains("Forward Wiki run"))

    let moonclaw_events = test_http_get_json(
      base + "/api/moonclaw/events?workspace=\{workspace_id}",
      200,
    )
    let moonclaw_text = moonclaw_events.stringify()
    assert_true(moonclaw_text.contains("run-forward-001"))
    assert_true(moonclaw_text.contains("Forward review"))

    let (_, site_body) = test_http_get(
      base + "/api/workspaces/\{workspace_id}/site/findings.html",
      200,
    )
    assert_true(site_body.contains("wiki/findings/open.md"))
    let (_, raw_body) = test_http_get(
      base +
      "/api/workspaces/\{workspace_id}/raw?path=raw%2Fsources%2Fsource-a.txt",
      200,
    )
    assert_eq(raw_body, "primary evidence\n")
    let (_, artifact_body) = test_http_get(
      base +
      "/api/workspaces/\{workspace_id}/raw?path=.moonsuite%2Fproducts%2Fmoonclaw%2Fjobs%2Frun-forward-001%2Fartifacts%2Fgenerated-summary.md",
      200,
    )
    assert_true(artifact_body.contains("Generated Summary"))

    ignore(
      test_http_post_json(
        base + "/api/workspaces/\{workspace_id}/markdown",
        { "path": "raw/escaped.md", "content": "no\n" },
        400,
      ),
    )
    ignore(
      test_http_post_json(
        base + "/api/workspaces/\{workspace_id}/markdown",
        { "path": "wiki/../raw/escaped.md", "content": "no\n" },
        400,
      ),
    )
    ignore(
      test_http_get(
        base +
        "/api/workspaces/\{workspace_id}/preview?path=%2e%2e%2Foutside.md",
        400,
      ),
    )
    assert_false(@fs.exists(@pathx.join(book_root, "raw/escaped.md")))
    assert_eq(
      @fs.read_file(@pathx.join(root, "outside.md")).text(),
      "outside\n",
    )
  })
}

///|
async fn test_http_get(
  url : String,
  expected_code : Int,
) -> (@http.Response, String) {
  let (response, data) = @http.get(url)
  let body = data.text()
  assert_eq(response.code, expected_code)
  (response, body)
}

///|
async fn test_http_post_json(
  url : String,
  body : Json,
  expected_code : Int,
) -> Json {
  let (response, data) = @http.post(url, body, headers={
    "Content-Type": "application/json",
  })
  let text = data.text()
  assert_eq(response.code, expected_code)
  @json.parse(text) catch {
    _ => {
      fail("expected JSON response from " + url + ": " + text)
      Json::object({})
    }
  }
}

///|
async fn test_http_get_json(url : String, expected_code : Int) -> Json {
  let (_, body) = test_http_get(url, expected_code)
  @json.parse(body) catch {
    _ => {
      fail("expected JSON response from " + url + ": " + body)
      Json::object({})
    }
  }
}

///|
fn find_test_entry(
  entries : Array[@desk.DeskFileEntry],
  path : String,
) -> @desk.DeskFileEntry? {
  for entry in entries {
    if entry.path == path {
      return Some(entry)
    }
  }
  None
}

///|
fn find_test_entry_index(
  entries : Array[@desk.DeskFileEntry],
  path : String,
) -> Int? {
  for index, entry in entries {
    if entry.path == path {
      return Some(index)
    }
  }
  None
}

///|
test "request body helpers handle optional strings" {
  let payload : Json = { "title": "Draft", "path": "inbox/draft.md" }
  assert_eq(json_string(payload, "title", default="Fallback"), "Draft")
  assert_true(json_string_opt(payload, "path") is Some("inbox/draft.md"))
  assert_true(json_string_opt(payload, "missing") is None)
}

///|
async test "workspace markdown edits stay scoped to wiki and inbox markdown" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-markdown-edit-wbtest-" + @async.now().to_string(),
  )
  @fsx.make_directory(@pathx.join(root, "wiki"), recursive=true)
  let workspace = @desk.workspace(
    id="book-demo",
    name="Demo",
    root_path=root,
    kind=MoonBook,
  )
  match write_workspace_markdown(workspace, "wiki/index.md", "# Updated\n") {
    Ok(path) => assert_eq(path, "wiki/index.md")
    Err(message) => fail(message)
  }
  assert_eq(
    @fs.read_file(@pathx.join(root, "wiki/index.md")).text(),
    "# Updated\n",
  )
  match write_workspace_markdown(workspace, "inbox/draft.markdown", "Draft\n") {
    Ok(path) => assert_eq(path, "inbox/draft.markdown")
    Err(message) => fail(message)
  }
  assert_eq(
    @fs.read_file(@pathx.join(root, "inbox/draft.markdown")).text(),
    "Draft\n",
  )
}

///|
async test "workspace markdown edits reject raw and non markdown paths" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-markdown-edit-reject-wbtest-" + @async.now().to_string(),
  )
  @fsx.make_directory(@pathx.join(root, "raw"), recursive=true)
  let workspace = @desk.workspace(
    id="book-demo",
    name="Demo",
    root_path=root,
    kind=MoonBook,
  )
  match write_workspace_markdown(workspace, "raw/source.md", "no\n") {
    Ok(_) => fail("raw markdown should not be writable through MoonWiki edit")
    Err(message) => assert_true(message.contains("wiki/*.md"))
  }
  match write_workspace_markdown(workspace, "wiki/config.json", "{}\n") {
    Ok(_) => fail("json should not be writable through MoonWiki edit")
    Err(message) => assert_true(message.contains("wiki/*.md"))
  }
  assert_false(@fs.exists(@pathx.join(root, "raw/source.md")))
  assert_false(@fs.exists(@pathx.join(root, "wiki/config.json")))
}

///|
test "moondesk health payload exposes readiness contract" {
  assert_eq(moondesk_health_path(), "/__moondesk_health")
  let suite_root = "/tmp/moondesk-health-suite"
  let book_root = @pathx.join(suite_root, "books/research-health")
  let health = moondesk_health_json("ui/rabbita-desk/dist", book_root)
  assert_true(json_bool(health, "ok", default=false))
  assert_eq(json_string(health, "service", default=""), "moondesk")
  assert_true(
    json_string(health, "ui_root", default="").contains("ui/rabbita-desk/dist"),
  )
  assert_eq(json_string(health, "workspace_root", default=""), book_root)
  assert_eq(json_string(health, "suite_root", default=""), suite_root)
  assert_eq(
    json_string(health, "books_root", default=""),
    @pathx.join(suite_root, "books"),
  )
  assert_eq(
    json_string(health, "suite_path", default=""),
    @pathx.join(suite_root, ".moonsuite"),
  )
  assert_true(
    !json_string(health, "suite_path", default="").contains(
      "books/research-health/.moonsuite",
    ),
  )
}

///|
test "town request listing normalizes book-pattern handoff records" {
  let record : Json = {
    "id": "request-publish-research-policy-watch",
    "kind": "book-pattern-publish",
    "status": "ready-for-moontown",
    "book_id": "research-policy-watch",
    "title": "Policy Reports PDF Evidence Watch",
    "pattern_id": "pdf-evidence-watch",
    "purpose": "Standing research-book for official-source discovery.",
  }
  let listing = town_request_listing_record(
    record, "research-policy-watch.json",
  )
  assert_eq(
    json_string(listing, "id", default=""),
    "request-publish-research-policy-watch",
  )
  assert_eq(json_string(listing, "status", default=""), "ready-for-moontown")
  assert_eq(
    json_string(listing, "path", default=""),
    ".moonsuite/products/moontown/moondesk-requests/research-policy-watch.json",
  )
  let request = json_object_field_or_empty(listing, "request")
  assert_eq(
    json_string(request, "title", default=""),
    "Policy Reports PDF Evidence Watch",
  )
  assert_eq(
    json_string(request, "book_id", default=""),
    "research-policy-watch",
  )
  assert_eq(
    json_string(request, "pattern_id", default=""),
    "pdf-evidence-watch",
  )
}

///|
fn parse_moonclaw_json_output_for_test(text : String) -> Json {
  let parsed = @json.parse(text) catch { _ => Json::object({}) }
  if json_string(parsed, "proposal_id", default="") != "" {
    return parsed
  }
  let lines = text.split("\n").to_array()
  let mut index = lines.length()
  while index > 0 {
    index -= 1
    let line = lines[index].to_owned().trim().to_owned()
    if line == "{" || line.contains("\"proposal_id\"") {
      let candidate_lines : Array[String] = []
      let mut cursor = index
      while cursor < lines.length() {
        candidate_lines.push(lines[cursor].to_owned())
        cursor += 1
      }
      let candidate = candidate_lines.join("\n").trim().to_owned()
      let candidate_json = @json.parse(candidate) catch {
        _ => Json::object({})
      }
      if json_string(candidate_json, "proposal_id", default="") != "" {
        return candidate_json
      }
    }
  }
  Json::object({})
}

///|
test "moonclaw json parser tolerates log-prefixed pretty json" {
  let parsed = parse_moonclaw_json_output_for_test(
    "{\"level\":\"Info\",\"msg\":\"started\"}\n" +
    "{\n  \"proposal_id\": \"proposal-1\",\n  \"run_id\": \"run-1\",\n  \"status\": \"WaitingForInput\"\n}\n",
  )
  assert_eq(json_string(parsed, "proposal_id", default=""), "proposal-1")
  assert_eq(json_string(parsed, "run_id", default=""), "run-1")
  assert_eq(json_string(parsed, "status", default=""), "WaitingForInput")
}

///|
test "import markdown records URL and attachment sidecar" {
  let markdown = import_markdown(
    {
      "url": "https://example.com",
      "note": "keep this",
      "data_url": "data:image/png;base64,abc",
    },
    "url",
    "Example",
  )
  assert_true(markdown.contains("# Example"))
  assert_true(markdown.contains("- URL: https://example.com"))
  assert_true(markdown.contains("keep this"))
  assert_true(markdown.contains(".data-url.txt"))
}

///|
test "calendar escaping keeps ICS text single-line" {
  let escaped = ics_escape("A, B; C\nD")
  assert_eq(escaped, "A\\, B\\; C D")
}

///|
test "standing goal records normalize host payloads" {
  let record = standing_goal_record_from_payload(
    {
      "title": "Track APIs",
      "prompt": "Watch API docs",
      "target_book_id": "research-api",
      "cadence_ticks": "0",
      "review_policy": "accepted_new_knowledge",
      "source_policy": "web-first",
    },
    daemon_tick=42,
  )
  assert_eq(json_string(record, "id", default=""), "watch-track-apis")
  assert_eq(json_int(record, "cadence_ticks", default=0), 1)
  assert_eq(
    json_string(record, "review_policy", default=""),
    "accepted_new_knowledge",
  )
  assert_eq(json_int(record, "next_due_tick", default=0), 42)
}

///|
test "pdf evidence watch pattern builds reusable book and goal ids" {
  let base_types = book_base_type_records_from_patterns(book_pattern_records())
  assert_eq(base_types.length(), 1)
  assert_eq(json_string(base_types[0], "id", default=""), "research-book")
  assert_true(base_types[0].stringify().contains("pdf-evidence-watch"))
  assert_eq(book_pattern_base_type("pdf-evidence-watch"), "research-book")
  assert_eq(book_pattern_base_type("external-pack"), "")
  assert_true(book_pattern_supported("pdf-evidence-watch"))
  assert_false(book_pattern_supported("external-pack"))
  assert_true(book_pattern_supports_standing_watch("pdf-evidence-watch"))
  assert_false(book_pattern_supports_standing_watch("external-pack"))
  assert_eq(
    book_pattern_creation_backend("pdf-evidence-watch"),
    "builtin-pdf-evidence-watch",
  )
  assert_eq(book_pattern_creation_backend("external-pack"), "")
  assert_true(
    book_pattern_template_registry_refs("pdf-evidence-watch").contains(
      "moontown://templates/books/pdf-evidence-watch/book.json",
    ),
  )
  assert_true(
    default_skill_pack_for_pattern("pdf-evidence-watch") ==
    ["pdf-watch", "pdf-analysis"],
  )
  assert_true(default_skill_pack_for_pattern("external-pack") == [])
  assert_eq(
    normalize_pdf_watch_book_id(
      "research-my-domain-pdf-watch",
      topic="Ignored Topic",
      pattern_id="pdf-evidence-watch",
    ),
    "research-my-domain-pdf-watch",
  )
  let book_id = pdf_watch_book_id(
    "Policy Reports",
    pattern_id="pdf-evidence-watch",
  )
  assert_eq(book_id, "research-policy-reports-pdf-watch")
  let goal = pdf_watch_standing_goal(
    book_id~,
    topic="Policy Reports",
    pattern_id="pdf-evidence-watch",
    purpose="Watch policy reports",
    cadence=30,
    source_policy="web-first",
    daemon_tick=7,
  )
  assert_eq(json_string(goal, "target_book_id", default=""), book_id)
  assert_eq(json_string(goal, "id", default=""), "watch-\{book_id}-pdfs")
  assert_eq(json_int(goal, "cadence_ticks", default=0), 30)
  assert_true(json_string(goal, "prompt", default="").contains("Bookkeeper"))
  let config = pdf_watch_book_json(
    book_id~,
    topic="Policy Reports",
    pattern_id="pdf-evidence-watch",
    purpose="Watch policy reports",
    cadence=30,
    websites=["https://example.org/reports"],
    source_policy="web-first",
    method_path="wiki/methods/analysis-method.md",
    notify_on=["accepted_new_knowledge"],
    skill_pack=["pdf-watch", "pdf-analysis", "source-screening"],
  )
  assert_eq(json_string(config, "type", default=""), "research-book")
  assert_eq(json_string(config, "book_type", default=""), "research-book")
  assert_eq(json_string(config, "pattern", default=""), "pdf-evidence-watch")
  assert_eq(
    json_string(config, "specialization", default=""),
    "pdf-evidence-watch",
  )
  let targets = json_object_field_or_empty(config, "targets")
  assert_eq(json_int(targets, "target_count", default=-1), 0)
  assert_false(json_bool(targets, "multi_target_supported", default=true))
  let watch = json_object_field_or_empty(config, "watch")
  assert_true(json_string_array_items(watch, "file_types") == ["pdf"])
  assert_true(
    json_string_array_items(watch, "notify_on") == ["accepted_new_knowledge"],
  )
  let analysis = json_object_field_or_empty(config, "analysis")
  assert_eq(
    json_string(analysis, "method_page", default=""),
    "wiki/methods/analysis-method.md",
  )
  assert_eq(
    json_string(analysis, "source_schema", default=""),
    "schemas/pdf-source.schema.md",
  )
  assert_true(
    json_string_array_items(analysis, "skills").contains("source-screening"),
  )
  assert_true(
    json_string_array_items(
      json_object_field_or_empty(config, "moondesk"),
      "skill_pack",
    ).contains("pdf-analysis"),
  )
  assert_true(
    pdf_watch_notify_on_from_payload({ "notify_on": ["new_finding"] }) ==
    ["new_finding"],
  )
  assert_true(
    pdf_watch_notify_on_from_payload({ "notify_rule": "changed_conclusion" }) ==
    ["changed_conclusion"],
  )
  let nested_payload : Json = {
    "watch": {
      "cadence_minutes": 45,
      "source_policy": "web-first",
      "websites": ["https://example.org/reports"],
    },
    "analysis": {
      "method_page": "wiki/methods/my-analysis-method.md",
      "notify_on": ["new_finding", "changed_conclusion"],
    },
  }
  assert_true(
    pdf_watch_websites_from_payload(nested_payload) ==
    ["https://example.org/reports"],
  )
  assert_eq(pdf_watch_cadence_from_payload(nested_payload), 45)
  assert_eq(pdf_watch_source_policy_from_payload(nested_payload), "web-first")
  assert_true(
    pdf_watch_notify_on_from_payload(nested_payload) ==
    ["new_finding", "changed_conclusion"],
  )
}

///|
async test "sync repairs pdf watch standing goals for UI decoder" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-standing-goal-repair-wbtest-" + @async.now().to_string(),
  )
  let book_id = "research-standing-goal-repair-pdf-watch"
  let book_root = @pathx.join(root, "books/" + book_id)
  let pattern_id = "pdf-evidence-watch"
  let topic = "Standing Goal Repair"
  let purpose = "Repair stale standing goals so the Wiki UI can decode them."
  assert_true(create_pdf_watch_book_dirs(book_root))
  let book_json = pdf_watch_book_json(
    book_id~,
    topic~,
    pattern_id~,
    purpose~,
    cadence=30,
    websites=["https://example.org/reports"],
    source_policy="web-first",
    method_path="wiki/methods/analysis-method.md",
    notify_on=["accepted_new_knowledge"],
    skill_pack=["pdf-watch", "pdf-analysis"],
  )
  let written = write_pdf_watch_book_files(
    book_root~,
    book_id~,
    topic~,
    pattern_id~,
    purpose~,
    book_json~,
    method_body="# Method\n",
    websites=["https://example.org/reports"],
  )
  assert_true(written)
  let stale_goal : Json = {
    "id": pdf_watch_goal_id(book_id),
    "title": "Watch Standing Goal Repair PDFs",
    "target_book_id": book_id,
    "cadence_ticks": 30,
    "next_due_tick": 0,
    "last_run_tick": Json::null(),
    "enabled": true,
    "source_policy": "web-first",
    "review_policy": "accepted_new_knowledge",
  }
  ignore(
    write_moontown_standing_goal_registration(
      root~,
      book_root~,
      book_id~,
      pattern_id~,
      goal=stale_goal,
    ),
  )
  @fsx.make_directory(moonsuite_product_dir(root, "moontown"), recursive=true)
  @fsx.write_to_file(
    town_standing_goals_path(root),
    Json::array([stale_goal]).stringify(indent=2) + "\n",
    create=0o644,
  )
  let result = sync_all_book_pattern_standing_goals(book_root)
  assert_true(json_bool(result, "ok", default=false))
  let repaired = read_json_array_file(town_standing_goals_path(root))[0]
  assert_true(
    json_string(repaired, "prompt", default="").contains("Bookkeeper"),
  )
  assert_eq(json_string(repaired, "target_book_id", default=""), book_id)
}

///|
async test "moontown bridge paths use owning suite for book workspaces" {
  let suite_root = @pathx.join(
    "/tmp",
    "moondesk-moontown-bridge-paths-wbtest-" +
    @desk.stable_id("moontown-bridge-paths", @async.now().to_string()),
  )
  let book_root = @pathx.join(suite_root, "books/research-bridge")
  assert_eq(
    moontown_product_root(book_root),
    @pathx.join(suite_root, ".moonsuite/products/moontown"),
  )
  assert_eq(
    town_moondesk_requests_root(book_root),
    @pathx.join(suite_root, ".moonsuite/products/moontown/moondesk-requests"),
  )
  assert_eq(
    town_moondesk_dispatches_root(book_root),
    @pathx.join(suite_root, ".moonsuite/products/moontown/moondesk-dispatches"),
  )
  assert_eq(
    town_daemon_path(book_root),
    @pathx.join(suite_root, ".moonsuite/products/moontown/daemon.json"),
  )
  assert_false(
    town_moondesk_requests_root(book_root).contains(
      "/books/research-bridge/.moonsuite/",
    ),
  )
}

///|
async test "town events read bridge ledgers from owning suite for book workspaces" {
  let suite_root = @pathx.join(
    "/tmp",
    "moondesk-moontown-bridge-events-wbtest-" +
    @desk.stable_id("moontown-bridge-events", @async.now().to_string()),
  )
  let book_root = @pathx.join(suite_root, "books/research-bridge")
  let request_file = town_moondesk_request_path(book_root, "request-one.json")
  @fsx.make_directory(
    @pathx.dirname(request_file),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    request_file,
    (
      {
        "id": "request-one",
        "ok": true,
        "title": "Book-root bridge request",
        "path": town_moondesk_request_relative_path("request-one.json"),
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  let dispatch_file = town_moondesk_dispatch_path(
    book_root, "dispatch-one.json",
  )
  @fsx.make_directory(
    @pathx.dirname(dispatch_file),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    dispatch_file,
    (
      {
        "id": "dispatch-one",
        "ok": false,
        "title": "Book-root bridge dispatch",
        "path": town_moondesk_dispatch_relative_path("dispatch-one.json"),
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  let events = collect_town_event_records(book_root, 10)
  let text = Json::array(events).stringify()
  assert_true(text.contains("Book-root bridge request"))
  assert_true(text.contains("Book-root bridge dispatch"))
  assert_false(
    @fs.exists(
      @pathx.join(
        book_root, ".moonsuite/products/moontown/moondesk-requests/request-one.json",
      ),
    ),
  )
}

///|
test "book pattern creation requires explicit supported pattern" {
  assert_true(
    book_pattern_id_from_creation_payload({ "pattern_id": "pdf-evidence-watch" })
    is Some("pdf-evidence-watch"),
  )
  assert_true(book_pattern_id_from_creation_payload({}) is None)
  assert_true(
    book_pattern_id_from_creation_payload({ "pattern_id": "external-pack" })
    is None,
  )
}
