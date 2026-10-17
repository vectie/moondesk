///|
test "owner card decodes actual CLI fixtures and keeps exact action and evidence parity" {
  let dispatch : Dispatch[Msg] = fn(_) { @rabbita.none }
  for
    run in [
      owner_cli_ready_fixture(),
      owner_cli_waiting_fixture(),
      owner_cli_review_fixture(),
      owner_cli_failed_fixture(),
      owner_cli_unknown_fixture(),
      owner_cli_accepted_fixture(),
      owner_cli_child_fixture(),
    ] {
    assert_true(moonflow_owner_summary_matches(run))
    assert_true(
      moonflow_owner_unavailable(
        { ..init_model(), moonflow_runs_state: None, },
        run,
      )
      is None,
    )
    let value = run.owner_summary.unwrap()
    let html = render_test_dom(
      @rabbita.static_cell(
        render_moonflow_owner_summary(
          dispatch,
          { ..init_model(), moonflow_runs_state: None, },
          run,
        ),
      ),
    )
    assert_true(html.contains(value.next_action))
    assert_true(html.contains(value.outcome_label))
    assert_true(html.contains("owner: unknown"))
    assert_true(html.contains(value.source_digest))
    assert_true(html.contains(value.last_event_id.unwrap()))
    assert_true(html.contains(value.acceptance_boundary))
    for evidence in value.evidence {
      for reference in evidence.artifacts {
        assert_true(html.contains(reference))
      }
      if !evidence.review_artifact.is_empty() {
        assert_true(html.contains(evidence.review_artifact))
      }
    }
  }
  let unknown = owner_cli_unknown_fixture().owner_summary.unwrap()
  assert_eq(unknown.actions[0].status, "unknown")
  assert_eq(
    unknown.next_action,
    "Reconcile the unknown outcome before any retry",
  )
  let accepted = owner_cli_accepted_fixture().owner_summary.unwrap()
  assert_true(accepted.next_actor_id is None)
  assert_eq(accepted.evidence[0].reviewer_id, "reviewer-1")
}

///|
test "owner completion is hidden for stale loading mismatched and legacy observations" {
  let dispatch : Dispatch[Msg] = fn(_) { @rabbita.none }
  let accepted = owner_cli_accepted_fixture()
  let ready_model = { ..init_model(), moonflow_runs_state: None, }
  for state in [Some(Stale), Some(Loading), Some(RecoverableError)] {
    let html = render_test_dom(
      @rabbita.static_cell(
        render_moonflow_owner_summary(
          dispatch,
          { ..ready_model, moonflow_runs_state: state, },
          accepted,
        ),
      ),
    )
    assert_false(html.contains("Internal work accepted for this revision"))
    assert_true(html.contains("Refresh work status"))
  }
  for
    run in [
      { ..accepted, owner_summary: None, },
      { ..accepted, source_digest: "sha256:changed", },
      { ..accepted, declaration_revision: "r2", },
      { ..accepted, last_sequence: accepted.last_sequence + 1, },
      { ..accepted, owner_summary_observation: None, },
      { ..accepted, owner_summary_observation: Some("event-head-mismatch"), },
      {
        ..accepted,
        owner_summary: Some({
          ..accepted.owner_summary.unwrap(),
          contract_id: "moonflow.owner-summary.v99",
        }),
      },
      { ..owner_cli_child_fixture(), owner_summary: accepted.owner_summary, },
      {
        ..accepted,
        items: [{ ..accepted.items[0], output_digest: "changed-output", }],
      },
    ] {
    assert_true(moonflow_owner_unavailable(ready_model, run) is Some(_))
    let html = render_test_dom(
      @rabbita.static_cell(
        render_moonflow_owner_summary(dispatch, ready_model, run),
      ),
    )
    assert_false(html.contains("Internal work accepted for this revision"))
  }
}

///|
test "owner refresh ignores older request and different workspace completions" {
  let dispatch : Dispatch[Msg] = fn(_) { @rabbita.none }
  let base = moonflow_runs_test_model()
  let (_, first) = update_workspace_results(dispatch, RequestMoonFlowRuns, base)
  let (_, second) = update_workspace_results(
    dispatch,
    RequestMoonFlowRuns,
    first,
  )
  assert_eq(second.moonflow_runs_generation, first.moonflow_runs_generation + 1)
  let child = owner_cli_child_fixture()
  let accepted = owner_cli_accepted_fixture()
  let (_, current) = update_workspace_results(
    dispatch,
    LoadedMoonFlowRunsAt(
      second.moonflow_runs_generation,
      base.selected_workspace_id,
      Ok([child]),
    ),
    second,
  )
  let (_, outdated) = update_workspace_results(
    dispatch,
    LoadedMoonFlowRunsAt(
      first.moonflow_runs_generation,
      base.selected_workspace_id,
      Ok([accepted]),
    ),
    current,
  )
  assert_eq(outdated.moonflow_runs[0].run_id, child.run_id)
  let switched = { ..second, selected_workspace_id: "another-book", }
  let (_, ignored) = update_workspace_results(
    dispatch,
    LoadedMoonFlowRunsAt(
      second.moonflow_runs_generation,
      base.selected_workspace_id,
      Ok([accepted]),
    ),
    switched,
  )
  assert_eq(ignored.moonflow_runs.length(), switched.moonflow_runs.length())
  let (_, ignored_error) = update_workspace_results(
    dispatch,
    LoadedMoonFlowRunsAt(
      first.moonflow_runs_generation,
      base.selected_workspace_id,
      Err("old failure"),
    ),
    current,
  )
  assert_eq(ignored_error.moonflow_runs_error, current.moonflow_runs_error)
}

///|
test "owner refresh cannot replace an already observed later event head" {
  let dispatch : Dispatch[Msg] = fn(_) { @rabbita.none }
  let accepted = owner_cli_accepted_fixture()
  let before = {
    ..moonflow_runs_test_model(),
    moonflow_runs: [accepted],
    moonflow_runs_state: None,
  }
  let (_, next) = update_workspace_results(
    dispatch,
    LoadedMoonFlowRuns(Ok([owner_cli_ready_fixture()])),
    before,
  )
  assert_true(next.moonflow_runs_state is Some(Stale))
  assert_eq(next.moonflow_runs[0].last_sequence, accepted.last_sequence)
}
