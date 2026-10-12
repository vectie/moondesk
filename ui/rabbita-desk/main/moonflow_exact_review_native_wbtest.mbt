///|
extern "js" fn exact_review_fixture_input() -> String =
  #| () => { const p=globalThis.process?.env?.MOONDESK_REVIEW_FIXTURE_INPUT;return p?process.getBuiltinModule('fs').readFileSync(p,'utf8'):''; }

///|
extern "js" fn exact_review_http_evidence() -> String =
  #| () => { const p=globalThis.process?.env?.MOONDESK_REVIEW_EVIDENCE;return p&&process.getBuiltinModule('fs').existsSync(p)?process.getBuiltinModule('fs').readFileSync(p,'utf8'):''; }

///|
extern "js" fn exact_review_emit_request(value : String) -> Unit =
  #| value => { const p=globalThis.process?.env?.MOONDESK_REVIEW_UI_REQUEST;if(p)process.getBuiltinModule('fs').writeFileSync(p,value); }

///|
fn exact_review_native_model(projection : Json, retained : Json) -> Model raise {
  let run : MoonFlowRunProjection = @json.from_json(projection)
  let identity = handoff_field(retained, "identity")
  let book = handoff_text(identity, "workspace_id")
  {
    ..init_model(),
    selected_workspace_id: book,
    workspaces: [
      @desk.workspace(
        id=book,
        name="Synthetic review Book",
        root_path="/suite/books/single-step-book",
        kind=MoonBook,
      ),
    ],
    moonflow_runs: [run],
    moonflow_retained: Some({
      identity,
      reference: handoff_text(retained, "reference"),
      generation: moonflow_plan_next_generation(),
      runs_generation: init_model().moonflow_runs_generation,
      response: Some(retained),
      notice: "Verified exact retained artifact",
      review: None,
    }),
  }
}

///|
test "compiled review UI emits exact bounded HTTP decision from retained native fixture" {
  let input = exact_review_fixture_input()
  if input == "" {
    println("EXACT_REVIEW_UI_REQUEST_NOT_CONFIGURED")
    return
  }
  let previous = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(previous)
  let fixture = @json.parse(input)
  let retained = handoff_field(fixture, "retained")
  let model = exact_review_native_model(
    handoff_field(fixture, "projection"),
    retained,
  )
  let (_, loading) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Open,
    model,
  )
  let selected = loading.moonflow_retained.unwrap()
  let snapshot = handoff_field(fixture, "snapshot")
  let payload = handoff_field(snapshot, "payload")
  let reviews = match handoff_field(payload, "reviews") {
    Array(values) => values
    _ => []
  }
  let response : Json = {
    "contract_id": "moondesk.exact-result-review.v1",
    "status": "ready",
    "identity": selected.identity,
    "sha256": handoff_text(retained, "sha256"),
    "record_digest": handoff_text(retained, "record_digest"),
    "head_digest": handoff_text(payload, "head_digest"),
    "message": "Synthetic fixture",
    "reviews": reviews.map(review => {
      ({ "review": review, "authorized": true, "evidence": Json::null() } : Json)
    }),
  }
  let (_, ready) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Reply(
      selected.generation,
      selected.review.unwrap().generation,
      selected.identity,
      "",
      Ok(response),
    ),
    loading,
  )
  let (_, chosen) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Select("review-approved"),
    ready,
  )
  let (_, noted) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Notes(
      "Exact artifact inspected. <script> & café 雪 remain plain review notes.",
    ),
    chosen,
  )
  let (_, pending) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Submit("approved"),
    noted,
  )
  let request = pending.moonflow_retained.unwrap().review.unwrap().request.unwrap()
  assert_eq(handoff_field(request, "identity"), selected.identity)
  assert_eq(handoff_text(request, "sha256"), handoff_text(retained, "sha256"))
  exact_review_emit_request(request.stringify(indent=2))
  println("EXACT_REVIEW_UI_REQUEST_PASS")
}

///|
test "compiled review UI consumes actual HTTP persisted evidence after lost acknowledgment and reopen" {
  let text = exact_review_http_evidence()
  if text == "" {
    println("EXACT_REVIEW_UI_HTTP_NOT_CONFIGURED")
    return
  }
  let previous = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(previous)
  let evidence = @json.parse(text)
  let model = exact_review_native_model(
    handoff_field(evidence, "projection"),
    handoff_field(evidence, "retained"),
  )
  let (_, loading) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Open,
    model,
  )
  let retained = loading.moonflow_retained.unwrap()
  let request = handoff_field(evidence, "request")
  let review = {
    ..retained.review.unwrap(),
    request: Some(request),
    selected_review: "review-approved",
  }
  let pending = {
    ..loading,
    moonflow_retained: Some({ ..retained, review: Some(review), }),
  }
  let (_, lost) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Reply(
      retained.generation,
      review.generation,
      retained.identity,
      handoff_text(request, "mutation_id"),
      Err("Actual HTTP response discarded"),
    ),
    pending,
  )
  assert_eq(
    lost.moonflow_retained.unwrap().review.unwrap().request,
    Some(request),
  )
  let (_, reconciled) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Reply(
      retained.generation,
      review.generation,
      retained.identity,
      handoff_text(request, "mutation_id"),
      Ok(handoff_field(evidence, "replayed")),
    ),
    lost,
  )
  assert_true(
    reconciled.moonflow_retained.unwrap().review.unwrap().request is None,
  )
  let html = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_moonflow_exact_review(
        code_mode_test_dispatch,
        reconciled.moonflow_retained.unwrap(),
      ),
    ),
  )
  assert_true(html.contains("approved"))
  assert_true(html.contains("&lt;script&gt;"))
  assert_false(html.contains("<script>"))
  assert_true(html.contains("café 雪"))
  assert_true(html.contains("review-evidence/"))
  assert_true(
    html.contains("flow-review-approve\" disabled") || html.contains("disabled"),
  )
  let (_, reopened) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Open,
    reconciled,
  )
  let reopened_retained = reopened.moonflow_retained.unwrap()
  let (_, loaded) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Reply(
      reopened_retained.generation,
      reopened_retained.review.unwrap().generation,
      reopened_retained.identity,
      "",
      Ok(handoff_field(evidence, "reopened")),
    ),
    reopened,
  )
  let (_, changed) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Select("review-changes"),
    loaded,
  )
  let changes_html = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_moonflow_exact_review(
        code_mode_test_dispatch,
        changed.moonflow_retained.unwrap(),
      ),
    ),
  )
  assert_true(changes_html.contains("changes-requested"))
  assert_true(changes_html.contains("Needs another exact artifact revision"))
  let stale_request = handoff_field(evidence, "stale_request")
  assert_true(
    work_continuation_draft_write(
      moonflow_exact_review_key(retained),
      stale_request.stringify(),
    ),
  )
  let stale_model = {
    ..loading,
    moonflow_retained: Some({
      ..retained,
      review: Some({ ..review, request: Some(stale_request), pending: true, }),
    }),
  }
  let (_, retired) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Reply(
      retained.generation,
      review.generation,
      retained.identity,
      handoff_text(stale_request, "mutation_id"),
      Ok(handoff_field(evidence, "stale_rejection")),
    ),
    stale_model,
  )
  assert_true(
    retired.moonflow_retained.unwrap().review.unwrap().request is None,
  )
  assert_eq(
    work_continuation_draft_read(moonflow_exact_review_key(retained)),
    "missing",
  )
  println(
    "EXACT_REVIEW_UI_HTTP_PASS: actual persisted decisions/evidence through compiled UI; lost acknowledgment and reopen are exact and separate from acceptance/execution",
  )
}
