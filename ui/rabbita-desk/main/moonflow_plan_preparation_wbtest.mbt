///|
fn plan_ui_result(model : Model, applied~ : Bool = false) -> Json {
  let editor = model.moonflow_composition.unwrap().plan_editor.unwrap()
  {
    "contract_id": "moondesk.flow-plan-result.v1",
    "ok": true,
    "status": if applied {
      "imported"
    } else {
      "prepared"
    },
    "message": if applied {
      "Child imported with zero attempts"
    } else {
      "Child prepared without execution"
    },
    "workspace_id": model.selected_workspace_id,
    "request_id": editor.request_id,
    "source_current": true,
    "receipt": {
      "prepared": {
        "source_graph_id": "diamond-r1",
        "graph": { "graph_id": "plan-child" },
      },
      "migration_preview": Json::null(),
    },
    "changes": [
      {
        "work_item_id": "left",
        "field": "timeout_ms",
        "before": 60000,
        "after": 90000,
      },
    ],
    "dispatched": false,
  }
}

///|
fn plan_ui_reply(
  model : Model,
  result : Result[Json, String],
) -> MoonFlowPlanMsg {
  let composition = model.moonflow_composition.unwrap()
  let editor = composition.plan_editor.unwrap()
  Reply(
    model.selected_workspace_id,
    composition.source_graph.unwrap().stringify(),
    editor.request_id,
    editor.generation,
    result,
  )
}

///|
test "plan UI prepare double click exact response explicit import and failed run refresh" {
  let previous = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(previous)
  let original = plan_form_fixture_model()
  let (_, editing) = update_moonflow_plan_authoring(
    EditMoonFlowPlanField("left", "timeout", "90000"),
    original,
  )
  let (_, pending) = update_moonflow_plan_preparation(
    code_mode_test_dispatch,
    Prepare,
    editing,
  )
  let first = pending.moonflow_composition.unwrap().plan_editor.unwrap()
  assert_eq(first.phase, "preparing")
  let (_, repeated) = update_moonflow_plan_preparation(
    code_mode_test_dispatch,
    Prepare,
    pending,
  )
  assert_eq(
    repeated.moonflow_composition.unwrap().plan_editor.unwrap().generation,
    first.generation,
  )
  let payload = moonflow_plan_payload(
    "prepare",
    pending.selected_workspace_id,
    first.request_id,
    form=Some(moonflow_plan_form_input(pending.moonflow_composition.unwrap())),
  )
  println("FLOW_PLAN_UI_REQUEST:" + payload.stringify())
  let (_, prepared) = update_moonflow_plan_preparation(
    code_mode_test_dispatch,
    plan_ui_reply(pending, Ok(plan_ui_result(pending))),
    pending,
  )
  assert_eq(
    prepared.moonflow_composition.unwrap().plan_editor.unwrap().phase,
    "prepared",
  )
  let markup = render_test_dom(
    @rabbita.static_cell(
      render_moonflow_plan_authoring(code_mode_test_dispatch, prepared),
    ),
  )
  assert_true(markup.contains("Import this child plan"))
  assert_true(markup.contains("left · Timeout (ms): 60000 → 90000"))
  assert_true(markup.contains("Technical preparation evidence"))
  let (_, applying) = update_moonflow_plan_preparation(
    code_mode_test_dispatch,
    Apply,
    prepared,
  )
  assert_eq(
    applying.moonflow_composition.unwrap().plan_editor.unwrap().phase,
    "applying",
  )
  let (_, twice) = update_moonflow_plan_preparation(
    code_mode_test_dispatch,
    Apply,
    applying,
  )
  assert_eq(
    twice.moonflow_composition.unwrap().plan_editor.unwrap().generation,
    applying.moonflow_composition.unwrap().plan_editor.unwrap().generation,
  )
  let (_, imported) = update_moonflow_plan_preparation(
    code_mode_test_dispatch,
    plan_ui_reply(applying, Ok(plan_ui_result(applying, applied=true))),
    applying,
  )
  assert_eq(
    imported.moonflow_composition.unwrap().plan_editor.unwrap().phase,
    "imported",
  )
  let (_, failed_refresh) = update_workspace_results(
    code_mode_test_dispatch,
    LoadedMoonFlowRuns(Err("offline")),
    imported,
  )
  assert_eq(
    failed_refresh.moonflow_composition.unwrap().plan_editor.unwrap().phase,
    "imported",
  )
  assert_eq(
    failed_refresh.moonflow_composition.unwrap().source_graph,
    original.moonflow_composition.unwrap().source_graph,
  )
}

///|
test "plan UI stale Book result and close ignore old completion and retain reload identity" {
  let model = plan_form_fixture_model()
  let (_, pending) = update_moonflow_plan_preparation(
    code_mode_test_dispatch,
    Prepare,
    model,
  )
  let reply = plan_ui_reply(pending, Ok(plan_ui_result(pending)))
  let (_, switched) = update_moonflow_plan_preparation(
    code_mode_test_dispatch,
    reply,
    { ..pending, selected_workspace_id: "another-book", },
  )
  assert_eq(
    switched.moonflow_composition.unwrap().plan_editor.unwrap().phase,
    "preparing",
  )
  let (_, closed) = update_moonflow_plan_preparation(
    code_mode_test_dispatch,
    Close,
    pending,
  )
  let (_, late) = update_moonflow_plan_preparation(
    code_mode_test_dispatch, reply, closed,
  )
  assert_true(late.moonflow_composition.unwrap().plan_editor.unwrap().closed)
  assert_true(
    late.moonflow_composition.unwrap().plan_editor.unwrap().receipt is None,
  )
  let (_, opened) = update_moonflow_plan_preparation(
    code_mode_test_dispatch,
    Open,
    late,
  )
  let (_, inspect_pending) = update_moonflow_plan_preparation(
    code_mode_test_dispatch,
    Inspect,
    opened,
  )
  assert_eq(
    inspect_pending.moonflow_composition.unwrap().plan_editor.unwrap().phase,
    "loading",
  )
  assert_eq(
    inspect_pending.moonflow_composition.unwrap().plan_editor.unwrap().request_id,
    pending.moonflow_composition.unwrap().plan_editor.unwrap().request_id,
  )
}

///|
test "plan UI failed refresh timeout and wrong request never enable import" {
  let model = plan_form_fixture_model()
  let (_, pending) = update_moonflow_plan_preparation(
    code_mode_test_dispatch,
    Prepare,
    model,
  )
  let editor = pending.moonflow_composition.unwrap().plan_editor.unwrap()
  let (_, timed) = update_moonflow_plan_preparation(
    code_mode_test_dispatch,
    Timeout("fixture-plan", editor.request_id, editor.generation),
    pending,
  )
  assert_eq(
    timed.moonflow_composition.unwrap().plan_editor.unwrap().phase,
    "uncertain",
  )
  let (_, refused) = update_moonflow_plan_preparation(
    code_mode_test_dispatch,
    Apply,
    timed,
  )
  assert_eq(
    refused.moonflow_composition.unwrap().plan_editor.unwrap().phase,
    "uncertain",
  )
  let (_, failed) = update_moonflow_plan_preparation(
    code_mode_test_dispatch,
    plan_ui_reply(pending, Err("temporary failure")),
    pending,
  )
  assert_eq(
    failed.moonflow_composition.unwrap().plan_editor.unwrap().phase,
    "uncertain",
  )
  let wrong = plan_ui_result(pending)
  guard wrong is Object(fields) else { fail("fixture") }
  fields["request_id"] = "another-request"
  let (_, ignored) = update_moonflow_plan_preparation(
    code_mode_test_dispatch,
    plan_ui_reply(pending, Ok(wrong)),
    pending,
  )
  assert_true(
    ignored.moonflow_composition.unwrap().plan_editor.unwrap().receipt is None,
  )
  let (_, unavailable) = update_workspace_results(
    code_mode_test_dispatch,
    LoadedMoonFlowComposition(Err("source unavailable")),
    pending,
  )
  let (_, late) = update_moonflow_plan_preparation(
    code_mode_test_dispatch,
    plan_ui_reply(pending, Ok(plan_ui_result(pending))),
    unavailable,
  )
  let (_, blocked) = update_moonflow_plan_preparation(
    code_mode_test_dispatch,
    Apply,
    late,
  )
  assert_eq(
    blocked.moonflow_composition.unwrap().plan_editor.unwrap().phase,
    "prepared",
  )
  assert_true(
    blocked.moonflow_composition.unwrap().plan_editor.unwrap().notice.contains(
      "Source refresh failed",
    ),
  )
}

///|
test "plan UI identifies fields and cycle then reopens saved request for host reload" {
  let previous = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(previous)
  let model = plan_form_fixture_model()
  let (_, cycle) = update_moonflow_plan_authoring(
    EditMoonFlowPlanField("root", "dependencies", "join"),
    model,
  )
  assert_true(
    moonflow_plan_field_errors(
      cycle.moonflow_composition.unwrap().plan_editor.unwrap(),
    )
    .join(" ")
    .contains("cycle"),
  )
  let (_, bad) = update_moonflow_plan_authoring(
    EditMoonFlowPlanField("left", "inputs", "../outside"),
    model,
  )
  assert_true(
    moonflow_plan_field_errors(
      bad.moonflow_composition.unwrap().plan_editor.unwrap(),
    )
    .join(" ")
    .contains("left · input artifacts"),
  )
  let (_, pending) = update_moonflow_plan_preparation(
    code_mode_test_dispatch,
    Prepare,
    model,
  )
  let (_, prepared) = update_moonflow_plan_preparation(
    code_mode_test_dispatch,
    plan_ui_reply(pending, Ok(plan_ui_result(pending))),
    pending,
  )
  let (_, reopened) = update_moonflow_plan_authoring(
    ReopenMoonFlowPlanDraft,
    prepared,
  )
  assert_true(
    reopened.moonflow_composition.unwrap().plan_editor.unwrap().receipt is None,
  )
  assert_eq(
    reopened.moonflow_composition.unwrap().plan_editor.unwrap().request_id,
    prepared.moonflow_composition.unwrap().plan_editor.unwrap().request_id,
  )
  let (_, blocked) = update_moonflow_plan_preparation(
    code_mode_test_dispatch,
    Apply,
    reopened,
  )
  assert_eq(
    blocked.moonflow_composition.unwrap().plan_editor.unwrap().phase,
    "draft",
  )
  let (_, loading) = update_moonflow_plan_preparation(
    code_mode_test_dispatch,
    Inspect,
    reopened,
  )
  assert_eq(
    loading.moonflow_composition.unwrap().plan_editor.unwrap().phase,
    "loading",
  )
}
