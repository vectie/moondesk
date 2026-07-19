///|
struct MoonFlowOperatorRowView {
  identity : String
  state : String
  primary : String
  secondary : String
  evidence_refs : Array[String]
  needs_attention : Bool
}

///|
fn moonflow_operator_text(value : String?, fallback : String) -> String {
  match value {
    Some(text) if !text.trim().is_empty() => text
    _ => fallback
  }
}

///|
fn moonflow_operator_int(value : Int?, fallback : String) -> String {
  match value {
    Some(number) => number.to_string()
    None => fallback
  }
}

///|
fn moonflow_operator_refs(value : Array[String]?) -> Array[String] {
  match value {
    Some(refs) => refs
    None => []
  }
}

///|
fn moonflow_operator_parts(parts : Array[String]) -> String {
  let visible = parts.filter(value => !value.trim().is_empty())
  if visible.is_empty() {
    "No further detail recorded"
  } else {
    visible.join(" · ")
  }
}

///|
fn moonflow_operator_state_class(state : String) -> String {
  match state.to_lower() {
    "accepted" | "adopted" | "complete" | "completed" | "delivered" |
    "resolved" | "succeeded" => "accepted"
    "blocked" | "escalated" | "exhausted" | "failed" | "overdue" |
    "quarantined" | "rejected" => "blocked"
    "active" | "evaluating" | "in_progress" | "pending" | "review" |
    "revising" => "review"
    _ => ""
  }
}

///|
fn render_moonflow_operator_row(row : MoonFlowOperatorRowView) -> @rabbita.Html {
  div(class="flow-item", [
    div(class="flow-item-main", [
      div(class="flow-item-title", [
        strong(row.identity),
        span(
          class="flow-item-status " + moonflow_operator_state_class(row.state),
          row.state,
        ),
      ]),
      p(class="flow-item-why", row.primary),
      small(row.secondary),
    ]),
    div(class="flow-evidence-lane", [
      span(if row.needs_attention { "Needs attention" } else { "Evidence" }),
      strong(
        if row.evidence_refs.is_empty() {
          "No reference published"
        } else {
          "\{row.evidence_refs.length()} reference(s)"
        },
      ),
      if row.evidence_refs.is_empty() {
        @html.nothing
      } else {
        small(row.evidence_refs.map(moonflow_short_identity).join(" · "))
      },
    ]),
  ])
}

///|
fn render_moonflow_operator_category(
  title : String,
  rows : Array[MoonFlowOperatorRowView],
) -> @rabbita.Html {
  if rows.is_empty() {
    @html.nothing
  } else {
    section(class="flow-section", [
      div(class="flow-section-heading", [
        h3(title),
        small("\{rows.length()} recorded"),
      ]),
      div(
        class="flow-item-list",
        rows.map(row => render_moonflow_operator_row(row)),
      ),
    ])
  }
}

///|
fn moonflow_recovery_operator_rows(
  recovery : MoonFlowRecoveryOperatorProjection?,
) -> Array[MoonFlowOperatorRowView] {
  match recovery {
    None => []
    Some(value) => {
      let manual = value.manual_intervention.unwrap_or(false)
      [
        {
          identity: "Recovery · " +
            moonflow_operator_text(value.claim_id, "no active claim"),
          state: moonflow_operator_text(value.state, "not recorded"),
          primary: moonflow_operator_parts([
            "owner " + moonflow_operator_text(value.owner, "not recorded"),
            "attempt " + moonflow_operator_int(value.attempt_count, "not recorded"),
            if manual { "manual intervention required" } else { "" },
            moonflow_operator_text(value.blocker, ""),
          ]),
          secondary: moonflow_operator_parts([
            "next due " + moonflow_operator_text(value.next_due_at, "not recorded"),
            "deadline " + moonflow_operator_text(value.deadline, "not recorded"),
            "expires " + moonflow_operator_text(value.expires_at, "not recorded"),
            "epoch " + moonflow_operator_int(value.epoch, "not recorded"),
            "fence " + moonflow_operator_int(value.fence, "not recorded"),
            "unknown since " +
              moonflow_operator_text(value.unknown_since, "not recorded"),
            "reconciliation age " +
              moonflow_operator_int(
                value.reconciliation_age_seconds,
                "not recorded",
              ),
            "provider observation " +
              moonflow_operator_text(
                value.last_provider_observation_digest,
                "not recorded",
              ),
            "recorded " +
              moonflow_operator_text(value.recorded_at, "not recorded"),
          ]),
          evidence_refs: moonflow_operator_refs(value.evidence_refs),
          needs_attention: manual || value.blocker.unwrap_or("") != "",
        },
      ]
    }
  }
}

///|
fn moonflow_due_operator_rows(
  values : Array[MoonFlowDueActionOperatorProjection]?,
) -> Array[MoonFlowOperatorRowView] {
  match values {
    None => []
    Some(actions) =>
      actions.map(value => {
        let overdue = value.overdue.unwrap_or(false)
        {
          identity: moonflow_operator_text(value.action_id, "Due action"),
          state: if overdue {
            "overdue"
          } else {
            moonflow_operator_text(value.state, "not recorded")
          },
          primary: moonflow_operator_parts([
            moonflow_operator_text(value.kind, "scheduled action"),
            "due " + moonflow_operator_text(value.due_at, "not recorded"),
            "deadline " + moonflow_operator_text(value.deadline, "not recorded"),
          ]),
          secondary: moonflow_operator_parts([
            "authority " +
              moonflow_operator_text(value.authority_ref, "not recorded"),
            "source " + moonflow_operator_text(value.source_ref, "not recorded"),
          ]),
          evidence_refs: moonflow_operator_refs(value.evidence_refs),
          needs_attention: overdue,
        }
      })
  }
}

///|
fn moonflow_callback_operator_rows(
  values : Array[MoonFlowCallbackOperatorProjection]?,
) -> Array[MoonFlowOperatorRowView] {
  match values {
    None => []
    Some(callbacks) =>
      callbacks.map(value => {
        let state = moonflow_operator_text(value.state, "recorded")
        {
          identity: moonflow_operator_text(value.callback_id, "Callback"),
          state,
          primary: moonflow_operator_parts([
            moonflow_operator_text(value.disposition, "no disposition recorded"),
            moonflow_operator_text(value.reason, ""),
          ]),
          secondary: moonflow_operator_parts([
            "provider event " +
              moonflow_operator_text(value.provider_event_id, "not recorded"),
            "source " + moonflow_operator_text(value.source_at, "not recorded"),
            "received " +
              moonflow_operator_text(value.received_at, "not recorded"),
          ]),
          evidence_refs: moonflow_operator_refs(value.evidence_refs),
          needs_attention: state == "conflict" || state == "stale",
        }
      })
  }
}

///|
fn moonflow_quarantine_operator_rows(
  values : Array[MoonFlowQuarantineOperatorProjection]?,
) -> Array[MoonFlowOperatorRowView] {
  match values {
    None => []
    Some(entries) =>
      entries.map(value => {
        {
          identity: moonflow_operator_text(value.quarantine_id, "Quarantined evidence"),
          state: moonflow_operator_text(value.state, "quarantined"),
          primary: moonflow_operator_text(value.reason, "No reason published"),
          secondary: moonflow_operator_parts([
            "callback " +
              moonflow_operator_text(value.callback_ref, "not recorded"),
            "quarantined " +
              moonflow_operator_text(value.quarantined_at, "not recorded"),
          ]),
          evidence_refs: moonflow_operator_refs(value.evidence_refs),
          needs_attention: true,
        }
      })
  }
}

///|
fn moonflow_intervention_operator_rows(
  values : Array[MoonFlowManualInterventionOperatorProjection]?,
) -> Array[MoonFlowOperatorRowView] {
  match values {
    None => []
    Some(interventions) =>
      interventions.map(value => {
        let state = moonflow_operator_text(value.state, "open")
        let resolved = value.resolved_at.unwrap_or("") != "" ||
          state == "resolved" || state == "closed"
        {
          identity: moonflow_operator_text(value.intervention_id, "Manual intervention"),
          state,
          primary: moonflow_operator_parts([
            moonflow_operator_text(value.required_action, "Action not recorded"),
            moonflow_operator_text(value.reason, ""),
          ]),
          secondary: moonflow_operator_parts([
            "owner " + moonflow_operator_text(value.owner, "not assigned"),
            "opened " + moonflow_operator_text(value.opened_at, "not recorded"),
            "resolved " +
              moonflow_operator_text(value.resolved_at, "not recorded"),
            "authority " +
              moonflow_operator_text(value.authority_ref, "not recorded"),
          ]),
          evidence_refs: moonflow_operator_refs(value.evidence_refs),
          needs_attention: !resolved,
        }
      })
  }
}

///|
fn moonflow_deliverable_operator_rows(
  values : Array[MoonFlowFinalDeliverableOperatorProjection]?,
) -> Array[MoonFlowOperatorRowView] {
  match values {
    None => []
    Some(deliverables) =>
      deliverables.map(value => {
        let state = moonflow_operator_text(value.state, "submitted")
        let review_required = value.human_review_required.unwrap_or(false)
        {
          identity: moonflow_operator_text(value.candidate_id, "Deliverable candidate"),
          state,
          primary: moonflow_operator_parts([
            "decision " + moonflow_operator_text(value.decision, "not recorded"),
            moonflow_operator_text(value.blocker, ""),
            if review_required { "named human review required" } else { "" },
          ]),
          secondary: moonflow_operator_parts([
            "producer " +
              moonflow_operator_text(value.producer_version, "not recorded"),
            "ability " +
              moonflow_operator_text(value.ability_version, "not recorded"),
            "policy " +
              moonflow_operator_text(value.policy_version, "not recorded"),
            "reviewer " +
              moonflow_operator_text(value.reviewer_id, "not recorded"),
            "terminal source " +
              moonflow_operator_text(value.source_terminal_ref, "not recorded"),
            "submitted " +
              moonflow_operator_text(value.submitted_at, "not recorded"),
            "decided " +
              moonflow_operator_text(value.decided_at, "not recorded"),
          ]),
          evidence_refs: moonflow_operator_refs(value.evidence_refs),
          needs_attention: (review_required &&
            value.reviewer_id.unwrap_or("") == "") || state == "escalated" ||
            state == "revise",
        }
      })
  }
}

///|
fn moonflow_artifact_operator_rows(
  values : Array[MoonFlowArtifactOperatorProjection]?,
) -> Array[MoonFlowOperatorRowView] {
  match values {
    None => []
    Some(artifacts) =>
      artifacts.map(value => {
        {
          identity: moonflow_operator_text(value.artifact_id, "Artifact"),
          state: moonflow_operator_text(value.state, "recorded"),
          primary: moonflow_operator_parts([
            "revision " + moonflow_operator_int(value.revision, "not recorded"),
            moonflow_operator_text(value.media_type, "media type not recorded"),
            moonflow_operator_text(value.locator, "locator not published"),
          ]),
          secondary: moonflow_operator_parts([
            "digest " + moonflow_short_identity(value.digest.unwrap_or("")),
            "lineage " +
              moonflow_operator_text(value.lineage_root_ref, "not recorded"),
            "previous " +
              moonflow_operator_text(value.previous_revision_ref, "none recorded"),
            "accepted " +
              moonflow_operator_text(value.accepted_at, "not recorded"),
          ]),
          evidence_refs: moonflow_operator_refs(value.evidence_refs),
          needs_attention: false,
        }
      })
  }
}

///|
fn moonflow_delivery_operator_rows(
  values : Array[MoonFlowDeliveryOperatorProjection]?,
) -> Array[MoonFlowOperatorRowView] {
  match values {
    None => []
    Some(deliveries) =>
      deliveries.map(value => {
        let authorized = value.authorized.unwrap_or(false)
        let state = moonflow_operator_text(value.state, "not recorded")
        {
          identity: moonflow_operator_text(value.delivery_id, "Delivery"),
          state,
          primary: moonflow_operator_parts([
            "destination " +
              moonflow_operator_text(value.destination, "not recorded"),
            if authorized { "authority recorded" } else { "authority not confirmed" },
          ]),
          secondary: moonflow_operator_parts([
            "artifact " +
              moonflow_operator_text(value.artifact_ref, "not recorded"),
            "authority " +
              moonflow_operator_text(value.authority_ref, "not recorded"),
            "receipt " +
              moonflow_operator_text(value.receipt_ref, "not recorded"),
            "delivered " +
              moonflow_operator_text(value.delivered_at, "not recorded"),
          ]),
          evidence_refs: moonflow_operator_refs(value.evidence_refs),
          needs_attention: (state == "pending" && !authorized) || state == "failed",
        }
      })
  }
}

///|
fn moonflow_outcome_operator_rows(
  values : Array[MoonFlowOutcomeOperatorProjection]?,
) -> Array[MoonFlowOperatorRowView] {
  match values {
    None => []
    Some(outcomes) =>
      outcomes.map(value => {
        let state = moonflow_operator_text(value.state, "observed")
        {
          identity: moonflow_operator_text(value.observation_id, "Outcome observation"),
          state,
          primary: moonflow_operator_text(value.summary, "No summary published"),
          secondary: moonflow_operator_parts([
            "artifact " +
              moonflow_operator_text(value.artifact_ref, "not recorded"),
            "source " + moonflow_operator_text(value.source, "not recorded"),
            "window " + moonflow_operator_text(value.window_start, "not recorded") +
              " → " + moonflow_operator_text(value.window_end, "not recorded"),
            "effective " +
              moonflow_operator_text(value.effective_at, "not recorded"),
            "retrieved " +
              moonflow_operator_text(value.retrieved_at, "not recorded"),
            "digest " + moonflow_operator_text(value.digest, "not recorded"),
            "corrects " +
              moonflow_operator_text(value.corrects_observation_ref, "none"),
          ]),
          evidence_refs: moonflow_operator_refs(value.evidence_refs),
          needs_attention: state == "conflicting" || state == "late" ||
            state == "missing",
        }
      })
  }
}

///|
fn moonflow_proposal_operator_rows(
  values : Array[MoonFlowProposalOperatorProjection]?,
) -> Array[MoonFlowOperatorRowView] {
  match values {
    None => []
    Some(proposals) =>
      proposals.map(value => {
        let state = moonflow_operator_text(value.state, "proposed")
        {
          identity: moonflow_operator_text(value.proposal_id, "Improvement proposal"),
          state,
          primary: moonflow_operator_parts([
            moonflow_operator_text(value.scope, "Scope not recorded"),
            moonflow_operator_text(value.expected_benefit, ""),
            "risk " + moonflow_operator_text(value.risk, "not recorded"),
          ]),
          secondary: moonflow_operator_parts([
            "owner " + moonflow_operator_text(value.owner_kind, "not routed"),
            "evaluation " +
              moonflow_operator_text(value.evaluation_method, "not recorded"),
            "expires " +
              moonflow_operator_text(value.expires_at, "not recorded"),
            "rollback " +
              moonflow_operator_text(value.rollback, "not recorded"),
            "policy " +
              moonflow_operator_text(value.policy_version, "not recorded"),
            "assessment " +
              moonflow_operator_text(
                value.source_assessment_ref,
                "not recorded",
              ),
          ]),
          evidence_refs: moonflow_operator_refs(value.evidence_refs),
          needs_attention: state == "pending_review" || state == "proposed",
        }
      })
  }
}

///|
fn moonflow_evaluation_operator_rows(
  values : Array[MoonFlowEvaluationOperatorProjection]?,
) -> Array[MoonFlowOperatorRowView] {
  match values {
    None => []
    Some(evaluations) =>
      evaluations.map(value => {
        let state = moonflow_operator_text(value.state, "not started")
        {
          identity: moonflow_operator_text(value.evaluation_id, "Offline evaluation"),
          state,
          primary: moonflow_operator_parts([
            moonflow_operator_text(value.result, "No result recorded"),
            "regression gate " +
              moonflow_operator_text(value.regression_gate, "not recorded"),
          ]),
          secondary: moonflow_operator_parts([
            "proposal " +
              moonflow_operator_text(value.proposal_ref, "not recorded"),
            "baseline " +
              moonflow_operator_text(value.baseline_version, "not recorded"),
            "proposed " +
              moonflow_operator_text(value.proposed_version, "not recorded"),
            "completed " +
              moonflow_operator_text(value.completed_at, "not recorded"),
          ]),
          evidence_refs: moonflow_operator_refs(value.evidence_refs),
          needs_attention: state == "failed" || state == "blocked",
        }
      })
  }
}

///|
fn moonflow_adoption_operator_rows(
  values : Array[MoonFlowHumanAdoptionOperatorProjection]?,
) -> Array[MoonFlowOperatorRowView] {
  match values {
    None => []
    Some(decisions) =>
      decisions.map(value => {
        let state = moonflow_operator_text(value.state, "pending")
        {
          identity: moonflow_operator_text(value.decision_id, "Human adoption decision"),
          state,
          primary: moonflow_operator_parts([
            "decision " + moonflow_operator_text(value.decision, "not recorded"),
            moonflow_operator_text(value.reason, ""),
          ]),
          secondary: moonflow_operator_parts([
            "proposal " +
              moonflow_operator_text(value.proposal_ref, "not recorded"),
            "reviewer " +
              moonflow_operator_text(value.reviewer_id, "not assigned"),
            "version " + moonflow_operator_text(value.old_version, "not recorded") +
              " → " + moonflow_operator_text(value.new_version, "not recorded"),
            "decided " +
              moonflow_operator_text(value.decided_at, "not recorded"),
          ]),
          evidence_refs: moonflow_operator_refs(value.evidence_refs),
          needs_attention: state == "pending" || value.reviewer_id.unwrap_or("") == "",
        }
      })
  }
}

///|
fn moonflow_operator_rows_total(groups : Array[Array[MoonFlowOperatorRowView]]) -> Int {
  groups.fold(init=0, fn(total, rows) { total + rows.length() })
}

///|
fn moonflow_operator_attention_total(
  groups : Array[Array[MoonFlowOperatorRowView]],
) -> Int {
  groups.fold(
    init=0,
    fn(total, rows) {
      total + rows.filter(row => row.needs_attention).length()
    },
  )
}

///|
fn moonflow_operator_attention_rows(
  groups : Array[Array[MoonFlowOperatorRowView]],
) -> Array[MoonFlowOperatorRowView] {
  let rows : Array[MoonFlowOperatorRowView] = []
  for group in groups {
    for row in group {
      if row.needs_attention {
        rows.push(row)
      }
    }
  }
  rows
}

///|
fn render_moonflow_lifecycle_stage(
  ordinal : String,
  title : String,
  state : String,
  detail : String,
) -> @rabbita.Html {
  div(class="flow-lifecycle-stage " + state, [
    span(class="flow-lifecycle-index", ordinal),
    div([
      strong(title),
      small(detail),
    ]),
    span(class="flow-lifecycle-state", state.replace(old="_", new=" ")),
  ])
}

///|
fn render_moonflow_lifecycle(
  execution_count : Int,
  execution_attention : Int,
  finalization_count : Int,
  finalization_attention : Int,
  learning_count : Int,
  learning_attention : Int,
) -> @rabbita.Html {
  div(class="flow-lifecycle", [
    render_moonflow_lifecycle_stage(
      "1",
      "Authorized intake",
      "complete",
      "Run and source identity recorded",
    ),
    render_moonflow_lifecycle_stage(
      "2",
      "Execution",
      if execution_attention > 0 {
        "attention"
      } else if execution_count > 0 {
        "active"
      } else {
        "waiting"
      },
      "\{execution_count} state(s) · \{execution_attention} need attention",
    ),
    render_moonflow_lifecycle_stage(
      "3",
      "Deliverable",
      if finalization_attention > 0 {
        "attention"
      } else if finalization_count > 0 {
        "active"
      } else {
        "waiting"
      },
      "\{finalization_count} artifact and delivery state(s)",
    ),
    render_moonflow_lifecycle_stage(
      "4",
      "Outcome and learning",
      if learning_attention > 0 {
        "attention"
      } else if learning_count > 0 {
        "active"
      } else {
        "waiting"
      },
      "\{learning_count} observation, proposal, or decision state(s)",
    ),
  ])
}

///|
fn moonflow_actions_for_run(
  model : Model,
  run_id : String,
) -> MoonFlowOperatorActions? {
  for actions in model.moonflow_operator_actions {
    if actions.run_id == run_id {
      return Some(actions)
    }
  }
  None
}

///|
fn render_moonflow_action_button(
  dispatch : Dispatch[Msg],
  run_id : String,
  action : MoonFlowOperatorAction,
  dominant : Bool,
  pending_action_id : String,
) -> @rabbita.Html {
  let applying = pending_action_id == action.action_id
  let another_action_applying = pending_action_id != "" && !applying
  div(class="flow-item", [
    div(class="flow-item-main", [
      div(class="flow-item-title", [
        strong(action.label),
        span(
          class="flow-item-status " + moonflow_operator_state_class(action.status),
          action.status,
        ),
      ]),
      p(class="flow-item-why", action.summary),
    ]),
    button(
      class=if dominant { "primary-button" } else { "secondary-button" },
      disabled=!action.enabled || action.status != "available" ||
        pending_action_id != "",
      on_click=dispatch(
        ExecuteMoonFlowOperatorAction(run_id, action.action_id),
      ),
      if applying {
        "Applying…"
      } else if another_action_applying {
        "Waiting"
      } else if action.enabled && action.status == "available" {
        action.label
      } else {
        action.status.replace(old="_", new=" ")
      },
    ),
  ])
}

///|
fn render_moonflow_operator_action_receipt(
  model : Model,
  run_id : String,
) -> @rabbita.Html {
  match model.moonflow_operator_action_receipt {
    Some(receipt) if receipt.run_id == run_id =>
      div(class="flow-evidence-lane", [
        span("Last action receipt"),
        strong(receipt.action_id + " · " + receipt.status),
        small(
          receipt.operation +
          (if receipt.record_persisted {
            " · durably recorded"
          } else {
            " · not persisted"
          }) +
          (if receipt.source_digest == "" {
            ""
          } else {
            " · evidence " + moonflow_short_identity(receipt.source_digest)
          }),
        ),
      ])
    _ => @html.nothing
  }
}

///|
fn render_moonflow_operator_actions(
  dispatch : Dispatch[Msg],
  model : Model,
  run_id : String,
) -> @rabbita.Html {
  guard moonflow_actions_for_run(model, run_id) is Some(catalog) else {
    return section(class="flow-section", [
      div(class="flow-section-heading", [
        h3("Authorized action queue"),
        span(class="flow-state", "loading"),
      ]),
      p(
        class="flow-quiet",
        "Loading the run-local handoffs issued for operator and Bookkeeper decisions.",
      ),
    ])
  }
  let enabled = catalog.actions.filter(action => {
    action.enabled && action.status == "available"
  })
  let primary = if enabled.is_empty() { None } else { Some(enabled[0]) }
  let secondary = match primary {
    Some(value) => catalog.actions.filter(action => action.action_id != value.action_id)
    None => catalog.actions
  }
  section(class="flow-section", [
    div(class="flow-section-heading", [
      div([
        h3("Authorized action queue"),
        small(model.moonflow_operator_action_status),
      ]),
      span(
        class="flow-state " +
          (if enabled.is_empty() { "blocked" } else { "in-progress" }),
        if catalog.status == "available" && !enabled.is_empty() {
          "ready"
        } else {
          catalog.status
        },
      ),
    ]),
    match primary {
      Some(action) => render_moonflow_action_button(
        dispatch,
        run_id,
        action,
        true,
        model.moonflow_operator_action_pending,
      )
      None => p(
        class="flow-quiet",
        if catalog.status == "unavailable" {
          "MoonFlow has not published authority-bound handoffs for this run."
        } else {
          "No action is executable. Stale, rejected, and unavailable actions remain visible below."
        },
      )
    },
    if secondary.is_empty() {
      @html.nothing
    } else {
      details(class="flow-disclosure", [
        summary("Other operations · \{secondary.length()}"),
        div(
          class="flow-disclosure-body flow-item-list",
          secondary.map(action => {
            render_moonflow_action_button(
              dispatch,
              run_id,
              action,
              false,
              model.moonflow_operator_action_pending,
            )
          }),
        ),
      ])
    },
    render_moonflow_operator_action_receipt(model, run_id),
    small(
      class="flow-quiet",
      "Choose only a published action. MoonDesk sends its opaque action ID; MoonFlow resolves the authority-bound handoff and records the receipt. Host configuration and templates never enter the browser.",
    ),
  ])
}

///|
fn render_moonflow_operator_surface(
  dispatch : Dispatch[Msg],
  model : Model,
  run : MoonFlowRunProjection,
) -> @rabbita.Html {
  let surface = match run.operator_surface {
    Some(value) => value
    None =>
      return section(class="flow-operator-workspace", [
        div(class="flow-workspace-head", [
          div([
            p(class="eyebrow", "Run workspace"),
            h3("Operate this run"),
          ]),
          span(class="flow-state blocked", "projection unavailable"),
        ]),
        div(class="flow-workspace-grid", [
          render_moonflow_operator_actions(dispatch, model, run.run_id),
          p(
            class="flow-workspace-empty",
            "No closed-loop operator projection was included in this run response.",
          ),
        ]),
      ])
  }
  if !surface.available.unwrap_or(false) {
    let status = moonflow_operator_text(surface.status, "unavailable")
      .replace(old="_", new=" ")
    return section(class="flow-operator-workspace", [
      div(class="flow-workspace-head", [
        div([
          p(class="eyebrow", "Run workspace"),
          h3("Operate this run"),
        ]),
        span(class="flow-state blocked", status),
      ]),
      div(class="flow-workspace-grid", [
        render_moonflow_operator_actions(dispatch, model, run.run_id),
        p(
          class="flow-workspace-empty",
          "MoonFlow has not published a usable generic operator projection for this run.",
        ),
      ]),
    ])
  }
  let recovery = moonflow_recovery_operator_rows(surface.recovery)
  let due = moonflow_due_operator_rows(surface.due_actions)
  let callbacks = moonflow_callback_operator_rows(surface.callbacks)
  let quarantine = moonflow_quarantine_operator_rows(surface.quarantine)
  let interventions = moonflow_intervention_operator_rows(
    surface.manual_interventions,
  )
  let deliverables = moonflow_deliverable_operator_rows(
    surface.final_deliverables,
  )
  let artifacts = moonflow_artifact_operator_rows(surface.artifacts)
  let deliveries = moonflow_delivery_operator_rows(surface.deliveries)
  let outcomes = moonflow_outcome_operator_rows(surface.outcomes)
  let proposals = moonflow_proposal_operator_rows(surface.proposals)
  let evaluations = moonflow_evaluation_operator_rows(surface.evaluations)
  let adoptions = moonflow_adoption_operator_rows(surface.human_adoptions)
  let execution_groups = [recovery, due, callbacks, quarantine, interventions]
  let finalization_groups = [deliverables, artifacts, deliveries]
  let learning_groups = [outcomes, proposals, evaluations, adoptions]
  let all_groups = [
    recovery,
    due,
    callbacks,
    quarantine,
    interventions,
    deliverables,
    artifacts,
    deliveries,
    outcomes,
    proposals,
    evaluations,
    adoptions,
  ]
  let record_count = moonflow_operator_rows_total(all_groups)
  let attention_count = moonflow_operator_attention_total(all_groups)
  let execution_count = moonflow_operator_rows_total(execution_groups)
  let finalization_count = moonflow_operator_rows_total(finalization_groups)
  let learning_count = moonflow_operator_rows_total(learning_groups)
  let execution_attention = moonflow_operator_attention_total(execution_groups)
  let finalization_attention = moonflow_operator_attention_total(
    finalization_groups,
  )
  let learning_attention = moonflow_operator_attention_total(learning_groups)
  let attention_rows = moonflow_operator_attention_rows([
    recovery,
    callbacks,
    quarantine,
    interventions,
    deliverables,
    deliveries,
  ])
  section(class="flow-operator-workspace", [
    div(class="flow-workspace-head", [
      div([
        p(class="eyebrow", "Run workspace"),
        h3("Operate this run"),
        small(
          if record_count == 0 {
            "The governed projection is ready for its first handoff"
          } else {
            "\{record_count} recorded state(s) · \{attention_count} need attention"
          },
        ),
      ]),
      span(
        class="flow-state " +
          (if attention_count > 0 { "blocked" } else { "in-progress" }),
        if attention_count > 0 { "attention" } else { "observed" },
      ),
    ]),
    render_moonflow_lifecycle(
      execution_count,
      execution_attention,
      finalization_count,
      finalization_attention,
      learning_count,
      learning_attention,
    ),
    div(class="flow-workspace-grid", [
      div(class="flow-workspace-primary", [
        render_moonflow_operator_actions(dispatch, model, run.run_id),
      ]),
      section(class="flow-workspace-attention", [
        div(class="flow-section-heading", [
          div([
            h3("Due actions and attention"),
            small("Deadlines and review blockers that need a human next"),
          ]),
          span(
            class="flow-state " +
              (if due.is_empty() && attention_rows.is_empty() {
                "complete"
              } else {
                "blocked"
              }),
            "\{due.length() + attention_rows.length()}",
          ),
        ]),
        if due.is_empty() && attention_rows.is_empty() {
          p(
            class="flow-workspace-empty",
            "Nothing is due and no human blocker is recorded.",
          )
        } else {
          div(class="flow-item-list", [
            render_moonflow_operator_category("Due now and upcoming", due),
            render_moonflow_operator_category(
              "Needs a decision",
              attention_rows,
            ),
          ])
        },
      ]),
    ]),
    section(class="flow-learning-loop", [
      div(class="flow-section-heading", [
        div([
          h3("Outcome and learning loop"),
          small(
            "Attach observed results, review bounded proposals, then adopt or reject through a named decision.",
          ),
        ]),
        span(
          class="flow-state " +
            (if learning_attention > 0 {
              "blocked"
            } else if learning_count > 0 {
              "in-progress"
            } else {
              ""
            }),
          "\{learning_count} record(s)",
        ),
      ]),
      if learning_count == 0 {
        p(
          class="flow-workspace-empty",
          "No outcome has been attached yet. When MoonFlow publishes an outcome or learning handoff, it appears in the authorized action queue above.",
        )
      } else {
        div(class="flow-learning-grid", [
          render_moonflow_operator_category("Observed outcomes", outcomes),
          render_moonflow_operator_category("Learning proposals", proposals),
          render_moonflow_operator_category("Offline evaluation", evaluations),
          render_moonflow_operator_category(
            "Bookkeeper adoption decisions",
            adoptions,
          ),
        ])
      },
    ]),
    details(class="flow-disclosure", [
      summary(
        "Execution evidence · " + execution_count.to_string(),
      ),
      div(class="flow-disclosure-body", [
        render_moonflow_operator_category("Recovery", recovery),
        render_moonflow_operator_category("Due actions and deadlines", due),
        render_moonflow_operator_category("Callbacks", callbacks),
        render_moonflow_operator_category("Quarantine", quarantine),
        render_moonflow_operator_category("Manual intervention", interventions),
      ]),
    ]),
    details(class="flow-disclosure", [
      summary(
        "Final deliverable and delivery · " +
        finalization_count.to_string(),
      ),
      div(class="flow-disclosure-body", [
        render_moonflow_operator_category("Final deliverable", deliverables),
        render_moonflow_operator_category("Immutable artifacts", artifacts),
        render_moonflow_operator_category("Governed delivery", deliveries),
      ]),
    ]),
    small(
      class="flow-quiet",
      "The workspace projection is read-only. Every mutation above resolves through a separately published, authority-bound MoonFlow handoff.",
    ),
    small(
      class="flow-quiet",
      moonflow_operator_text(surface.contract_id, "moonflow operator surface") +
      " · run " + moonflow_operator_text(surface.run_id, run.run_id) +
      " · recorded " +
      moonflow_operator_text(surface.recorded_at, "not recorded"),
    ),
  ])
}
