///|
fn desk_entries_test_entry(path : String) -> @desk.DeskFileEntry {
  @desk.file_entry(workspace_id="book-demo", path~)
}

///|
#warnings("-alert_unstable")
fn desk_entries_test_markup(model : Model) -> String {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  @rabbita.render_to_string(
    @rabbita.static_cell(render_desk_file_browser(dispatch, model)),
  )
}

///|
test "Desk entries owns all eight state mappings and bounded actions" {
  let model = init_model()
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
    assert_true(desk_entries_state_key(state).length() > 0)
    assert_true(desk_entries_state_title(state, model).length() > 0)
    assert_true(desk_entries_state_detail(state, model).length() > 0)
  }
  assert_true(desk_entries_state_action(FirstUseEmpty) is None)
  assert_true(desk_entries_state_action(LegitimateZero) is None)
  assert_true(desk_entries_state_action(Loading) is None)
  assert_true(desk_entries_state_action(Stale) is Some("Refresh"))
  assert_true(desk_entries_state_action(Disconnected) is Some("Retry"))
  assert_true(desk_entries_state_action(CapabilityLimited) is None)
  assert_true(desk_entries_state_action(RecoverableError) is Some("Retry"))
  assert_true(desk_entries_state_action(TerminalError) is None)
}

///|
test "Desk navigation clears old directories but same-directory refresh retains rows" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let entry = desk_entries_test_entry("wiki/page.md")
  let base = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    current_directory: "wiki",
    entries: [entry],
    desk_entries_state: None,
    desk_entries_error: "old failure",
  }
  let (_, different) = update_navigation_actions(
    dispatch,
    OpenDirectory("raw"),
    base,
  )
  assert_eq(different.current_directory, "raw")
  assert_true(different.entries.is_empty())
  assert_true(different.desk_entries_state is Some(Loading))
  assert_eq(different.desk_entries_error, "")
  let (_, same) = update_navigation_actions(
    dispatch,
    OpenDirectory("wiki"),
    base,
  )
  assert_eq(same.entries.length(), 1)
  assert_true(same.desk_entries_state is Some(Loading))
  let (_, refreshing) = update_workspace_surface_actions(
    dispatch,
    RefreshAll,
    base,
  )
  assert_eq(refreshing.entries.length(), 1)
  assert_true(refreshing.desk_entries_state is Some(Loading))
  assert_eq(refreshing.desk_entries_error, "")
  let (_, switched) = update_navigation_actions(
    dispatch,
    SelectWorkspace("book-next"),
    base,
  )
  assert_true(switched.entries.is_empty())
  assert_true(switched.desk_entries_state is Some(Loading))
}

///|
test "Desk entries rejects stale workspace and directory responses" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let entry = desk_entries_test_entry("wiki/current.md")
  let base = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    current_directory: "wiki",
    entries: [entry],
    desk_entries_state: Some(Loading),
    desk_entries_error: "",
    host_status: "refreshing",
  }
  let (_, wrong_workspace) = update_workspace_results(
    dispatch,
    LoadedEntries(
      "book-other",
      "wiki",
      0,
      Ok([desk_entries_test_entry("wiki/wrong.md")]),
    ),
    base,
  )
  assert_eq(wrong_workspace.entries[0].path, "wiki/current.md")
  assert_true(wrong_workspace.desk_entries_state is Some(Loading))
  assert_eq(wrong_workspace.host_status, "refreshing")
  let (_, wrong_directory) = update_workspace_results(
    dispatch,
    LoadedEntries("book-demo", "raw", 0, Err("stale private failure")),
    base,
  )
  assert_eq(wrong_directory.entries[0].path, "wiki/current.md")
  assert_eq(wrong_directory.desk_entries_error, "")
  assert_eq(wrong_directory.host_status, "refreshing")
}

///|
test "Desk entry results distinguish zero ready stale and recoverable failure" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let base = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    current_directory: "wiki",
    desk_entries_state: Some(Loading),
  }
  let (_, zero) = update_workspace_results(
    dispatch,
    LoadedEntries("book-demo", "wiki", 0, Ok([])),
    base,
  )
  assert_true(zero.desk_entries_state is Some(LegitimateZero))
  assert_eq(zero.desk_entries_error, "")
  let entry = desk_entries_test_entry("wiki/page.md")
  let (_, ready) = update_workspace_results(
    dispatch,
    LoadedEntries("book-demo", "wiki", 0, Ok([entry])),
    { ..base, desk_entries_error: "old failure" },
  )
  assert_true(ready.desk_entries_state is None)
  assert_eq(ready.entries.length(), 1)
  assert_eq(ready.desk_entries_error, "")
  let (_, stale) = update_workspace_results(
    dispatch,
    LoadedEntries("book-demo", "wiki", 0, Err("private refresh failure")),
    { ..ready, desk_entries_state: Some(Loading) },
  )
  assert_true(stale.desk_entries_state is Some(Stale))
  assert_eq(stale.entries.length(), 1)
  assert_eq(stale.desk_entries_error, "private refresh failure")
  assert_false(stale.host_status.contains("private refresh failure"))
  let (_, recoverable) = update_workspace_results(
    dispatch,
    LoadedEntries("book-demo", "wiki", 0, Err("private initial failure")),
    base,
  )
  assert_true(recoverable.desk_entries_state is Some(RecoverableError))
  assert_true(recoverable.entries.is_empty())
  assert_eq(recoverable.desk_entries_error, "private initial failure")
  assert_false(recoverable.host_status.contains("private initial failure"))
}

///|
test "Desk entries rejects an older response for the same folder" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let base = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    current_directory: "wiki",
    desk_entries_state: Some(Loading),
  }
  let (_, first) = update_workspace_results(
    dispatch,
    RequestEntries("book-demo", "wiki"),
    base,
  )
  assert_eq(first.desk_entries_request_generation, 1)
  let (_, second) = update_workspace_results(
    dispatch,
    RequestEntries("book-demo", "wiki"),
    first,
  )
  assert_eq(second.desk_entries_request_generation, 2)
  let (_, stale) = update_workspace_results(
    dispatch,
    LoadedEntries(
      "book-demo",
      "wiki",
      1,
      Ok([desk_entries_test_entry("wiki/older.md")]),
    ),
    second,
  )
  assert_true(stale.entries.is_empty())
  assert_true(stale.desk_entries_state is Some(Loading))
  let (_, current) = update_workspace_results(
    dispatch,
    LoadedEntries(
      "book-demo",
      "wiki",
      2,
      Ok([desk_entries_test_entry("wiki/current.md")]),
    ),
    stale,
  )
  assert_eq(current.entries.length(), 1)
  assert_eq(current.entries[0].path, "wiki/current.md")
  assert_true(current.desk_entries_state is None)
}

///|
#warnings("-alert_unstable")
test "Desk file list renders honest zero loading stale and error states" {
  let entry = desk_entries_test_entry("wiki/page.md")
  let base = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    current_directory: "wiki",
  }
  let first_use = desk_entries_test_markup(init_model())
  assert_true(first_use.contains("data-state=\"first-use-empty\""))
  assert_true(first_use.contains("No MoonBook selected"))
  assert_false(first_use.contains("0 items"))
  let loading = desk_entries_test_markup({
    ..base,
    entries: [entry],
    desk_entries_state: Some(Loading),
    desk_entries_error: "must remain hidden",
  })
  assert_true(loading.contains("data-state=\"loading\""))
  assert_true(loading.contains("wiki/page.md"))
  assert_true(loading.contains("Refreshing 1 item"))
  assert_false(loading.contains("must remain hidden"))
  let zero = desk_entries_test_markup({
    ..base,
    entries: [],
    desk_entries_state: Some(LegitimateZero),
  })
  assert_true(zero.contains("data-state=\"legitimate-zero\""))
  assert_true(zero.contains("data-testid=\"desk-empty-folder\""))
  assert_true(zero.contains("This folder is empty"))
  let stale = desk_entries_test_markup({
    ..base,
    entries: [entry],
    desk_entries_state: Some(Stale),
    desk_entries_error: "private stale failure",
  })
  assert_true(stale.contains("data-state=\"stale\""))
  assert_true(stale.contains("wiki/page.md"))
  assert_true(stale.contains("Technical details"))
  assert_true(stale.contains("private stale failure"))
  let failed = desk_entries_test_markup({
    ..base,
    entries: [],
    desk_entries_state: Some(RecoverableError),
    desk_entries_error: "private initial failure",
  })
  assert_true(failed.contains("data-state=\"recoverable-error\""))
  assert_true(failed.contains("Retry"))
  assert_true(failed.contains("private initial failure"))
  assert_true(failed.contains("Item count unavailable"))
  assert_false(failed.contains("This folder is empty"))
  assert_false(failed.contains("0 items"))
}

///|
#warnings("-alert_unstable")
test "Desk filter zero copy requires a successful nonempty listing" {
  let entry = desk_entries_test_entry("wiki/page.md")
  let base = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    current_directory: "wiki",
    entries: [entry],
    desk_filter_query: "missing",
  }
  let loaded = desk_entries_test_markup({ ..base, desk_entries_state: None })
  assert_true(loaded.contains("No matching files"))
  assert_false(loaded.contains("data-testid=\"desk-entries-state-panel\""))
  let stale = desk_entries_test_markup({
    ..base,
    desk_entries_state: Some(Stale),
    desk_entries_error: "refresh failed",
  })
  assert_false(stale.contains("No matching files"))
  assert_true(stale.contains("data-state=\"stale\""))
}
