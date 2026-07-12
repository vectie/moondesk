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
fn render_moonflow_workspace(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
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
    if model.moonflow_runs.is_empty() {
      section(class="flow-empty", [
        strong("No executable work yet"),
        p(
          "Compile an executable MoonBook document, then import its Work graph into MoonFlow.",
        ),
        button(
          class="primary-button",
          on_click=dispatch(SelectWorkspaceMode(MoonWiki)),
          "Open Wiki",
        ),
        small(model.moonflow_status),
      ])
    } else {
      section(
        class="flow-run-list",
        model.moonflow_runs.map(run => render_moonflow_run(dispatch, run)),
      )
    },
  ])
}

///|
fn render_moonflow_run(
  dispatch : Dispatch[Msg],
  run : MoonFlowRunProjection,
) -> @rabbita.Html {
  let accepted = moonflow_count_status(run, "accepted")
  let blocked = moonflow_count_status(run, "blocked")
  section(class="flow-run-card", [
    header(class="flow-run-head", [
      div([
        p(class="eyebrow", "Run · sequence \{run.last_sequence}"),
        h2(run.run_id),
        small(
          run.book_id +
          " · revision " +
          run.declaration_revision +
          " · source " +
          moonflow_short_identity(run.source_digest),
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
    render_moonflow_authority(run),
    render_moonflow_controls(dispatch, run),
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
    section(class="flow-section flow-contract", [
      h3("Executable document contract"),
      div(class="flow-contract-grid", [
        div([span("Protocol"), strong(run.protocol)]),
        div([span("MoonBook"), strong(run.book_id)]),
        div([span("Declaration revision"), strong(run.declaration_revision)]),
        div([
          span("Source identity"),
          strong(moonflow_short_identity(run.source_digest)),
        ]),
      ]),
    ]),
    div(
      class="flow-item-list",
      run.items.map(item => render_moonflow_item(item)),
    ),
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
