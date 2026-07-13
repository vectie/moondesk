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
fn moonflow_product_accepted(
  run : MoonFlowRunProjection,
  product : String,
) -> Bool {
  run.items.any(item => item.product_id == product && item.status == "accepted")
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
fn render_moonflow_workspace(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let selected_runs = moonflow_selected_runs(model)
  main_(class="flow-main", [
    section(class="flow-hero", [
      div([
        p(class="eyebrow", "Executable work"),
        h1("MoonFlow"),
        p(
          class="lead",
          "An executable document in motion: declarations become governed work, evidence, review, and reusable learning.",
        ),
      ]),
      button(
        class="secondary-button",
        on_click=dispatch(SelectWorkspaceMode(MoonFlow)),
        "Refresh",
      ),
    ]),
    if selected_runs.is_empty() {
      section(class="flow-empty", [
        strong("No executable work yet"),
        p(
          "Prepare the selected MoonBook's executable document and import its Work graph into MoonFlow.",
        ),
        button(
          class="primary-button",
          attrs=@html.Attrs::build().data_set(
            "testid", "moonflow-prepare-selected",
          ),
          disabled=model.selected_workspace_id == "",
          on_click=dispatch(PrepareMoonFlow),
          "Prepare selected MoonBook",
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
        render_moonflow_handoffs(
          dispatch,
          model,
          "not started",
          model.selected_workspace_id,
        ),
      ])
    } else {
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
              "Prepare the selected MoonBook again after its declarations change. Existing runs remain immutable.",
            ),
          ]),
          button(
            class="secondary-button",
            attrs=@html.Attrs::build().data_set(
              "testid", "moonflow-prepare-selected",
            ),
            disabled=model.selected_workspace_id == "" ||
              model.moonflow_status.contains("Preparing executable work"),
            on_click=dispatch(PrepareMoonFlow),
            "Prepare latest MoonBook revision",
          ),
          small("\{selected_runs.length()} revision(s) for this MoonBook"),
        ]),
        section(class="flow-run-list", run_children),
      ])
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
    render_moonflow_next_actions(run),
    render_moonflow_blockers(run),
    render_moonflow_readiness(run),
    render_moonflow_handoffs(dispatch, model, run.run_id, run.book_id),
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
fn moonsuite_product_available(model : Model, product_name : String) -> Bool {
  model.moonsuite_products.any(product => {
    product.name.to_lower() == product_name.to_lower() &&
    (product.status == "installed" || product.status == "enabled")
  })
}

///|
fn render_moonflow_handoffs(
  dispatch : Dispatch[Msg],
  model : Model,
  run_id : String,
  book_id : String,
) -> @rabbita.Html {
  let book_label = if book_id == "" { "not selected" } else { book_id }
  let town_available = moonsuite_product_available(model, "MoonTown")
  section(
    class="flow-handoff-section",
    attrs=@html.Attrs::build()
      .data_set("testid", "flow-capability-handoffs")
      .data_set("book-id", book_id)
      .data_set("run-id", run_id),
    [
      div(class="flow-section-heading", [
        h3("Continue across the suite"),
        small("MoonBook " + book_label + " · run " + run_id),
      ]),
      div(class="flow-handoff-grid", [
        render_flow_handoff_card(
          "MoonTown",
          "Deliberate, compare proposals, and promote implementation criteria.",
          if town_available {
            "Available"
          } else {
            "Adapter pending"
          },
          button(
            class="secondary-button compact-button",
            disabled=book_id == "" || !town_available,
            on_click=dispatch(SelectActivity(Town)),
            if town_available {
              "Open Town"
            } else {
              "Town adapter pending"
            },
          ),
        ),
        render_flow_handoff_card(
          "MoonRobo",
          "Build and validate against the accepted run criteria.",
          if moonsuite_product_available(model, "MoonRobo") {
            "Installed · handoff pending"
          } else {
            "Adapter pending"
          },
          span(
            class="flow-handoff-note",
            "Keeps this MoonBook and run selected",
          ),
        ),
        render_flow_handoff_card(
          "MoonMoon",
          "Simulate the accepted robot and return uncertainty evidence.",
          if moonsuite_product_available(model, "MoonMoon") {
            "Installed · handoff pending"
          } else {
            "Adapter pending"
          },
          span(class="flow-handoff-note", "No deployment authority granted"),
        ),
        render_flow_handoff_card(
          "MoonMold",
          "Create governed 3D artifacts for Town, Robo, simulation, or fabrication.",
          if moonsuite_product_available(model, "MoonMold") {
            "Installed · handoff pending"
          } else {
            "Adapter pending"
          },
          span(
            class="flow-handoff-note",
            "Physical export remains approval-gated",
          ),
        ),
      ]),
    ],
  )
}

///|
fn render_flow_handoff_card(
  name : String,
  description : String,
  status : String,
  action : @rabbita.Html,
) -> @rabbita.Html {
  section(class="flow-handoff-card", [
    div([strong(name), span(class="flow-handoff-status", status)]),
    p(description),
    action,
  ])
}

///|
fn render_moonflow_runtime_evidence(
  run : MoonFlowRunProjection,
) -> @rabbita.Html {
  let binding = run.autonomy_binding
  let envelope = binding.envelope
  let scorecard = run.intervention_scorecard
  let control = run.run_control
  section(class="flow-section flow-contract", [
    h3("Runtime evidence"),
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
      div([span("Control record"), strong(control.contract_id)]),
      div([span("Control run"), strong(control.run_id)]),
      div([
        span("Control reason"),
        strong(if control.reason == "" { "none" } else { control.reason }),
      ]),
      div([span("Control recorded"), strong(control.recorded_at)]),
    ]),
  ])
}

///|
fn render_moonflow_controls(
  dispatch : Dispatch[Msg],
  run : MoonFlowRunProjection,
) -> @rabbita.Html {
  let control = run.run_control
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
          (if control.state == "paused" { "blocked" } else { "in-progress" }),
        if control.authority_ceiling.is_empty() {
          "envelope ceiling"
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

///|
fn render_moonflow_authority(run : MoonFlowRunProjection) -> @rabbita.Html {
  let binding = run.autonomy_binding
  let envelope = binding.envelope
  let scorecard = run.intervention_scorecard
  let authority_state = if envelope.envelope_id == "" {
    "Not bound"
  } else if envelope.revoked {
    "Revoked"
  } else {
    "Bound · " + envelope.mode
  }
  section(class="flow-section flow-authority", [
    div(class="flow-section-heading", [
      div([h3("Autonomy envelope"), small(authority_state)]),
      span(
        class="flow-state " +
          (if scorecard.unattended_qualified {
            "complete"
          } else {
            "in-progress"
          }),
        if scorecard.unattended_qualified {
          "unattended qualified"
        } else {
          "qualification pending"
        },
      ),
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
        strong("\{scorecard.required_intervention_count}"),
      ]),
    ]),
    if scorecard.finalization_findings.is_empty() {
      @html.nothing
    } else {
      p(
        class="flow-authority-finding",
        scorecard.finalization_findings.join(" · "),
      )
    },
  ])
}

///|
fn render_moonflow_readiness(run : MoonFlowRunProjection) -> @rabbita.Html {
  let stages : Array[(String, Bool)] = [
    ("Evidence", moonflow_product_accepted(run, "moonwiki")),
    ("Deliberated", moonflow_product_accepted(run, "moontown")),
    ("Digital model", moonflow_product_accepted(run, "moonrobo")),
    ("Scenario", moonflow_product_accepted(run, "moonmoon")),
    ("Bookkeeper", moonflow_product_accepted(run, "moonbook")),
    ("Physical", false),
  ]
  section(class="flow-section", [
    h3("Claim and readiness ladder"),
    div(
      class="flow-readiness",
      stages.map(stage => {
        let (label, achieved) = stage
        div(class=if achieved { "achieved" } else { "" }, [
          span(if achieved { "✓" } else { "·" }),
          strong(label),
        ])
      }),
    ),
    small(
      class="flow-quiet",
      "Physical construction, launch, deployment, and physical readiness remain outside this envelope.",
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
fn render_moonflow_item(item : MoonFlowItemProjection) -> @rabbita.Html {
  let relationship = if item.depends_on.is_empty() {
    "No dependencies"
  } else {
    "\{item.depends_on.length()} dependency item(s)"
  }
  let validation = if item.approvals.is_empty() {
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
        validation,
      ),
      p(class="flow-item-why", moonflow_item_explanation(item)),
      div(class="flow-item-contract", [
        span("Declaration " + item.declaration_id),
        span("Authority " + item.requested_authority),
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
