///|
fn moonflow_owner_summary_matches(run : MoonFlowRunProjection) -> Bool {
  guard run.owner_summary is Some(value) else { return false }
  if value.contract_id != "moonflow.owner-summary.v1" ||
    value.run_id != run.run_id ||
    value.book_id != run.book_id ||
    value.declaration_revision != run.declaration_revision ||
    value.source_digest != run.source_digest ||
    value.last_sequence != run.last_sequence ||
    value.outcome != run.outcome ||
    value.last_event_id.unwrap_or("").is_empty() ||
    value.recorded_at.unwrap_or("").is_empty() ||
    value.evidence.length() != run.items.length() {
    return false
  }
  for index, item in run.items {
    let evidence = value.evidence[index]
    if evidence.work_item_id != item.work_item_id ||
      evidence.attempt_id != item.active_attempt_id ||
      evidence.result_id != item.result_id ||
      evidence.output_digest != item.output_digest ||
      evidence.artifacts != item.artifacts ||
      evidence.review_id != item.acceptance_review_id ||
      evidence.review_artifact != item.acceptance_review_artifact ||
      evidence.reviewer_id != item.acceptance_reviewer_id {
      return false
    }
  }
  let action_ids : Array[String] = []
  for action in value.actions {
    guard moonflow_item_by_id(run, action.work_item_id) is Some(item) else {
      return false
    }
    let status = if item.attempt_status == "unknown" {
      "unknown"
    } else {
      item.status
    }
    if item.status == "accepted" ||
      action.status != status ||
      action.product_id != item.product_id ||
      action_ids.contains(action.work_item_id) {
      return false
    }
    action_ids.push(action.work_item_id)
  }
  action_ids.length() ==
  run.items.filter(item => item.status != "accepted").length()
}

///|
fn moonflow_owner_unavailable(
  model : Model,
  run : MoonFlowRunProjection,
) -> String? {
  if model.moonflow_runs_state is Some(Loading) {
    Some(
      "Refreshing the observation; wait before acting on earlier work status",
    )
  } else if model.moonflow_runs_state is Some(Stale | RecoverableError) {
    Some("Refresh the run before relying on this earlier observation")
  } else if !moonflow_owner_summary_matches(run) {
    Some(
      "A matching next-action summary is unavailable; refresh or inspect the retained run evidence",
    )
  } else if run.owner_summary_observation != Some("event-head-matched") {
    Some(
      "The event head could not be verified; refresh or inspect the retained run evidence",
    )
  } else {
    None
  }
}

///|
fn render_moonflow_owner_evidence(
  dispatch : Dispatch[Msg],
  model : Model,
  run : MoonFlowRunProjection,
  item_id : String,
) -> @rabbita.Html {
  guard run.owner_summary is Some(value) else { return @html.nothing }
  guard value.evidence
    .filter(evidence => evidence.work_item_id == item_id)
    .get(0)
    is Some(evidence) else {
    return @html.nothing
  }
  div(class="flow-item-contract", [
    strong("Exact retained evidence"),
    span("Attempt " + evidence.attempt_id + " · result " + evidence.result_id),
    span("Output identity " + evidence.output_digest),
    if evidence.artifacts.is_empty() {
      span("No retained artifacts recorded")
    } else {
      match moonflow_item_by_id(run, item_id) {
        Some(item) =>
          render_moonflow_retained_references(dispatch, model, run, item)
        None => div(evidence.artifacts.map(reference => code(reference)))
      }
    },
    if evidence.review_artifact.is_empty() {
      span("No internal review receipt recorded")
    } else {
      div([
        code(evidence.review_artifact),
        span(
          "Review " +
          evidence.review_id +
          " · reviewer " +
          evidence.reviewer_id,
        ),
      ])
    },
  ])
}

///|
fn render_moonflow_owner_summary(
  dispatch : Dispatch[Msg],
  model : Model,
  run : MoonFlowRunProjection,
) -> @rabbita.Html {
  match moonflow_owner_unavailable(model, run) {
    Some(reason) =>
      section(class="flow-section flow-owner-summary", [
        h3("Check the current next action"),
        p(reason),
        button(
          class="secondary-button",
          on_click=dispatch(SelectWorkspaceMode(MoonFlow)),
          "Refresh work status",
        ),
        small("Earlier observations and controls remain in the details below"),
      ])
    None => {
      guard run.owner_summary is Some(value) else { return @html.nothing }
      section(
        class="flow-section flow-owner-summary",
        attrs=@html.Attrs::build().data_set("testid", "moonflow-owner-summary"),
        [
          h3(value.next_action),
          p(value.outcome_label),
          small(
            "Next role: " +
            value.next_role.unwrap_or("not recorded") +
            " · owner: " +
            value.next_actor_id.unwrap_or("unknown"),
          ),
          div(
            class="flow-action-list",
            value.actions.map(action => {
              details(class="flow-disclosure", [
                summary(action.work_item_id + " · " + action.action),
                div(class="flow-disclosure-body", [
                  p(
                    "Next role: " +
                    action.next_role.unwrap_or("not recorded") +
                    " · owner: " +
                    action.next_actor_id.unwrap_or("unknown"),
                  ),
                  div(action.reasons.map(reason => p(reason))),
                  if action.depends_on.is_empty() {
                    @html.nothing
                  } else {
                    small(
                      "Dependency order: " + action.depends_on.join(" → "),
                    )
                  },
                  render_moonflow_owner_evidence(
                    dispatch,
                    model,
                    run,
                    action.work_item_id,
                  ),
                  match moonflow_item_by_id(run, action.work_item_id) {
                    Some(item) => render_moonflow_item(item)
                    None => @html.nothing
                  },
                ]),
              ])
            }),
          ),
          details(class="flow-disclosure", [
            summary("Observation and accepted-work evidence"),
            div(class="flow-disclosure-body", [
              p(
                "Revision " +
                value.declaration_revision +
                " · sequence " +
                value.last_sequence.to_string(),
              ),
              code("Run " + value.run_id + " · source " + value.source_digest),
              code(
                "Event " +
                value.last_event_id.unwrap_or("unknown") +
                " · recorded " +
                value.recorded_at.unwrap_or("unknown"),
              ),
              p(
                "Matches the event head read by the host; this is an observation, not a live-status guarantee",
              ),
              div(
                run.items
                .filter(item => item.status == "accepted")
                .map(item => {
                  render_moonflow_owner_evidence(
                    dispatch,
                    model,
                    run,
                    item.work_item_id,
                  )
                }),
              ),
            ]),
          ]),
          small(value.acceptance_boundary),
        ],
      )
    }
  }
}
