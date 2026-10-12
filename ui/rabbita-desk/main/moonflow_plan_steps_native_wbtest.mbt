///|
extern "js" fn steps_http_evidence() -> String =
  #| () => { const p=globalThis.process?.env?.MOONDESK_STEPS_HTTP_EVIDENCE;return p?process.getBuiltinModule('fs').readFileSync(p,'utf8'):''; }

///|
test "compiled step UI renders actual native HTTP preparation and imported revision recovery" {
  let text = steps_http_evidence()
  if text == "" {
    println("STEPS_UI_HTTP_RESPONSE_NOT_CONFIGURED")
    return
  }
  let previous = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(previous)
  guard @json.parse(text) is Array(cases) else { fail("native evidence") }
  assert_eq(cases.length(), 2)
  for case in cases {
    let request = handoff_field(case, "request")
    let form = handoff_field(request, "form")
    let source = handoff_field(form, "source_graph")
    let workspace_id = handoff_text(request, "workspace_id")
    let request_id = handoff_text(request, "request_id")
    let original = plan_form_fixture_model()
    let (_, a) = update_moonflow_plan_authoring(
      DuplicateMoonFlowPlanItem("left"),
      original,
    )
    let (_, b) = update_moonflow_plan_authoring(
      DuplicateMoonFlowPlanItem("left-copy-1"),
      a,
    )
    let (_, c) = update_moonflow_plan_authoring(
      EditMoonFlowPlanField("left-copy-2", "inputs", "requests/third.json"),
      b,
    )
    let (_, d) = update_moonflow_plan_authoring(
      RemoveMoonFlowPlanItem("join"),
      c,
    )
    let composition = d.moonflow_composition.unwrap()
    assert_eq(composition.source_graph, Some(source))
    assert_eq(moonflow_plan_form_input(composition), form)
    let pending = {
      ..d,
      selected_workspace_id: workspace_id,
      moonflow_composition: Some({
        ..composition,
        workspace_id: Some(workspace_id),
        plan_editor: Some({
          ..composition.plan_editor.unwrap(),
          request_id,
          phase: "preparing",
        }),
      }),
    }
    let (_, prepared) = update_moonflow_plan_preparation(
      code_mode_test_dispatch,
      plan_ui_reply(pending, Ok(handoff_field(case, "prepared"))),
      pending,
    )
    assert_eq(
      prepared.moonflow_composition.unwrap().plan_editor.unwrap().phase,
      "prepared",
    )
    let markup = @rabbita.render_to_string(
      @rabbita.static_cell(
        render_moonflow_plan_authoring(code_mode_test_dispatch, prepared),
      ),
    )
    assert_true(markup.contains("Added step from source operation"))
    assert_true(markup.contains("Removed step"))
    assert_true(markup.contains("left-copy-2"))
    let (_, applying) = update_moonflow_plan_preparation(
      code_mode_test_dispatch,
      Apply,
      prepared,
    )
    assert_eq(
      applying.moonflow_composition.unwrap().plan_editor.unwrap().phase,
      "applying",
    )
    let (_, imported) = update_moonflow_plan_preparation(
      code_mode_test_dispatch,
      plan_ui_reply(applying, Ok(handoff_field(case, "applied"))),
      applying,
    )
    assert_eq(
      imported.moonflow_composition.unwrap().plan_editor.unwrap().phase,
      "imported",
    )
    let reopened = moonflow_plan_reopen(
      workspace_id,
      imported.moonflow_composition.unwrap(),
    )
    assert_eq(reopened.plan_editor.unwrap().request_id, request_id)
    assert_eq(reopened.plan_editor.unwrap().fields.length(), 5)
    assert_true(reopened.plan_editor.unwrap().receipt is None)
    assert_true(
      reopened.plan_editor.unwrap().notice.contains(
        "Reload the prepared result",
      ),
    )
  }
  println(
    "STEPS_UI_NATIVE_RESPONSE_PASSED: actual HTTP prepared/imported new and revision evidence rendered and explicitly reopened",
  )
}
