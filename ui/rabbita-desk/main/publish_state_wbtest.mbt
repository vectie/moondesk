///|
fn publish_test_review(status : String) -> ReviewItem {
  {
    id: "review-1",
    workspace_id: "book-demo",
    path: "wiki/reviews/change.md",
    title: "Proposed change",
    kind: "review",
    status,
    detail: "Needs a decision",
  }
}

///|
test "Publish selection and book changes own loading and clear cross-book evidence" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  assert_true(init_model().publish_state is Some(FirstUseEmpty))
  let (_, without_book) = update_navigation_actions(
    dispatch,
    SelectWorkspaceMode(PublishWorkspace),
    init_model(),
  )
  assert_true(without_book.publish_state is Some(FirstUseEmpty))
  let selected = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    review_items: [publish_test_review("pending")],
    publish_state: Some(Stale),
    publish_error: "old readiness failure",
  }
  let (_, loading) = update_navigation_actions(
    dispatch,
    SelectWorkspaceMode(PublishWorkspace),
    selected,
  )
  assert_true(loading.publish_state is Some(Loading))
  assert_eq(loading.review_items.length(), 1)
  assert_eq(loading.publish_error, "")
  let (_, explicit_change) = select_workspace_action(
    dispatch, "book-next", selected,
  )
  assert_eq(explicit_change.review_items.length(), 0)
  assert_true(explicit_change.review_state is Some(Loading))
  assert_true(explicit_change.publish_state is Some(Loading))
  assert_eq(explicit_change.publish_error, "")
  let (_, automatic_change) = update_workspace_results(
    dispatch,
    LoadedWorkspaces(
      Ok([
        @desk.workspace(
          id="book-next",
          name="Next",
          root_path="/tmp/moonsuite/books/next",
          kind=MoonBook,
        ),
      ]),
    ),
    selected,
  )
  assert_eq(automatic_change.selected_workspace_id, "book-next")
  assert_eq(automatic_change.review_items.length(), 0)
  assert_true(automatic_change.publish_state is Some(Loading))
}

///|
test "Publish readiness evidence distinguishes zero ready stale and failure" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let base = { ..init_model(), selected_workspace_id: "book-demo" }
  let (_, zero) = update_town_results(dispatch, LoadedReviewItems(Ok([])), base)
  assert_true(zero.publish_state is Some(LegitimateZero))
  assert_eq(zero.publish_error, "")
  let pending_item = publish_test_review("pending")
  let (_, ready) = update_town_results(
    dispatch,
    LoadedReviewItems(Ok([pending_item])),
    { ..base, publish_error: "old failure" },
  )
  assert_true(ready.publish_state is None)
  assert_eq(ready.review_items.length(), 1)
  assert_eq(ready.publish_error, "")
  let refreshing = { ..ready, publish_state: Some(Loading) }
  assert_true(publish_state_keeps_evidence(refreshing.publish_state))
  let (_, stale) = update_town_results(
    dispatch,
    LoadedReviewItems(Err("readiness refresh failed")),
    refreshing,
  )
  assert_true(stale.publish_state is Some(Stale))
  assert_eq(stale.review_items.length(), 1)
  assert_eq(stale.publish_error, "readiness refresh failed")
  let (_, failed) = update_town_results(
    dispatch,
    LoadedReviewItems(Err("readiness unavailable")),
    base,
  )
  assert_true(failed.publish_state is Some(RecoverableError))
  assert_eq(failed.review_items.length(), 0)
  assert_eq(failed.publish_error, "readiness unavailable")
  let decision : ReviewDecisionResult = {
    id: "review-1",
    workspace_id: "book-demo",
    source_path: "wiki/reviews/change.md",
    decision: "accepted",
    status: "recorded",
    note: "",
    receipt_path: "review/receipts/review-1.json",
  }
  let (_, invalidated) = update_town_results(
    dispatch,
    DecidedReviewItem(Ok(decision)),
    { ..stale, publish_error: "old failure" },
  )
  assert_true(invalidated.publish_state is Some(Loading))
  assert_eq(invalidated.publish_error, "")
}

///|
test "Publish owns all eight state mappings and bounded actions" {
  let states = [
    FirstUseEmpty,
    LegitimateZero,
    Loading,
    Stale,
    Disconnected,
    CapabilityLimited,
    RecoverableError,
    TerminalError,
  ]
  for state in states {
    assert_true(publish_state_title(state).length() > 0)
    assert_true(publish_state_detail(state, false).length() > 0)
    assert_false(publish_state_title(state).contains("Search"))
    assert_false(
      publish_state_detail(state, false).contains("review items here"),
    )
  }
  assert_true(publish_state_action(FirstUseEmpty) is Some("Check"))
  assert_true(publish_state_action(LegitimateZero) is None)
  assert_true(publish_state_action(Loading) is None)
  assert_true(publish_state_action(Stale) is Some("Refresh"))
  assert_true(publish_state_action(Disconnected) is Some("Retry"))
  assert_true(publish_state_action(CapabilityLimited) is None)
  assert_true(publish_state_action(RecoverableError) is Some("Retry"))
  assert_true(publish_state_action(TerminalError) is None)
}

///|
#warnings("-alert_unstable")
test "Publish renders honest readiness states without false output evidence" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let no_book = @rabbita.render_to_string(
    @rabbita.static_cell(render_publish_workspace(dispatch, init_model())),
  )
  assert_true(no_book.contains("Choose a book to check publishing"))
  assert_false(no_book.contains("data-testid=\"publish-state-panel\""))
  let failed = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_publish_workspace(dispatch, {
        ..init_model(),
        selected_workspace_id: "book-demo",
        publish_state: Some(RecoverableError),
        publish_error: "private readiness failure",
      }),
    ),
  )
  assert_true(failed.contains("data-state=\"recoverable-error\""))
  assert_true(failed.contains("Publishing readiness couldn’t be checked"))
  assert_true(failed.contains("Technical details"))
  assert_true(failed.contains("private readiness failure"))
  assert_false(failed.contains("data-testid=\"publish-output-check\""))
  let zero = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_publish_workspace(dispatch, {
        ..init_model(),
        selected_workspace_id: "book-demo",
        publish_state: Some(LegitimateZero),
      }),
    ),
  )
  assert_true(zero.contains("data-state=\"legitimate-zero\""))
  assert_true(zero.contains("data-testid=\"publish-output-check\""))
  assert_true(zero.contains("Open output location"))
  assert_true(zero.contains("Technical and portable exports"))
  assert_false(zero.contains("output is ready"))
  let loading = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_publish_workspace(dispatch, {
        ..init_model(),
        selected_workspace_id: "book-demo",
        review_items: [publish_test_review("pending")],
        publish_state: Some(Loading),
      }),
    ),
  )
  assert_true(loading.contains("data-state=\"loading\""))
  assert_true(loading.contains("data-testid=\"publish-review-required\""))
  let stale = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_publish_workspace(dispatch, {
        ..init_model(),
        selected_workspace_id: "book-demo",
        review_items: [publish_test_review("accepted")],
        publish_state: Some(Stale),
        publish_error: "stale readiness failure",
      }),
    ),
  )
  assert_true(stale.contains("data-state=\"stale\""))
  assert_true(stale.contains("Showing earlier readiness evidence"))
  assert_true(stale.contains("No blockers in the last successful check"))
  assert_true(stale.contains("data-testid=\"publish-output-check\""))
  assert_true(stale.contains("stale readiness failure"))
  for
    state in [
      FirstUseEmpty,
      LegitimateZero,
      Loading,
      Stale,
      Disconnected,
      CapabilityLimited,
      RecoverableError,
      TerminalError,
    ] {
    let markup = @rabbita.render_to_string(
      @rabbita.static_cell(
        render_publish_workspace(dispatch, {
          ..init_model(),
          selected_workspace_id: "book-demo",
          publish_state: Some(state),
        }),
      ),
    )
    assert_true(markup.contains("data-state=\"\{surface_state_key(state)}\""))
    assert_true(markup.contains(publish_state_title(state)))
  }
}
