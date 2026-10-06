///|
async test "supervisor Book TOML markers match existing metadata presence semantics" {
  let suite = @fs.tmpdir(prefix="moondesk-supervisor-toml-")
  defer @fs.rmdir(suite, recursive=true)
  for
    (book_id, marker, content) in [
      (
        "canonical-book", "book.toml", "[book]\ntitle = \"Imported Book\"\nsrc = \"wiki\"\n",
      ),
      ("canonical-wiki", "wiki.toml", "[wiki]\nsource = \"wiki\"\n"),
      ("malformed-book", "book.toml", "[book\ntitle = broken\n"),
      ("malformed-wiki", "wiki.toml", "not valid TOML [\n"),
      ("empty-book", "book.toml", ""),
      ("empty-wiki", "wiki.toml", ""),
    ] {
    let book_root = workspace_context(suite).book_root(book_id)
    @fs.mkdir(book_root, recursive=true)
    let marker_path = @pathx.join(book_root, marker)
    @fs.write_file(marker_path, content, create_mode=CreateNew)
    // Existing discovery uses metadata presence, not successful TOML parsing.
    assert_true(moonbook_metadata_exists(book_root))
    assert_true(moonbook_workspace_status(book_root) is Ready)
    assert_true(supervisor_bridge_installed_book_marker_exists(book_root))
    assert_eq(
      supervisor_bridge_delegate_cwd(suite, {
        "workspace_id": "workspace-a",
        "book_id": book_id,
      }),
      Ok(book_root),
    )
    assert_eq(@fs.read_file(marker_path).text(), content)
    assert_false(@fs.exists(@pathx.join(book_root, "book.json")))
    assert_false(
      @fs.exists(@pathx.join(book_root, "state/agent-installation.json")),
    )
  }
}

///|
async test "supervisor Book TOML markers reject directories and unrelated folders" {
  let suite = @fs.tmpdir(prefix="moondesk-supervisor-nonbooks-")
  defer @fs.rmdir(suite, recursive=true)
  for
    (book_id, marker) in [
      ("book-directory", "book.toml"),
      ("wiki-directory", "wiki.toml"),
      ("unrelated", "memory/procedures"),
    ] {
    let book_root = workspace_context(suite).book_root(book_id)
    @fs.mkdir(@pathx.join(book_root, marker), recursive=true)
    @fs.write_file(
      @pathx.join(book_root, "README.md"),
      "# Not a Book marker\n",
      create_mode=CreateNew,
    )
    assert_false(moonbook_metadata_exists(book_root))
    assert_true(moonbook_workspace_status(book_root) is NeedsAttention)
    assert_false(supervisor_bridge_installed_book_marker_exists(book_root))
    assert_true(
      supervisor_bridge_delegate_cwd(suite, {
        "workspace_id": "workspace-a",
        "book_id": book_id,
      })
      is Err(_),
    )
  }
  assert_false(
    supervisor_bridge_installed_book_marker_exists(
      @pathx.join(suite, "missing"),
    ),
  )
}

///|
async test "supervisor imported Book markers retain exact active-root confinement" {
  let suite = @fs.tmpdir(prefix="moondesk-supervisor-active-book-")
  defer @fs.rmdir(suite, recursive=true)
  let active = workspace_context(suite).book_root("book-a")
  let sibling = workspace_context(suite).book_root("book-b")
  for book_root in [active, sibling] {
    @fs.mkdir(book_root, recursive=true)
    @fs.write_file(
      @pathx.join(book_root, "book.toml"),
      "[book]\ntitle = \"Book\"\n",
      create_mode=CreateNew,
    )
  }
  let selected : Json = { "workspace_id": "workspace-a", "book_id": "book-a" }
  assert_eq(supervisor_bridge_delegate_cwd(suite, selected), Ok(active))
  assert_eq(supervisor_bridge_delegate_cwd(active, selected), Ok(active))
  assert_true(supervisor_bridge_delegate_cwd(sibling, selected) is Err(_))
  for
    book_id in [
      "", ".", "..", "../book-a", "book-a/../book-b", "book-a\\book-b", active,
    ] {
    assert_true(
      supervisor_bridge_delegate_cwd(suite, {
        "workspace_id": "workspace-a",
        "book_id": book_id,
      })
      is Err(_),
    )
  }
  assert_true(
    supervisor_bridge_delegate_cwd(suite, { "book_id": "book-a" }) is Err(_),
  )
  assert_eq(
    supervisor_bridge_delegate_cwd(active, {
      "workspaceId": "workspace-a",
      "bookId": "book-a",
    }),
    Ok(active),
  )
}

///|
/// Opt-in cross-product fixture: a byte-identical copy of the real MoonBook
/// import_agent_bundle output, supplied by the audit runner. This does not
/// claim to invoke the CLI process, activate learning, or require installation.
async test "supervisor accepts real MoonBook import API fixture without fabricated markers" {
  guard @env.get_env_var("MOONDESK_IMPORTED_BOOK_FIXTURE") is Some(fixture) else {
    return
  }
  let suite = @pathx.join(fixture, "suite")
  let book_root = workspace_context(suite).book_root("book-a")
  let proof = @json.parse(
    @fs.read_file(@pathx.join(fixture, "roundtrip-proof.json")).text(),
  )
  let hashes : Map[String, String] = @json.from_json(
    @json.parse(
      @fs.read_file(@pathx.join(fixture, "source-hashes.json")).text(),
    ),
  )
  for path, expected in hashes {
    assert_eq(
      @crypto.bytes_to_hex_string(
        @crypto.sha256(@fs.read_file(@pathx.join(book_root, path)).binary()),
      ),
      expected,
    )
  }
  assert_true(@fs.exists(@pathx.join(book_root, "book.toml")))
  assert_true(@fs.exists(@pathx.join(book_root, "wiki.toml")))
  for marker in ["book.json", "book/book.json", "book/moonbook-ui-state.json"] {
    assert_false(@fs.exists(@pathx.join(book_root, marker)))
  }
  let installation = @json.parse(
    @fs.read_file(@pathx.join(book_root, "state/agent-installation.json")).text(),
  )
  for key in ["agent_id", "version", "bundle_digest"] {
    assert_eq(
      json_string(installation, key, default="missing"),
      json_string(proof, key, default=""),
    )
  }
  guard json_object_field(proof, "lessons") is Some(Array(lessons)) else {
    fail("Actual imported lesson proof missing")
  }
  assert_eq(lessons.length(), 4)
  for lesson in lessons {
    let path = json_string(lesson, "path", default="")
    let content = @fs.read_file(@pathx.join(book_root, path)).binary()
    assert_eq(
      "sha256:" + @crypto.bytes_to_hex_string(@crypto.sha256(content)),
      json_string(lesson, "revision", default=""),
    )
  }
  assert_true(moonbook_workspace_status(book_root) is Ready)
  let dispatch = supervisor_bridge_execution_dispatch(
    supervisor_bridge_delegate_fixture(),
    workspace_root=book_root,
  )
  guard dispatch is Ok(dispatch) else {
    fail("Imported Book delegate should map")
  }
  assert_eq(dispatch.endpoint, "delegate")
  guard json_object_field(dispatch.body, "task") is Some(task) else {
    fail("Native worker task missing")
  }
  assert_eq(json_string(task, "cwd", default=""), book_root)
  assert_eq(json_string(task, "model", default=""), "gpt-5.6-sol")
  assert_eq(json_object_field(task, "metadata").unwrap(), {
    "workspace_id": "workspace-a",
    "book_id": "book-a",
  })
  // Recognition and dispatch projection are read-only for the imported Book.
  for path, expected in hashes {
    assert_eq(
      @crypto.bytes_to_hex_string(
        @crypto.sha256(@fs.read_file(@pathx.join(book_root, path)).binary()),
      ),
      expected,
    )
  }
  for marker in ["book.json", "book/book.json", "book/moonbook-ui-state.json"] {
    assert_false(@fs.exists(@pathx.join(book_root, marker)))
  }
}
