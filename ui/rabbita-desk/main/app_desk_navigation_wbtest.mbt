///|
test "desk breadcrumbs expose clickable path segments" {
  let crumbs = desk_breadcrumbs("book/site/generated")
  assert_eq(crumbs.length(), 4)
  assert_eq(crumbs[0].0, "root")
  assert_eq(crumbs[0].1, "")
  assert_false(crumbs[0].2)
  assert_eq(crumbs[1].0, "book")
  assert_eq(crumbs[1].1, "book")
  assert_eq(crumbs[2].0, "site")
  assert_eq(crumbs[2].1, "book/site")
  assert_eq(crumbs[3].0, "generated")
  assert_eq(crumbs[3].1, "book/site/generated")
  assert_true(crumbs[3].2)
}

///|
test "desk root breadcrumb is active at project root" {
  let crumbs = desk_breadcrumbs("")
  assert_eq(crumbs.length(), 1)
  assert_eq(crumbs[0].0, "root")
  assert_true(crumbs[0].2)
}

///|
test "desk path helpers find containing directories" {
  assert_eq(parent_path("wiki/index.md"), "wiki")
  assert_eq(
    parent_path("book/site/generated/index.html"),
    "book/site/generated",
  )
  assert_eq(parent_path("wiki"), "")
  assert_eq(parent_path(""), "")
}

///|
test "desk folder outline includes root and current child directories" {
  let outline = desk_folder_outline("", [
    @desk.file_entry(workspace_id="book-demo", path="wiki", is_directory=true),
    @desk.file_entry(workspace_id="book-demo", path="raw", is_directory=true),
    @desk.file_entry(workspace_id="book-demo", path="book.json"),
  ])
  assert_eq(outline.length(), 3)
  assert_eq(outline[0].0, "root")
  assert_eq(outline[0].1, "")
  assert_true(outline[0].2)
  assert_eq(outline[1].0, "wiki")
  assert_eq(outline[1].1, "wiki")
  assert_false(outline[1].2)
  assert_eq(outline[1].3, 1)
  assert_eq(outline[2].0, "raw")
  assert_eq(outline[2].1, "raw")
}

///|
test "desk folder outline keeps ancestor chain for nested directory" {
  let outline = desk_folder_outline("book/site", [
    @desk.file_entry(
      workspace_id="book-demo",
      path="book/site/generated",
      is_directory=true,
    ),
    @desk.file_entry(workspace_id="book-demo", path="book/site/index.html"),
  ])
  assert_eq(outline.length(), 4)
  assert_eq(outline[0].1, "")
  assert_eq(outline[1].1, "book")
  assert_eq(outline[1].3, 1)
  assert_false(outline[1].2)
  assert_eq(outline[2].1, "book/site")
  assert_eq(outline[2].3, 2)
  assert_true(outline[2].2)
  assert_eq(outline[3].1, "book/site/generated")
  assert_eq(outline[3].3, 3)
  assert_false(outline[3].2)
}

///|
test "desk entry counts split folders and files" {
  let counts = desk_entry_counts([
    @desk.file_entry(workspace_id="book-demo", path="wiki", is_directory=true),
    @desk.file_entry(workspace_id="book-demo", path="raw", is_directory=true),
    @desk.file_entry(workspace_id="book-demo", path="book.json"),
    @desk.file_entry(workspace_id="book-demo", path="wiki/index.md"),
  ])
  assert_eq(counts.0, 4)
  assert_eq(counts.1, 2)
  assert_eq(counts.2, 2)
  assert_eq(desk_entry_count_label(counts), "4 items, 2 folders, 2 files")
}

///|
test "desk selection label uses virtual root for empty path" {
  assert_eq(desk_selection_label(init_model()), "No selection")
  let model = { ..init_model(), selected_path: "wiki/index.md" }
  assert_eq(desk_selection_label(model), "Selected wiki/index.md")
}

///|
test "desk access labels distinguish browse and writable entries" {
  assert_eq(desk_access_label(None), "Browse only")
  assert_eq(
    desk_access_label(Some(@desk.file_entry(workspace_id="book-demo", path="book.json"))),
    "Read-only",
  )
  assert_eq(
    desk_access_label(
      Some(
        @desk.file_entry(
          workspace_id="book-demo",
          path="wiki/index.md",
          writable=true,
        ),
      ),
    ),
    "Writable",
  )
}

///|
test "desk size labels use compact units" {
  assert_eq(size_label(None), "-")
  assert_eq(size_label(Some(24)), "24 B")
  assert_eq(size_label(Some(4096)), "4 KB")
  assert_eq(size_label(Some(3 * 1024 * 1024)), "3 MB")
}

///|
test "search hit focuses Desk on containing directory" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, next) = update_navigation_actions(
    dispatch,
    SelectSearchHit("book-demo", "wiki/sources/report.md"),
    init_model(),
  )
  assert_true(next.workspace_mode is Desk)
  assert_true(next.activity is Files)
  assert_eq(next.selected_workspace_id, "book-demo")
  assert_eq(next.selected_path, "wiki/sources/report.md")
  assert_eq(next.current_directory, "wiki/sources")
  assert_eq(next.preview_status, "loading search result")
}

///|
test "switching to desk loads selected file context directory" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    workspace_mode: MoonWiki,
    activity: Inbox,
    selected_workspace_id: "book-demo",
    selected_path: "wiki/sources/report.md",
    current_directory: "raw",
  }
  let (_, next) = update_navigation_actions(
    dispatch,
    SelectWorkspaceMode(Desk),
    model,
  )
  assert_true(next.workspace_mode is Desk)
  assert_true(next.activity is Files)
  assert_eq(next.selected_path, "wiki/sources/report.md")
  assert_eq(next.current_directory, "wiki/sources")
  assert_eq(next.preview_status, "loading desk context")
}

///|
test "switching to desk keeps selected directory as context" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    workspace_mode: MoonWiki,
    selected_workspace_id: "book-demo",
    selected_path: "wiki/sources",
    current_directory: "wiki",
    entries: [
      @desk.file_entry(
        workspace_id="book-demo",
        path="wiki/sources",
        is_directory=true,
      ),
    ],
  }
  let (_, next) = update_navigation_actions(
    dispatch,
    SelectWorkspaceMode(Desk),
    model,
  )
  assert_true(next.workspace_mode is Desk)
  assert_eq(next.selected_path, "wiki/sources")
  assert_eq(next.current_directory, "wiki/sources")
  assert_eq(next.preview_status, "loading desk context")
}
