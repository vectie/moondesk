///|
extern "js" fn step_native_http_evidence() -> String =
  #| () => { const p=globalThis.process?.env?.MOONDESK_FLOW_STEP_EVIDENCE;return p?process.getBuiltinModule('fs').readFileSync(p,'utf8'):''; }

///|
test "single step compiled UI renders actual HTTP Review after lost response reconcile" {
  let text = step_native_http_evidence()
  if text == "" {
    println(
      "FLOW_STEP_NATIVE_UI_NOT_CONFIGURED: actual HTTP evidence rendering not exercised",
    )
    return
  }
  let evidence = @json.parse(text)
  let request = handoff_field(evidence, "request")
  let projection : MoonFlowRunProjection = @json.from_json(
    handoff_field(evidence, "projection"),
  )
  let previous = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(previous)
  let state = MoonFlowSingleStepState::{
    workspace_id: handoff_text(request, "workspace_id"),
    run_id: handoff_text(request, "run_id"),
    work_item_id: handoff_text(request, "work_item_id"),
    request_id: handoff_text(request, "request_id"),
    status: "reconcile-required",
    message: "Waiting",
    generation: moonflow_plan_next_generation(),
    pending: true,
    result: None,
  }
  let model = {
    ..init_model(),
    selected_workspace_id: state.workspace_id,
    workspaces: [
      @desk.workspace(
        id=state.workspace_id,
        name="Native Book",
        root_path="/suite/books/single-step-book",
        kind=MoonBook,
      ),
    ],
    moonflow_runs: [projection],
    moonflow_single_step: Some(state),
  }
  assert_true(moonflow_single_step_save(state, "missing"))
  let (_, unknown) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Reply(
      state.workspace_id,
      state.run_id,
      state.work_item_id,
      state.request_id,
      state.generation,
      Err("Browser did not receive actual HTTP result"),
    ),
    model,
  )
  assert_eq(unknown.moonflow_single_step.unwrap().status, "reconcile-required")
  let (_, pending) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Reconcile,
    unknown,
  )
  let attempt = pending.moonflow_single_step.unwrap()
  assert_eq(attempt.request_id, state.request_id)
  let (_, reviewed) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Reply(
      attempt.workspace_id,
      attempt.run_id,
      attempt.work_item_id,
      attempt.request_id,
      attempt.generation,
      Ok(handoff_field(evidence, "reconciled")),
    ),
    pending,
  )
  let markup = render_test_dom(
    @rabbita.static_cell(
      render_moonflow_single_step(code_mode_test_dispatch, reviewed, projection),
    ),
  )
  assert_eq(reviewed.moonflow_single_step.unwrap().status, "review")
  assert_true(markup.contains("Review required"))
  assert_true(markup.contains("fixture-reference-only"))
  assert_true(markup.contains("Physical authority: false"))
  assert_false(markup.contains("flow-single-step-execute"))
  assert_false(markup.contains("flow-single-step-reconcile"))
  assert_true(markup.contains(state.request_id))
  assert_true(markup.contains("Artifact:"))
  println(
    "FLOW_STEP_NATIVE_UI: actual HTTP projection and reconciliation rendered Review, original action, artifact evidence and fixture-only boundary; no run-again control",
  )
}
