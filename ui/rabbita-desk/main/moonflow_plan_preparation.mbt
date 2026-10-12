///|
enum MoonFlowPlanMsg {
  Prepare
  Restart
  Apply
  Inspect
  Close
  Open
  Reply(String, String, String, Int, Result[Json, String])
  Timeout(String, String, Int)
}

///|
let moonflow_plan_generation_counter : Ref[Int] = Ref(0)

///|
fn moonflow_plan_next_generation() -> Int {
  moonflow_plan_generation_counter.val += 1
  moonflow_plan_generation_counter.val
}

///|
fn moonflow_plan_busy(editor : MoonFlowPlanEditor) -> Bool {
  editor.phase == "preparing" ||
  editor.phase == "applying" ||
  editor.phase == "loading"
}

///|
fn moonflow_plan_post(
  dispatch : Dispatch[Msg],
  workspace : String,
  source : String,
  editor : MoonFlowPlanEditor,
  payload : Json,
) -> @rabbita.Cmd {
  @rabbita.batch([
    @http.post(@desk.desktop_api_url(["api", "moonflow", "plans"]))
    .with_json(payload)
    .expect_json(result => {
      dispatch(
        MoonFlowPlan(
          Reply(
            workspace,
            source,
            editor.request_id,
            editor.generation,
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
        MoonFlowPlan(Timeout(workspace, editor.request_id, editor.generation)),
      ),
      65000,
    ),
  ])
}

///|
fn moonflow_plan_replace(
  model : Model,
  composition : MoonFlowComposition,
  editor : MoonFlowPlanEditor,
) -> Model {
  {
    ..model,
    moonflow_composition: Some({ ..composition, plan_editor: Some(editor), }),
  }
}

///|
fn update_moonflow_plan_preparation(
  dispatch : Dispatch[Msg],
  msg : MoonFlowPlanMsg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  guard model.moonflow_composition is Some(composition) &&
    composition.workspace_id == Some(model.selected_workspace_id) &&
    composition.source_graph is Some(source) else {
    return (@rabbita.none, model)
  }
  let editor = composition.plan_editor.unwrap_or(
    moonflow_plan_seed(composition),
  )
  let workspace = model.selected_workspace_id
  match msg {
    Restart => {
      guard !editor.closed && !moonflow_plan_busy(editor) else {
        return (@rabbita.none, model)
      }
      update_moonflow_plan_preparation(
        dispatch,
        Prepare,
        moonflow_plan_replace(model, composition, {
          ..editor,
          request_id: "",
          receipt: None,
          phase: "draft",
          generation: moonflow_plan_next_generation(),
        }),
      )
    }
    Close =>
      (
        @rabbita.none,
        moonflow_plan_replace(model, composition, {
          ..editor,
          closed: true,
          phase: "draft",
          generation: moonflow_plan_next_generation(),
          notice: if editor.phase == "applying" {
            "This view is closed. The import request may finish; reopen and reload its result before retrying. No execution was requested."
          } else {
            "The editor is closed. Your visible fields are retained; a pending preparation may finish without executing work."
          },
        }),
      )
    Open =>
      (
        @rabbita.none,
        moonflow_plan_replace(model, composition, { ..editor, closed: false, }),
      )
    Timeout(book, request, generation) => {
      guard book == workspace &&
        request == editor.request_id &&
        generation == editor.generation &&
        moonflow_plan_busy(editor) else {
        return (@rabbita.none, model)
      }
      (
        @rabbita.none,
        moonflow_plan_replace(model, composition, {
          ..editor,
          phase: "uncertain",
          notice: "The response has not arrived. Your fields and request identity are retained. Reload the prepared result before retrying an import.",
        }),
      )
    }
    Reply(book, expected_source, request, generation, result) => {
      guard book == workspace &&
        source.stringify() == expected_source &&
        request == editor.request_id &&
        generation == editor.generation &&
        !editor.closed &&
        (moonflow_plan_busy(editor) || editor.phase == "uncertain") else {
        return (@rabbita.none, model)
      }
      let value = match result {
        Ok(value) => value
        Err(error) =>
          return (
            @rabbita.none,
            moonflow_plan_replace(model, composition, {
              ..editor,
              phase: "uncertain",
              notice: "Could not refresh the plan result: " +
              error +
              ". Your draft is retained; reload the result before importing.",
            }),
          )
      }
      guard handoff_text(value, "workspace_id") == workspace &&
        handoff_text(value, "request_id") == request &&
        handoff_text(value, "contract_id") == "moondesk.flow-plan-result.v1" else {
        return (
          @rabbita.none,
          moonflow_plan_replace(model, composition, {
            ..editor,
            phase: "uncertain",
            notice: "The plan response did not match this Book and request. Reload its result before continuing.",
          }),
        )
      }
      guard handoff_field(value, "ok") == (true : Json) else {
        return (
          @rabbita.none,
          moonflow_plan_replace(model, composition, {
            ..editor,
            phase: "blocked",
            notice: handoff_text(value, "message"),
          }),
        )
      }
      let applied = handoff_text(value, "status") == "imported"
      let next = moonflow_plan_replace(model, composition, {
        ..editor,
        phase: if applied {
          "imported"
        } else {
          "prepared"
        },
        receipt: Some(value),
        notice: handoff_text(value, "message"),
      })
      let (_, saved) = update_moonflow_plan_authoring(
        SaveMoonFlowPlanDraft,
        next,
      )
      // The explicit result is retained even if the independent run refresh
      // fails. Runs reload through the existing production projection path.
      let saved = match saved.moonflow_composition {
        Some(c) =>
          moonflow_plan_replace(saved, c, {
            ..c.plan_editor.unwrap(),
            notice: handoff_text(value, "message") +
            (if c.plan_editor.unwrap().notice.contains("not saved") {
              " Local storage is unavailable or changed; keep this view open."
            } else {
              " Draft and request identity saved locally."
            }),
          })
        None => saved
      }
      (
        if applied && editor.phase == "applying" {
          dispatch(MoonFlowPlan(Inspect))
        } else if applied {
          fetch_moonflow_runs_cmd(dispatch)
        } else {
          @rabbita.none
        },
        saved,
      )
    }
    Prepare | Apply | Inspect => {
      guard !editor.closed && !moonflow_plan_busy(editor) else {
        return (@rabbita.none, model)
      }
      let action = match msg {
        Prepare => "prepare"
        Apply => "apply"
        _ => "inspect"
      }
      if action != "inspect" &&
        composition.plan_source_unconfirmed.unwrap_or(false) {
        return (
          @rabbita.none,
          moonflow_plan_replace(model, composition, {
            ..editor,
            notice: "Source refresh failed. Reload the selected Book before preparing or importing; your draft is retained.",
          }),
        )
      }
      if action == "apply" &&
        (
          editor.phase != "prepared" ||
          editor.receipt is None ||
          handoff_field(editor.receipt.unwrap(), "source_current") !=
          (true : Json)
        ) {
        return (
          @rabbita.none,
          moonflow_plan_replace(model, composition, {
            ..editor,
            notice: "Reload and review a current prepared child before importing.",
          }),
        )
      }
      let request_id = if action == "prepare" && editor.request_id == "" {
        work_continuation_nonce()
      } else {
        editor.request_id
      }
      guard request_id != "" else { return (@rabbita.none, model) }
      let payload : Json = if action == "prepare" {
        let form = moonflow_plan_form_input(composition) catch {
          error =>
            return (
              @rabbita.none,
              moonflow_plan_replace(model, composition, {
                ..editor,
                notice: "Preparation blocked: \{error}",
              }),
            )
        }
        moonflow_plan_payload(action, workspace, request_id, form=Some(form))
      } else {
        moonflow_plan_payload(action, workspace, request_id, form=None)
      }
      let next = {
        ..editor,
        request_id,
        generation: moonflow_plan_next_generation(),
        phase: match msg {
          Prepare => "preparing"
          Apply => "applying"
          _ => "loading"
        },
        notice: match msg {
          Prepare =>
            "Validating fields, capturing inputs and preparing an immutable child plan…"
          Apply =>
            "Importing the reviewed child plan; no work is being executed…"
          _ => "Reloading retained preparation and import evidence…"
        },
      }
      let pending_model = moonflow_plan_replace(model, composition, next)
      let (_, saved) = update_moonflow_plan_authoring(
        SaveMoonFlowPlanDraft,
        pending_model,
      )
      let saved_composition = saved.moonflow_composition.unwrap()
      let saved_editor = saved_composition.plan_editor.unwrap()
      let saved = moonflow_plan_replace(saved, saved_composition, {
        ..saved_editor,
        notice: next.notice +
        (if saved_editor.notice.contains("not saved") {
          " Local storage could not retain the request; keep this view open."
        } else {
          ""
        }),
      })
      (
        moonflow_plan_post(
          dispatch,
          workspace,
          source.stringify(),
          next,
          payload,
        ),
        saved,
      )
    }
  }
}

///|
fn moonflow_plan_payload(
  action : String,
  workspace : String,
  request_id : String,
  form~ : Json?,
) -> Json {
  match form {
    Some(form) =>
      {
        "action": action,
        "workspace_id": workspace,
        "request_id": request_id,
        "form": form,
      }
    None =>
      { "action": action, "workspace_id": workspace, "request_id": request_id }
  }
}

///|
fn moonflow_plan_value_summary(value : Json) -> String {
  match value {
    Array(values) =>
      if values.is_empty() {
        "None"
      } else {
        values
        .map(item => {
          match item {
            String(text) => text
            _ => item.stringify()
          }
        })
        .join("; ")
      }
    String(text) => text
    _ => value.stringify()
  }
}

///|
fn render_moonflow_plan_prepared(
  dispatch : Dispatch[Msg],
  composition : MoonFlowComposition,
  editor : MoonFlowPlanEditor,
) -> @rabbita.Html {
  let controls = div(class="flow-canvas-tools", [
    button(
      class="primary-button",
      disabled=moonflow_plan_busy(editor) ||
        composition.plan_source_unconfirmed.unwrap_or(false) ||
        !moonflow_plan_field_errors(editor).is_empty(),
      attrs=@html.Attrs::build().data_set("testid", "flow-plan-prepare"),
      on_click=dispatch(
        MoonFlowPlan(if editor.request_id == "" { Prepare } else { Restart }),
      ),
      if editor.request_id == "" {
        "Prepare child plan"
      } else {
        "Prepare a fresh child"
      },
    ),
    if editor.request_id != "" {
      button(
        class="secondary-button",
        disabled=moonflow_plan_busy(editor),
        on_click=dispatch(MoonFlowPlan(Inspect)),
        "Reload prepared result",
      )
    } else {
      @html.nothing
    },
    button(
      class="secondary-button",
      on_click=dispatch(MoonFlowPlan(Close)),
      if moonflow_plan_busy(editor) {
        "Close while waiting"
      } else {
        "Close editor"
      },
    ),
  ])
  div([
    controls,
    match editor.receipt {
      None => @html.nothing
      Some(result) => {
        let receipt = handoff_field(result, "receipt")
        let prepared = handoff_field(receipt, "prepared")
        let graph = handoff_field(prepared, "graph")
        let changes = match handoff_field(result, "changes") {
          Array(values) => values
          _ => []
        }
        let migration = handoff_field(receipt, "migration_preview")
        section(class="flow-handoff-card", [
          h3(
            if handoff_text(result, "status") == "imported" {
              "Child plan imported"
            } else {
              "Review the prepared child"
            },
          ),
          p("Source: " + handoff_text(prepared, "source_graph_id")),
          p("Child: " + handoff_text(graph, "graph_id")),
          p(
            if changes.is_empty() {
              "No editable declaration fields changed. This remains a separate child plan."
            } else {
              "\{changes.length()} declaration field changes:"
            },
          ),
          div(
            changes.map(change => {
              p(
                handoff_text(change, "work_item_id") +
                " · " +
                moonflow_plan_field_title(handoff_text(change, "field")) +
                ": " +
                moonflow_plan_value_summary(handoff_field(change, "before")) +
                " → " +
                moonflow_plan_value_summary(handoff_field(change, "after")),
              )
            }),
          ),
          p(
            if migration == Json::null() {
              "This source has no imported parent run. Import creates a new run with zero attempts."
            } else {
              "This is a revision of an existing run. Flow rechecks checkpoint eligibility before importing; the parent run stays unchanged."
            },
          ),
          render_moonflow_plan_migration(migration),
          p(
            "Declared input snapshots are retained with the child. Preparation and import do not grant approvals or execute product work.",
          ),
          render_moonflow_plan_capture_limits(receipt),
          if handoff_field(result, "source_current") != (true : Json) {
            p(
              class="flow-error",
              "Source or catalog changed. This packet is retained for inspection; prepare a new child before importing.",
            )
          } else {
            @html.nothing
          },
          if editor.phase == "prepared" {
            button(
              class="primary-button",
              disabled=composition.plan_source_unconfirmed.unwrap_or(false) ||
                handoff_field(result, "source_current") != (true : Json),
              attrs=@html.Attrs::build().data_set("testid", "flow-plan-import"),
              on_click=dispatch(MoonFlowPlan(Apply)),
              if migration == Json::null() {
                "Import this child plan"
              } else {
                "Import this reviewed revision"
              },
            )
          } else {
            @html.nothing
          },
          details(class="technical-details", [
            summary("Technical preparation evidence"),
            pre(result.stringify(indent=2)),
          ]),
        ])
      }
    },
  ])
}

///|
fn render_moonflow_plan_capture_limits(receipt : Json) -> @rabbita.Html {
  let limitations = match handoff_field(receipt, "capture_limitations") {
    Array(values) => values
    String(value) if value != "" => [value.to_json()]
    _ => []
  }
  if limitations.is_empty() {
    return @html.nothing
  }
  div(class="flow-plan-capture-limits", [
    strong("Input capture limits"),
    p(
      "Some resources referenced inside inputs can still change. This plan does not promise reproducible execution of those resources.",
    ),
    div(limitations.map(value => p(moonflow_plan_value_summary(value)))),
  ])
}

///|
fn moonflow_plan_field_title(field : String) -> String {
  match field {
    "timeout_ms" => "Timeout (ms)"
    "input_artifacts" => "Input artifacts"
    "depends_on" => "Dependencies"
    "acceptance_criteria" => "Acceptance criteria"
    "added_step" => "Added step from source operation"
    "removed_step" => "Removed step"
    _ => field
  }
}

///|
fn render_moonflow_plan_migration(migration : Json) -> @rabbita.Html {
  if migration == Json::null() {
    return @html.nothing
  }
  let items = match handoff_field(migration, "decisions") {
    Array(values) => values
    _ => []
  }
  div([
    p(
      "Checkpoint review: " +
      moonflow_plan_value_summary(handoff_field(migration, "reused_count")) +
      " reusable, " +
      moonflow_plan_value_summary(handoff_field(migration, "invalidated_count")) +
      " need new review, " +
      moonflow_plan_value_summary(handoff_field(migration, "new_count")) +
      " new",
    ),
    div(
      items.map(item => {
        p(
          handoff_text(item, "child_work_item_id") +
          " · " +
          handoff_text(item, "decision") +
          ": " +
          handoff_text(item, "reason"),
        )
      }),
    ),
  ])
}
