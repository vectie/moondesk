///|
test "primary navigation order, hooks, and shortcuts are stable" {
  let items = primary_navigation_items()
  assert_eq(items.length(), 7)
  assert_eq(items[0].1, "Home")
  assert_eq(items[1].1, "Pages")
  assert_eq(items[2].1, "Code")
  assert_eq(items[3].1, "Requests")
  assert_eq(items[4].1, "Runs")
  assert_eq(items[5].1, "Review")
  assert_eq(items[6].1, "Publish")
  assert_eq(items[0].2, "mode-desk")
  assert_eq(items[1].2, "mode-wiki")
  assert_eq(items[2].2, "mode-code")
  assert_eq(items[3].2, "mode-requests")
  assert_eq(items[4].2, "mode-runs")
  assert_eq(items[5].2, "mode-review")
  assert_eq(items[6].2, "mode-publish")
  assert_eq(items[0].3, "Meta+1 Control+1")
  assert_eq(items[6].3, "Meta+7 Control+7")
}

///|
#warnings("-alert_unstable")
test "title bar renders desktop and compact navigation with unique hooks" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_title_bar(dispatch, init_model())),
  )
  assert_true(markup.contains("data-testid=\"mode-requests\""))
  assert_true(markup.contains("data-testid=\"mode-publish\""))
  assert_true(markup.contains("data-testid=\"primary-nav-summary\""))
  assert_true(markup.contains("data-testid=\"compact-mode-requests\""))
  assert_true(markup.contains("data-testid=\"compact-mode-publish\""))
  assert_true(markup.contains("aria-keyshortcuts=\"Meta+7 Control+7\""))
  assert_eq(markup.split("role=\"navigation\"").length(), 3)
  assert_eq(markup.split("aria-label=\"Primary destinations\"").length(), 3)
  assert_eq(markup.split("aria-current=\"page\"").length(), 3)
}

///|
test "primary destination selection enters typed loading states" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let selected = { ..init_model(), selected_workspace_id: "book-demo" }
  let (_, requests) = update_navigation_actions(
    dispatch,
    SelectWorkspaceMode(RequestsWorkspace),
    selected,
  )
  assert_true(requests.workspace_mode is RequestsWorkspace)
  assert_true(requests.activity is Town)
  assert_true(requests.requests_state is Some(Loading))
  let (_, review) = update_navigation_actions(
    dispatch,
    SelectWorkspaceMode(ReviewWorkspace),
    selected,
  )
  assert_true(review.workspace_mode is ReviewWorkspace)
  assert_true(review.activity is Runs)
  assert_true(review.review_state is Some(Loading))
}

///|
test "every primary destination palette retains secondary tools" {
  for
    mode in [
      Desk,
      MoonWiki,
      MoonCode,
      RequestsWorkspace,
      RunsWorkspace,
      ReviewWorkspace,
      PublishWorkspace,
    ] {
    let titles = palette_commands_for_mode(mode).map(command => command.0)
    assert_true(titles.contains("Open Home"))
    assert_true(titles.contains("Open Pages"))
    assert_true(titles.contains("Open Code"))
    assert_true(titles.contains("Open Requests"))
    assert_true(titles.contains("Open Runs"))
    assert_true(titles.contains("Open Review"))
    assert_true(titles.contains("Open Publish"))
    assert_true(titles.contains("Open Flow"))
    assert_true(titles.contains("Open Packs"))
  }
}

///|
#warnings("-alert_unstable")
test "runs workspace distinguishes no book from a legitimate zero" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let no_book = @rabbita.render_to_string(
    @rabbita.static_cell(render_runs_workspace(dispatch, init_model())),
  )
  assert_true(no_book.contains("Choose a book to see its runs"))
  let empty = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_runs_workspace(dispatch, {
        ..init_model(),
        selected_workspace_id: "book-demo",
      }),
    ),
  )
  assert_true(empty.contains("data-testid=\"runs-state-panel\""))
  assert_true(empty.contains("data-state=\"first-use-empty\""))
  assert_false(empty.contains("No runs yet"))
}

///|
#warnings("-alert_unstable")
test "publish workspace blocks on review without claiming output exists" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let ready = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_publish_workspace(dispatch, {
        ..init_model(),
        selected_workspace_id: "book-demo",
        publish_state: Some(LegitimateZero),
      }),
    ),
  )
  assert_true(ready.contains("data-testid=\"publish-output-check\""))
  assert_true(ready.contains("Open output location"))
  assert_false(ready.contains("output is ready"))
  let pending = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_publish_workspace(dispatch, {
        ..init_model(),
        selected_workspace_id: "book-demo",
        review_items: [
          {
            id: "review-1",
            workspace_id: "book-demo",
            path: "review/change.md",
            title: "Proposed change",
            kind: "page",
            status: "pending",
            detail: "Needs a decision",
          },
        ],
        publish_state: None,
      }),
    ),
  )
  assert_true(pending.contains("data-testid=\"publish-review-required\""))
  assert_true(pending.contains("Review required"))
}
