///|
fn moonflow_runs_test_budget() -> MoonFlowBudget {
  {
    model_tokens: 0,
    tool_calls: 0,
    storage_bytes: 0,
    attempts: 0,
    concurrency: 0,
  }
}

///|
fn moonflow_runs_test_run(
  book_id : String,
  run_id : String,
) -> MoonFlowRunProjection {
  {
    protocol: "moonflow.v1",
    run_id,
    book_id,
    declaration_revision: "revision-1",
    source_digest: "source-1",
    last_sequence: 1,
    outcome: "active",
    runnable_item_ids: [],
    items: [],
    autonomy_binding: Some({
      contract_id: "autonomy.v1",
      run_id,
      envelope: {
        envelope_id: "envelope-1",
        mode: "governed",
        expires_at: "",
        revoked: false,
        external_effects_allowed: false,
        physical_effects_allowed: false,
        budget: moonflow_runs_test_budget(),
      },
      usage_ref: "usage-1",
      usage: moonflow_runs_test_budget(),
      recorded_at: "2026-07-31T00:00:00Z",
    }),
    intervention_scorecard: Some({
      contract_id: "intervention.v1",
      run_id,
      required_intervention_count: 0,
      hidden_orchestration_count: 0,
      normal_path_manual_count: 0,
      unattended_qualified: true,
      finalization_findings: [],
      recorded_at: "2026-07-31T00:00:00Z",
    }),
    run_control: Some({
      contract_id: "control.v1",
      run_id,
      state: "active",
      authority_ceiling: "governed",
      reason: "",
      recorded_at: "2026-07-31T00:00:00Z",
    }),
    operator_surface: None,
  }
}

///|
fn moonflow_runs_test_model() -> Model {
  {
    ..init_model(),
    selected_workspace_id: "book-selected",
    workspaces: [
      @desk.workspace(
        id="book-selected",
        name="Selected",
        root_path="/tmp/books/book-selected",
        kind=MoonBook,
      ),
      @desk.workspace(
        id="book-other",
        name="Other",
        root_path="/tmp/books/book-other",
        kind=MoonBook,
      ),
    ],
  }
}

///|
fn moonflow_test_capability(available : Bool) -> MoonFlowCapabilityEvidence {
  {
    available,
    reason: if available {
      "capability-ready"
    } else {
      "runtime-root-unavailable"
    },
    root: if available {
      "/runtime/flow"
    } else {
      "/missing/flow"
    },
    platform_evidence: None,
    installation_evidence: None,
    configuration_evidence: None,
  }
}

///|
test "Flow run listing transitions through loading zero ready stale and failure" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let selected_run = moonflow_runs_test_run("book-selected", "run-selected")
  let other_run = moonflow_runs_test_run("book-other", "run-other")
  let (_, first_use) = update_workspace_results(
    dispatch,
    LoadedMoonFlowRuns(Ok([selected_run, other_run])),
    init_model(),
  )
  assert_true(first_use.moonflow_runs_state is Some(FirstUseEmpty))
  assert_eq(first_use.moonflow_runs.length(), 2)
  let ready_model = {
    ..moonflow_runs_test_model(),
    moonflow_runs: [selected_run, other_run],
    moonflow_runs_state: None,
  }
  let (_, loading) = select_workspace_mode_action(
    dispatch,
    MoonFlow,
    ready_model,
  )
  assert_true(loading.moonflow_runs_state is Some(Loading))
  assert_eq(moonflow_selected_runs(loading).length(), 1)
  let (_, zero) = update_workspace_results(
    dispatch,
    LoadedMoonFlowRuns(Ok([other_run])),
    loading,
  )
  assert_true(zero.moonflow_runs_state is Some(LegitimateZero))
  assert_eq(zero.moonflow_runs.length(), 1)
  assert_eq(moonflow_selected_runs(zero).length(), 0)
  let (_, ready) = update_workspace_results(
    dispatch,
    LoadedMoonFlowRuns(Ok([other_run, selected_run])),
    loading,
  )
  assert_true(ready.moonflow_runs_state is None)
  assert_eq(ready.moonflow_runs.length(), 2)
  assert_eq(moonflow_selected_runs(ready).length(), 1)
  let (_, stale) = update_workspace_results(
    dispatch,
    LoadedMoonFlowRuns(Err("private refresh failure")),
    ready,
  )
  assert_true(stale.moonflow_runs_state is Some(Stale))
  assert_eq(moonflow_selected_runs(stale).length(), 1)
  assert_true(stale.moonflow_runs_error is Some("private refresh failure"))
  let (_, failed) = update_workspace_results(
    dispatch,
    LoadedMoonFlowRuns(Err("private initial failure")),
    { ..loading, moonflow_runs: [] },
  )
  assert_true(failed.moonflow_runs_state is Some(RecoverableError))
  assert_eq(failed.moonflow_runs.length(), 0)
  let (_, retrying) = select_workspace_mode_action(dispatch, MoonFlow, failed)
  assert_true(retrying.moonflow_runs_state is Some(Loading))
  assert_true(retrying.moonflow_runs_error is None)
}

///|
#warnings("-alert_unstable")
test "Flow run listing renders owned copy and confines refresh diagnostics" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let selected_run = moonflow_runs_test_run("book-selected", "run-selected")
  let loading_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_moonflow_workspace(dispatch, {
        ..moonflow_runs_test_model(),
        moonflow_runs: [selected_run],
        moonflow_runs_state: Some(Loading),
      }),
    ),
  )
  assert_true(loading_markup.contains("data-state=\"loading\""))
  assert_true(loading_markup.contains("Refreshing executable work"))
  assert_true(loading_markup.contains("run-selected"))
  let ready_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_moonflow_workspace(dispatch, {
        ..moonflow_runs_test_model(),
        moonflow_runs: [selected_run],
        moonflow_runs_state: None,
      }),
    ),
  )
  assert_true(ready_markup.contains("run-selected"))
  assert_true(ready_markup.contains("Executable work exists"))
  assert_false(ready_markup.contains("moonflow-runs-state-announcement"))
  let zero_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_moonflow_workspace(dispatch, {
        ..moonflow_runs_test_model(),
        moonflow_runs_state: Some(LegitimateZero),
      }),
    ),
  )
  assert_true(zero_markup.contains("data-state=\"legitimate-zero\""))
  assert_eq(zero_markup.split("No executable work yet").length(), 2)
  let zero_before_canvas = zero_markup
    .split("data-testid=\"moonflow-composition-canvas\"")
    .to_array()
  assert_eq(zero_before_canvas.length(), 2)
  assert_true(zero_before_canvas[0].contains("data-state=\"legitimate-zero\""))
  let stale_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_moonflow_workspace(dispatch, {
        ..moonflow_runs_test_model(),
        moonflow_runs: [selected_run],
        moonflow_runs_state: Some(Stale),
        moonflow_runs_error: Some("private refresh failure"),
      }),
    ),
  )
  assert_true(stale_markup.contains("Showing earlier executable work"))
  assert_true(stale_markup.contains("run-selected"))
  assert_true(
    stale_markup.contains(
      "<summary>Technical details</summary><code>private refresh failure</code>",
    ),
  )
  let failed_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_moonflow_workspace(dispatch, {
        ..moonflow_runs_test_model(),
        moonflow_runs_state: Some(RecoverableError),
        moonflow_runs_error: Some("private initial failure"),
      }),
    ),
  )
  assert_true(failed_markup.contains("Executable work couldn’t be loaded"))
  assert_true(failed_markup.contains(">Retry</button>"))
  assert_true(
    failed_markup.contains(
      "<summary>Technical details</summary><code>private initial failure</code>",
    ),
  )
  assert_false(failed_markup.contains("No executable work yet"))
}

///|
#warnings("-alert_unstable")
test "Flow capability limits preparation without erasing run history" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let selected_run = moonflow_runs_test_run("book-selected", "run-selected")
  let base = {
    ..moonflow_runs_test_model(),
    moonflow_runs: [selected_run],
    moonflow_runs_state: None,
  }
  let (_, limited) = update_workspace_results(
    dispatch,
    LoadedMoonFlowCapability(Ok(moonflow_test_capability(false))),
    base,
  )
  assert_true(moonflow_effective_runs_state(limited) is Some(CapabilityLimited))
  assert_true(limited.moonflow_runs_state is None)
  assert_eq(moonflow_selected_runs(limited).length(), 1)
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_moonflow_workspace(dispatch, limited)),
  )
  assert_true(markup.contains("data-state=\"capability-limited\""))
  assert_eq(markup.split("Executable work isn’t available").length(), 3)
  assert_eq(
    markup
    .split("This setup cannot provide governed runs for the selected book.")
    .length(),
    3,
  )
  assert_true(markup.contains("run-selected"))
  assert_false(markup.contains("data-testid=\"moonflow-prepare-selected\""))
  assert_true(markup.contains("<summary>Technical details</summary>"))
  assert_true(markup.contains("runtime-root-unavailable"))
  assert_true(markup.contains("/missing/flow"))
  let limited_before_canvas = markup
    .split("data-testid=\"moonflow-composition-canvas\"")
    .to_array()
  assert_eq(limited_before_canvas.length(), 2)
  assert_true(
    limited_before_canvas[0].contains("data-state=\"capability-limited\""),
  )
  let (_, refused) = update_workspace_surface_actions(
    dispatch,
    PrepareMoonFlow,
    limited,
  )
  assert_false(refused.moonflow_ingest_preparing)
  assert_eq(
    refused.moonflow_status,
    "Flow preparation is not available in the current setup",
  )
  let (_, ready) = update_workspace_results(
    dispatch,
    LoadedMoonFlowCapability(Ok(moonflow_test_capability(true))),
    limited,
  )
  assert_true(moonflow_effective_runs_state(ready) is None)
}

///|
test "Flow capability probe failure preserves compatibility state" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let base = {
    ..moonflow_runs_test_model(),
    moonflow_runs_state: Some(LegitimateZero),
  }
  let (_, failed) = update_workspace_results(
    dispatch,
    LoadedMoonFlowCapability(Err("capability endpoint unavailable")),
    base,
  )
  assert_true(moonflow_effective_runs_state(failed) is Some(LegitimateZero))
  assert_true(
    failed.moonflow_capability_error is Some("capability endpoint unavailable"),
  )
}

///|
#warnings("-alert_unstable")
test "Flow renders missing autonomy scorecard and control evidence unavailable" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let run = {
    ..moonflow_runs_test_run("book-selected", "run-without-runtime-evidence"),
    autonomy_binding: None,
    intervention_scorecard: None,
    run_control: None,
  }
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_moonflow_run(dispatch, init_model(), run)),
  )
  assert_true(markup.contains("Autonomy binding evidence unavailable."))
  assert_true(markup.contains("Intervention scorecard evidence unavailable."))
  assert_true(markup.contains("Run-control evidence unavailable."))
  assert_true(
    markup.contains(
      "MoonDesk will not offer controls without a persisted control record.",
    ),
  )
  assert_false(markup.contains("unattended qualified"))
  assert_false(markup.contains(">Pause</button>"))
  assert_false(markup.contains(">Cancel run</button>"))
}

///|
test "Flow ingest busy state is explicit and settles on every result" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, preparing) = update_workspace_surface_actions(
    dispatch,
    PrepareMoonFlow,
    moonflow_runs_test_model(),
  )
  assert_true(preparing.moonflow_ingest_preparing)
  let (_, failed) = update_workspace_results(
    dispatch,
    ImportedMoonFlow(Err("import failed")),
    preparing,
  )
  assert_false(failed.moonflow_ingest_preparing)
}
