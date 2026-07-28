///|
fn requests_test_record() -> RequestRecord {
  {
    id: "request-1",
    status: "queued",
    path: "requests/request-1.json",
    request: {
      "prompt": "Build an index",
      "context_entries": ["wiki/index.md"],
    },
  }
}

///|
test "Requests ledger transitions preserve prior records and composer feedback" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let initial = { ..init_model(), selected_workspace_id: "book-demo" }
  assert_true(initial.requests_state is Some(FirstUseEmpty))
  let (_, loading) = select_activity_action(dispatch, Town, initial)
  assert_true(loading.requests_state is Some(Loading))
  assert_eq(loading.requests.length(), 0)
  let (_, zero) = update_town_results(dispatch, LoadedRequests(Ok([])), loading)
  assert_true(zero.requests_state is Some(LegitimateZero))
  assert_eq(zero.requests_error, "")
  let record = requests_test_record()
  let (_, ready) = update_town_results(
    dispatch,
    LoadedRequests(Ok([record])),
    loading,
  )
  assert_true(ready.requests_state is None)
  assert_eq(ready.requests.length(), 1)
  let refreshing = { ..ready, requests_state: Some(Loading) }
  assert_true(requests_state_keeps_items(refreshing.requests_state))
  let (_, stale) = update_town_results(
    dispatch,
    LoadedRequests(Err("raw ledger failure")),
    { ..refreshing, request_status: "Task created." },
  )
  assert_true(stale.requests_state is Some(Stale))
  assert_eq(stale.requests.length(), 1)
  assert_eq(stale.requests_error, "raw ledger failure")
  assert_eq(stale.request_status, "Task created.")
  let (_, failed) = update_town_results(
    dispatch,
    LoadedRequests(Err("raw empty failure")),
    loading,
  )
  assert_true(failed.requests_state is Some(RecoverableError))
  assert_eq(failed.requests.length(), 0)
  let (_, submitted) = update_town_results(
    dispatch,
    SubmittedRequest(Ok(record)),
    { ..stale, requests_error: "old error" },
  )
  assert_true(submitted.requests_state is Some(Loading))
  assert_eq(submitted.requests_error, "")
}

///|
test "Requests owns state copy, actions, technical disclosure, and composer enablement" {
  assert_eq(requests_state_key(Some(FirstUseEmpty)), "first-use-empty")
  assert_eq(requests_state_key(None), "ready")
  assert_eq(requests_state_title(LegitimateZero), "No requests yet")
  assert_true(
    requests_state_detail(LegitimateZero, false).contains(
      "no saved requests yet",
    ),
  )
  assert_false(requests_state_detail(LegitimateZero, false).contains("failed"))
  assert_true(requests_state_action(FirstUseEmpty) is Some("Check"))
  assert_true(requests_state_action(Stale) is Some("Refresh"))
  assert_true(requests_state_action(RecoverableError) is Some("Retry"))
  assert_true(requests_state_action(Loading) is None)
  assert_true(
    requests_state_technical_detail(Stale, "raw ledger failure")
    is Some("raw ledger failure"),
  )
  assert_true(
    requests_state_technical_detail(LegitimateZero, "ignored") is None,
  )
  let enabled = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    request_prompt: "Stage this request",
    requests_state: Some(RecoverableError),
    daemon_lifecycle: None,
  }
  assert_false(wiki_task_start_disabled(enabled))
}

///|
#warnings("-alert_unstable")
test "Requests renders honest zero and stale retained records without false empty activity" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let zero_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_town_pane(dispatch, {
        ..init_model(),
        selected_workspace_id: "book-demo",
        requests_state: Some(LegitimateZero),
      }),
    ),
  )
  assert_true(zero_markup.contains("requests-state-panel"))
  assert_true(zero_markup.contains("legitimate-zero"))
  assert_true(zero_markup.contains("No requests yet"))
  assert_true(zero_markup.contains("no saved requests yet"))
  assert_false(zero_markup.contains("No activity yet"))
  assert_false(zero_markup.contains("raw ledger failure"))
  let stale_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_town_pane(dispatch, {
        ..init_model(),
        selected_workspace_id: "book-demo",
        requests: [requests_test_record()],
        requests_state: Some(Stale),
        requests_error: "raw ledger failure",
      }),
    ),
  )
  assert_true(stale_markup.contains("stale"))
  assert_true(stale_markup.contains("Showing earlier requests"))
  assert_true(stale_markup.contains("Build an index"))
  assert_true(stale_markup.contains("Technical details"))
  assert_true(stale_markup.contains("raw ledger failure"))
  assert_false(stale_markup.contains("No matching pages"))
}
