///|
fn exact_review_ui_response(
  retained : MoonFlowRetainedState,
  state~ : String = "requested",
  authorized~ : Bool = true,
) -> Json {
  let result = retained.response.unwrap()
  {
    "contract_id": "moondesk.exact-result-review.v1",
    "status": "ready",
    "identity": retained.identity,
    "sha256": handoff_text(result, "sha256"),
    "record_digest": handoff_text(result, "record_digest"),
    "head_digest": "sha256:" + "c".repeat(64),
    "message": "Existing collaboration review only",
    "reviews": [
      {
        "authorized": authorized,
        "review": {
          "review_id": "review-1",
          "state": state,
          "subject_digest": handoff_text(result, "sha256"),
          "assigned_reviewer": { "principal_id": "assigned-human" },
        },
        "evidence": null,
      },
    ],
  }
}

///|
fn exact_review_ui_ready() -> Model {
  let (_, loading) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Open,
    retained_ui_ready(),
  )
  let retained = loading.moonflow_retained.unwrap()
  let review = retained.review.unwrap()
  update_moonflow_exact_review(
    code_mode_test_dispatch,
    Reply(
      retained.generation,
      review.generation,
      retained.identity,
      "",
      Ok(exact_review_ui_response(retained)),
    ),
    loading,
  ).1
}

///|
test "confirmed exact stale-head rejection retires only original request then safely reopens with new head" {
  let previous = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(previous)
  let (_, noted) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Notes("Keep these review notes"),
    exact_review_ui_ready(),
  )
  let (_, pending) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Submit("approved"),
    noted,
  )
  let retained = pending.moonflow_retained.unwrap()
  let state = retained.review.unwrap()
  let request = state.request.unwrap()
  let rejection : Json = {
    "contract_id": "moondesk.exact-result-review.v1",
    "status": "rejected",
    "mutation_status": "not-applied",
    "rejection_reason": "stale-head",
    "identity": retained.identity,
    "mutation_id": handoff_text(request, "mutation_id"),
    "observed_head": "sha256:" + "d".repeat(64),
    "rejected_request": request,
    "message": "Stale head; reopen the review",
  }
  let mismatched = @json.parse(rejection.stringify())
  if mismatched is Object(fields) {
    fields["rejected_request"] = Json::null()
  }
  let (_, not_retired) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Reply(
      retained.generation,
      state.generation,
      retained.identity,
      handoff_text(request, "mutation_id"),
      Ok(mismatched),
    ),
    pending,
  )
  assert_eq(
    not_retired.moonflow_retained.unwrap().review.unwrap().request,
    Some(request),
  )
  let (_, rejected) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Reply(
      retained.generation,
      state.generation,
      retained.identity,
      handoff_text(request, "mutation_id"),
      Ok(rejection),
    ),
    not_retired,
  )
  assert_true(
    rejected.moonflow_retained.unwrap().review.unwrap().request is None,
  )
  assert_eq(
    work_continuation_draft_read(moonflow_exact_review_key(retained)),
    "missing",
  )
  let (_, reopened) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Open,
    rejected,
  )
  let current = reopened.moonflow_retained.unwrap()
  let response = @json.parse(exact_review_ui_response(current).stringify())
  if response is Object(fields) {
    fields["head_digest"] = ("sha256:" + "d".repeat(64)).to_json()
  }
  let (_, ready) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Reply(
      current.generation,
      current.review.unwrap().generation,
      current.identity,
      "",
      Ok(response),
    ),
    reopened,
  )
  assert_eq(
    ready.moonflow_retained.unwrap().review.unwrap().notes,
    "Keep these review notes",
  )
  let (_, new_pending) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Submit("approved"),
    ready,
  )
  let next = new_pending.moonflow_retained.unwrap().review.unwrap().request.unwrap()
  assert_not_eq(
    handoff_text(next, "mutation_id"),
    handoff_text(request, "mutation_id"),
  )
  assert_eq(handoff_text(next, "expected_head"), "sha256:" + "d".repeat(64))
}

///|
test "stalled review inspection can reopen and ignores old GET callback" {
  let previous = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(previous)
  let (_, loading) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Open,
    retained_ui_ready(),
  )
  let retained = loading.moonflow_retained.unwrap()
  let generation = retained.review.unwrap().generation
  let (_, timed) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Timeout(retained.generation, generation, retained.identity),
    loading,
  )
  assert_false(timed.moonflow_retained.unwrap().review.unwrap().pending)
  let (_, late) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Reply(
      retained.generation,
      generation,
      retained.identity,
      "",
      Ok(exact_review_ui_response(retained)),
    ),
    timed,
  )
  assert_true(late.moonflow_retained.unwrap().review.unwrap().response is None)
  let (_, again) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Open,
    late,
  )
  assert_true(again.moonflow_retained.unwrap().review.unwrap().pending)
  assert_not_eq(
    again.moonflow_retained.unwrap().review.unwrap().generation,
    generation,
  )
}

///|
test "exact review UI retains original mutation through lost acknowledgment and ignores later selection callbacks" {
  let previous = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(previous)
  let ready = exact_review_ui_ready()
  assert_eq(
    ready.moonflow_retained.unwrap().review.unwrap().selected_review,
    "review-1",
  )
  let (_, noted) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Notes("Checked <script> & café 雪"),
    ready,
  )
  let (_, pending) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Submit("approved"),
    noted,
  )
  let retained = pending.moonflow_retained.unwrap()
  let review = retained.review.unwrap()
  assert_true(review.pending)
  let request = review.request.unwrap()
  assert_false(request.stringify().contains("\"actor\""))
  assert_false(request.stringify().contains("recorded_at"))
  let (_, duplicate) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Submit("changes-requested"),
    pending,
  )
  assert_eq(
    duplicate.moonflow_retained.unwrap().review.unwrap().request,
    Some(request),
  )
  let (_, lost) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Reply(
      retained.generation,
      review.generation,
      retained.identity,
      handoff_text(request, "mutation_id"),
      Err("lost acknowledgment"),
    ),
    duplicate,
  )
  assert_false(lost.moonflow_retained.unwrap().review.unwrap().pending)
  let (_, retry) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Retry,
    lost,
  )
  assert_eq(
    retry.moonflow_retained.unwrap().review.unwrap().request,
    Some(request),
  )
  let (_, timed) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Timeout(
      retained.generation,
      retry.moonflow_retained.unwrap().review.unwrap().generation,
      retained.identity,
    ),
    retry,
  )
  let (_, late) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Reply(
      retained.generation,
      review.generation,
      retained.identity,
      handoff_text(request, "mutation_id"),
      Ok(exact_review_ui_response(retained, state="approved")),
    ),
    timed,
  )
  assert_eq(
    late.moonflow_retained.unwrap().review.unwrap().request,
    Some(request),
  )
  let (_, closed) = update_moonflow_retained(
    code_mode_test_dispatch,
    Close,
    late,
  )
  let (_, ignored) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Reply(
      retained.generation,
      review.generation,
      retained.identity,
      handoff_text(request, "mutation_id"),
      Ok(exact_review_ui_response(retained)),
    ),
    closed,
  )
  assert_true(ignored.moonflow_retained is None)
  let reopened = exact_review_ui_ready()
  assert_eq(
    reopened.moonflow_retained.unwrap().review.unwrap().request,
    Some(request),
  )
}

///|
test "exact review UI disables unmapped humans and binds head bytes subject and immutable notes" {
  let previous = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(previous)
  let ready = exact_review_ui_ready()
  let retained = ready.moonflow_retained.unwrap()
  let state = retained.review.unwrap()
  let denied = {
    ..ready,
    moonflow_retained: Some({
      ..retained,
      review: Some({
        ..state,
        response: Some(exact_review_ui_response(retained, authorized=false)),
      }),
    }),
  }
  let (_, unchanged) = update_moonflow_exact_review(
    code_mode_test_dispatch,
    Submit("begin"),
    denied,
  )
  assert_true(
    unchanged.moonflow_retained.unwrap().review.unwrap().request is None,
  )
  let html = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_moonflow_exact_review(code_mode_test_dispatch, retained),
    ),
  )
  assert_true(html.contains("Begin review"))
  assert_true(html.contains("Changes requested"))
  assert_true(html.contains("customer delivery"))
  let changed = @json.parse(exact_review_ui_response(retained).stringify())
  if changed is Object(fields) {
    fields["record_digest"] = ("sha256:" + "d".repeat(64)).to_json()
  }
  assert_false(moonflow_exact_review_matches(retained, changed))
}
