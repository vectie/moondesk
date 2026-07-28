///|
fn test_run() -> @desk.DeskRunProjection {
  @desk.run_projection(
    run_id="run-private-123",
    book_id="book-demo",
    goal_id=Some("goal-1"),
    status="completed",
    phase="finished",
    summary="Artifact ready",
    artifacts=[
      @desk.run_artifact(
        id="artifact-1",
        path="generated/report.md",
        title="Report",
      ),
    ],
    started_at=Some("2026-07-27T10:00:00Z"),
    updated_at=Some("2026-07-27T10:01:00Z"),
  )
}

///|
test "runs starts first-use and enters loading only with a book" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  assert_true(init_model().runs_state is Some(FirstUseEmpty))
  let (_, without_book) = update_navigation_actions(
    dispatch,
    SelectWorkspaceMode(RunsWorkspace),
    init_model(),
  )
  assert_true(without_book.runs_state is Some(FirstUseEmpty))
  let (_, loading) = update_navigation_actions(
    dispatch,
    SelectWorkspaceMode(RunsWorkspace),
    {
      ..init_model(),
      selected_workspace_id: "book-demo",
      runs: [test_run()],
      runs_state: Some(Stale),
      runs_error: "old error",
    },
  )
  assert_true(loading.runs_state is Some(Loading))
  assert_eq(loading.runs.length(), 1)
  assert_eq(loading.runs_error, "")
  let (_, auto_selected) = update_workspace_results(
    dispatch,
    LoadedWorkspaces(
      Ok([
        @desk.workspace(
          id="book-demo",
          name="Demo",
          root_path="/tmp/moonsuite/books/demo",
          kind=MoonBook,
        ),
      ]),
    ),
    init_model(),
  )
  assert_eq(auto_selected.selected_workspace_id, "book-demo")
  assert_true(auto_selected.runs_state is Some(Loading))
  let (_, selection_changed) = update_workspace_results(
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
    {
      ..init_model(),
      selected_workspace_id: "book-missing",
      runs: [test_run()],
      runs_state: Some(Stale),
      runs_error: "old book failure",
    },
  )
  assert_eq(selection_changed.selected_workspace_id, "book-next")
  assert_true(selection_changed.runs_state is Some(Loading))
  assert_eq(selection_changed.runs.length(), 0)
  assert_eq(selection_changed.runs_error, "")
}

///|
test "runs result evidence selects zero ready stale and recoverable states" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let base = { ..init_model(), selected_workspace_id: "book-demo" }
  let (_, zero) = update_workspace_results(dispatch, LoadedRuns(Ok([])), base)
  assert_true(zero.runs_state is Some(LegitimateZero))
  assert_eq(zero.runs_error, "")
  let (_, ready) = update_workspace_results(
    dispatch,
    LoadedRuns(Ok([test_run()])),
    { ..base, runs_error: "old" },
  )
  assert_true(ready.runs_state is None)
  assert_eq(ready.runs_error, "")
  let (_, stale) = update_workspace_results(
    dispatch,
    LoadedRuns(Err("runs endpoint failed")),
    ready,
  )
  assert_true(stale.runs_state is Some(Stale))
  assert_eq(stale.runs.length(), 1)
  assert_eq(stale.runs_error, "runs endpoint failed")
  assert_eq(stale.host_status, ready.host_status)
  let (_, recoverable) = update_workspace_results(
    dispatch,
    LoadedRuns(Err("no response")),
    base,
  )
  assert_true(recoverable.runs_state is Some(RecoverableError))
  assert_eq(recoverable.runs_error, "no response")
}

///|
test "runs owns all eight plain-language mappings and actions" {
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
    assert_false(runs_state_title(state).contains("Search"))
    assert_false(runs_state_detail(state, false).contains("page"))
    assert_true(runs_state_title(state).length() > 0)
    assert_true(runs_state_detail(state, false).length() > 0)
  }
  assert_true(runs_state_action(FirstUseEmpty) is Some("Check"))
  assert_true(runs_state_action(LegitimateZero) is Some("Start a request"))
  assert_true(runs_state_action(Loading) is None)
  assert_true(runs_state_action(Stale) is Some("Refresh"))
  assert_true(runs_state_action(Disconnected) is Some("Retry"))
  assert_true(runs_state_action(CapabilityLimited) is None)
  assert_true(runs_state_action(RecoverableError) is Some("Retry"))
  assert_true(runs_state_action(TerminalError) is None)
}

///|
#warnings("-alert_unstable")
test "runs render has stable state hook disclosure and retained artifact action" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let no_book = @rabbita.render_to_string(
    @rabbita.static_cell(render_runs_workspace(dispatch, init_model())),
  )
  assert_true(no_book.contains("Choose a book to see its runs"))
  assert_false(no_book.contains("data-testid=\"runs-state-panel\""))
  let stale = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_runs_workspace(dispatch, {
        ..init_model(),
        selected_workspace_id: "book-demo",
        runs: [test_run()],
        runs_state: Some(Stale),
        runs_error: "private raw failure",
      }),
    ),
  )
  assert_true(stale.contains("data-testid=\"runs-state-panel\""))
  assert_true(stale.contains("data-state=\"stale\""))
  assert_true(stale.contains("Technical details"))
  assert_true(stale.contains("private raw failure"))
  assert_true(stale.contains("Report"))
  assert_true(stale.contains("run-private-123"))
  assert_true(stale.contains("data-testid=\"runs-refresh\""))
  let loading = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_runs_workspace(dispatch, {
        ..init_model(),
        selected_workspace_id: "book-demo",
        runs: [test_run()],
        runs_state: Some(Loading),
        runs_error: "must remain hidden",
      }),
    ),
  )
  assert_true(loading.contains("data-state=\"loading\""))
  assert_true(loading.contains("Report"))
  assert_false(loading.contains("must remain hidden"))
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
    let markup = @rabbita.render_to_string(
      @rabbita.static_cell(
        render_runs_workspace(dispatch, {
          ..init_model(),
          selected_workspace_id: "book-demo",
          runs_state: Some(state),
        }),
      ),
    )
    assert_true(markup.contains("data-state=\"\{surface_state_key(state)}\""))
    assert_true(markup.contains(runs_state_title(state)))
  }
}
