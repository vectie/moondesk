///|
test "surface state stable mappings cover all states" {
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
  let keys = [
    "first-use-empty", "legitimate-zero", "loading", "stale", "disconnected", "capability-limited",
    "recoverable-error", "terminal-error",
  ]
  let titles = [
    "Start here", "No results", "Working on it", "This may be out of date", "You’re offline",
    "This action isn’t available", "Something went wrong", "This can’t continue",
  ]
  for index = 0; index < states.length(); index = index + 1 {
    assert_eq(surface_state_key(states[index]), keys[index])
    assert_eq(pages_search_state_title(states[index]), titles[index])
    assert_true(pages_search_state_detail(states[index]).length() > 0)
  }
}

///|
test "surface state primary actions and technical detail stay separate" {
  assert_true(
    pages_search_state_primary_action(FirstUseEmpty) is Some("Search"),
  )
  assert_true(
    pages_search_state_primary_action(LegitimateZero) is Some("Search"),
  )
  assert_true(pages_search_state_primary_action(Loading) is None)
  assert_true(pages_search_state_primary_action(Stale) is Some("Refresh"))
  assert_true(pages_search_state_primary_action(Disconnected) is Some("Retry"))
  assert_true(pages_search_state_primary_action(CapabilityLimited) is None)
  assert_true(
    pages_search_state_primary_action(RecoverableError) is Some("Retry"),
  )
  assert_true(pages_search_state_primary_action(TerminalError) is None)
  assert_true(pages_search_state_technical_detail(FirstUseEmpty) is None)
  assert_true(pages_search_state_technical_detail(LegitimateZero) is None)
  assert_true(pages_search_state_technical_detail(Loading) is None)
  assert_true(pages_search_state_technical_detail(Stale) is Some(_))
  assert_true(pages_search_state_technical_detail(Disconnected) is Some(_))
  assert_true(pages_search_state_technical_detail(CapabilityLimited) is Some(_))
  assert_true(pages_search_state_technical_detail(RecoverableError) is Some(_))
  assert_true(pages_search_state_technical_detail(TerminalError) is Some(_))
}

///|
fn pages_search_test_response(
  hits : Array[SearchHit],
  query? : String = "moonbit",
  ok? : Bool = true,
  status? : String = "ready",
  message? : String = "Search completed",
  workspace_id? : String = "",
) -> PagesSearchResponse {
  {
    contract: "pages-search.v1",
    ok,
    status,
    message,
    query,
    workspace_id,
    hits,
  }
}

///|
test "Pages search transitions use typed surface evidence" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let initial = init_model()
  assert_true(initial.search_state is Some(FirstUseEmpty))
  let (_, loading) = update_workspace_surface_actions(
    dispatch,
    SetSearchQuery("moonbit"),
    initial,
  )
  let (_, loading) = update_workspace_surface_actions(
    dispatch,
    SearchNow,
    loading,
  )
  assert_true(loading.search_state is Some(Loading))
  let (_, empty) = update_workspace_results(
    dispatch,
    LoadedPagesSearch(Ok(pages_search_test_response([]))),
    loading,
  )
  assert_true(empty.search_state is Some(LegitimateZero))
  let hit : SearchHit = {
    workspace_id: "book-demo",
    workspace_name: "Demo",
    path: "wiki/index.md",
    title: "index.md",
    kind: Markdown,
    source_layer: Wiki,
    snippet: "MoonBit",
  }
  let (_, ready) = update_workspace_results(
    dispatch,
    LoadedPagesSearch(Ok(pages_search_test_response([hit]))),
    loading,
  )
  assert_true(ready.search_state is None)
  let (_, failed) = update_workspace_results(
    dispatch,
    LoadedPagesSearch(Err("search unavailable")),
    loading,
  )
  assert_true(failed.search_state is Some(RecoverableError))
  assert_eq(search_action_label(failed.search_state), "Retry")
  assert_eq(search_action_label(ready.search_state), "Search")
}

///|
test "Pages search maps explicit scope evidence and preserves only same-query stale hits" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let hit : SearchHit = {
    workspace_id: "book-demo",
    workspace_name: "Demo",
    path: "wiki/index.md",
    title: "index.md",
    kind: Markdown,
    source_layer: Wiki,
    snippet: "MoonBit",
  }
  let cached = {
    ..init_model(),
    search_query: "moonbit",
    search_evidence_query: "moonbit",
    search_hits: [hit],
  }
  let (_, loading) = update_workspace_surface_actions(
    dispatch,
    SearchNow,
    cached,
  )
  assert_true(loading.search_state is Some(Loading))
  assert_eq(loading.search_hits.length(), 1)
  let (_, stale) = update_workspace_results(
    dispatch,
    LoadedPagesSearch(Err("host unavailable")),
    loading,
  )
  assert_true(stale.search_state is Some(Stale))
  assert_eq(stale.search_hits.length(), 1)
  assert_eq(stale.search_status, "Showing earlier search results")
  assert_eq(stale.search_error, "host unavailable")
  let limited_response = pages_search_test_response(
    [],
    ok=false,
    status="scope-unavailable",
    message="scope cannot be read",
  )
  let (_, limited) = update_workspace_results(
    dispatch,
    LoadedPagesSearch(Ok(limited_response)),
    stale,
  )
  assert_true(limited.search_state is Some(CapabilityLimited))
  assert_true(limited.search_hits.is_empty())
  assert_eq(limited.search_error, "scope cannot be read")
  let terminal_response = pages_search_test_response(
    [],
    ok=false,
    status="workspace-not-found",
    message="book missing",
  )
  let (_, terminal) = update_workspace_results(
    dispatch,
    LoadedPagesSearch(Ok(terminal_response)),
    limited,
  )
  assert_true(terminal.search_state is Some(TerminalError))
  assert_true(terminal.search_hits.is_empty())
  let (_, changed) = update_workspace_surface_actions(
    dispatch,
    SetSearchQuery("different"),
    stale,
  )
  assert_true(changed.search_hits.is_empty())
  assert_eq(changed.search_evidence_query, "")
}

///|
test "Pages search keeps host diagnostics in closed technical details" {
  let marker = "scope /private/example cannot be read"
  let markup = render_accessibility_test_html(
    render_search_state_panel(CapabilityLimited, error=marker),
  )
  assert_true(markup.contains("data-state=\"capability-limited\""))
  assert_true(markup.contains("Technical details"))
  assert_true(markup.contains("<details"))
  assert_false(markup.contains("<details open"))
  assert_true(markup.contains(marker))
  assert_true(markup.contains(pages_search_state_title(CapabilityLimited)))
  assert_true(markup.contains(pages_search_state_detail(CapabilityLimited)))
}

///|
fn review_state_test_item() -> ReviewItem {
  {
    id: "review-1",
    workspace_id: "book-demo",
    path: "wiki/reviews/pending.md",
    title: "Pending proposal",
    kind: "review",
    status: "pending",
    detail: "wiki/reviews/pending.md",
  }
}

///|
test "Review transitions distinguish loading zero ready stale and failure" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let item = review_state_test_item()
  let initial = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    review_items: [item],
    review_state: None,
  }
  let (_, loading) = select_activity_action(dispatch, Runs, initial)
  assert_true(loading.review_state is Some(Loading))
  assert_eq(loading.review_items.length(), 1)
  let (_, empty) = update_town_results(
    dispatch,
    LoadedReviewItems(Ok([])),
    loading,
  )
  assert_true(empty.review_state is Some(LegitimateZero))
  let (_, ready) = update_town_results(
    dispatch,
    LoadedReviewItems(Ok([item])),
    loading,
  )
  assert_true(ready.review_state is None)
  assert_eq(ready.review_items.length(), 1)
  let (_, stale) = update_town_results(
    dispatch,
    LoadedReviewItems(Err("review refresh failed")),
    ready,
  )
  assert_true(stale.review_state is Some(Stale))
  assert_eq(stale.review_items.length(), 1)
  assert_eq(stale.host_status, "review refresh failed")
  let (_, failed) = update_town_results(
    dispatch,
    LoadedReviewItems(Err("review unavailable")),
    { ..loading, review_items: [] },
  )
  assert_true(failed.review_state is Some(RecoverableError))
  assert_eq(failed.review_items.length(), 0)
}

///|
#warnings("-alert_unstable")
test "Review renders surface-owned state copy and preserves stale items" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let empty_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_review_pane(dispatch, {
        ..init_model(),
        selected_workspace_id: "book-demo",
        review_state: Some(LegitimateZero),
      }),
    ),
  )
  assert_true(empty_markup.contains("review-state-panel"))
  assert_true(empty_markup.contains("legitimate-zero"))
  assert_true(empty_markup.contains("Nothing needs review"))
  assert_false(empty_markup.contains("No matching pages"))
  let stale_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_review_pane(dispatch, {
        ..init_model(),
        selected_workspace_id: "book-demo",
        review_items: [review_state_test_item()],
        review_state: Some(Stale),
        host_status: "review refresh failed",
      }),
    ),
  )
  assert_true(stale_markup.contains("Showing earlier review items"))
  assert_true(stale_markup.contains("Pending proposal"))
  assert_true(stale_markup.contains("Technical details"))
  assert_true(stale_markup.contains("review refresh failed"))
  assert_false(stale_markup.contains("Try the search again"))
}
