///|
struct MoonFlowExactReviewState {
  generation : Int32
  response : Json?
  selected_review : String
  notes : String
  request : Json?
  pending : Bool
  notice : String
}

///|
enum MoonFlowExactReviewMsg {
  Open
  Select(String)
  Notes(String)
  Submit(String)
  Retry
  Reply(Int32, Int32, Json, String, Result[Json, String])
  Timeout(Int32, Int32, Json)
}

///|
fn moonflow_exact_review_key(retained : MoonFlowRetainedState) -> String {
  "moondesk.exact-review.v1:" +
  retained.identity.stringify() +
  ":" +
  handoff_text(retained.response.unwrap_or(Json::null()), "sha256")
}

///|
fn moonflow_exact_review_matches(
  retained : MoonFlowRetainedState,
  response : Json,
) -> Bool {
  guard retained.response is Some(result) else { return false }
  handoff_text(response, "contract_id") == "moondesk.exact-result-review.v1" &&
  handoff_text(response, "status") == "ready" &&
  handoff_field(response, "identity") == retained.identity &&
  handoff_text(response, "sha256") == handoff_text(result, "sha256") &&
  handoff_text(response, "record_digest") ==
  handoff_text(result, "record_digest") &&
  moonflow_retained_digest_valid(handoff_text(response, "head_digest"))
}

///|
fn moonflow_exact_review_entries(response : Json) -> Array[Json] {
  match handoff_field(response, "reviews") {
    Array(values) => values
    _ => []
  }
}

///|
fn moonflow_exact_review_post(
  dispatch : Dispatch[Msg],
  retained : MoonFlowRetainedState,
  review : MoonFlowExactReviewState,
  request : Json,
) -> @rabbita.Cmd {
  @rabbita.batch([
    @http.post(@desk.desktop_api_url(["api", "moonflow", "review"]))
    .with_json(request)
    .expect_json(result => {
      dispatch(
        MoonFlowRetained(
          Review(
            Reply(
              retained.generation,
              review.generation,
              retained.identity,
              handoff_text(request, "mutation_id"),
              match result {
                Ok(value) => Ok(value)
                Err(error) => Err(error.to_string())
              },
            ),
          ),
        ),
      )
    }),
    @rabbita.delay(
      dispatch(
        MoonFlowRetained(
          Review(
            Timeout(retained.generation, review.generation, retained.identity),
          ),
        ),
      ),
      40000,
    ),
  ])
}

///|
fn update_moonflow_exact_review(
  dispatch : Dispatch[Msg],
  msg : MoonFlowExactReviewMsg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  guard model.moonflow_retained is Some(retained) &&
    retained.response is Some(result) &&
    moonflow_retained_current(model, retained) else {
    return (@rabbita.none, model)
  }
  if msg is Open {
    let saved = @json.parse(
      work_continuation_draft_read(moonflow_exact_review_key(retained)),
    ) catch {
      _ => Json::null()
    }
    let request = if handoff_field(saved, "identity") == retained.identity &&
      handoff_text(saved, "sha256") == handoff_text(result, "sha256") &&
      handoff_text(saved, "record_digest") ==
      handoff_text(result, "record_digest") &&
      handoff_text(saved, "mutation_id") != "" {
      Some(saved)
    } else {
      None
    }
    let review = MoonFlowExactReviewState::{
      generation: moonflow_plan_next_generation(),
      response: None,
      selected_review: retained.review
      .map(previous => previous.selected_review)
      .unwrap_or(""),
      notes: retained.review.map(previous => previous.notes).unwrap_or(""),
      request,
      pending: true,
      notice: "Loading the existing exact-byte collaboration review…",
    }
    return (
      @rabbita.batch([
        @http.get(moonflow_retained_url(retained.identity) + "/review").expect_json(response => {
            dispatch(
              MoonFlowRetained(
                Review(
                  Reply(
                    retained.generation,
                    review.generation,
                    retained.identity,
                    "",
                    match response {
                      Ok(value) => Ok(value)
                      Err(error) => Err(error.to_string())
                    },
                  ),
                ),
              ),
            )
          },
        ),
        @rabbita.delay(
          dispatch(
            MoonFlowRetained(
              Review(
                Timeout(
                  retained.generation,
                  review.generation,
                  retained.identity,
                ),
              ),
            ),
          ),
          40000,
        ),
      ]),
      {
        ..model,
        moonflow_retained: Some({ ..retained, review: Some(review), }),
      },
    )
  }
  guard retained.review is Some(review) else { return (@rabbita.none, model) }
  let (command, next) = match msg {
    Open => (@rabbita.none, review)
    Select(id) => {
      if review.pending || review.request is Some(_) {
        return (@rabbita.none, model)
      }
      (@rabbita.none, { ..review, selected_review: id, notes: "", })
    }
    Notes(notes) => {
      if review.pending || review.request is Some(_) {
        return (@rabbita.none, model)
      }
      (@rabbita.none, { ..review, notes: notes[:16384].to_owned(), })
    }
    Submit(action) => {
      guard !review.pending &&
        review.request is None &&
        review.response is Some(response) &&
        moonflow_exact_review_matches(retained, response) else {
        return (@rabbita.none, model)
      }
      let matches = moonflow_exact_review_entries(response).filter(entry => {
        handoff_text(handoff_field(entry, "review"), "review_id") ==
        review.selected_review
      })
      guard matches.length() == 1 &&
        handoff_field(matches[0], "authorized") == ToJson::to_json(true) else {
        return (@rabbita.none, model)
      }
      let state = handoff_text(handoff_field(matches[0], "review"), "state")
      guard (action == "begin" && state == "requested") ||
        (
          ["approved", "changes-requested"].contains(action) &&
          ["requested", "in-review"].contains(state) &&
          review.notes.trim() != ""
        ) else {
        return (@rabbita.none, model)
      }
      let request : Json = {
        "identity": retained.identity,
        "sha256": handoff_text(result, "sha256"),
        "record_digest": handoff_text(result, "record_digest"),
        "review_id": review.selected_review,
        "expected_head": handoff_text(response, "head_digest"),
        "mutation_id": work_continuation_nonce(),
        "action": action,
        "notes": if action == "begin" {
          ""
        } else {
          review.notes
        },
      }
      let stored = work_continuation_draft_read(
        moonflow_exact_review_key(retained),
      )
      guard stored == "missing" &&
        moonflow_plan_save_matching(
          moonflow_exact_review_key(retained),
          stored,
          request.stringify(),
        ) else {
        return (
          @rabbita.none,
          {
            ..model,
            moonflow_retained: Some({
              ..retained,
              review: Some({
                ..review,
                notice: "Could not retain this mutation safely. Reopen the review to reconcile any original request.",
              }),
            }),
          },
        )
      }
      let next = {
        ..review,
        request: Some(request),
        pending: true,
        generation: moonflow_plan_next_generation(),
        notice: "Submitting this exact collaboration decision…",
      }
      (moonflow_exact_review_post(dispatch, retained, next, request), next)
    }
    Retry => {
      guard !review.pending && review.request is Some(request) else {
        return (@rabbita.none, model)
      }
      let next = {
        ..review,
        pending: true,
        generation: moonflow_plan_next_generation(),
        notice: "Reconciling the original immutable mutation…",
      }
      (moonflow_exact_review_post(dispatch, retained, next, request), next)
    }
    Reply(retained_generation, generation, identity, mutation_id, response) => {
      guard retained.generation == retained_generation &&
        review.generation == generation &&
        retained.identity == identity else {
        return (@rabbita.none, model)
      }
      let value = match response {
        Ok(value) => value
        Err(_) => Json::null()
      }
      let matched = moonflow_exact_review_matches(retained, value)
      if mutation_id != "" &&
        review.request.map(request => handoff_text(request, "mutation_id")) !=
        Some(mutation_id) {
        return (@rabbita.none, model)
      }
      let rejected = handoff_text(value, "contract_id") ==
        "moondesk.exact-result-review.v1" &&
        handoff_text(value, "status") == "rejected" &&
        handoff_text(value, "mutation_status") == "not-applied" &&
        handoff_text(value, "rejection_reason") == "stale-head" &&
        handoff_field(value, "identity") == retained.identity &&
        mutation_id != "" &&
        handoff_text(value, "mutation_id") == mutation_id &&
        review.request == Some(handoff_field(value, "rejected_request")) &&
        moonflow_retained_digest_valid(handoff_text(value, "observed_head")) &&
        handoff_text(value, "observed_head") !=
        handoff_text(handoff_field(value, "rejected_request"), "expected_head")
      let confirmed = matched &&
        mutation_id != "" &&
        handoff_text(value, "mutation_id") == mutation_id &&
        ["persisted", "reconciled"].contains(
          handoff_text(value, "mutation_status"),
        )
      if (confirmed || rejected) && review.request is Some(request) {
        ignore(
          work_continuation_draft_remove_matching(
            moonflow_exact_review_key(retained),
            request.stringify(),
          ),
        )
      }
      let entries = moonflow_exact_review_entries(value)
      let selected = if review.selected_review != "" {
        review.selected_review
      } else if entries.length() == 1 {
        handoff_text(handoff_field(entries[0], "review"), "review_id")
      } else {
        ""
      }
      (
        @rabbita.none,
        {
          ..review,
          generation: if rejected {
            moonflow_plan_next_generation()
          } else {
            review.generation
          },
          pending: false,
          response: if matched {
            Some(value)
          } else {
            None
          },
          selected_review: selected,
          request: if confirmed || rejected {
            None
          } else {
            review.request
          },
          notice: if matched {
            handoff_text(value, "message")
          } else if handoff_text(value, "message") != "" {
            handoff_text(value, "message")
          } else {
            "Review response unavailable. Reopen or retry the original mutation; no new decision was inferred."
          },
        },
      )
    }
    Timeout(retained_generation, generation, identity) => {
      guard retained.generation == retained_generation &&
        review.generation == generation &&
        retained.identity == identity &&
        review.pending else {
        return (@rabbita.none, model)
      }
      (
        @rabbita.none,
        {
          ..review,
          pending: false,
          generation: moonflow_plan_next_generation(),
          notice: if review.request is Some(_) {
            "Response timed out. Retry the original mutation to reconcile its persisted outcome."
          } else {
            "Review inspection timed out. Reopen to load the current persisted review."
          },
        },
      )
    }
  }
  (
    command,
    { ..model, moonflow_retained: Some({ ..retained, review: Some(next), }), },
  )
}

///|
fn render_moonflow_exact_review(
  dispatch : Dispatch[Msg],
  retained : MoonFlowRetainedState,
) -> @rabbita.Html {
  guard retained.review is Some(state) else {
    return button(
      class="secondary-button",
      attrs=@html.Attrs::build().data_set("testid", "flow-exact-review-open"),
      on_click=dispatch(MoonFlowRetained(Review(Open))),
      "Open existing exact-result review",
    )
  }
  let entries = moonflow_exact_review_entries(
    state.response.unwrap_or(Json::null()),
  )
  let selected = entries
    .filter(entry => {
      handoff_text(handoff_field(entry, "review"), "review_id") ==
      state.selected_review
    })
    .get(0)
    .unwrap_or(Json::null())
  let review = handoff_field(selected, "review")
  let review_state = handoff_text(review, "state")
  let can_decide = !state.pending &&
    state.request is None &&
    handoff_field(selected, "authorized") == ToJson::to_json(true) &&
    ["requested", "in-review"].contains(review_state)
  section(attrs=@html.Attrs::build().data_set("testid", "flow-exact-review"), [
    h3("Existing collaboration review"),
    p(state.notice),
    p(
      "Bound to this selected artifact byte SHA-256. Approval records a collaboration decision only. It does not accept the Flow item, approve customer delivery, or run dependent work.",
    ),
    div(
      entries.map(entry => {
        let item = handoff_field(entry, "review")
        button(
          class="secondary-button",
          disabled=state.pending || state.request is Some(_),
          on_click=dispatch(
            MoonFlowRetained(Review(Select(handoff_text(item, "review_id")))),
          ),
          handoff_text(item, "review_id") + " · " + handoff_text(item, "state"),
        )
      }),
    ),
    p("Selected review: " + state.selected_review + " · " + review_state),
    p(
      "Assigned human reviewer: " +
      handoff_text(handoff_field(review, "assigned_reviewer"), "principal_id"),
    ),
    code(handoff_text(review, "subject_digest")),
    button(
      disabled=!can_decide || review_state != "requested",
      attrs=@html.Attrs::build().data_set("testid", "flow-review-begin"),
      on_click=dispatch(MoonFlowRetained(Review(Submit("begin")))),
      "Begin review",
    ),
    textarea(
      value=state.notes,
      rows=4,
      disabled=!can_decide,
      attrs=@html.Attrs::build().aria_label("Immutable review decision notes"),
      on_input=text => dispatch(MoonFlowRetained(Review(Notes(text)))),
      "",
    ),
    button(
      disabled=!can_decide || state.notes.trim() == "",
      attrs=@html.Attrs::build().data_set("testid", "flow-review-approve"),
      on_click=dispatch(MoonFlowRetained(Review(Submit("approved")))),
      "Approved",
    ),
    button(
      disabled=!can_decide || state.notes.trim() == "",
      attrs=@html.Attrs::build().data_set("testid", "flow-review-changes"),
      on_click=dispatch(MoonFlowRetained(Review(Submit("changes-requested")))),
      "Changes requested",
    ),
    if state.request is Some(_) {
      button(
        disabled=state.pending,
        on_click=dispatch(MoonFlowRetained(Review(Retry))),
        "Retry original mutation",
      )
    } else {
      @html.nothing
    },
    button(
      class="secondary-button",
      disabled=state.pending,
      on_click=dispatch(MoonFlowRetained(Review(Open))),
      "Reopen persisted review",
    ),
    p(
      "Immutable decision evidence: " +
      handoff_text(review, "decision_evidence_ref"),
    ),
    code(handoff_text(review, "decision_evidence_digest")),
    pre(
      attrs=@html.Attrs::build().data_set(
        "testid", "flow-review-evidence-notes",
      ),
      handoff_text(handoff_field(selected, "evidence"), "notes"),
    ),
    p(handoff_text(handoff_field(selected, "evidence"), "message")),
  ])
}
