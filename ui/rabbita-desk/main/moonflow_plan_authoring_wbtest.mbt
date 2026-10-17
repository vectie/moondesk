///|
fn plan_form_fixture_graph() -> Json {
  let items = [
    ("root", []),
    ("left", ["root"]),
    ("right", ["root"]),
    ("join", ["left", "right"]),
  ].map(pair => {
    let (id, dependencies) = pair
    (
      {
        "work_item_id": id,
        "declaration_id": id,
        "product_id": "moonmold",
        "requested_authority": "workspace-mutation",
        "acceptance_criteria": ["Review the exact " + id + " artifact"],
        "operation": "moonmold/spatial.operation.execute@0.2.0",
        "input_contracts": ["moonmold/spatial-operation-request@1.0.0"],
        "output_contracts": ["moonmold/spatial-operation-receipt@1.0.0"],
        "required_claim": "digital-artifact",
        "input_artifacts": ["requests/" + id + ".json"],
        "timeout_ms": 60000,
        "depends_on": dependencies,
      } : Json)
  })
  {
    "contract_id": "moonsuite.work-model.v1",
    "graph_id": "diamond-r1",
    "book_id": "fixture-plan",
    "declaration_revision": "r1",
    "source_digest": "sha256:fixture-source",
    "items": items,
    "recorded_at": "2026-07-31T00:00:00Z",
  }
}

///|
fn plan_form_fixture_model() -> Model raise {
  let graph = plan_form_fixture_graph()
  guard graph is Object(fields) else { fail("expected graph") }
  let composition : MoonFlowComposition = @json.from_json({
    "workspace_id": "fixture-plan",
    "selected_item_ids": ["root", "left", "right", "join"],
    "source_graph": graph,
    "items": fields["items"],
  })
  {
    ..init_model(),
    selected_workspace_id: "fixture-plan",
    moonflow_composition: Some(composition),
  }
}

///|
test "plan form controls prepare exact edited diamond fixture through host" {
  let model = plan_form_fixture_model()
  let before = model.moonflow_composition.unwrap().source_graph
    .unwrap()
    .stringify()
  let (_, a) = update_moonflow_plan_authoring(
    EditMoonFlowPlanField("left", "inputs", "requests/left-v2.json"),
    model,
  )
  let (_, b) = update_moonflow_plan_authoring(
    EditMoonFlowPlanField(
      "left", "criteria", "Exact revised left output is reviewed",
    ),
    a,
  )
  let (_, c) = update_moonflow_plan_authoring(
    EditMoonFlowPlanField("left", "timeout", "90000"),
    b,
  )
  let (_, d) = update_moonflow_plan_authoring(
    EditMoonFlowPlanField("right", "dependencies", ""),
    c,
  )
  let exported = moonflow_plan_form_input(d.moonflow_composition.unwrap())
  assert_eq(
    d.moonflow_composition.unwrap().source_graph.unwrap().stringify(),
    before,
  )
  guard exported is Object(fields) else { fail("expected form") }
  guard fields["edits"] is Array(edits) else { fail("expected edits") }
  assert_eq(handoff_text(edits[1], "work_item_id"), "left")
  assert_eq(handoff_field(edits[1], "timeout_ms"), (90000 : Json))
  let rendered = render_test_dom(
    @rabbita.static_cell(
      render_moonflow_plan_authoring(code_mode_test_dispatch, d),
    ),
  )
  assert_true(rendered.contains("flow-plan-prepare"))
  assert_false(rendered.contains("flow-plan-export"))
  assert_true(rendered.contains("immutable child plan"))
  assert_true(rendered.contains("Input artifact paths"))
  assert_false(rendered.contains("Execute"))
  println("FLOW_PLAN_FORM_FIXTURE:" + exported.stringify())
}

///|
test "plan form incomplete local draft survives save reopen with blocked preparation" {
  let previous = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(previous)
  let model = plan_form_fixture_model()
  let (_, invalid) = update_moonflow_plan_authoring(
    EditMoonFlowPlanField("left", "timeout", "not yet"),
    model,
  )
  let (_, saved) = update_moonflow_plan_authoring(
    SaveMoonFlowPlanDraft,
    invalid,
  )
  assert_true(
    saved.moonflow_composition.unwrap().plan_editor.unwrap().notice.contains(
      "Draft saved",
    ),
  )
  let (_, reopened) = update_moonflow_plan_authoring(
    ReopenMoonFlowPlanDraft,
    model,
  )
  assert_eq(
    reopened.moonflow_composition.unwrap().plan_editor.unwrap().fields[1].timeout,
    "not yet",
  )
  let rendered = render_test_dom(
    @rabbita.static_cell(
      render_moonflow_plan_authoring(code_mode_test_dispatch, reopened),
    ),
  )
  assert_true(rendered.contains("Preparation blocked"))
  assert_false(rendered.contains("flow-plan-export"))
}

///|
test "plan form duplicate saves are idempotent and stale tab cannot overwrite" {
  let previous = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(previous)
  let first = plan_form_fixture_model()
  let stale = plan_form_fixture_model()
  let (_, edited) = update_moonflow_plan_authoring(
    EditMoonFlowPlanField("left", "timeout", "75000"),
    first,
  )
  let (_, saved) = update_moonflow_plan_authoring(SaveMoonFlowPlanDraft, edited)
  let (_, again) = update_moonflow_plan_authoring(SaveMoonFlowPlanDraft, saved)
  assert_eq(
    again.moonflow_composition.unwrap().plan_editor.unwrap().saved_body,
    saved.moonflow_composition.unwrap().plan_editor.unwrap().saved_body,
  )
  let (_, newer) = update_moonflow_plan_authoring(
    EditMoonFlowPlanField("left", "timeout", "99000"),
    stale,
  )
  let (_, refused) = update_moonflow_plan_authoring(
    SaveMoonFlowPlanDraft,
    newer,
  )
  assert_true(
    refused.moonflow_composition.unwrap().plan_editor.unwrap().notice.contains(
      "not saved",
    ),
  )
  let (_, reopened) = update_moonflow_plan_authoring(
    ReopenMoonFlowPlanDraft,
    refused,
  )
  assert_eq(
    reopened.moonflow_composition.unwrap().plan_editor.unwrap().fields[1].timeout,
    "75000",
  )
}

///|
test "plan form storage failure keeps current draft and source change has a separate saved identity" {
  let previous = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(previous)
  let model = plan_form_fixture_model()
  let (_, edited) = update_moonflow_plan_authoring(
    EditMoonFlowPlanField("root", "criteria", "Keep this unsaved criterion"),
    model,
  )
  let blocked = continuation_draft_block_storage("write")
  defer continuation_desk_storage_cleanup(blocked)
  let (_, failed) = update_moonflow_plan_authoring(
    SaveMoonFlowPlanDraft,
    edited,
  )
  assert_true(
    failed.moonflow_composition.unwrap().plan_editor.unwrap().notice.contains(
      "not saved",
    ),
  )
  assert_eq(
    failed.moonflow_composition.unwrap().plan_editor.unwrap().fields[0].criteria,
    "Keep this unsaved criterion",
  )
  let source = plan_form_fixture_graph()
  let changed = plan_form_fixture_graph()
  guard changed is Object(fields) else { fail("expected graph") }
  fields["source_digest"] = "different-source"
  assert_true(
    moonflow_plan_storage_key("book", source) !=
    moonflow_plan_storage_key("book", changed),
  )
}

///|
test "plan form retains unsaved edits across composition refresh and refuses fractional timeout" {
  let model = plan_form_fixture_model()
  let composition = model.moonflow_composition.unwrap()
  let (_, edited) = update_moonflow_plan_authoring(
    EditMoonFlowPlanField("left", "timeout", "1.5"),
    model,
  )
  let refreshed = moonflow_plan_receive(edited, composition)
  assert_eq(refreshed.plan_editor.unwrap().fields[1].timeout, "1.5")
  try moonflow_plan_form_input(refreshed) catch {
    _ => ()
  } noraise {
    _ => fail("fractional timeout exported")
  }
}

///|
test "plan form failed and unavailable refresh retain draft but block export until source returns" {
  let model = plan_form_fixture_model()
  let original = model.moonflow_composition.unwrap()
  let (_, edited) = update_moonflow_plan_authoring(
    EditMoonFlowPlanField("left", "timeout", "75000"),
    model,
  )
  for
    message in [
      LoadedMoonFlowComposition(Err("temporary read failed")),
      LoadedMoonFlowComposition(
        Ok({ ..original, validation_status: Some("unavailable"), }),
      ),
    ] {
    let (_, failed) = update_workspace_results(
      code_mode_test_dispatch, message, edited,
    )
    let retained = failed.moonflow_composition.unwrap()
    assert_eq(retained.plan_editor.unwrap().fields[1].timeout, "75000")
    try moonflow_plan_form_input(retained) catch {
      _ => ()
    } noraise {
      _ => fail("unconfirmed source exported")
    }
    let (_, recovered) = update_workspace_results(
      code_mode_test_dispatch,
      LoadedMoonFlowComposition(Ok(original)),
      failed,
    )
    assert_eq(
      recovered.moonflow_composition.unwrap().plan_editor.unwrap().fields[1].timeout,
      "75000",
    )
    ignore(moonflow_plan_form_input(recovered.moonflow_composition.unwrap()))
  }
}

///|
test "plan form workspace switch cannot save old editor in new Book or replace its draft" {
  let previous = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(previous)
  let first = plan_form_fixture_model()
  let (_, edited) = update_moonflow_plan_authoring(
    EditMoonFlowPlanField("left", "timeout", "75000"),
    first,
  )
  let switched = { ..edited, selected_workspace_id: "another-book", }
  let (_, ignored) = update_moonflow_plan_authoring(
    SaveMoonFlowPlanDraft,
    switched,
  )
  assert_eq(
    ignored.moonflow_composition.unwrap().plan_editor.unwrap().saved_body,
    "missing",
  )
  let next = {
    ..first.moonflow_composition.unwrap(),
    workspace_id: Some("another-book"),
  }
  let (_, loaded) = update_workspace_results(
    code_mode_test_dispatch,
    LoadedMoonFlowComposition(Ok(next)),
    switched,
  )
  assert_eq(
    loaded.moonflow_composition.unwrap().plan_editor.unwrap().fields[1].timeout,
    "60000",
  )
  let (_, stale) = update_workspace_results(
    code_mode_test_dispatch,
    LoadedMoonFlowComposition(Ok(first.moonflow_composition.unwrap())),
    loaded,
  )
  assert_eq(
    stale.moonflow_composition.unwrap().workspace_id,
    Some("another-book"),
  )
  let (_, second_edited) = update_moonflow_plan_authoring(
    EditMoonFlowPlanField("left", "timeout", "88000"),
    stale,
  )
  let (_, stale_save) = update_workspace_results(
    code_mode_test_dispatch,
    SavedMoonFlowComposition(Ok(first.moonflow_composition.unwrap())),
    second_edited,
  )
  assert_eq(
    stale_save.moonflow_composition.unwrap().workspace_id,
    Some("another-book"),
  )
  assert_eq(
    stale_save.moonflow_composition.unwrap().plan_editor.unwrap().fields[1].timeout,
    "88000",
  )
}
