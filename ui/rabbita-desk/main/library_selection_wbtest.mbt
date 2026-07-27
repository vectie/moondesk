///|
test "native library picker response distinguishes selection and cancellation" {
  guard parse_browser_library_selection(
      "{\"ok\":true,\"path\":\"/tmp/library\",\"cancelled\":false,\"error\":\"\"}",
    )
    is Ok(selected) else {
    fail("expected selected path")
  }
  assert_eq(selected, "/tmp/library")
  guard parse_browser_library_selection(
      "{\"ok\":false,\"path\":\"\",\"cancelled\":true,\"error\":\"\"}",
    )
    is Ok(cancelled) else {
    fail("expected cancellation")
  }
  assert_eq(cancelled, "")
}

///|
test "library selection response preserves a host rejection message" {
  let response : Json = {
    "error": "Choose a library folder, not one MoonBook",
    "ok": false,
    "status": "error",
    "message": "Choose a library folder, not one MoonBook",
  }
  guard library_selection_http_result(Ok(response)) is Err(message) else {
    fail("expected the host rejection")
  }
  assert_eq(message, "Choose a library folder, not one MoonBook")
}

///|
test "library selection response decodes successful metadata" {
  let response : Json = {
    "root_path": "/tmp/library",
    "suite_root": "/tmp/library",
    "active_suite_root": "/tmp/library",
    "library_path": "/tmp/library/books",
    "books_root": "/tmp/library/books",
    "products": [],
  }
  guard library_selection_http_result(Ok(response)) is Ok(metadata) else {
    fail("expected library metadata")
  }
  assert_eq(metadata.root_path, "/tmp/library")
  assert_eq(metadata.books_root, "/tmp/library/books")
}

///|
test "library picker cancellation preserves the active library" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    loading: false,
    workspace_root_path: "/tmp/original",
    workspace_library_path: "/tmp/original/books",
    selected_workspace_id: "book-a",
    selected_path: "wiki/index.md",
  }
  let (_, next) = update_library_selection(
    dispatch,
    LibraryFolderPicked(Ok("")),
    model,
  )
  assert_eq(next.workspace_root_path, "/tmp/original")
  assert_eq(next.workspace_library_path, "/tmp/original/books")
  assert_eq(next.selected_workspace_id, "book-a")
  assert_eq(next.selected_path, "wiki/index.md")
  assert_eq(next.host_status, "Library selection cancelled")
}

///|
test "selected library replaces stale workspace-scoped state" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let stale_workspace = @desk.workspace(
    id="old-book",
    name="Old Book",
    root_path="/tmp/old/books/old-book",
    kind=MoonBook,
  )
  let metadata : WorkspaceMetadata = {
    root_path: "/tmp/new",
    suite_root: "/tmp/new",
    active_suite_root: "/tmp/new",
    library_path: "/tmp/new/books",
    books_root: "/tmp/new/books",
    products: [],
  }
  let (_, next) = update_library_selection(
    dispatch,
    SelectedLibrary(Ok(metadata)),
    {
      ..init_model(),
      loading: false,
      workspaces: [stale_workspace],
      selected_workspace_id: "old-book",
      current_directory: "wiki",
      selected_path: "wiki/index.md",
      desk_selected_paths: ["wiki/index.md"],
      review_items: [publish_test_review("pending")],
      review_state: Some(Stale),
      publish_state: Some(Stale),
      publish_error: "old readiness failure",
      preview: Some(preview_state_test_preview("wiki/index.md", "old preview")),
      preview_state: Some(Stale),
      preview_error: "old preview failure",
      preview_request_workspace_id: "old-book",
      preview_request_path: "wiki/index.md",
    },
  )
  assert_eq(next.workspace_root_path, "/tmp/new")
  assert_eq(next.workspace_library_path, "/tmp/new/books")
  assert_true(next.loading)
  assert_eq(next.workspaces.length(), 0)
  assert_eq(next.selected_workspace_id, "")
  assert_eq(next.current_directory, "")
  assert_eq(next.selected_path, "")
  assert_eq(next.desk_selected_paths.length(), 0)
  assert_eq(next.review_items.length(), 0)
  assert_true(next.review_state is Some(FirstUseEmpty))
  assert_true(next.publish_state is Some(FirstUseEmpty))
  assert_eq(next.publish_error, "")
  assert_true(next.preview is None)
  assert_true(next.preview_state is Some(FirstUseEmpty))
  assert_eq(next.preview_error, "")
  assert_eq(next.preview_request_workspace_id, "")
  assert_eq(next.preview_request_path, "")
  assert_eq(next.host_status, "MoonBook library ready")
}

///|
test "library selection errors stay visible without clearing current state" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    loading: false,
    workspace_root_path: "/tmp/original",
  }
  let (_, next) = update_library_selection(
    dispatch,
    SelectedLibrary(Err("A source checkout cannot be used as a library")),
    model,
  )
  assert_eq(next.workspace_root_path, "/tmp/original")
  assert_eq(next.host_status, "A source checkout cannot be used as a library")
}

///|
#warnings("-alert_unstable")
test "library selection status is rendered beside the library control" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_desk_library_diagnostics(dispatch, {
        ..init_model(),
        host_status: "Could not choose a library folder",
      }),
    ),
  )
  assert_true(markup.contains("data-testid=\"desk-library-selection-status\""))
  assert_true(markup.contains(">Could not choose a library folder</p>"))
}
