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
