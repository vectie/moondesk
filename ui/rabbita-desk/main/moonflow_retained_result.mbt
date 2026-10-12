///|
struct MoonFlowRetainedState {
  identity : Json
  reference : String
  generation : Int
  runs_generation : Int
  response : Json?
  notice : String
  review : MoonFlowExactReviewState?
}

///|
enum MoonFlowRetainedMsg {
  Inspect(String, String, Int)
  Reply(Int, Json, Result[Json, String])
  Close
  Review(MoonFlowExactReviewMsg)
}

///|
fn moonflow_retained_identity(
  model : Model,
  run : MoonFlowRunProjection,
  item : MoonFlowItemProjection,
  index : Int,
) -> Json? {
  let actions = run.single_step_actions
    .unwrap_or([])
    .filter(action => action.work_item_id == item.work_item_id)
  guard actions.length() == 1 &&
    actions[0].status == "review" &&
    item.product_id == "moonmold" &&
    item.operation == "moonmold/spatial.operation.execute@0.2.0" &&
    item.attempt_status == "succeeded" &&
    item.active_attempt_id != "" &&
    item.result_id != "" &&
    index >= 0 &&
    index < item.artifacts.length() else {
    return None
  }
  Some({
    "workspace_id": model.selected_workspace_id,
    "run_id": run.run_id,
    "work_item_id": item.work_item_id,
    "attempt_id": item.active_attempt_id,
    "result_id": item.result_id,
    "action_id": actions[0].request_id,
    "artifact_index": index,
  })
}

///|
fn moonflow_retained_url(identity : Json) -> String {
  @desk.desktop_api_url([
    "api",
    "moonflow",
    "retained",
    handoff_text(identity, "workspace_id"),
    handoff_text(identity, "run_id"),
    handoff_text(identity, "work_item_id"),
    handoff_text(identity, "attempt_id"),
    handoff_text(identity, "result_id"),
    handoff_text(identity, "action_id"),
    handoff_field(identity, "artifact_index").stringify(),
  ])
}

///|
fn moonflow_retained_current(
  model : Model,
  state : MoonFlowRetainedState,
) -> Bool {
  guard handoff_text(state.identity, "workspace_id") ==
    model.selected_workspace_id &&
    state.runs_generation == model.moonflow_runs_generation else {
    return false
  }
  guard moonflow_selected_runs(model)
    .filter(run => run.run_id == handoff_text(state.identity, "run_id"))
    .get(0)
    is Some(run) &&
    moonflow_item_by_id(run, handoff_text(state.identity, "work_item_id"))
    is Some(item) else {
    return false
  }
  let index = match handoff_field(state.identity, "artifact_index") {
    Number(n) => n.to_int()
    _ => -1
  }
  moonflow_retained_identity(model, run, item, index) == Some(state.identity) &&
  item.artifacts.get(index) == Some(state.reference)
}

///|
fn update_moonflow_retained(
  dispatch : Dispatch[Msg],
  msg : MoonFlowRetainedMsg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    Review(action) => update_moonflow_exact_review(dispatch, action, model)
    Close => (@rabbita.none, { ..model, moonflow_retained: None, })
    Inspect(run_id, item_id, index) => {
      guard moonflow_selected_runs(model)
        .filter(run => run.run_id == run_id)
        .get(0)
        is Some(run) &&
        moonflow_item_by_id(run, item_id) is Some(item) &&
        moonflow_retained_identity(model, run, item, index) is Some(identity) else {
        return (@rabbita.none, { ..model, moonflow_retained: None, })
      }
      let state = MoonFlowRetainedState::{
        identity,
        reference: item.artifacts[index],
        generation: moonflow_plan_next_generation(),
        runs_generation: model.moonflow_runs_generation,
        response: None,
        notice: "Checking the retained result records and exact bytes…",
        review: None,
      }
      (
        @http.get(moonflow_retained_url(identity)).expect_json(result => {
          dispatch(
            MoonFlowRetained(
              Reply(
                state.generation,
                identity,
                match result {
                  Ok(value) => Ok(value)
                  Err(error) => Err(error.to_string())
                },
              ),
            ),
          )
        }),
        { ..model, moonflow_retained: Some(state), },
      )
    }
    Reply(generation, identity, response) => {
      guard model.moonflow_retained is Some(state) &&
        state.generation == generation &&
        state.identity == identity &&
        moonflow_retained_current(model, state) else {
        return (@rabbita.none, model)
      }
      let value = match response {
        Ok(value) => value
        Err(_) => Json::null()
      }
      let correlated = handoff_text(value, "contract_id") ==
        "moondesk.flow-retained-result.v1" &&
        handoff_field(value, "identity") == identity
      let verified = correlated &&
        handoff_text(value, "status") == "verified" &&
        handoff_text(value, "reference") == state.reference &&
        moonflow_retained_digest_valid(handoff_text(value, "sha256")) &&
        moonflow_retained_digest_valid(handoff_text(value, "record_digest")) &&
        [
          "Adapter receipt byte identity", "Flow-recorded artifact byte identity",
        ].contains(handoff_text(value, "identity_scope"))
      (
        @rabbita.none,
        {
          ..model,
          moonflow_retained: Some({
            ..state,
            response: if verified {
              Some(value)
            } else {
              None
            },
            notice: if verified {
              "Exact retained bytes verified"
            } else if correlated && handoff_text(value, "message") != "" {
              handoff_text(value, "message")
            } else {
              "Retained result unavailable or response identity changed. Reopen this reference to check again."
            },
          }),
        },
      )
    }
  }
}

///|
fn moonflow_retained_digest_valid(digest : String) -> Bool {
  digest.length() == 71 &&
  digest.has_prefix("sha256:") &&
  digest[7:]
  .to_owned()
  .all(char => char.is_ascii_digit() || (char >= 'a' && char <= 'f'))
}

///|
fn render_moonflow_retained_references(
  dispatch : Dispatch[Msg],
  model : Model,
  run : MoonFlowRunProjection,
  item : MoonFlowItemProjection,
) -> @rabbita.Html {
  div(
    item.artifacts.mapi((index, reference) => {
      let available = moonflow_retained_identity(model, run, item, index)
        is Some(_)
      div([
        button(
          class="secondary-button",
          disabled=!available,
          attrs=@html.Attrs::build().data_set(
            "testid",
            "flow-retained-open-" + item.work_item_id + "-" + index.to_string(),
          ),
          on_click=dispatch(
            MoonFlowRetained(Inspect(run.run_id, item.work_item_id, index)),
          ),
          "Artifact: " + reference,
        ),
        if available {
          @html.nothing
        } else {
          small(
            "Inspection unavailable: this reference has no matching supported single-step result",
          )
        },
      ])
    }),
  )
}

///|
fn render_moonflow_retained(
  dispatch : Dispatch[Msg],
  model : Model,
  run : MoonFlowRunProjection,
) -> @rabbita.Html {
  guard model.moonflow_retained is Some(state) &&
    moonflow_retained_current(model, state) &&
    handoff_text(state.identity, "run_id") == run.run_id else {
    return @html.nothing
  }
  section(
    class="flow-handoff-card",
    attrs=@html.Attrs::build().data_set("testid", "flow-retained-inspection"),
    [
      h3("Inspect retained result"),
      p(state.notice),
      p(
        "Book: " +
        handoff_text(state.identity, "workspace_id") +
        " · Run: " +
        run.run_id +
        " · Item: " +
        handoff_text(state.identity, "work_item_id"),
      ),
      p(
        "Attempt: " +
        handoff_text(state.identity, "attempt_id") +
        " · Result: " +
        handoff_text(state.identity, "result_id"),
      ),
      p("Action: " + handoff_text(state.identity, "action_id")),
      code(state.reference),
      match state.response {
        None => @html.nothing
        Some(response) =>
          div([
            p(
              "Adapter request: " + handoff_text(response, "adapter_request_id"),
            ),
            strong(handoff_text(response, "identity_scope")),
            p(
              handoff_text(response, "sha256") +
              " · " +
              handoff_field(response, "byte_length").stringify() +
              " bytes",
            ),
            p(
              "Fixture-reference-only. Production qualified: false. Physical authority: false. Inspection does not accept or review this result.",
            ),
            p(
              "The adapter output digest binds receipt bytes only. Other output bytes are checked against Flow’s recorded per-file observations. Embedded Mold JSON digests describe semantic content, not file-byte identity.",
            ),
            pre(
              attrs=@html.Attrs::build().data_set(
                "testid", "flow-retained-preview",
              ),
              handoff_text(response, "preview_text")[:32768].to_owned(),
            ),
            if handoff_field(response, "preview_truncated") == true.to_json() {
              p(
                "Preview truncated at 32 Ki UTF-16 code units. Download contains the complete exact bytes.",
              )
            } else {
              @html.nothing
            },
            a(
              href=moonflow_retained_url(state.identity) +
                "/download/" +
                handoff_text(response, "sha256")[7:].to_owned() +
                "-" +
                handoff_text(response, "record_digest")[7:].to_owned(),
              download="",
              attrs=@html.Attrs::build().data_set(
                "testid", "flow-retained-download",
              ),
              "Download exact retained bytes",
            ),
            small(
              "Download rechecks all retained records and file identities. Changed or missing evidence is refused.",
            ),
            render_moonflow_exact_review(dispatch, state),
          ])
      },
      button(
        class="secondary-button",
        on_click=dispatch(MoonFlowRetained(Close)),
        "Close inspection",
      ),
    ],
  )
}
