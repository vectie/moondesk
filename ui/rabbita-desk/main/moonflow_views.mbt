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
  if run.outcome != "" {
    "complete"
  } else if moonflow_count_status(run, "blocked") > 0 {
    "blocked"
  } else if !run.runnable_item_ids.is_empty() {
    "ready"
  } else {
    "in-progress"
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
          "Outcomes first. Work advances only through explicit evidence and acceptance.",
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
        model.moonflow_runs.map(run => render_moonflow_run(run)),
      )
    },
  ])
}

///|
fn render_moonflow_run(run : MoonFlowRunProjection) -> @rabbita.Html {
  let accepted = moonflow_count_status(run, "accepted")
  let blocked = moonflow_count_status(run, "blocked")
  section(class="flow-run-card", [
    header(class="flow-run-head", [
      div([
        p(class="eyebrow", "Run · sequence \{run.last_sequence}"),
        h2(run.run_id),
        small(run.protocol),
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
    if run.outcome == "" {
      p(class="flow-outcome pending", "Outcome pending")
    } else {
      p(class="flow-outcome", run.outcome)
    },
    render_moonflow_next_actions(run),
    render_moonflow_blockers(run),
    div(
      class="flow-item-list",
      run.items.map(item => render_moonflow_item(item)),
    ),
  ])
}

///|
fn render_moonflow_next_actions(run : MoonFlowRunProjection) -> @rabbita.Html {
  section(class="flow-section", [
    h3("Next actions"),
    if run.outcome != "" {
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
  div(class="flow-item", [
    div([
      strong(item.work_item_id),
      small(
        item.product_id +
        " · " +
        relationship +
        " · attempt \{item.attempt_count} · " +
        validation,
      ),
    ]),
    span(class="flow-item-status " + item.status, item.status),
    small(
      if item.artifacts.is_empty() {
        "No evidence attached"
      } else {
        "\{item.artifacts.length()} evidence artifact(s)"
      },
    ),
  ])
}
