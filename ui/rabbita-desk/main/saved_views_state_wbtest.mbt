///|
fn saved_views_test_record() -> SavedViewRecord {
  {
    id: "view-1",
    title: "Current findings",
    query: "moonbit",
    workspace_id: "book-demo",
    path: "wiki/findings/index.md",
    created_at: "2026-07-27T00:00:00Z",
    updated_at: "2026-07-27T00:00:00Z",
  }
}

///|
test "saved-view state mappings cover the shared contract" {
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
    assert_true(saved_views_state_key(Some(state)).length() > 0)
    assert_true(saved_views_state_title(Some(state)).length() > 0)
    assert_true(saved_views_state_detail(Some(state)).length() > 0)
  }
  assert_eq(saved_views_state_key(None), "ready")
  assert_true(saved_views_state_action(Some(FirstUseEmpty)) is Some(_))
  assert_true(saved_views_state_action(Some(Loading)) is None)
  assert_true(saved_views_state_action(Some(Stale)) is Some("Refresh"))
  assert_true(saved_views_state_action(Some(RecoverableError)) is Some("Retry"))
  assert_true(saved_views_state_action(Some(CapabilityLimited)) is None)
  assert_true(saved_views_state_action(Some(TerminalError)) is None)
  assert_true(saved_views_state_keeps_rows(None))
  assert_true(saved_views_state_keeps_rows(Some(Loading)))
  assert_true(saved_views_state_keeps_rows(Some(Stale)))
  assert_false(saved_views_state_keeps_rows(Some(RecoverableError)))
}

///|
test "saved-view listing distinguishes zero ready stale and recoverable failure" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let initial = init_model()
  assert_true(initial.saved_views_state is Some(FirstUseEmpty))
  let (_, loading) = select_activity_action(dispatch, Settings, initial)
  assert_true(loading.saved_views_state is Some(Loading))
  let (_, zero) = update_workspace_results(
    dispatch,
    LoadedSavedViews(Ok([])),
    loading,
  )
  assert_true(zero.saved_views_state is Some(LegitimateZero))
  let record = saved_views_test_record()
  let (_, ready) = update_workspace_results(
    dispatch,
    LoadedSavedViews(Ok([record])),
    zero,
  )
  assert_true(ready.saved_views_state is None)
  assert_eq(ready.saved_views.length(), 1)
  let (_, refreshing) = update_workspace_surface_actions(
    dispatch,
    RefreshSavedViews,
    ready,
  )
  assert_true(refreshing.saved_views_state is Some(Loading))
  assert_eq(refreshing.saved_views.length(), 1)
  let (_, stale) = update_workspace_results(
    dispatch,
    LoadedSavedViews(Err("catalog unavailable")),
    refreshing,
  )
  assert_true(stale.saved_views_state is Some(Stale))
  assert_eq(stale.saved_views.length(), 1)
  assert_eq(stale.saved_views_error, "catalog unavailable")
  let (_, failed) = update_workspace_results(
    dispatch,
    LoadedSavedViews(Err("catalog unavailable")),
    { ..initial, saved_views_state: Some(Loading) },
  )
  assert_true(failed.saved_views_state is Some(RecoverableError))
  assert_true(failed.saved_views.is_empty())
}

///|
test "saved-view save feedback is separate from listing transport" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let ready = {
    ..init_model(),
    saved_views: [saved_views_test_record()],
    saved_views_state: None,
  }
  let (_, saving) = update_workspace_surface_actions(
    dispatch,
    SaveCurrentView,
    ready,
  )
  assert_eq(saving.saved_view_action_status, "Saving view")
  assert_true(saving.saved_views_state is None)
  assert_eq(saving.saved_views.length(), 1)
  let record = saved_views_test_record()
  let (_, saved) = update_workspace_results(
    dispatch,
    SavedView(Ok(record)),
    saving,
  )
  assert_true(saved.saved_views_state is Some(Loading))
  assert_eq(saved.saved_views.length(), 1)
  assert_true(saved.saved_view_action_status.contains("Saved"))
  let (_, save_failed) = update_workspace_results(
    dispatch,
    SavedView(Err("save denied")),
    ready,
  )
  assert_true(save_failed.saved_views_state is None)
  assert_eq(save_failed.saved_views.length(), 1)
  assert_eq(save_failed.saved_view_action_status, "save denied")
}

///|
test "saved-view rendering never turns failure into empty success" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let zero_markup = render_accessibility_test_html(
    render_saved_views_panel(dispatch, {
      ..init_model(),
      saved_views_state: Some(LegitimateZero),
    }),
  )
  assert_true(zero_markup.contains("No saved views yet"))
  assert_true(zero_markup.contains("Save current view"))
  let failure = {
    ..init_model(),
    saved_views_state: Some(RecoverableError),
    saved_views_error: "private catalog marker",
  }
  let failure_markup = render_accessibility_test_html(
    render_saved_views_panel(dispatch, failure),
  )
  assert_true(failure_markup.contains("data-state=\"recoverable-error\""))
  assert_true(failure_markup.contains("Saved views could not be loaded"))
  assert_false(failure_markup.contains("No saved views yet"))
  assert_true(failure_markup.contains("aria-live=\"polite\""))
  assert_true(failure_markup.contains("<details"))
  assert_false(failure_markup.contains("<details open"))
  assert_true(failure_markup.contains("private catalog marker"))
  let stale = {
    ..failure,
    saved_views: [saved_views_test_record()],
    saved_views_state: Some(Stale),
  }
  let stale_markup = render_accessibility_test_html(
    render_saved_views_panel(dispatch, stale),
  )
  assert_true(stale_markup.contains("Current findings"))
  assert_true(stale_markup.contains("Showing saved views"))
  assert_true(stale_markup.contains(">Refresh<"))
}
