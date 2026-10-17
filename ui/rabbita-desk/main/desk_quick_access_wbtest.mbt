///|
test "Quick Access never reinterprets another Book's favorites or recents" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, switched) = update(dispatch, SelectWorkspace("book-b"), {
    ..init_model(),
    workspace_mode: Desk,
    selected_workspace_id: "book-a",
    favorites: ["raw/report.md"],
    recent_paths: ["raw/report.md"],
  })
  assert_true(switched.favorites.is_empty())
  assert_true(switched.recent_paths.is_empty())
}

///|
test "Quick Access records folder navigation and clears a stale Forward branch" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, wiki) = update_navigation_actions(dispatch, OpenDirectory("wiki"), {
    ..init_model(),
    workspace_mode: Desk,
    selected_workspace_id: "book-a",
  })
  let (_, root) = update_navigation_actions(dispatch, NavigateDeskBack, wiki)
  let (_, report) = update_navigation_actions(
    dispatch,
    OpenQuickPath("raw/report.md"),
    root,
  )
  assert_eq(report.current_directory, "raw")
  assert_eq(report.desk_location_input, "raw")
  assert_eq(report.selected_path, "raw/report.md")
  assert_true(report.desk_back_stack == [""])
  assert_true(report.desk_forward_stack.is_empty())
}

///|
fn quick_access_test_model() -> Model {
  rebind_desk_quick_access({
    ..init_model(),
    workspace_mode: Desk,
    selected_workspace_id: "book-a",
    workspace_books_root_path: "/books",
    workspaces: [
      @desk.workspace(
        id="book-a",
        name="A",
        root_path="/books/a",
        kind=MoonBook,
      ),
      @desk.workspace(
        id="book-b",
        name="B",
        root_path="/books/b",
        kind=MoonBook,
      ),
    ],
  })
}

///|
fn quick_access_test_preview(
  model : Model,
  path : String,
  directory~ : Bool = false,
) -> Model {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, selected) = update(dispatch, SelectPath(path), model)
  let (_, loading) = update(
    dispatch,
    RequestPreview(selected.selected_workspace_id, path),
    selected,
  )
  let entry = @desk.file_entry(
    workspace_id=loading.selected_workspace_id,
    path~,
    is_directory=directory,
  )
  let (_, loaded) = update(
    dispatch,
    LoadedPreview(
      loading.selected_workspace_id,
      path,
      loading.preview_request_generation,
      Ok(@desk.preview(entry, body="output")),
    ),
    loading,
  )
  loaded
}

///|
test "Quick Access retains independent favorites and recents for same named Book files" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let a = quick_access_test_preview(quick_access_test_model(), "raw/report.md")
  let (_, a) = update(dispatch, ToggleFavorite("raw/report.md"), a)
  let scope_a = desk_quick_access_scope(a)
  let (_, b) = update(dispatch, SelectWorkspace("book-b"), a)
  assert_true(b.favorites.is_empty())
  assert_true(b.recent_paths.is_empty())
  let b = quick_access_test_preview(b, "raw/report.md")
  let (_, b) = update(dispatch, ToggleFavorite("raw/report.md"), b)
  let (_, b) = update(dispatch, ToggleFavorite("wiki/b-only.md"), b)
  let (_, ignored) = update(
    dispatch,
    OpenDeskQuickPath(scope_a, "raw/report.md"),
    b,
  )
  assert_eq(ignored.selected_workspace_id, "book-b")
  assert_eq(ignored.selected_path, b.selected_path)
  assert_true(ignored.desk_back_stack == b.desk_back_stack)
  let (_, a) = update(dispatch, SelectWorkspace("book-a"), b)
  assert_true(a.favorites == ["raw/report.md"])
  assert_true(a.recent_paths == ["raw/report.md"])
  let (_, b) = update(dispatch, SelectWorkspace("book-b"), a)
  assert_true(b.favorites == ["raw/report.md", "wiki/b-only.md"])
  assert_true(b.recent_paths == ["raw/report.md"])
}

///|
test "Quick Access file branch supports Back Forward and repeated clicks" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let base = quick_access_test_preview(
    quick_access_test_model(),
    "raw/report.md",
  )
  let (_, wiki) = update(dispatch, OpenDirectory("wiki"), base)
  let (_, root) = update(dispatch, NavigateDeskBack, wiki)
  let scope = desk_quick_access_scope(root)
  let (_, report) = update(
    dispatch,
    OpenDeskQuickPath(scope, "raw/report.md"),
    root,
  )
  assert_eq(report.current_directory, "raw")
  assert_eq(report.desk_location_input, "raw")
  assert_eq(report.selected_path, "raw/report.md")
  assert_true(report.desk_back_stack == [""])
  assert_true(report.desk_forward_stack.is_empty())
  let (_, repeated) = update(
    dispatch,
    OpenDeskQuickPath(scope, "raw/report.md"),
    report,
  )
  assert_true(repeated.desk_back_stack == [""])
  assert_eq(repeated.selected_path, "raw/report.md")
  let (_, back) = update(dispatch, NavigateDeskBack, repeated)
  assert_eq(back.current_directory, "")
  assert_eq(back.desk_location_input, "")
  assert_true(back.desk_forward_stack == ["raw"])
  let (_, forward) = update(dispatch, NavigateDeskForward, back)
  assert_eq(forward.current_directory, "raw")
  assert_eq(forward.desk_location_input, "raw")
  assert_eq(forward.selected_path, "raw")
}

///|
test "Quick Access folder favorites open the folder itself after leaving and switching Books" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let base = {
    ..quick_access_test_model(),
    entries: [
      @desk.file_entry(
        workspace_id="book-a",
        path="raw/results",
        is_directory=true,
      ),
    ],
  }
  let (_, favorite) = update(dispatch, ToggleFavorite("raw/results"), base)
  let (_, b) = update(dispatch, SelectWorkspace("book-b"), favorite)
  let (_, a) = update(dispatch, SelectWorkspace("book-a"), b)
  assert_true(a.desk_quick_access_directories == ["raw/results"])
  let scope = desk_quick_access_scope(a)
  let (_, folder) = update(dispatch, OpenDeskQuickPath(scope, "raw/results"), a)
  assert_eq(folder.current_directory, "raw/results")
  assert_eq(folder.desk_location_input, "raw/results")
  assert_eq(folder.selected_path, "raw/results")
  assert_true(folder.desk_back_stack == [""])
  let (_, repeated) = update(
    dispatch,
    OpenDeskQuickPath(scope, "raw/results"),
    folder,
  )
  assert_true(repeated.desk_back_stack == [""])
  assert_eq(repeated.current_directory, "raw/results")
}

///|
test "Quick Access recent folders remember directory kind from preview" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let directory = quick_access_test_preview(
    quick_access_test_model(),
    "raw/results",
    directory=true,
  )
  assert_true(directory.desk_quick_access_directories == ["raw/results"])
  let (_, elsewhere) = update(dispatch, OpenDirectory("wiki"), directory)
  let (_, reopened) = update(
    dispatch,
    OpenDeskQuickPath(desk_quick_access_scope(elsewhere), "raw/results"),
    elsewhere,
  )
  assert_eq(reopened.current_directory, "raw/results")
}

///|
test "Quick Access rejects malformed legacy and stale entries without guessing ownership" {
  let unowned = {
    ..quick_access_test_model(),
    desk_quick_access_owner: "",
    favorites: ["raw/report.md"],
    recent_paths: ["raw/report.md"],
  }
  let bound = rebind_desk_quick_access(unowned)
  assert_true(bound.favorites.is_empty())
  assert_true(bound.recent_paths.is_empty())
  let cleaned = rebind_desk_quick_access({
    ..bound,
    favorites: [
      "../outside", "/absolute", "raw//bad", "raw/./bad", "raw\\bad", "bad\u0000name",
      "", "raw/good.md", "raw/good.md",
    ],
  })
  assert_true(cleaned.favorites == ["raw/good.md"])
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, stale) = update(
    dispatch,
    OpenDeskQuickPath(desk_quick_access_scope(cleaned), "raw/not-present.md"),
    cleaned,
  )
  assert_eq(stale.selected_path, cleaned.selected_path)
  let (_, malformed) = update(
    dispatch,
    OpenDeskQuickPath(desk_quick_access_scope(cleaned), "../outside"),
    cleaned,
  )
  assert_eq(malformed.current_directory, cleaned.current_directory)
}

///|
test "Quick Access isolates same Book ids in different libraries and roots" {
  let a = quick_access_test_model()
  let a = {
    ..a,
    favorites: ["raw/report.md"],
    recent_paths: ["raw/report.md"],
  }
  let other_library = rebind_desk_quick_access({
    ..a,
    workspace_books_root_path: "/other/books",
  })
  assert_true(other_library.favorites.is_empty())
  assert_true(other_library.recent_paths.is_empty())
  let returned = rebind_desk_quick_access({
    ..other_library,
    workspace_books_root_path: "/books",
  })
  assert_true(returned.favorites == ["raw/report.md"])
  let relocated = rebind_desk_quick_access({
    ..returned,
    workspaces: [
      @desk.workspace(
        id="book-a",
        name="A",
        root_path="/books/other-a",
        kind=MoonBook,
      ),
    ],
  })
  assert_true(relocated.favorites.is_empty())
}

///|
test "Quick Access ignores old preview completion after a newer Book choice" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let a = quick_access_test_model()
  let (_, selected) = update(dispatch, SelectPath("raw/report.md"), a)
  let (_, loading) = update(
    dispatch,
    RequestPreview("book-a", "raw/report.md"),
    selected,
  )
  let (_, b) = update(dispatch, SelectWorkspace("book-b"), loading)
  let (_, late) = update(
    dispatch,
    LoadedPreview(
      "book-a",
      "raw/report.md",
      loading.preview_request_generation,
      Ok(
        @desk.preview(
          @desk.file_entry(workspace_id="book-a", path="raw/report.md"),
          body="A",
        ),
      ),
    ),
    b,
  )
  assert_eq(late.selected_workspace_id, "book-b")
  assert_true(late.recent_paths.is_empty())
  assert_true(late.preview is None)
}

///|
#warnings("-alert_unstable")
test "Quick Access current Book empty state and rendered history controls stay honest" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let empty = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_desk_workspace_sidebar(dispatch, quick_access_test_model()),
    ),
  )
  assert_true(empty.contains("desk-quick-access-empty"))
  assert_true(empty.contains("No favorites or recent files yet."))
  let (_, opened) = update(
    dispatch,
    OpenQuickPath("raw/report.md"),
    quick_access_test_model(),
  )
  let rendered = @rabbita.render_to_string(
    @rabbita.static_cell(render_desk_file_browser(dispatch, opened)),
  )
  assert_true(rendered.contains("data-testid=\"desk-back\""))
  assert_true(rendered.contains("value=\"raw\""))
  assert_eq(opened.desk_back_stack.length(), 1)
  assert_eq(opened.desk_forward_stack.length(), 0)
}

///|
test "Quick Access preserves known folder kind immediately after rename" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let base = {
    ..quick_access_test_model(),
    selected_path: "raw/old",
    current_directory: "raw",
    favorites: ["raw/old"],
    desk_quick_access_directories: ["raw/old"],
  }
  let (_, renamed) = update(
    dispatch,
    RenamedDeskEntry(
      Ok({ workspace_id: "book-a", path: "raw/new", directory: "raw", }),
    ),
    base,
  )
  let (_, opened) = update(
    dispatch,
    OpenDeskQuickPath(desk_quick_access_scope(renamed), "raw/new"),
    renamed,
  )
  assert_eq(opened.current_directory, "raw/new")
  assert_eq(opened.desk_location_input, "raw/new")
}

///|
test "Quick Access same-folder files preserve directory Forward and unrelated messages do not rescan paths" {
  assert_false(desk_quick_access_paths_changed(SetDeskFilterQuery("report")))
  assert_true(desk_quick_access_paths_changed(ToggleFavorite("raw/report.md")))
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..quick_access_test_model(),
    current_directory: "raw",
    favorites: ["raw/report.md"],
    desk_back_stack: [""],
    desk_forward_stack: ["wiki"],
  }
  let (_, opened) = update(
    dispatch,
    OpenDeskQuickPath(desk_quick_access_scope(model), "raw/report.md"),
    model,
  )
  assert_eq(opened.selected_path, "raw/report.md")
  assert_eq(opened.current_directory, "raw")
  assert_true(opened.desk_back_stack == [""])
  assert_true(opened.desk_forward_stack == ["wiki"])
}

///|
test "Quick Access deferred confirmation retains original Book scope after catalog replacement" {
  let dispatch : Dispatch[Msg] = fn(_) { @rabbita.none }
  let a = {
    ..quick_access_test_model(),
    selected_path: "wiki/index.md",
    current_directory: "wiki",
    favorites: ["raw/a.md"],
    markdown_editor_path: "wiki/index.md",
    markdown_editor_original: "original",
    markdown_editor_content: "draft",
  }
  let scope = desk_quick_access_scope(a)
  let (_, pending) = update(dispatch, OpenDeskQuickPath(scope, "raw/a.md"), a)
  assert_true(
    pending.pending_markdown_navigation ==
    PendingDeskQuickPath(scope, "raw/a.md"),
  )
  let (_, b) = update(
    dispatch,
    LoadedWorkspaces(
      Ok([
        @desk.workspace(
          id="book-b",
          name="B",
          root_path="/books/b",
          kind=MoonBook,
        ),
      ]),
    ),
    pending,
  )
  assert_eq(b.selected_workspace_id, "book-b")
  let (_, confirmed) = update(dispatch, ConfirmDiscardMarkdownNavigation, b)
  assert_eq(confirmed.selected_path, b.selected_path)
  assert_eq(confirmed.current_directory, b.current_directory)
  assert_true(confirmed.desk_back_stack == b.desk_back_stack)
  assert_true(
    confirmed.pending_markdown_navigation is NoPendingMarkdownNavigation,
  )
}

///|
test "Quick Access stale deferred confirmation does not discard the new Book's draft" {
  let dispatch : Dispatch[Msg] = fn(_) { @rabbita.none }
  let a = {
    ..quick_access_test_model(),
    selected_path: "wiki/index.md",
    favorites: ["raw/shared.md"],
    markdown_editor_path: "wiki/index.md",
    markdown_editor_original: "original",
    markdown_editor_content: "A draft",
  }
  let (_, pending) = update(
    dispatch,
    OpenDeskQuickPath(desk_quick_access_scope(a), "raw/shared.md"),
    a,
  )
  let (_, b) = update(
    dispatch,
    LoadedWorkspaces(
      Ok([
        @desk.workspace(
          id="book-b",
          name="B",
          root_path="/books/b",
          kind=MoonBook,
        ),
      ]),
    ),
    pending,
  )
  let b = {
    ..b,
    selected_path: "wiki/b.md",
    markdown_editor_path: "wiki/b.md",
    markdown_editor_content: "B draft",
    favorites: ["raw/shared.md"],
  }
  let (_, confirmed) = update(dispatch, ConfirmDiscardMarkdownNavigation, b)
  assert_eq(confirmed.selected_path, "wiki/b.md")
  assert_eq(confirmed.markdown_editor_content, "B draft")
  assert_true(
    confirmed.pending_markdown_navigation is NoPendingMarkdownNavigation,
  )
}

///|
test "Quick Access deferred folder and file navigation preserve cancellation and same Book confirmation" {
  let dispatch : Dispatch[Msg] = fn(_) { @rabbita.none }
  for directory in [false, true] {
    let a = {
      ..quick_access_test_model(),
      selected_path: "wiki/index.md",
      current_directory: "wiki",
      favorites: ["raw/result"],
      desk_quick_access_directories: if directory {
        ["raw/result"]
      } else {
        []
      },
      markdown_editor_path: "wiki/index.md",
      markdown_editor_original: "original",
      markdown_editor_content: "draft",
    }
    let scope = desk_quick_access_scope(a)
    let (_, pending) = update(
      dispatch,
      OpenDeskQuickPath(scope, "raw/result"),
      a,
    )
    assert_true(
      pending.pending_markdown_navigation ==
      PendingDeskQuickPath(scope, "raw/result"),
    )
    let (_, cancelled) = update(
      dispatch,
      CancelDiscardMarkdownNavigation,
      pending,
    )
    assert_eq(cancelled.markdown_editor_content, "draft")
    assert_eq(cancelled.current_directory, "wiki")
    assert_true(cancelled.desk_back_stack.is_empty())
    let (_, opened) = update(
      dispatch,
      ConfirmDiscardMarkdownNavigation,
      pending,
    )
    assert_eq(opened.selected_path, "raw/result")
    assert_eq(
      opened.current_directory,
      if directory {
        "raw/result"
      } else {
        "raw"
      },
    )
    assert_true(opened.desk_back_stack == ["wiki"])
    assert_true(
      opened.pending_markdown_navigation is NoPendingMarkdownNavigation,
    )
  }
}
