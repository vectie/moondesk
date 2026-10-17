///|
struct MoonFlowSingleStepAction {
  work_item_id : String
  request_id : String
  status : String
  message : String
} derive(FromJson)

///|
struct MoonFlowSingleStepState {
  workspace_id : String
  run_id : String
  work_item_id : String
  request_id : String
  status : String
  message : String
  generation : Int32
  pending : Bool
  result : Json?
}

///|
enum MoonFlowSingleStepMsg {
  Select(String, String)
  Execute
  Reconcile
  Reply(String, String, String, String, Int32, Result[Json, String])
  Timeout(String, String, String, String, Int32)
}

///|
fn moonflow_single_step_key(
  book : String,
  run : String,
  item : String,
) -> String {
  "moondesk.single-step.v1:" + [book, run, item].to_json().stringify()
}

///|
fn moonflow_single_step_stored(state : MoonFlowSingleStepState) -> String {
  (
    {
      "request_id": state.request_id,
      "status": if state.pending {
        "reconcile-required"
      } else {
        state.status
      },
      "message": if state.pending {
        "The original action may have run. Reconcile this same attempt before continuing."
      } else {
        state.message
      },
    } : Json).stringify()
}

///|
fn moonflow_single_step_save(
  state : MoonFlowSingleStepState,
  expected : String,
) -> Bool {
  let existing = @json.parse(expected) catch { _ => Json::null() }
  let original = handoff_text(existing, "request_id")
  if original != "" && original != state.request_id {
    return false
  }
  moonflow_plan_save_matching(
    moonflow_single_step_key(
      state.workspace_id,
      state.run_id,
      state.work_item_id,
    ),
    expected,
    moonflow_single_step_stored(state),
  )
}

///|
fn moonflow_single_step_state(
  model : Model,
  run : MoonFlowRunProjection,
  item : String,
) -> MoonFlowSingleStepState {
  if model.moonflow_single_step is Some(state) &&
    state.workspace_id == model.selected_workspace_id &&
    state.run_id == run.run_id &&
    state.work_item_id == item &&
    state.pending {
    return state
  }
  let saved = @json.parse(
    work_continuation_draft_read(
      moonflow_single_step_key(model.selected_workspace_id, run.run_id, item),
    ),
  ) catch {
    _ => Json::null()
  }
  let server = run.single_step_actions
    .unwrap_or([])
    .filter(action => action.work_item_id == item)
    .get(0)
  {
    workspace_id: model.selected_workspace_id,
    run_id: run.run_id,
    work_item_id: item,
    request_id: match server {
      Some(action) => action.request_id
      None => handoff_text(saved, "request_id")
    },
    status: match server {
      Some(action) => action.status
      None => handoff_text(saved, "status")
    },
    message: match server {
      Some(action) => action.message
      None => handoff_text(saved, "message")
    },
    generation: moonflow_plan_next_generation(),
    pending: false,
    result: None,
  }
}

///|
fn moonflow_single_step_eligible(
  run : MoonFlowRunProjection,
  item : MoonFlowItemProjection,
) -> Bool {
  run.runnable_item_ids.contains(item.work_item_id) &&
  item.status == "ready" &&
  item.adapter_id == Some("moonmold-pack-local-v1") &&
  item.operation == "moonmold/spatial.operation.execute@0.2.0" &&
  item.requested_authority == "workspace-mutation" &&
  item.required_claim == "digital-artifact"
}

///|
fn moonflow_single_step_payload(
  state : MoonFlowSingleStepState,
  action : String,
) -> Json {
  {
    "workspace_id": state.workspace_id,
    "run_id": state.run_id,
    "work_item_id": state.work_item_id,
    "request_id": state.request_id,
    "action": action,
  }
}

///|
fn moonflow_single_step_post(
  dispatch : Dispatch[Msg],
  state : MoonFlowSingleStepState,
  action : String,
) -> @rabbita.Cmd {
  @rabbita.batch([
    @http.post(@desk.desktop_api_url(["api", "moonflow", "single-step"]))
    .with_json(moonflow_single_step_payload(state, action))
    .expect_json(result => {
      dispatch(
        MoonFlowSingleStep(
          Reply(
            state.workspace_id,
            state.run_id,
            state.work_item_id,
            state.request_id,
            state.generation,
            match result {
              Ok(value) => Ok(value)
              Err(error) => Err(error.to_string())
            },
          ),
        ),
      )
    }),
    @rabbita.delay(
      dispatch(
        MoonFlowSingleStep(
          Timeout(
            state.workspace_id,
            state.run_id,
            state.work_item_id,
            state.request_id,
            state.generation,
          ),
        ),
      ),
      125000,
    ),
  ])
}

///|
fn moonflow_single_step_identity(
  state : MoonFlowSingleStepState,
  book : String,
  run : String,
  item : String,
  request : String,
  generation : Int32,
) -> Bool {
  state.workspace_id == book &&
  state.run_id == run &&
  state.work_item_id == item &&
  state.request_id == request &&
  state.generation == generation
}

///|
fn update_moonflow_single_step(
  dispatch : Dispatch[Msg],
  msg : MoonFlowSingleStepMsg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  if msg is Select(run_id, item_id) {
    guard moonflow_selected_runs(model)
      .filter(run => run.run_id == run_id)
      .get(0)
      is Some(run) &&
      run.items.any(item => item.work_item_id == item_id) else {
      return (@rabbita.none, model)
    }
    let state = moonflow_single_step_state(model, run, item_id)
    return (
      @rabbita.none,
      { ..model, moonflow_single_step: Some(state), moonflow_retained: None, },
    )
  }
  guard model.moonflow_single_step is Some(state) &&
    state.workspace_id == model.selected_workspace_id &&
    moonflow_selected_runs(model)
    .filter(run => run.run_id == state.run_id)
    .get(0)
    is Some(run) else {
    return (@rabbita.none, model)
  }
  let key = moonflow_single_step_key(
    state.workspace_id,
    state.run_id,
    state.work_item_id,
  )
  let previous = work_continuation_draft_read(key)
  match msg {
    Select(_, _) => (@rabbita.none, model)
    Execute | Reconcile => {
      guard !state.pending else { return (@rabbita.none, model) }
      let execute = msg is Execute
      if execute {
        guard state.status == "" || state.status == "blocked" else {
          return (@rabbita.none, model)
        }
        let stored = @json.parse(previous) catch { _ => Json::null() }
        let original = handoff_text(stored, "request_id")
        if run.single_step_actions
          .unwrap_or([])
          .any(action => action.work_item_id == state.work_item_id) ||
          (
            original != "" &&
            (
              original != state.request_id ||
              !["", "blocked"].contains(handoff_text(stored, "status"))
            )
          ) {
          let restored = moonflow_single_step_state(
            { ..model, moonflow_single_step: None, },
            run,
            state.work_item_id,
          )
          return (
            @rabbita.none,
            { ..model, moonflow_single_step: Some(restored), },
          )
        }
        guard (state.status == "" || state.status == "blocked") &&
          run.items.any(item => {
            item.work_item_id == state.work_item_id &&
            moonflow_single_step_eligible(run, item)
          }) else {
          return (@rabbita.none, model)
        }
      } else {
        guard state.request_id != "" && state.status == "reconcile-required" else {
          return (@rabbita.none, model)
        }
      }
      let pending = {
        ..state,
        request_id: if state.request_id == "" {
          work_continuation_nonce()
        } else {
          state.request_id
        },
        status: "reconcile-required",
        pending: true,
        generation: moonflow_plan_next_generation(),
        message: if execute {
          "Running only this digital step. The result will stop at Review."
        } else {
          "Reconciling the original attempt without running it again."
        },
      }
      // Persist before constructing/sending HTTP. Storage failure is a blocker,
      // not permission to create an untracked action on refresh.
      // A verified server action for this exact Book/run/item supersedes a
      // losing tab's local ID, but only on reconciliation, never execution.
      let saved = if !execute &&
        run.single_step_actions
        .unwrap_or([])
        .any(action => {
          action.work_item_id == state.work_item_id &&
          action.request_id == state.request_id
        }) {
        moonflow_plan_save_matching(
          key,
          previous,
          moonflow_single_step_stored(pending),
        )
      } else {
        moonflow_single_step_save(pending, previous)
      }
      guard saved else {
        return (
          @rabbita.none,
          {
            ..model,
            moonflow_single_step: Some({
              ..state,
              message: "The action identity could not be saved locally or changed in another tab. Reload this Book before running; no request was sent.",
            }),
          },
        )
      }
      (
        moonflow_single_step_post(
          dispatch,
          pending,
          if execute {
            "execute"
          } else {
            "reconcile"
          },
        ),
        { ..model, moonflow_single_step: Some(pending), },
      )
    }
    Timeout(book, run_id, item, request, generation) => {
      guard state.pending &&
        moonflow_single_step_identity(
          state, book, run_id, item, request, generation,
        ) else {
        return (@rabbita.none, model)
      }
      let next = {
        ..state,
        pending: false,
        status: "reconcile-required",
        message: "The response has not arrived. Reconcile this same attempt; do not run it again.",
      }
      let _ = moonflow_single_step_save(next, previous)
      (@rabbita.none, { ..model, moonflow_single_step: Some(next), })
    }
    Reply(book, run_id, item, request, generation, response) => {
      guard moonflow_single_step_identity(
          state, book, run_id, item, request, generation,
        ) &&
        (state.pending || state.status == "reconcile-required") else {
        return (@rabbita.none, model)
      }
      let value = match response {
        Ok(value) => value
        Err(_) => Json::null()
      }
      let matched = handoff_text(value, "contract_id") ==
        "moondesk.flow-single-step-result.v1" &&
        handoff_text(value, "workspace_id") == book &&
        handoff_text(value, "run_id") == run_id &&
        handoff_text(value, "work_item_id") == item &&
        handoff_text(value, "request_id") == request &&
        ["review", "reconcile-required", "not-applied", "failed", "blocked"].contains(
          handoff_text(value, "status"),
        )
      let next = {
        ..state,
        pending: false,
        status: if matched {
          handoff_text(value, "status")
        } else {
          "reconcile-required"
        },
        message: if matched {
          handoff_text(value, "message")
        } else {
          "The response was lost or did not match this action. Reconcile the original attempt; do not run it again."
        },
        result: if matched {
          Some(handoff_field(value, "result"))
        } else {
          state.result
        },
      }
      let _ = moonflow_single_step_save(next, previous)
      let updated = { ..model, moonflow_single_step: Some(next), }
      (
        if matched {
          fetch_moonflow_runs_cmd(dispatch)
        } else {
          @rabbita.none
        },
        updated,
      )
    }
  }
}

///|
fn render_moonflow_single_step(
  dispatch : Dispatch[Msg],
  model : Model,
  run : MoonFlowRunProjection,
) -> @rabbita.Html {
  let selected = match model.moonflow_single_step {
    Some(state) if state.workspace_id == model.selected_workspace_id &&
      state.run_id == run.run_id => Some(state)
    _ => None
  }
  let setup = run.single_step_setup.unwrap_or(Json::null())
  section(
    class="flow-handoff-card",
    attrs=@html.Attrs::build().data_set("testid", "flow-single-step"),
    [
      h3("Run one digital step"),
      p(
        "Select one imported Mold item. Existing Gate authority is checked; successful digital work stops at Review. Review is a separate explicit decision.",
      ),
      p(
        if handoff_text(setup, "message") == "" {
          "The host must configure a trusted Flow executable and single-step configuration with existing Gate authority."
        } else {
          handoff_text(setup, "message")
        },
      ),
      div(
        run.items.map(item => {
          button(
            class="secondary-button",
            attrs=@html.Attrs::build().data_set(
              "testid",
              "flow-single-step-select-" + item.work_item_id,
            ),
            on_click=dispatch(
              MoonFlowSingleStep(Select(run.run_id, item.work_item_id)),
            ),
            item.work_item_id + " · " + item.status,
          )
        }),
      ),
      match selected {
        None => p("Choose the imported item to inspect its action and result.")
        Some(state) =>
          div([
            strong("Selected: " + state.work_item_id),
            if state.request_id != "" {
              small("Action: " + state.request_id)
            } else {
              @html.nothing
            },
            p(
              attrs=@html.Attrs::build().data_set(
                "testid", "flow-single-step-status",
              ),
              state.message,
            ),
            if state.status == "review" {
              div([
                strong("Review required"),
                p(
                  "Digital result: fixture-reference-only. Production qualified: false. Physical authority: false. No reviewer or dependent item was dispatched.",
                ),
              ])
            } else if state.status == "reconcile-required" {
              button(
                class="primary-button",
                disabled=state.pending,
                attrs=@html.Attrs::build().data_set(
                  "testid", "flow-single-step-reconcile",
                ),
                on_click=dispatch(MoonFlowSingleStep(Reconcile)),
                "Reconcile same attempt",
              )
            } else if state.status == "not-applied" || state.status == "failed" {
              p(
                "This action is closed. This route will not run it again; inspect the retained evidence before planning further work.",
              )
            } else {
              button(
                class="primary-button",
                disabled=state.pending ||
                  !run.items.any(item => {
                    item.work_item_id == state.work_item_id &&
                    moonflow_single_step_eligible(run, item)
                  }),
                attrs=@html.Attrs::build().data_set(
                  "testid", "flow-single-step-execute",
                ),
                on_click=dispatch(MoonFlowSingleStep(Execute)),
                "Run this digital step",
              )
            },
            match moonflow_item_by_id(run, state.work_item_id) {
              Some(item) if item.attempt_count > 0 =>
                div([
                  p(
                    "Attempt: " +
                    item.active_attempt_id +
                    " · " +
                    item.attempt_status,
                  ),
                  p("Output digest: " + item.output_digest),
                  render_moonflow_retained_references(
                    dispatch, model, run, item,
                  ),
                ])
              _ => @html.nothing
            },
            if !run.items.any(item => {
                item.work_item_id == state.work_item_id &&
                moonflow_single_step_eligible(run, item)
              }) &&
              state.request_id == "" {
              p(
                "This item is not a ready digital Mold step with the supported exact operation. No execution is available for this selection.",
              )
            } else {
              @html.nothing
            },
            match state.result {
              Some(result) if result != Json::null() =>
                details(class="technical-details", [
                  summary("Retained digital-step evidence"),
                  pre(result.stringify(indent=2)),
                ])
              _ => @html.nothing
            },
          ])
      },
    ],
  )
}
