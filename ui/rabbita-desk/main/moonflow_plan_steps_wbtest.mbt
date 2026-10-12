///|
test "declared step controls duplicate twice remove repair save reopen without requests" {
  let previous = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(previous)
  let initial = plan_form_fixture_model()
  let source = initial.moonflow_composition.unwrap().source_graph
  let (_, first) = update_moonflow_plan_authoring(
    DuplicateMoonFlowPlanItem("left"),
    initial,
  )
  let (_, second) = update_moonflow_plan_authoring(
    DuplicateMoonFlowPlanItem("left-copy-1"),
    first,
  )
  let (_, edited) = update_moonflow_plan_authoring(
    EditMoonFlowPlanField("left-copy-2", "inputs", "requests/third.json"),
    second,
  )
  let (_, removed) = update_moonflow_plan_authoring(
    RemoveMoonFlowPlanItem("join"),
    edited,
  )
  let form = moonflow_plan_form_input(removed.moonflow_composition.unwrap())
  assert_eq(
    handoff_text(form, "contract_id"),
    "moonflow.declared-plan-form-input.v2",
  )
  assert_eq(
    handoff_field(form, "added_templates"),
    ({ "left-copy-1": "left", "left-copy-2": "left" } : Json),
  )
  let (_, saved) = update_moonflow_plan_authoring(
    SaveMoonFlowPlanDraft,
    removed,
  )
  let (_, reopened) = update_moonflow_plan_authoring(
    ReopenMoonFlowPlanDraft,
    initial,
  )
  assert_eq(
    moonflow_plan_form_input(reopened.moonflow_composition.unwrap()),
    form,
  )
  assert_eq(saved.moonflow_composition.unwrap().source_graph, source)
  let editor = reopened.moonflow_composition.unwrap().plan_editor.unwrap()
  assert_eq(editor.request_id, "")
  assert_eq(editor.phase, "draft")
  assert_true(editor.receipt is None)
  let rendered = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_moonflow_plan_authoring(code_mode_test_dispatch, reopened),
    ),
  )
  assert_true(rendered.contains("Duplicate declared operation"))
  assert_true(rendered.contains("Remove this step"))
  assert_true(rendered.contains("Removed source steps: join"))
  assert_true(rendered.contains("no inherited acceptance"))
  println("FLOW_STEPS_FORM_FIXTURE:" + form.stringify())
  let workspace_id = @desk.stable_id("book", "steps-book")
  let native_model = {
    ..reopened,
    selected_workspace_id: workspace_id,
    moonflow_composition: Some({
      ..reopened.moonflow_composition.unwrap(),
      workspace_id: Some(workspace_id),
    }),
  }
  let (_, pending) = update_moonflow_plan_preparation(
    code_mode_test_dispatch,
    Prepare,
    native_model,
  )
  assert_eq(
    pending.moonflow_composition.unwrap().plan_editor.unwrap().phase,
    "preparing",
  )
  println(
    "FLOW_STEPS_REQUEST_FIXTURE:" +
    moonflow_plan_payload(
      "prepare",
      workspace_id,
      pending.moonflow_composition.unwrap().plan_editor.unwrap().request_id,
      form=Some(moonflow_plan_form_input(pending.moonflow_composition.unwrap())),
    ).stringify(),
  )
}

///|
test "declared step removal retains dependents and blocks until explicitly repaired" {
  let (_, removed) = update_moonflow_plan_authoring(
    RemoveMoonFlowPlanItem("root"),
    plan_form_fixture_model(),
  )
  let editor = removed.moonflow_composition.unwrap().plan_editor.unwrap()
  assert_eq(editor.fields.length(), 3)
  assert_eq(editor.fields[0].dependencies, "root")
  assert_false(moonflow_plan_field_errors(editor).is_empty())
  try moonflow_plan_form_input(removed.moonflow_composition.unwrap()) catch {
    _ => ()
  } noraise {
    _ => fail("dangling plan prepared")
  }
  let (_, left) = update_moonflow_plan_authoring(
    EditMoonFlowPlanField("left", "dependencies", ""),
    removed,
  )
  let (_, right) = update_moonflow_plan_authoring(
    EditMoonFlowPlanField("right", "dependencies", ""),
    left,
  )
  ignore(moonflow_plan_form_input(right.moonflow_composition.unwrap()))
  let mut empty = right
  for id in ["left", "right", "join"] {
    let (_, next) = update_moonflow_plan_authoring(
      RemoveMoonFlowPlanItem(id),
      empty,
    )
    empty = next
  }
  try moonflow_plan_form_input(empty.moonflow_composition.unwrap()) catch {
    _ => ()
  } noraise {
    _ => fail("empty plan prepared")
  }
}

///|
test "declared step mutations are ignored during prepare and restore rejects unknown templates" {
  let model = plan_form_fixture_model()
  let composition = model.moonflow_composition.unwrap()
  let seed = moonflow_plan_seed(composition)
  let busy = { ..seed, phase: "preparing", request_id: "pending-request", }
  let waiting = {
    ..model,
    moonflow_composition: Some({ ..composition, plan_editor: Some(busy), }),
  }
  for msg in [DuplicateMoonFlowPlanItem("left"), RemoveMoonFlowPlanItem("root")] {
    let (_, result) = update_moonflow_plan_authoring(msg, waiting)
    assert_eq(
      result.moonflow_composition.unwrap().plan_editor.unwrap().fields,
      busy.fields,
    )
  }
  let invalid = [
    { ..seed.fields[0], work_item_id: "new", source_item_id: Some("absent"), },
  ]
  try moonflow_plan_validate_templates(composition, invalid) catch {
    _ => ()
  } noraise {
    _ => fail("unknown template")
  }
  let invalid = [
    { ..seed.fields[0], work_item_id: "../bad", source_item_id: Some("root"), },
  ]
  try moonflow_plan_validate_templates(composition, invalid) catch {
    _ => ()
  } noraise {
    _ => fail("unsafe ID")
  }
}

///|
test "old local plan drafts without template fields still reopen" {
  let previous = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(previous)
  let model = plan_form_fixture_model()
  let composition = model.moonflow_composition.unwrap()
  let source = composition.source_graph.unwrap()
  let fields = moonflow_plan_seed(composition).fields.to_json()
  guard fields is Array(items) else { fail("fields") }
  for item in items {
    guard item is Object(value) else { fail("item") }
    value.remove("source_item_id")
  }
  let body : Json = {
    "contract_id": "moondesk.declared-plan-draft.v1",
    "source_graph": source,
    "fields": fields,
    "prepared_request_id": "",
  }
  assert_true(
    moonflow_plan_save_matching(
      moonflow_plan_storage_key("fixture-plan", source),
      "missing",
      body.stringify(),
    ),
  )
  let restored = moonflow_plan_reopen("fixture-plan", composition)
  assert_eq(restored.plan_editor.unwrap().fields.length(), 4)
  assert_true(restored.plan_editor.unwrap().notice.contains("reopened"))
  assert_eq(
    handoff_text(moonflow_plan_form_input(restored), "contract_id"),
    "moonflow.declared-plan-form-input.v1",
  )
}

///|
test "duplicating legacy label generates a safe new item without changing original" {
  let original = plan_form_fixture_model().moonflow_composition.unwrap()
  let items = original.items.map(item => {
    ..item,
    work_item_id: "source..legacy",
  })
  let composition = { ..original, items: [items[0]], }
  let seed = moonflow_plan_seed(composition)
  moonflow_plan_validate_templates(composition, seed.fields)
  let duplicated = moonflow_plan_duplicate(composition, seed, "source..legacy")
  assert_eq(duplicated.fields[0].work_item_id, "source..legacy")
  assert_eq(duplicated.fields[1].work_item_id, "step-copy-1")
  moonflow_plan_validate_templates(composition, duplicated.fields)
}
