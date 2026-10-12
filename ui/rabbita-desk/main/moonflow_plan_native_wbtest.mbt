///|
extern "js" fn moonflow_plan_native_evidence_text() -> String =
  #| () => {
  #|   const path = globalThis.process?.env?.MOONDESK_FLOW_PLAN_EVIDENCE;
  #|   return path ? process.getBuiltinModule('fs').readFileSync(path, 'utf8') : '';
  #| }

///|
test "plan UI renders actual native preparation import and migration receipts" {
  let text = moonflow_plan_native_evidence_text()
  if text == "" {
    println(
      "FLOW_PLAN_NATIVE_RENDER_NOT_CONFIGURED: actual native receipt rendering was not exercised",
    )
    return
  }
  guard @json.parse(text) is Array(cases) && cases.length() == 2 else {
    fail("Expected actual import and revision host evidence")
  }
  for value in cases {
    let model = plan_form_fixture_model()
    let composition = model.moonflow_composition.unwrap()
    let prepared = handoff_field(value, "prepared")
    let editor = {
      ..moonflow_plan_seed(composition),
      phase: "prepared",
      request_id: handoff_text(value, "ui_request_id"),
      receipt: Some(prepared),
    }
    let updated = moonflow_plan_replace(model, composition, editor)
    let markup = @rabbita.render_to_string(
      @rabbita.static_cell(
        render_moonflow_plan_authoring(code_mode_test_dispatch, updated),
      ),
    )
    assert_true(markup.contains("flow-plan-import"))
    assert_true(markup.contains("Input capture limits"))
    assert_true(markup.contains("does not promise reproducible execution"))
    let receipt = handoff_field(prepared, "receipt")
    let graph = handoff_field(handoff_field(receipt, "prepared"), "graph")
    assert_true(markup.contains(handoff_text(graph, "graph_id")))
    let revision = handoff_field(value, "revision") == (true : Json)
    assert_true(
      markup.contains(
        if revision {
          "Import this reviewed revision"
        } else {
          "Import this child plan"
        },
      ),
    )
    let applied = handoff_field(value, "applied")
    let imported = moonflow_plan_replace(model, composition, {
      ..editor,
      phase: "imported",
      receipt: Some(applied),
    })
    let complete = @rabbita.render_to_string(
      @rabbita.static_cell(
        render_moonflow_plan_authoring(code_mode_test_dispatch, imported),
      ),
    )
    assert_true(complete.contains("Child plan imported"))
    assert_false(complete.contains("flow-plan-import\""))
    let actual_projection : MoonFlowRunProjection = @json.from_json(
      handoff_field(handoff_field(applied, "applied"), "projection"),
    )
    let listed = {
      ..imported,
      workspaces: [
        @desk.workspace(
          id="fixture-plan",
          name="Fixture",
          root_path="/suite/books/fixture-plan",
          kind=MoonBook,
        ),
      ],
      moonflow_runs: [
        {
          ..actual_projection,
          run_id: "diamond-r1",
          declaration_revision: "r1",
        },
        actual_projection,
      ],
    }
    assert_eq(
      moonflow_selected_runs(listed)[0].run_id,
      actual_projection.run_id,
    )
  }
  println(
    "FLOW_PLAN_NATIVE_RENDER: actual native import and revision receipts rendered through production UI",
  )
}
