///|
fn moonflow_count_status(run : MoonFlowRunProjection, status : String) -> Int {
  run.items.filter(item => item.status == status).length()
}

///|
fn moonflow_item_by_id(
  run : MoonFlowRunProjection,
  item_id : String,
) -> MoonFlowItemProjection? {
  for item in run.items {
    if item.work_item_id == item_id {
      return Some(item)
    }
  }
  None
}

///|
fn moonflow_run_state(run : MoonFlowRunProjection) -> String {
  if run.outcome == "accepted" {
    "complete"
  } else if run.outcome == "blocked" || run.outcome == "failed" {
    "blocked"
  } else if run.outcome == "active" || run.outcome == "review" {
    "in-progress"
  } else if !run.runnable_item_ids.is_empty() {
    "ready"
  } else {
    "in-progress"
  }
}

///|
fn moonflow_budget_label(used : Int, limit : Int) -> String {
  if limit <= 0 {
    "not granted"
  } else {
    "\{used} / \{limit}"
  }
}

///|
fn moonflow_item_explanation(item : MoonFlowItemProjection) -> String {
  if item.status == "blocked" || item.status == "failed" {
    if item.blocker != "" {
      item.blocker
    } else if item.error_kind != "" {
      "Execution reported " + item.error_kind
    } else {
      "No blocker evidence was recorded"
    }
  } else if item.status == "accepted" {
    if item.acceptance_review_id != "" && item.output_digest != "" {
      "Accepted by explicit review with bound output evidence"
    } else {
      "Accepted state is missing visible review or output identity"
    }
  } else if item.status == "ready" {
    "Dependencies are accepted; the declared product may execute now"
  } else if item.status == "review" {
    "Execution finished and awaits criterion-by-criterion review"
  } else {
    "Waiting for its next governed state transition"
  }
}

///|
fn moonflow_short_identity(value : String) -> String {
  if value == "" {
    "not recorded"
  } else if value.length() <= 16 {
    value
  } else {
    value[0:12].to_owned() + "…"
  }
}

///|
fn moonflow_earlier_runs(
  runs : Array[MoonFlowRunProjection],
) -> Array[MoonFlowRunProjection] {
  let earlier : Array[MoonFlowRunProjection] = []
  for index = 1; index < runs.length(); index = index + 1 {
    earlier.push(runs[index])
  }
  earlier
}

///|
fn moonflow_book_root_matches(book_root : String, book_id : String) -> Bool {
  let normalized = book_root.replace(old="\\", new="/").trim_end(chars="/")
  normalized == book_id || normalized.has_suffix("/" + book_id)
}

///|
fn moonflow_selected_runs(model : Model) -> Array[MoonFlowRunProjection] {
  let mut selected_root = ""
  for workspace in model.workspaces {
    if workspace.id == model.selected_workspace_id {
      selected_root = workspace.root_path
    }
  }
  if selected_root == "" {
    return []
  }
  model.moonflow_runs.filter(run => {
    moonflow_book_root_matches(selected_root, run.book_id)
  })
}

///|
fn render_moonflow_runs_state(
  dispatch : Dispatch[Msg],
  model : Model,
  selected_runs : Array[MoonFlowRunProjection],
) -> @rabbita.Html {
  match model.moonflow_runs_state {
    None | Some(LegitimateZero) => @html.nothing
    Some(state) =>
      section(
        class="surface-state-panel flow-runs-state",
        attrs=@html.Attrs::build()
          .data_set("testid", "moonflow-runs-state-panel")
          .data_set("state", moonflow_runs_state_key(model.moonflow_runs_state)),
        [
          render_polite_state_announcement(
            "moonflow-runs-state-announcement",
            moonflow_runs_state_title(state, !selected_runs.is_empty()),
            moonflow_runs_state_detail(state, !selected_runs.is_empty()),
          ),
          strong(moonflow_runs_state_title(state, !selected_runs.is_empty())),
          p(moonflow_runs_state_detail(state, !selected_runs.is_empty())),
          match moonflow_runs_state_action(state) {
            Some(label) =>
              button(
                class="secondary-button",
                on_click=dispatch(SelectWorkspaceMode(MoonFlow)),
                label,
              )
            None => @html.nothing
          },
          if moonflow_runs_state_shows_details(state) {
            details(class="technical-details", [
              summary("Technical details"),
              code(
                if state == CapabilityLimited {
                  moonflow_capability_technical_detail(model)
                } else {
                  model.moonflow_runs_error.unwrap_or("")
                },
              ),
            ])
          } else {
            @html.nothing
          },
        ],
      )
  }
}

///|
fn render_moonflow_workspace(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let selected_runs = moonflow_selected_runs(model)
  let runs_state = moonflow_effective_runs_state(model)
  main_(class="flow-main", attrs=main_content_attrs(MoonFlow), [
    section(class="flow-hero flow-hero-compact", [
      div([
        h1("MoonFlow"),
        p(
          class="lead",
          "Executable work for the selected MoonBook: compose, run, review.",
        ),
      ]),
      button(
        class="secondary-button compact-button",
        on_click=dispatch(SelectWorkspaceMode(MoonFlow)),
        "Refresh",
      ),
    ]),
    render_moonflow_runs_state(
      dispatch,
      { ..model, moonflow_runs_state: runs_state },
      selected_runs,
    ),
    if selected_runs.is_empty() &&
      moonflow_runs_state_shows_empty_action(runs_state) {
      section(
        class="flow-empty",
        attrs=@html.Attrs::build()
          .data_set("testid", "moonflow-runs-state-panel")
          .data_set("state", moonflow_runs_state_key(model.moonflow_runs_state)),
        [
          strong("No executable work yet"),
          p(
            "Start with the selected MoonBook's executable document. MoonFlow creates the run, then publishes authority-bound handoffs for every governed decision.",
          ),
          button(
            class="primary-button",
            attrs=@html.Attrs::build().data_set(
              "testid", "moonflow-prepare-selected",
            ),
            disabled=model.selected_workspace_id == "",
            on_click=dispatch(PrepareMoonFlow),
            "Start governed run",
          ),
          small(model.moonflow_status),
          if model.moonflow_status.contains("no executable Work graph") {
            button(
              class="secondary-button",
              on_click=dispatch(SelectWorkspaceMode(MoonWiki)),
              "Create executable document in Wiki",
            )
          } else {
            @html.nothing
          },
        ],
      )
    } else {
      @html.nothing
    },
    render_moonflow_composition_canvas(dispatch, model),
    if selected_runs.is_empty() &&
      moonflow_runs_state_shows_empty_action(runs_state) {
      render_moonflow_composition_continuation(model.moonflow_composition)
    } else {
      @html.nothing
    },
    if !selected_runs.is_empty() &&
      moonflow_runs_state_keeps_records(runs_state) {
      let latest = selected_runs[0]
      let earlier = moonflow_earlier_runs(selected_runs)
      let run_children : Array[@rabbita.Html] = [
        render_moonflow_run(dispatch, model, latest),
      ]
      if !earlier.is_empty() {
        run_children.push(
          details(class="flow-history", [
            summary("Earlier revisions (\{earlier.length()})"),
            div(
              class="flow-history-list",
              earlier.map(run => render_moonflow_history_row(run)),
            ),
          ]),
        )
      }
      div([
        section(class="flow-revision-toolbar", [
          div([
            strong("Executable work exists"),
            p(
              "Ingest a new revision after the selected MoonBook changes. Existing runs and their evidence remain immutable.",
            ),
          ]),
          if runs_state is Some(CapabilityLimited) {
            @html.nothing
          } else {
            button(
              class="secondary-button",
              attrs=@html.Attrs::build().data_set(
                "testid", "moonflow-prepare-selected",
              ),
              disabled=model.selected_workspace_id == "" ||
                model.moonflow_ingest_preparing,
              on_click=dispatch(PrepareMoonFlow),
              "Ingest latest revision",
            )
          },
          small("\{selected_runs.length()} revision(s) for this MoonBook"),
        ]),
        section(class="flow-run-list", run_children),
      ])
    } else {
      @html.nothing
    },
  ])
}

///|
fn render_moonflow_history_row(run : MoonFlowRunProjection) -> @rabbita.Html {
  div(class="flow-history-row", [
    div([strong("Revision " + run.declaration_revision), small(run.run_id)]),
    span(class="flow-state " + moonflow_run_state(run), moonflow_run_state(run)),
  ])
}

///|
fn render_moonflow_run(
  dispatch : Dispatch[Msg],
  model : Model,
  run : MoonFlowRunProjection,
) -> @rabbita.Html {
  let accepted = moonflow_count_status(run, "accepted")
  let blocked = moonflow_count_status(run, "blocked")
  section(class="flow-run-card", [
    header(class="flow-run-head", [
      div([
        p(class="eyebrow", "Run · sequence \{run.last_sequence}"),
        h2(run.book_id),
        small(
          "Executable revision " +
          run.declaration_revision +
          " · " +
          moonflow_run_state(run),
        ),
      ]),
      span(
        class="flow-state " + moonflow_run_state(run),
        moonflow_run_state(run),
      ),
    ]),
    div(class="flow-metrics", [
      div([strong("\{run.runnable_item_ids.length()}"), span("ready now")]),
      div([strong("\{accepted}"), span("accepted")]),
      div([strong("\{blocked}"), span("blocked")]),
      div([strong("\{run.items.length()}"), span("total")]),
    ]),
    if run.outcome != "accepted" &&
      run.outcome != "blocked" &&
      run.outcome != "failed" {
      p(class="flow-outcome pending", "Outcome pending")
    } else {
      p(class="flow-outcome", run.outcome)
    },
    render_moonflow_operator_surface(dispatch, model, run),
    details(class="flow-disclosure flow-work-declaration-disclosure", [
      summary("Executable document work · \{run.items.length()} item(s)"),
      div(class="flow-disclosure-body", [
        render_moonflow_next_actions(run),
        render_moonflow_blockers(run),
        render_moonflow_claim_coverage(run),
      ]),
    ]),
    render_moonflow_run_continuation(run),
    details(class="flow-disclosure flow-operator-disclosure", [
      summary("Operator controls"),
      div(class="flow-disclosure-body", [
        render_moonflow_authority(run),
        render_moonflow_controls(dispatch, run),
      ]),
    ]),
    details(class="flow-disclosure flow-developer-disclosure", [
      summary("Technical evidence"),
      div(class="flow-disclosure-body", [
        section(class="flow-section flow-contract", [
          h3("Executable document contract"),
          div(class="flow-contract-grid", [
            div([span("Run"), strong(run.run_id)]),
            div([span("Protocol"), strong(run.protocol)]),
            div([span("MoonBook"), strong(run.book_id)]),
            div([span("Declaration revision"), strong(run.declaration_revision)]),
            div([
              span("Source identity"),
              strong(moonflow_short_identity(run.source_digest)),
            ]),
          ]),
        ]),
        render_moonflow_runtime_evidence(run),
        div(
          class="flow-item-list",
          run.items.map(item => render_moonflow_item(item)),
        ),
      ]),
    ]),
  ])
}

///|
fn moonflow_composition_entry_items(
  composition : MoonFlowComposition,
) -> Array[MoonFlowCompositionItem] {
  composition.items.filter(item => {
    composition.selected_item_ids.contains(item.work_item_id) &&
    item.depends_on.all(dependency => {
      !composition.selected_item_ids.contains(dependency)
    })
  })
}

///|
fn render_flow_continuation_card(
  product_id : String,
  operation : String,
  declaration_id : String,
  status : String,
  detail : String,
) -> @rabbita.Html {
  section(class="flow-handoff-card", [
    div([strong(product_id), span(class="flow-handoff-status", status)]),
    p(operation),
    span(
      class="flow-handoff-note",
      "Declaration " + declaration_id + " · " + detail,
    ),
  ])
}

///|
fn render_moonflow_composition_continuation(
  composition : MoonFlowComposition?,
) -> @rabbita.Html {
  match composition {
    None => @html.nothing
    Some(value) => {
      let entries = moonflow_composition_entry_items(value)
      section(
        class="flow-handoff-section",
        attrs=@html.Attrs::build().data_set("testid", "flow-graph-continuation"),
        [
          div(class="flow-section-heading", [
            h3("Graph-derived continuation"),
            small("Selected entry nodes · \{entries.length()}"),
          ]),
          if entries.is_empty() {
            p(
              class="flow-quiet",
              "The selected graph publishes no entry node. Review its dependencies and validation evidence.",
            )
          } else {
            div(
              class="flow-handoff-grid",
              entries.map(item => {
                render_flow_continuation_card(
                  item.product_id,
                  item.operation,
                  item.declaration_id,
                  moonflow_composition_item_catalog_status(value, item),
                  "authority " +
                  item.requested_authority +
                  " · claim " +
                  item.required_claim,
                )
              }),
            )
          },
        ],
      )
    }
  }
}

///|
fn render_moonflow_run_continuation(
  run : MoonFlowRunProjection,
) -> @rabbita.Html {
  let runnable : Array[MoonFlowItemProjection] = []
  for item_id in run.runnable_item_ids {
    match moonflow_item_by_id(run, item_id) {
      Some(item) => runnable.push(item)
      None => ()
    }
  }
  section(
    class="flow-handoff-section",
    attrs=@html.Attrs::build()
      .data_set("testid", "flow-graph-continuation")
      .data_set("run-id", run.run_id),
    [
      div(class="flow-section-heading", [
        h3("Graph-derived continuation"),
        small("Runnable projection items · \{runnable.length()}"),
      ]),
      if runnable.is_empty() {
        p(
          class="flow-quiet",
          if run.outcome == "accepted" {
            "The projection is complete; it publishes no further runnable item."
          } else {
            "The projection publishes no runnable item. Review blockers and acceptance state."
          },
        )
      } else {
        div(
          class="flow-handoff-grid",
          runnable.map(item => {
            render_flow_continuation_card(
              item.product_id,
              item.operation,
              item.declaration_id,
              item.status,
              "authority " +
              item.requested_authority +
              " · claim " +
              item.required_claim,
            )
          }),
        )
      },
    ],
  )
}

///|
fn render_moonflow_runtime_evidence(
  run : MoonFlowRunProjection,
) -> @rabbita.Html {
  section(class="flow-section flow-contract", [
    h3("Runtime evidence"),
    match run.autonomy_binding {
      Some(binding) if moonflow_autonomy_evidence_available(binding) => {
        let envelope = binding.envelope
        div(class="flow-contract-grid", [
          div([span("Autonomy binding"), strong(binding.contract_id)]),
          div([span("Bound run"), strong(binding.run_id)]),
          div([span("Usage evidence"), strong(binding.usage_ref)]),
          div([span("Binding recorded"), strong(binding.recorded_at)]),
          div([span("Envelope expires"), strong(envelope.expires_at)]),
          div([
            span("Storage budget"),
            strong(
              moonflow_budget_label(
                binding.usage.storage_bytes,
                envelope.budget.storage_bytes,
              ),
            ),
          ]),
          div([
            span("Concurrency"),
            strong(
              moonflow_budget_label(
                binding.usage.concurrency,
                envelope.budget.concurrency,
              ),
            ),
          ]),
        ])
      }
      _ =>
        p(
          class="flow-evidence-unavailable",
          "Autonomy binding evidence unavailable.",
        )
    },
    match run.intervention_scorecard {
      Some(scorecard) if moonflow_scorecard_evidence_available(scorecard) =>
        div(class="flow-contract-grid", [
          div([span("Intervention record"), strong(scorecard.contract_id)]),
          div([span("Intervention run"), strong(scorecard.run_id)]),
          div([
            span("Hidden orchestration"),
            strong(scorecard.hidden_orchestration_count.to_string()),
          ]),
          div([
            span("Normal-path manual work"),
            strong(scorecard.normal_path_manual_count.to_string()),
          ]),
          div([span("Scorecard recorded"), strong(scorecard.recorded_at)]),
        ])
      _ =>
        p(
          class="flow-evidence-unavailable",
          "Intervention scorecard evidence unavailable.",
        )
    },
    match run.run_control {
      Some(control) if moonflow_control_evidence_available(control) =>
        div(class="flow-contract-grid", [
          div([span("Control record"), strong(control.contract_id)]),
          div([span("Control run"), strong(control.run_id)]),
          div([
            span("Control reason"),
            strong(if control.reason == "" { "none" } else { control.reason }),
          ]),
          div([span("Control recorded"), strong(control.recorded_at)]),
        ])
      _ =>
        p(
          class="flow-evidence-unavailable",
          "Run-control evidence unavailable.",
        )
    },
  ])
}

///|
fn moonflow_autonomy_evidence_available(
  binding : MoonFlowAutonomyBinding,
) -> Bool {
  !binding.contract_id.is_empty() &&
  !binding.envelope.envelope_id.is_empty() &&
  !binding.recorded_at.is_empty()
}

///|
fn moonflow_scorecard_evidence_available(
  scorecard : MoonFlowInterventionScorecard,
) -> Bool {
  !scorecard.contract_id.is_empty() && !scorecard.recorded_at.is_empty()
}

///|
fn moonflow_control_evidence_available(control : MoonFlowRunControl) -> Bool {
  !control.contract_id.is_empty() && !control.recorded_at.is_empty()
}

///|
fn render_moonflow_controls(
  dispatch : Dispatch[Msg],
  run : MoonFlowRunProjection,
) -> @rabbita.Html {
  match run.run_control {
    Some(control) if moonflow_control_evidence_available(control) => {
      let terminal = run.outcome == "accepted" ||
        run.outcome == "blocked" ||
        run.outcome == "failed" ||
        control.state == "cancelled"
      section(class="flow-section flow-controls", [
        div(class="flow-section-heading", [
          div([
            h3("Bounded intervention"),
            small("Current state · " + control.state),
          ]),
          span(
            class="flow-state " +
              (if control.state == "paused" {
                "blocked"
              } else {
                "in-progress"
              }),
            if control.authority_ceiling.is_empty() {
              "ceiling unavailable"
            } else {
              "≤ " + control.authority_ceiling
            },
          ),
        ]),
        div(class="flow-control-actions", [
          if terminal {
            @html.nothing
          } else if control.state == "paused" {
            button(
              class="secondary-button",
              on_click=dispatch(ControlMoonFlow(run.run_id, "resume", "")),
              "Resume",
            )
          } else {
            button(
              class="secondary-button",
              on_click=dispatch(
                ControlMoonFlow(
                  run.run_id,
                  "pause",
                  "operator requested inspection",
                ),
              ),
              "Pause",
            )
          },
          if terminal || control.authority_ceiling == "observe" {
            @html.nothing
          } else {
            button(
              class="secondary-button",
              on_click=dispatch(
                ControlMoonFlow(run.run_id, "narrow-authority", "observe"),
              ),
              "Narrow to observe",
            )
          },
          if terminal {
            @html.nothing
          } else {
            button(
              class="secondary-button danger-button",
              on_click=dispatch(
                ControlMoonFlow(
                  run.run_id,
                  "cancel",
                  "operator cancelled from MoonDesk",
                ),
              ),
              "Cancel run",
            )
          },
        ]),
        small(
          class="flow-quiet",
          "Controls cannot widen the envelope. Cancel is terminal; pause and narrowed authority are durable across restarts.",
        ),
      ])
    }
    _ =>
      section(class="flow-section flow-controls", [
        h3("Bounded intervention"),
        p(
          class="flow-evidence-unavailable",
          "Run-control evidence unavailable. MoonDesk will not offer controls without a persisted control record.",
        ),
      ])
  }
}

///|
fn render_moonflow_authority(run : MoonFlowRunProjection) -> @rabbita.Html {
  match run.autonomy_binding {
    Some(binding) if moonflow_autonomy_evidence_available(binding) => {
      let envelope = binding.envelope
      let authority_state = if envelope.revoked {
        "Revoked"
      } else {
        "Bound · " + envelope.mode
      }
      let scorecard = match run.intervention_scorecard {
        Some(value) if moonflow_scorecard_evidence_available(value) =>
          Some(value)
        _ => None
      }
      section(class="flow-section flow-authority", [
        div(class="flow-section-heading", [
          div([h3("Autonomy envelope"), small(authority_state)]),
          match scorecard {
            Some(value) =>
              span(
                class="flow-state " +
                  (if value.unattended_qualified {
                    "complete"
                  } else {
                    "in-progress"
                  }),
                if value.unattended_qualified {
                  "unattended qualified"
                } else {
                  "not unattended-qualified"
                },
              )
            None =>
              span(
                class="flow-state blocked",
                "qualification evidence unavailable",
              )
          },
        ]),
        div(class="flow-authority-grid", [
          div([
            span("Envelope"),
            strong(moonflow_short_identity(envelope.envelope_id)),
          ]),
          div([
            span("Effects"),
            strong(
              if envelope.external_effects_allowed ||
                envelope.physical_effects_allowed {
                "Expanded authority"
              } else {
                "Workspace + simulation only"
              },
            ),
          ]),
          div([
            span("Model tokens"),
            strong(
              moonflow_budget_label(
                binding.usage.model_tokens,
                envelope.budget.model_tokens,
              ),
            ),
          ]),
          div([
            span("Tool calls"),
            strong(
              moonflow_budget_label(
                binding.usage.tool_calls,
                envelope.budget.tool_calls,
              ),
            ),
          ]),
          div([
            span("Attempts"),
            strong(
              moonflow_budget_label(
                binding.usage.attempts,
                envelope.budget.attempts,
              ),
            ),
          ]),
          div([
            span("Human interventions"),
            strong(
              match scorecard {
                Some(value) => value.required_intervention_count.to_string()
                None => "Unavailable"
              },
            ),
          ]),
        ]),
        match scorecard {
          Some(value) if !value.finalization_findings.is_empty() =>
            p(
              class="flow-authority-finding",
              value.finalization_findings.join(" · "),
            )
          Some(_) => @html.nothing
          None =>
            p(
              class="flow-evidence-unavailable",
              "Intervention scorecard evidence unavailable.",
            )
        },
      ])
    }
    _ =>
      section(class="flow-section flow-authority", [
        div(class="flow-section-heading", [
          div([h3("Autonomy envelope"), small("Unavailable")]),
          span(class="flow-state blocked", "evidence unavailable"),
        ]),
        p(
          class="flow-evidence-unavailable",
          "No persisted autonomy binding was published for this run.",
        ),
      ])
  }
}

///|
fn render_moonflow_claim_coverage(run : MoonFlowRunProjection) -> @rabbita.Html {
  let claims : Array[String] = []
  for item in run.items {
    if !item.required_claim.is_empty() && !claims.contains(item.required_claim) {
      claims.push(item.required_claim)
    }
  }
  section(class="flow-section", [
    h3("Declared claim coverage"),
    if claims.is_empty() {
      p(class="flow-quiet", "Required claim evidence is unavailable.")
    } else {
      div(
        class="flow-readiness",
        claims.map(claim => {
          let matching = run.items.filter(item => item.required_claim == claim)
          let accepted = matching
            .filter(item => item.status == "accepted")
            .length()
          div(
            class=if accepted == matching.length() { "achieved" } else { "" },
            [
              span(if accepted == matching.length() { "✓" } else { "·" }),
              strong(claim),
              small("\{accepted} / \{matching.length()} accepted"),
            ],
          )
        }),
      )
    },
    small(
      class="flow-quiet",
      "Claims come from the imported graph. A product name alone never establishes readiness.",
    ),
  ])
}

///|
fn render_moonflow_next_actions(run : MoonFlowRunProjection) -> @rabbita.Html {
  section(class="flow-section", [
    h3("Next actions"),
    if run.outcome == "accepted" {
      p(
        class="flow-quiet",
        "Run complete. Every work item reached accepted state.",
      )
    } else if run.runnable_item_ids.is_empty() {
      p(
        class="flow-quiet",
        "No item is ready. Review blockers or wait for acceptance.",
      )
    } else {
      div(
        class="flow-action-list",
        run.runnable_item_ids.map(item_id => {
          match moonflow_item_by_id(run, item_id) {
            Some(item) =>
              div(class="flow-action", [
                strong(item.work_item_id),
                span("Run with " + item.product_id),
              ])
            None => @html.nothing
          }
        }),
      )
    },
  ])
}

///|
fn render_moonflow_blockers(run : MoonFlowRunProjection) -> @rabbita.Html {
  let blockers = run.items.filter(item => item.status == "blocked")
  if blockers.is_empty() {
    @html.nothing
  } else {
    section(class="flow-section flow-blockers", [
      h3("Needs attention"),
      div(
        class="flow-action-list",
        blockers.map(item => {
          div(class="flow-action", [
            strong(item.work_item_id),
            span(
              if item.blocker == "" {
                "Blocked without a recorded reason"
              } else {
                item.blocker
              },
            ),
          ])
        }),
      ),
    ])
  }
}

///|
fn moonflow_item_execution_label(item : MoonFlowItemProjection) -> String {
  if item.attempt_status == "checkpoint-reused" {
    "checkpoint reused"
  } else {
    "attempt \{item.attempt_count}"
  }
}

///|
fn moonflow_run_item_binding_status(item : MoonFlowItemProjection) -> String {
  if moonflow_optional_evidence(item.adapter_id, "").is_empty() ||
    moonflow_optional_evidence(item.claim_ceiling, "").is_empty() ||
    item.review_required is None {
    "Catalog binding unavailable"
  } else if moonflow_optional_evidence(item.health_evidence_ref, "").is_empty() ||
    moonflow_optional_evidence(item.health_evidence_digest, "").is_empty() {
    "Catalog health unavailable"
  } else {
    "Catalog health published"
  }
}

///|
fn render_moonflow_item(item : MoonFlowItemProjection) -> @rabbita.Html {
  let relationship = if item.depends_on.is_empty() {
    "No dependencies"
  } else {
    "\{item.depends_on.length()} dependency item(s)"
  }
  let review_evidence = if item.approvals.is_empty() {
    "no approval"
  } else {
    "\{item.approvals.length()} approval(s)"
  }
  let execution = moonflow_item_execution_label(item)
  div(class="flow-item", [
    div(class="flow-item-main", [
      div(class="flow-item-title", [
        strong(item.work_item_id),
        span(class="flow-item-status " + item.status, item.status),
      ]),
      small(
        item.product_id +
        " owns " +
        (if item.operation == "" { "declared work" } else { item.operation }) +
        " · " +
        relationship +
        " · " +
        execution +
        " · " +
        review_evidence,
      ),
      p(class="flow-item-why", moonflow_item_explanation(item)),
      div(class="flow-item-contract", [
        span("Declaration " + item.declaration_id),
        span("Operation " + item.operation),
        span("Input " + moonflow_contract_refs(item.input_contracts)),
        span("Output " + moonflow_contract_refs(item.output_contracts)),
        span("Authority " + item.requested_authority),
        span("Required claim " + item.required_claim),
        span(
          "Request artifacts " + moonflow_contract_refs(item.input_artifacts),
        ),
        span("Timeout \{item.timeout_ms} ms"),
        span(
          "Claim ceiling " +
          moonflow_optional_evidence(item.claim_ceiling, "Unavailable"),
        ),
        span(
          if moonflow_optional_evidence(item.adapter_id, "").is_empty() {
            "Review requirement unavailable"
          } else {
            match item.review_required {
              Some(true) => "Named review required"
              Some(false) => "No manifest review requirement"
              None => "Review requirement unavailable"
            }
          },
        ),
        span(
          "Adapter " +
          moonflow_optional_evidence(item.adapter_id, "Unavailable"),
        ),
        span(moonflow_run_item_binding_status(item)),
        span(
          "Health checked " +
          moonflow_optional_evidence(item.health_checked_at, "Unavailable"),
        ),
        span(
          "Health valid until " +
          moonflow_optional_evidence(item.health_valid_until, "Unavailable"),
        ),
        span(
          "Health evidence " +
          moonflow_optional_evidence(item.health_evidence_ref, "Unavailable"),
        ),
        span(
          "Health digest " +
          moonflow_short_identity(
            moonflow_optional_evidence(item.health_evidence_digest, ""),
          ),
        ),
        span(
          "\{item.acceptance_criteria.length()} acceptance criterion/criteria",
        ),
      ]),
    ]),
    div(class="flow-evidence-lane", [
      span("Evidence"),
      strong(
        if item.artifacts.is_empty() {
          "None attached"
        } else {
          "\{item.artifacts.length()} artifact(s)"
        },
      ),
      small("input " + moonflow_short_identity(item.input_digest)),
      small("output " + moonflow_short_identity(item.output_digest)),
      small(
        "attempt " +
        (if item.attempt_status == "" {
          "not started"
        } else {
          item.attempt_status
        }) +
        (if item.compensable { " · reversible" } else { "" }),
      ),
      small(
        if item.request_id == "" {
          "request not submitted"
        } else {
          "request " + moonflow_short_identity(item.request_id)
        },
      ),
      small(
        if item.result_id == "" {
          "result pending"
        } else {
          "result " + moonflow_short_identity(item.result_id)
        },
      ),
      small(
        if item.external_job_id != "" {
          "external job " + moonflow_short_identity(item.external_job_id)
        } else if item.active_attempt_id != "" {
          "active attempt " + moonflow_short_identity(item.active_attempt_id)
        } else {
          "attempt identity not recorded"
        },
      ),
      small(
        if item.idempotency_key == "" {
          "retry identity not recorded"
        } else {
          "retry " + moonflow_short_identity(item.idempotency_key)
        },
      ),
      small(
        if item.acceptance_review_id == "" {
          "review not recorded"
        } else {
          "review " + item.acceptance_review_id
        },
      ),
      small(
        if item.acceptance_reviewer_id == "" {
          "review authority not recorded"
        } else {
          "by " + item.acceptance_reviewer_id
        },
      ),
      small(
        if item.acceptance_review_artifact == "" {
          "review evidence not attached"
        } else {
          item.acceptance_review_artifact
        },
      ),
    ]),
  ])
}
