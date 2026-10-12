///|
fn retained_ui_model() -> Model {
  let base = moonflow_runs_test_model()
  let item = {
    ..flow_test_item("review"),
    work_item_id: "selected",
    product_id: "moonmold",
    operation: "moonmold/spatial.operation.execute@0.2.0",
    attempt_status: "succeeded",
    active_attempt_id: "attempt-1",
    result_id: "result-1",
    artifacts: ["retained/receipt.json", "retained/output.json"],
  }
  let run = {
    ..moonflow_runs_test_run("book-selected", "run-1"),
    items: [item],
    single_step_actions: Some([
      {
        work_item_id: "selected",
        request_id: "action-1",
        status: "review",
        message: "Review required",
      },
    ]),
  }
  { ..base, moonflow_runs: [run], }
}

///|
fn retained_ui_reply(state : MoonFlowRetainedState) -> Json {
  {
    "contract_id": "moondesk.flow-retained-result.v1",
    "status": "verified",
    "identity": state.identity,
    "reference": state.reference,
    "sha256": "sha256:" + "a".repeat(64),
    "record_digest": "sha256:" + "b".repeat(64),
    "byte_length": 90000,
    "identity_scope": "Flow-recorded artifact byte identity",
    "adapter_request_id": "adapter-request-1",
    "preview_kind": "text",
    "preview_text": "<script>alert('unsafe')</script> & 雪 " +
    "x".repeat(40000),
    "preview_truncated": true,
  }
}

///|
fn retained_ui_ready() -> Model {
  let (_, pending) = update_moonflow_retained(
    code_mode_test_dispatch,
    Inspect("run-1", "selected", 1),
    retained_ui_model(),
  )
  let state = pending.moonflow_retained.unwrap()
  update_moonflow_retained(
    code_mode_test_dispatch,
    Reply(state.generation, state.identity, Ok(retained_ui_reply(state))),
    pending,
  ).1
}

///|
test "retained UI binds all context and escapes bounded preview before exact download" {
  let ready = retained_ui_ready()
  let state = ready.moonflow_retained.unwrap()
  assert_true(state.response is Some(_))
  let url = moonflow_retained_url(state.identity)
  assert_eq(
    url, "/api/moonflow/retained/book-selected/run-1/selected/attempt-1/result-1/action-1/1",
  )
  assert_false(url.contains("retained/output.json"))
  let html = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_moonflow_retained(
        code_mode_test_dispatch,
        ready,
        ready.moonflow_runs[0],
      ),
    ),
  )
  assert_true(html.contains("Flow-recorded artifact byte identity"))
  assert_true(html.contains("&lt;script&gt;"))
  assert_false(html.contains("<script>"))
  assert_false(html.contains("x".repeat(33000)))
  assert_true(
    html.contains("preview truncated") || html.contains("Preview truncated"),
  )
  assert_true(
    html.contains(url + "/download/" + "a".repeat(64) + "-" + "b".repeat(64)),
  )
  assert_true(html.contains("download=\"\""))
  assert_true(html.contains("adapter-request-1"))
  assert_true(html.contains("Action: action-1"))
  assert_false(html.contains("contenteditable"))
  assert_false(html.contains("flow-single-step-execute"))
  assert_false(html.contains("flow-single-step-reconcile"))
}

///|
test "retained UI selection close reload Book switch refresh and late callbacks fail closed" {
  let (_, first) = update_moonflow_retained(
    code_mode_test_dispatch,
    Inspect("run-1", "selected", 0),
    retained_ui_model(),
  )
  let a = first.moonflow_retained.unwrap()
  let (_, second) = update_moonflow_retained(
    code_mode_test_dispatch,
    Inspect("run-1", "selected", 1),
    first,
  )
  let b = second.moonflow_retained.unwrap()
  let (_, stale) = update_moonflow_retained(
    code_mode_test_dispatch,
    Reply(a.generation, a.identity, Ok(retained_ui_reply(a))),
    second,
  )
  assert_eq(stale.moonflow_retained.unwrap().generation, b.generation)
  assert_true(stale.moonflow_retained.unwrap().response is None)
  let (_, closed) = update_moonflow_retained(
    code_mode_test_dispatch,
    Close,
    stale,
  )
  let (_, late) = update_moonflow_retained(
    code_mode_test_dispatch,
    Reply(b.generation, b.identity, Ok(retained_ui_reply(b))),
    closed,
  )
  assert_true(late.moonflow_retained is None)
  for
    model in [
      { ..second, selected_workspace_id: "book-other", },
      {
        ..second,
        moonflow_runs_generation: second.moonflow_runs_generation + 1,
      },
      { ..second, moonflow_runs: [], },
    ] {
    let rebound = sync_workspace_editor_context(model)
    assert_true(rebound.moonflow_retained is None)
    let (_, ignored) = update_moonflow_retained(
      code_mode_test_dispatch,
      Reply(b.generation, b.identity, Ok(retained_ui_reply(b))),
      rebound,
    )
    assert_true(ignored.moonflow_retained is None)
  }
  assert_true(init_model().moonflow_retained is None)
  let (_, reopened) = update_moonflow_retained(
    code_mode_test_dispatch,
    Inspect("run-1", "selected", 1),
    retained_ui_model(),
  )
  assert_true(reopened.moonflow_retained.unwrap().response is None)
  assert_not_eq(reopened.moonflow_retained.unwrap().generation, b.generation)
  let (_, item_selected) = update_moonflow_single_step(
    code_mode_test_dispatch,
    Select("run-1", "selected"),
    retained_ui_ready(),
  )
  assert_true(item_selected.moonflow_retained is None)
}

///|
test "retained UI rejects mismatched response and shows missing changed unsupported explicitly" {
  let (_, pending) = update_moonflow_retained(
    code_mode_test_dispatch,
    Inspect("run-1", "selected", 1),
    retained_ui_model(),
  )
  let state = pending.moonflow_retained.unwrap()
  for
    key in [
      "identity", "reference", "sha256", "record_digest", "identity_scope", "contract_id",
    ] {
    let response = retained_ui_reply(state)
    if response is Object(fields) {
      fields[key] = "wrong"
    }
    let (_, rejected) = update_moonflow_retained(
      code_mode_test_dispatch,
      Reply(state.generation, state.identity, Ok(response)),
      pending,
    )
    assert_true(rejected.moonflow_retained.unwrap().response is None)
  }
  for
    message in [
      "Retained bytes are missing", "Flow-recorded artifact byte identity changed",
      "Unsupported result protocol",
    ] {
    let response : Json = {
      "contract_id": "moondesk.flow-retained-result.v1",
      "status": "unavailable",
      "identity": state.identity,
      "message": message,
    }
    let (_, unavailable) = update_moonflow_retained(
      code_mode_test_dispatch,
      Reply(state.generation, state.identity, Ok(response)),
      pending,
    )
    let html = @rabbita.render_to_string(
      @rabbita.static_cell(
        render_moonflow_retained(
          code_mode_test_dispatch,
          unavailable,
          unavailable.moonflow_runs[0],
        ),
      ),
    )
    assert_true(html.contains(message))
    assert_false(html.contains("flow-retained-download"))
  }
  let run = pending.moonflow_runs[0]
  let unsupported = { ..run, single_step_actions: None, }
  let html = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_moonflow_retained_references(
        code_mode_test_dispatch,
        pending,
        unsupported,
        run.items[0],
      ),
    ),
  )
  assert_true(html.contains("Inspection unavailable"))
  assert_true(html.contains("disabled"))
}

///|
extern "js" fn retained_native_http_evidence() -> String =
  #| () => { const p=globalThis.process?.env?.MOONDESK_RETAINED_HTTP_EVIDENCE; return p?process.getBuiltinModule('fs').readFileSync(p,'utf8'):''; }

///|
test "retained compiled UI consumes actual native HTTP and preserves exact download identity" {
  let text = retained_native_http_evidence()
  if text == "" {
    println(
      "RETAINED_COMPILED_UI_NOT_CONFIGURED: native HTTP response not supplied",
    )
    return
  }
  let evidence = @json.parse(text)
  let run : MoonFlowRunProjection = @json.from_json(
    handoff_field(evidence, "projection"),
  )
  guard handoff_field(evidence, "observations") is Array(observations) else {
    fail("Native observations missing")
  }
  for index, observation in observations {
    let response = handoff_field(observation, "response")
    let identity = handoff_field(response, "identity")
    let workspace_id = handoff_text(identity, "workspace_id")
    let model = {
      ..init_model(),
      selected_workspace_id: workspace_id,
      workspaces: [
        @desk.workspace(
          id=workspace_id,
          name="Native fixture",
          root_path="/suite/books/single-step-book",
          kind=MoonBook,
        ),
      ],
      moonflow_runs: [run],
    }
    let (_, pending) = update_moonflow_retained(
      code_mode_test_dispatch,
      Inspect(run.run_id, "other", index),
      model,
    )
    let state = pending.moonflow_retained.unwrap()
    assert_eq(state.identity, identity)
    assert_eq(
      moonflow_retained_url(identity),
      handoff_text(observation, "inspection_url"),
    )
    let (_, ready) = update_moonflow_retained(
      code_mode_test_dispatch,
      Reply(state.generation, identity, Ok(response)),
      pending,
    )
    let html = @rabbita.render_to_string(
      @rabbita.static_cell(
        render_moonflow_retained(code_mode_test_dispatch, ready, run),
      ),
    )
    assert_true(html.contains(handoff_text(observation, "download_url")))
    assert_true(html.contains(handoff_text(response, "sha256")))
    assert_eq(
      handoff_field(observation, "download_bytes_equal"),
      true.to_json(),
    )
    if index == 1 {
      assert_true(html.contains("&lt;script&gt;"))
      assert_false(html.contains("<script>"))
      assert_true(html.contains("café 雪"))
      assert_true(html.contains("Flow-recorded artifact byte identity"))
    } else {
      assert_true(html.contains("Adapter receipt byte identity"))
    }
    assert_false(html.contains("flow-single-step-execute"))
    assert_false(html.contains("flow-single-step-reconcile"))
  }
  println(
    "RETAINED_COMPILED_UI: actual native HTTP receipt/artifact responses, click identity, escaped JSON/text, distinct byte identity labels, exact proven binary download routes; no edit/review/execute/reconcile",
  )
}
