///|
struct MoonFlowPlanFields {
  work_item_id : String
  source_item_id : String?
  inputs : String
  dependencies : String
  criteria : String
  timeout : String
} derive(FromJson, ToJson, Eq, Debug)

///|
struct MoonFlowPlanEditor {
  fields : Array[MoonFlowPlanFields]
  saved_body : String
  notice : String
  phase : String
  request_id : String
  generation : Int
  receipt : Json?
  closed : Bool
} derive(FromJson)

///|
fn moonflow_plan_seed(composition : MoonFlowComposition) -> MoonFlowPlanEditor {
  {
    fields: composition.items.map(item => {
      work_item_id: item.work_item_id,
      source_item_id: None,
      inputs: item.input_artifacts.join("\n"),
      dependencies: item.depends_on.join("\n"),
      criteria: item.acceptance_criteria.join("\n"),
      timeout: item.timeout_ms.to_string(),
    }),
    saved_body: "missing",
    notice: "Edit a new plan while the selected source stays unchanged. Save draft before leaving this view.",
    phase: "draft",
    request_id: "",
    generation: 0,
    receipt: None,
    closed: false,
  }
}

///|
fn moonflow_plan_storage_key(workspace_id : String, source : Json) -> String {
  // The exact source is part of the key. A newer graph can never silently reuse
  // an older source's local form, even when its authored graph_id is reused.
  "moondesk.declared-plan-draft.v1:" + workspace_id + ":" + source.stringify()
}

///|
extern "js" fn moonflow_plan_save_matching(
  key : String,
  expected : String,
  next : String,
) -> Bool =
  #| (key, expected, next) => { try { const s=globalThis.localStorage;if(!s || next.length>655360 || key.length>655360)return false;const old=s.getItem(key);if(old!==next && (old===null?'missing':old)!==expected)return false;s.setItem(key,next);return s.getItem(key)===next; }catch(_){return false;} }

///|
fn moonflow_plan_reopen(
  workspace_id : String,
  composition : MoonFlowComposition,
) -> MoonFlowComposition {
  guard composition.source_graph is Some(source) else { return composition }
  let seed = moonflow_plan_seed(composition)
  let saved = work_continuation_draft_read(
    moonflow_plan_storage_key(workspace_id, source),
  )
  let editor = if saved == "missing" {
    {
      ..seed,
      notice: "No saved draft for this exact source. Changes stay local until you save or prepare.",
    }
  } else {
    try {
      let value = @json.parse(saved)
      guard value is Object(fields) else { fail("draft must be an object") }
      let legacy = fields.get("contract_id") ==
        Some("moondesk.declared-plan-draft.v1")
      guard (
          legacy ||
          fields.get("contract_id") == Some("moondesk.declared-plan-draft.v2")
        ) &&
        fields.get("source_graph") == Some(source) else {
        fail("saved draft source mismatch")
      }
      guard fields.get("fields") is Some(items) else {
        fail("draft fields are missing")
      }
      let restored : Array[MoonFlowPlanFields] = @json.from_json(items)
      guard !legacy ||
        restored.map(item => item.work_item_id) ==
        composition.items.map(item => item.work_item_id) else {
        fail("saved draft work items differ from source")
      }
      moonflow_plan_validate_templates(composition, restored)
      MoonFlowPlanEditor::{
        fields: restored,
        saved_body: saved,
        notice: if handoff_text(value, "prepared_request_id") == "" {
          "Saved local draft reopened. It has not been prepared or run."
        } else {
          "Saved draft and request identity reopened. Reload the prepared result to check whether it was prepared or imported before continuing."
        },
        phase: "draft",
        request_id: handoff_text(value, "prepared_request_id"),
        generation: seed.generation,
        receipt: None,
        closed: false,
      }
    } catch {
      _ =>
        {
          ..seed,
          saved_body: saved,
          notice: "Saved draft could not be read. It remains in local storage; Save will replace it with the visible form.",
        }
    }
  }
  { ..composition, plan_editor: Some(editor), }
}

///|
fn moonflow_plan_receive(
  model : Model,
  next : MoonFlowComposition,
) -> MoonFlowComposition {
  match model.moonflow_composition {
    Some(previous) if previous.workspace_id == next.workspace_id &&
      previous.source_graph == next.source_graph &&
      previous.plan_editor is Some(_) =>
      { ..next, plan_editor: previous.plan_editor, }
    _ => moonflow_plan_reopen(model.selected_workspace_id, next)
  }
}

///|
fn moonflow_plan_lines(text : String) -> Array[String] {
  text
  .split("\n")
  .map(line => line.trim().to_owned())
  .filter(line => !line.is_empty())
  .to_array()
}

///|
fn moonflow_plan_form_input(composition : MoonFlowComposition) -> Json raise {
  guard !composition.plan_source_unconfirmed.unwrap_or(false) else {
    fail(
      "Source refresh failed. Your draft is retained; reload the selected source before preparing",
    )
  }
  guard composition.source_graph is Some(source) else {
    fail("Reload a declared source graph first")
  }
  let editor = composition.plan_editor.unwrap_or(
    moonflow_plan_seed(composition),
  )
  let errors = moonflow_plan_field_errors(editor)
  guard errors.is_empty() else { fail(errors.join("; ")) }
  let edits : Array[Json] = []
  moonflow_plan_validate_templates(composition, editor.fields)
  let templates : Map[String, Json] = Map([])
  for item in editor.fields {
    if item.source_item_id is Some(template) {
      templates[item.work_item_id] = template.to_json()
    }
    let timeout_text = item.timeout.trim().to_owned()
    guard !timeout_text.is_empty() &&
      timeout_text.iter().all(char => char.is_ascii_digit()) else {
      fail(
        "\{item.work_item_id}: timeout must be a whole number of milliseconds",
      )
    }
    let timeout = @string.parse_int(timeout_text)
    guard timeout > 0 && timeout <= 86400000 else {
      fail("\{item.work_item_id}: timeout must be 1..86400000 milliseconds")
    }
    let inputs = moonflow_plan_lines(item.inputs)
    let criteria = moonflow_plan_lines(item.criteria)
    guard !inputs.is_empty() && !criteria.is_empty() else {
      fail(
        "\{item.work_item_id}: input artifacts and acceptance criteria are required",
      )
    }
    edits.push({
      "work_item_id": item.work_item_id,
      "input_artifacts": inputs,
      "depends_on": moonflow_plan_lines(item.dependencies),
      "acceptance_criteria": criteria,
      "timeout_ms": timeout,
    })
  }
  let expanded = !templates.is_empty() ||
    editor.fields.map(item => item.work_item_id) !=
    composition.items.map(item => item.work_item_id)
  let result : Json = {
    "contract_id": if expanded {
      "moonflow.declared-plan-form-input.v2"
    } else {
      "moonflow.declared-plan-form-input.v1"
    },
    "source_kind": "existing-graph",
    "source_graph": source,
    "edits": edits,
  }
  if expanded && result is Object(fields) {
    fields["added_templates"] = Json::object(templates)
  }
  result
}

///|
fn moonflow_plan_update_field(
  editor : MoonFlowPlanEditor,
  id : String,
  field : String,
  value : String,
) -> MoonFlowPlanEditor {
  let fields = editor.fields.map(item => {
    if item.work_item_id != id {
      item
    } else {
      match field {
        "inputs" => { ..item, inputs: value, }
        "dependencies" => { ..item, dependencies: value, }
        "criteria" => { ..item, criteria: value, }
        "timeout" => { ..item, timeout: value, }
        _ => item
      }
    }
  })
  {
    ..editor,
    fields,
    phase: "draft",
    request_id: "",
    generation: moonflow_plan_next_generation(),
    receipt: None,
    notice: "Unsaved local plan draft. Prepare checks these fields and creates an immutable child plan without executing work.",
  }
}

///|
fn update_moonflow_plan_authoring(
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  guard model.moonflow_composition is Some(composition) else {
    return (@rabbita.none, model)
  }
  guard composition.workspace_id == Some(model.selected_workspace_id) else {
    return (@rabbita.none, model)
  }
  guard composition.source_graph is Some(source) else {
    return (@rabbita.none, model)
  }
  let current = composition.plan_editor.unwrap_or(
    moonflow_plan_seed(composition),
  )
  let updated = match msg {
    EditMoonFlowPlanField(_, _, _)
    | DuplicateMoonFlowPlanItem(_)
    | RemoveMoonFlowPlanItem(_) if moonflow_plan_busy(current) => composition
    DuplicateMoonFlowPlanItem(id) =>
      {
        ..composition,
        plan_editor: Some(moonflow_plan_duplicate(composition, current, id)),
      }
    RemoveMoonFlowPlanItem(id) =>
      {
        ..composition,
        plan_editor: Some({
          ..moonflow_plan_update_field(current, "", "", ""),
          fields: current.fields.filter(item => item.work_item_id != id),
          notice: "Step removed from this local child draft. Other steps remain; repair any dependency naming the removed step before preparing.",
        }),
      }
    EditMoonFlowPlanField(id, field, value) =>
      {
        ..composition,
        plan_editor: Some(moonflow_plan_update_field(current, id, field, value)),
      }
    ReopenMoonFlowPlanDraft => {
      let reopened = moonflow_plan_reopen(
        model.selected_workspace_id,
        composition,
      )
      {
        ..reopened,
        plan_editor: reopened.plan_editor.map(value => {
          ..value,
          generation: moonflow_plan_next_generation(),
        }),
      }
    }
    SaveMoonFlowPlanDraft => {
      let body : Json = {
        "contract_id": "moondesk.declared-plan-draft.v2",
        "source_graph": source,
        "fields": current.fields.to_json(),
        "prepared_request_id": current.request_id,
      }
      let encoded = body.stringify()
      let saved = moonflow_plan_save_matching(
        moonflow_plan_storage_key(model.selected_workspace_id, source),
        current.saved_body,
        encoded,
      )
      {
        ..composition,
        plan_editor: Some({
          ..current,
          saved_body: if saved {
            encoded
          } else {
            current.saved_body
          },
          notice: if saved {
            "Draft saved in this browser, including incomplete fields. Reopen saved draft restores this exact source."
          } else {
            "Draft was not saved: storage is unavailable/full, or another tab changed it. Keep this form open or reopen the saved draft."
          },
        }),
      }
    }
    _ => composition
  }
  (@rabbita.none, { ..model, moonflow_composition: Some(updated), })
}

///|
fn moonflow_plan_textarea(
  dispatch : Dispatch[Msg],
  id : String,
  field : String,
  title : String,
  value : String,
  disabled~ : Bool,
) -> @rabbita.Html {
  div(class="form-field", [
    @html.label(title),
    textarea(
      attrs=@html.Attrs::build().aria_label(id + " " + title),
      value~,
      disabled~,
      rows=3,
      on_input=text => dispatch(EditMoonFlowPlanField(id, field, text)),
      "",
    ),
  ])
}

///|
fn render_moonflow_plan_authoring(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  guard model.moonflow_composition is Some(composition) else {
    return @html.nothing
  }
  guard composition.workspace_id == Some(model.selected_workspace_id) else {
    return @html.nothing
  }
  guard composition.source_graph is Some(_) else { return @html.nothing }
  let editor = composition.plan_editor.unwrap_or(
    moonflow_plan_seed(composition),
  )
  if editor.closed {
    return section(class="flow-handoff-section", [
      h3("Declared plan draft"),
      p(
        attrs=@html.Attrs::build().role("status").aria_live("polite"),
        editor.notice,
      ),
      button(
        class="secondary-button",
        on_click=dispatch(MoonFlowPlan(Open)),
        "Reopen plan editor",
      ),
    ])
  }
  section(
    class="flow-handoff-section",
    attrs=@html.Attrs::build().data_set("testid", "flow-plan-authoring"),
    [
      h3("Author a new declared plan"),
      p(
        "Source: the selected Book’s complete work graph. Duplicate a declared operation or remove a step from this child draft. Product owner, operation, schemas, authority and claim stay fixed. Repair dependencies explicitly; one entry per line.",
      ),
      p(editor.notice),
      div(
        class="flow-plan-field-errors",
        attrs=@html.Attrs::build().aria_live("polite"),
        moonflow_plan_field_errors(editor).map(error => {
          p(class="flow-error", error)
        }),
      ),
      div(
        class="flow-handoff-grid",
        editor.fields.map(item => {
          let declared = composition.items
            .filter(value => {
              value.work_item_id ==
              item.source_item_id.unwrap_or(item.work_item_id)
            })
            .get(0)
          div(class="flow-handoff-card", [
            @html.h4(item.work_item_id),
            p(
              match item.source_item_id {
                Some(template) =>
                  "Added duplicate of " +
                  template +
                  ". This step has no inherited acceptance."
                None => "Retained source step"
              },
            ),
            p(
              match declared {
                Some(value) =>
                  value.operation +
                  " · " +
                  value.input_contracts.join(", ") +
                  " → " +
                  value.output_contracts.join(", ")
                None => "Unknown source item"
              },
            ),
            moonflow_plan_textarea(
              dispatch,
              item.work_item_id,
              "inputs",
              "Input artifact paths",
              item.inputs,
              disabled=moonflow_plan_busy(editor),
            ),
            moonflow_plan_textarea(
              dispatch,
              item.work_item_id,
              "dependencies",
              "Dependency item IDs",
              item.dependencies,
              disabled=moonflow_plan_busy(editor),
            ),
            moonflow_plan_textarea(
              dispatch,
              item.work_item_id,
              "criteria",
              "Acceptance criteria",
              item.criteria,
              disabled=moonflow_plan_busy(editor),
            ),
            div(class="form-field", [
              @html.label("Timeout (milliseconds)"),
              input(
                value=item.timeout,
                attrs=@html.Attrs::build()
                  .disabled(moonflow_plan_busy(editor))
                  .aria_label(item.work_item_id + " Timeout milliseconds"),
                on_input=value => {
                  dispatch(
                    EditMoonFlowPlanField(item.work_item_id, "timeout", value),
                  )
                },
              ),
            ]),
            button(
              class="secondary-button",
              disabled=moonflow_plan_busy(editor) ||
                editor.fields.length() >= 256,
              on_click=dispatch(DuplicateMoonFlowPlanItem(item.work_item_id)),
              "Duplicate declared operation",
            ),
            button(
              class="secondary-button",
              disabled=moonflow_plan_busy(editor),
              on_click=dispatch(RemoveMoonFlowPlanItem(item.work_item_id)),
              "Remove this step",
            ),
          ])
        }),
      ),
      p(
        "Removed source steps: " +
        composition.items
        .filter(item => {
          !editor.fields.any(field => field.work_item_id == item.work_item_id)
        })
        .map(item => item.work_item_id)
        .join(", "),
      ),
      div(class="flow-canvas-tools", [
        button(
          class="secondary-button",
          on_click=dispatch(SaveMoonFlowPlanDraft),
          "Save local plan draft",
        ),
        button(
          class="secondary-button",
          disabled=moonflow_plan_busy(editor),
          on_click=dispatch(ReopenMoonFlowPlanDraft),
          "Reopen saved draft",
        ),
        try moonflow_plan_form_input(composition) catch {
          error => p(class="flow-quiet", "Preparation blocked: \{error}")
        } noraise {
          _ => @html.nothing
        },
      ]),
      render_moonflow_plan_prepared(dispatch, composition, editor),
      p(
        "Prepare validates dependencies, cycles, artifact files and fresh capability health, then captures input bytes into a separate immutable child plan. Review the changes and explicitly import it here. Neither action dispatches or approves work.",
      ),
      p(
        "Artifact paths are relative to this suite’s Flow workspace. Your source graph, parent run and their approvals remain unchanged. Captured input bindings can require new checkpoint review.",
      ),
    ],
  )
}
