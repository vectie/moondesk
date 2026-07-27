///|
async test "library selection accepts a folder and prepares MoonSuite layout" {
  let stamp = @async.now().to_string()
  let bootstrap = @pathx.join("/tmp", "moondesk-library-bootstrap-" + stamp)
  let selected = @pathx.join("/tmp", "moondesk-library-selected-" + stamp)
  @fsx.make_directory(bootstrap, recursive=true, exists_ok=true)
  @fsx.make_directory(selected, recursive=true, exists_ok=true)
  let canonical = @fs.realpath(selected)
  guard select_library_root(bootstrap, selected) is Ok(actual) else {
    fail("expected library selection to succeed")
  }
  assert_eq(actual, canonical)
  assert_true(@fsx.exists(@pathx.join(selected, "books")))
  assert_true(@fsx.exists(@pathx.join(selected, ".moonsuite/suite.json")))
  assert_eq(restore_library_root(bootstrap), canonical)
}

///|
async test "library selection stores preferences under the bootstrap root" {
  let stamp = @async.now().to_string()
  let bootstrap = @pathx.join("/tmp", "moondesk-library-owner-" + stamp)
  let selected = @pathx.join("/tmp", "moondesk-library-external-" + stamp)
  @fsx.make_directory(bootstrap, recursive=true, exists_ok=true)
  @fsx.make_directory(selected, recursive=true, exists_ok=true)
  guard select_library_root(bootstrap, selected) is Ok(_) else {
    fail("expected library selection to succeed")
  }
  let preference = library_selection_path(bootstrap)
  assert_true(@fsx.exists(preference))
  assert_false(
    @fsx.exists(
      @pathx.join(
        moonsuite_product_artifact_for_workspace_root(
          selected, "moondesk", "preferences",
        ),
        "library.json",
      ),
    ),
  )
}

///|
async test "choosing the books folder activates its owning suite" {
  let stamp = @async.now().to_string()
  let root = @pathx.join("/tmp", "moondesk-library-books-" + stamp)
  assert_true(prepare_moonsuite_workspace_root(root))
  let canonical = @fs.realpath(root)
  guard validated_library_root(@pathx.join(root, "books")) is Ok(actual) else {
    fail("expected books folder to resolve to its owning suite")
  }
  assert_eq(actual, canonical)
}

///|
async test "library selection rejects source checkouts and individual books" {
  let stamp = @async.now().to_string()
  let source = @pathx.join("/tmp", "moondesk-library-source-" + stamp)
  let book = @pathx.join("/tmp", "moondesk-library-book-" + stamp)
  @fsx.make_directory(source, recursive=true, exists_ok=true)
  @fsx.make_directory(book, recursive=true, exists_ok=true)
  @fsx.write_to_file(@pathx.join(source, "moon.mod"), "{}\n")
  @fsx.write_to_file(@pathx.join(book, "book.json"), "{}\n")
  assert_true(validated_library_root(source) is Err(_))
  assert_true(validated_library_root(book) is Err(_))
}

///|
async test "invalid saved library falls back to the bootstrap root" {
  let stamp = @async.now().to_string()
  let bootstrap = @pathx.join("/tmp", "moondesk-library-fallback-" + stamp)
  @fsx.make_directory(
    @pathx.dirname(library_selection_path(bootstrap)),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    library_selection_path(bootstrap),
    "{\"root_path\":\"/path/that/does/not/exist\"}\n",
  )
  assert_eq(restore_library_root(bootstrap), bootstrap)
}

///|
async test "library selection resolves symlinks before applying root safety" {
  let stamp = @async.now().to_string()
  let link = @pathx.join("/tmp", "moondesk-library-root-link-" + stamp)
  @fs.symlink(link, target="/")
  assert_true(validated_library_root(link) is Err(_))
}
