///|
fn step_ui_model() -> Model {
  let base = moonflow_runs_test_model()
  let item = {
    ..flow_test_item("ready"),
    work_item_id: "selected",
    product_id: "moonmold",
    adapter_id: Some("moonmold-pack-local-v1"),
    operation: "moonmold/spatial.operation.execute@0.2.0",
    requested_authority: "workspace-mutation",
    required_claim: "digital-artifact",
    attempt_count: 0,
    active_attempt_id: "",
    request_id: "",
    result_id: "",
    acceptance_review_id: "",
    approvals: [],
  }
  let run = {
    ..moonflow_runs_test_run("book-selected", "single-desk-ready"),
    runnable_item_ids: ["selected", "other"],
    items: [item, { ..item, work_item_id: "other", }],
  }
  let (_, selected) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Select(run.run_id, "selected"),
    { ..base, moonflow_runs: [run], },
  )
  selected
}

///|
fn step_ui_reply(model : Model, status : String) -> MoonFlowSingleStepMsg {
  let state = model.moonflow_single_step.unwrap()
  Reply(
    state.workspace_id,
    state.run_id,
    state.work_item_id,
    state.request_id,
    state.generation,
    Ok({
      "contract_id": "moondesk.flow-single-step-result.v1",
      "workspace_id": state.workspace_id,
      "run_id": state.run_id,
      "work_item_id": state.work_item_id,
      "request_id": state.request_id,
      "status": status,
      "message": "Selected digital artifact awaits explicit review",
      "result": {
        "qualification": {
          "evidence_class": "fixture-reference-only",
          "production_qualified": false,
          "physical_authority": false,
        },
      },
    }),
  )
}

///|
extern "js" fn step_ui_write_fixture_request(body : String) =
  #| body => { const p = globalThis.process?.env?.MOONDESK_FLOW_STEP_UI_REQUEST; if (p) process.getBuiltinModule('fs').writeFileSync(p,body); }

///|
test "single step UI persists before send and double clicks retain one identity" {
  let previous = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(previous)
  let selected = step_ui_model()
  let (_, pending) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Execute,
    selected,
  )
  let state = pending.moonflow_single_step.unwrap()
  assert_true(state.pending)
  assert_true(state.request_id != "")
  let saved = @json.parse(
    work_continuation_draft_read(
      moonflow_single_step_key(
        state.workspace_id,
        state.run_id,
        state.work_item_id,
      ),
    ),
  )
  assert_eq(handoff_text(saved, "request_id"), state.request_id)
  assert_eq(handoff_text(saved, "status"), "reconcile-required")
  let (_, repeated) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Execute,
    pending,
  )
  assert_eq(repeated.moonflow_single_step.unwrap().generation, state.generation)
  let payload = moonflow_single_step_payload(state, "execute")
  guard payload is Object(fields) else { fail("Expected fixed request") }
  assert_eq(fields.length(), 5)
  assert_false(payload.stringify().contains("executable"))
  assert_false(payload.stringify().contains("configuration"))
  assert_false(payload.stringify().contains("envelope"))
  let native_model = {
    ..selected,
    selected_workspace_id: @desk.stable_id("book", "single-step-book"),
    workspaces: [
      @desk.workspace(
        id=@desk.stable_id("book", "single-step-book"),
        name="Native fixture",
        root_path="/suite/books/single-step-book",
        kind=MoonBook,
      ),
    ],
    moonflow_runs: [
      { ..selected.moonflow_runs[0], book_id: "single-step-book", },
    ],
    moonflow_single_step: None,
  }
  let (_, native_selected) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Select("single-desk-ready", "selected"),
    native_model,
  )
  let (_, native_pending) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Execute,
    native_selected,
  )
  let native_request = moonflow_single_step_payload(
    native_pending.moonflow_single_step.unwrap(),
    "execute",
  )
  step_ui_write_fixture_request(native_request.stringify(indent=2))
  println("FLOW_STEP_UI_REQUEST:" + native_request.stringify())
}

///|
test "single step UI timeout reload and reconcile never generate another action" {
  let previous = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(previous)
  let (_, pending) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Execute,
    step_ui_model(),
  )
  let state = pending.moonflow_single_step.unwrap()
  let (_, timeout) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Timeout(
      state.workspace_id,
      state.run_id,
      state.work_item_id,
      state.request_id,
      state.generation,
    ),
    pending,
  )
  assert_false(timeout.moonflow_single_step.unwrap().pending)
  let (_, prevented) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Execute,
    timeout,
  )
  assert_eq(
    prevented.moonflow_single_step.unwrap().generation,
    state.generation,
  )
  let (_, reopened) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Select(state.run_id, state.work_item_id),
    { ..pending, moonflow_single_step: None, },
  )
  assert_eq(reopened.moonflow_single_step.unwrap().request_id, state.request_id)
  assert_eq(reopened.moonflow_single_step.unwrap().status, "reconcile-required")
  let (_, reconciling) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Reconcile,
    reopened,
  )
  assert_true(reconciling.moonflow_single_step.unwrap().pending)
  assert_eq(
    reconciling.moonflow_single_step.unwrap().request_id,
    state.request_id,
  )
  let (_, closed) = update_moonflow_single_step(
    code_mode_test_dispatch,
    step_ui_reply(reconciling, "not-applied"),
    reconciling,
  )
  let (_, refused) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Execute,
    closed,
  )
  assert_eq(refused.moonflow_single_step.unwrap().status, "not-applied")
  assert_false(refused.moonflow_single_step.unwrap().pending)
}

///|
test "single step UI ignores late Book item and older reconcile responses" {
  let previous = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(previous)
  let (_, pending) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Execute,
    step_ui_model(),
  )
  let reply = step_ui_reply(pending, "review")
  let (_, other_book) = update_moonflow_single_step(
    code_mode_test_dispatch,
    reply,
    { ..pending, selected_workspace_id: "book-other", },
  )
  assert_true(other_book.moonflow_single_step.unwrap().pending)
  let (_, other_item) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Select("single-desk-ready", "other"),
    pending,
  )
  let (_, ignored) = update_moonflow_single_step(
    code_mode_test_dispatch, reply, other_item,
  )
  assert_eq(ignored.moonflow_single_step.unwrap().work_item_id, "other")
  assert_eq(ignored.moonflow_single_step.unwrap().request_id, "")
  let (_, returned) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Select("single-desk-ready", "selected"),
    ignored,
  )
  assert_eq(returned.moonflow_single_step.unwrap().status, "reconcile-required")
  let (_, reconciling) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Reconcile,
    returned,
  )
  let (_, stale) = update_moonflow_single_step(
    code_mode_test_dispatch, reply, reconciling,
  )
  assert_true(stale.moonflow_single_step.unwrap().pending)
}

///|
test "single step UI restores server action and renders honest Review result" {
  let previous = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(previous)
  let base = step_ui_model()
  let run = {
    ..base.moonflow_runs[0],
    single_step_actions: Some([
      {
        work_item_id: "selected",
        request_id: "original-action",
        status: "reconcile-required",
        message: "Original attempt needs reconciliation",
      },
    ]),
  }
  let (_, restored) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Select(run.run_id, "selected"),
    { ..base, moonflow_runs: [run], moonflow_single_step: None, },
  )
  assert_eq(
    restored.moonflow_single_step.unwrap().request_id,
    "original-action",
  )
  let (_, pending) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Reconcile,
    restored,
  )
  let (_, reviewed) = update_moonflow_single_step(
    code_mode_test_dispatch,
    step_ui_reply(pending, "review"),
    pending,
  )
  let markup = render_test_dom(
    @rabbita.static_cell(
      render_moonflow_single_step(code_mode_test_dispatch, reviewed, run),
    ),
  )
  assert_true(markup.contains("Review required"))
  assert_true(markup.contains("fixture-reference-only"))
  assert_true(markup.contains("Production qualified: false"))
  assert_true(markup.contains("Physical authority: false"))
  assert_false(markup.contains("flow-single-step-execute"))
  assert_false(markup.contains("flow-single-step-reconcile"))
  assert_true(markup.contains("No reviewer or dependent item was dispatched"))
}

///|
test "single step UI wrong response identity cannot imply success" {
  let previous = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(previous)
  let (_, pending) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Execute,
    step_ui_model(),
  )
  let state = pending.moonflow_single_step.unwrap()
  let (_, unknown) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Reply(
      state.workspace_id,
      state.run_id,
      state.work_item_id,
      state.request_id,
      state.generation,
      Ok({ "status": "review", "request_id": "other" }),
    ),
    pending,
  )
  assert_eq(unknown.moonflow_single_step.unwrap().status, "reconcile-required")
}

///|
test "single step UI another tab preserves original action instead of creating one" {
  let previous = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(previous)
  let tab_a = step_ui_model()
  let tab_b = step_ui_model()
  let (_, pending) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Execute,
    tab_a,
  )
  let original = pending.moonflow_single_step.unwrap()
  let (_, other_tab) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Execute,
    tab_b,
  )
  let recovered = other_tab.moonflow_single_step.unwrap()
  assert_eq(recovered.request_id, original.request_id)
  assert_eq(recovered.status, "reconcile-required")
  assert_false(recovered.pending)
  assert_false(
    moonflow_single_step_save(
      { ..original, request_id: "different-action", },
      work_continuation_draft_read(
        moonflow_single_step_key(
          original.workspace_id,
          original.run_id,
          original.work_item_id,
        ),
      ),
    ),
  )
}

///|
extern "js" fn step_ui_disable_storage() =
  #| () => { globalThis.localStorage = {getItem:()=>null,setItem:()=>{throw new Error('unavailable')}}; }

///|
test "single step UI failed local identity save blocks execution and retains setup detail" {
  let previous = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(previous)
  let model = step_ui_model()
  step_ui_disable_storage()
  let (_, blocked) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Execute,
    model,
  )
  assert_false(blocked.moonflow_single_step.unwrap().pending)
  assert_eq(blocked.moonflow_single_step.unwrap().request_id, "")
  assert_true(
    blocked.moonflow_single_step.unwrap().message.contains(
      "no request was sent",
    ),
  )
  let markup = render_test_dom(
    @rabbita.static_cell(
      render_moonflow_single_step(
        code_mode_test_dispatch,
        blocked,
        blocked.moonflow_runs[0],
      ),
    ),
  )
  assert_true(markup.contains("host must configure"))
}

///|
test "single step server original action replaces stale local identity only for reconcile" {
  let previous = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(previous)
  let (_, losing) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Execute,
    step_ui_model(),
  )
  let run = {
    ..losing.moonflow_runs[0],
    single_step_actions: Some([
      {
        work_item_id: "selected",
        request_id: "server-original",
        status: "reconcile-required",
        message: "Original pending",
      },
    ]),
  }
  let (_, reopened) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Select(run.run_id, "selected"),
    { ..losing, moonflow_runs: [run], moonflow_single_step: None, },
  )
  assert_eq(
    reopened.moonflow_single_step.unwrap().request_id,
    "server-original",
  )
  let (_, reconciling) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Reconcile,
    reopened,
  )
  let state = reconciling.moonflow_single_step.unwrap()
  assert_true(state.pending)
  assert_eq(state.request_id, "server-original")
  assert_eq(
    handoff_text(
      @json.parse(
        work_continuation_draft_read(
          moonflow_single_step_key(
            state.workspace_id,
            state.run_id,
            state.work_item_id,
          ),
        ),
      ),
      "request_id",
    ),
    "server-original",
  )
}

///|
test "single step UI setup blocker retries same identity after correction" {
  let previous = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(previous)
  let (_, pending) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Execute,
    step_ui_model(),
  )
  let original = pending.moonflow_single_step.unwrap().request_id
  let (_, blocked) = update_moonflow_single_step(
    code_mode_test_dispatch,
    step_ui_reply(pending, "blocked"),
    pending,
  )
  let (_, retry) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Execute,
    blocked,
  )
  assert_true(retry.moonflow_single_step.unwrap().pending)
  assert_eq(retry.moonflow_single_step.unwrap().request_id, original)
}

///|
test "single step central Book departure clears pending view and safely restores original" {
  let previous = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(previous)
  let (_, pending) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Execute,
    step_ui_model(),
  )
  let state = pending.moonflow_single_step.unwrap()
  let departed = sync_workspace_editor_context({
    ..pending,
    selected_workspace_id: "book-other",
  })
  assert_true(departed.moonflow_single_step is None)
  let (_, late) = update_moonflow_single_step(
    code_mode_test_dispatch,
    step_ui_reply(pending, "review"),
    { ..departed, selected_workspace_id: state.workspace_id, },
  )
  assert_true(late.moonflow_single_step is None)
  let (_, reopened) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Select(state.run_id, state.work_item_id),
    late,
  )
  assert_eq(reopened.moonflow_single_step.unwrap().request_id, state.request_id)
  assert_eq(reopened.moonflow_single_step.unwrap().status, "reconcile-required")
  assert_false(reopened.moonflow_single_step.unwrap().pending)
}
