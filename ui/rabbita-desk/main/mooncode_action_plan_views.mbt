///|
fn render_mooncode_action_plan_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="mooncode-review-board action-plan-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "execution and review plan"),
        h3("Action Plan"),
      ]),
      span(class="record-kind", model.mooncode_action_plan_status),
    ]),
    match model.mooncode_action_plan {
      Some(plan) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Actions", plan.action_count.to_string()),
            info_chip("Pending runtime", plan.pending_runtime_count.to_string()),
            info_chip("Running", plan.running_count.to_string()),
            info_chip("Blocked", plan.blocked_count.to_string()),
            info_chip("Ready review", plan.ready_for_review_count.to_string()),
            info_chip("Completed", plan.completed_count.to_string()),
            info_chip("Tests", plan.run_test_command_count.to_string()),
            info_chip("Packages", plan.package_command_count.to_string()),
            info_chip("Commits", plan.commit_command_count.to_string()),
            info_chip("Deferred Steers", plan.deferred_steer_count.to_string()),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Status", plan.status),
            info_row("Next", plan.next_required_action),
            info_row(
              "Readiness Next",
              json_string_value(
                plan.readiness,
                "next_action",
                default=plan.next_required_action,
              ),
            ),
            info_row(
              "Readiness Owner",
              json_string_value(
                plan.readiness,
                "next_owner",
                default="mooncode",
              ),
            ),
            info_row(
              "Readiness Blocker",
              json_string_value(
                plan.readiness,
                "first_blocker_label",
                default="none",
              ),
            ),
            info_row("Manifest", empty_label(plan.manifest_path)),
            info_row("Recorded", empty_label(plan.recorded_at)),
            info_row("Runtime", empty_label(plan.runtime_session_id)),
          ]),
          render_mooncode_action_plan_recommended_command(dispatch, plan),
          render_mooncode_action_plan_gates(plan.acceptance_gates),
          if plan.actions.length() == 0 {
            p(class="status-line", "no MoonCode actions queued yet")
          } else {
            div(
              class="mooncode-review-list action-plan-list",
              plan.actions[:mooncode_action_plan_limit(plan.actions)].map(action =>
                render_mooncode_action_plan_item(dispatch, action)
              ),
            )
          },
          p(class="mooncode-event-detail", plan.rule),
        ])
      None =>
        p(
          class="status-line",
          "No MoonCode action plan has been loaded for this session yet.",
        )
    },
  ])
}

///|
fn render_mooncode_action_plan_recommended_command(
  dispatch : Dispatch[Msg],
  plan : MoonCodeActionPlan,
) -> @rabbita.Html {
  let commands = if plan.recommended_commands.length() > 0 {
    plan.recommended_commands
  } else if plan.recommended_command.available {
    [plan.recommended_command]
  } else {
    []
  }
  if commands.length() > 0 {
    let children : Array[@rabbita.Html] = []
    for index, command in commands {
      if command.available && command.action != "" && command.label != "" {
        children.push(
          button(
            class=if index == 0 { "primary-button" } else { "secondary-button" },
            on_click=dispatch(
              mooncode_recommended_command_message(command),
            ),
            command.label,
          ),
        )
      }
    }
    children.push(span(class="status-line", plan.next_required_action))
    div(class="toolbar-actions action-plan-actions", children)
  } else {
    span(class="hidden-inline", "")
  }
}

///|
fn mooncode_recommended_command_message(
  command : MoonCodeActionPlanRecommendedCommand
) -> Msg {
  match command.ui_action {
    "runtime_loop" => RunMoonCodeRuntimeLoop
    "runtime_service" => StartMoonCodeRuntimeService
    _ =>
      RunMoonCodeCommandWithMessage(
        command.action,
        command.context_path,
        command.message,
        command.status,
      )
  }
}

///|
fn render_mooncode_action_plan_gates(
  gates : MoonCodeActionPlanGates
) -> @rabbita.Html {
  div(class="mooncode-stats gate-stats", [
    info_chip("No failing tests", if gates.no_failing_tests { "yes" } else { "no" }),
    info_chip("Verified tests", if gates.has_verified_tests { "yes" } else { "no" }),
    info_chip(
      "Tool approvals",
      if gates.tool_approvals_resolved { "resolved" } else { "pending" },
    ),
    info_chip("Diffs", if gates.diffs_resolved { "resolved" } else { "pending" }),
    info_chip(
      "Package",
      if gates.has_source_bound_package { "source-bound" } else { "missing" },
    ),
  ])
}

///|
fn mooncode_action_plan_limit(actions : Array[MoonCodeActionPlanItem]) -> Int {
  if actions.length() > 8 {
    8
  } else {
    actions.length()
  }
}

///|
fn render_mooncode_action_plan_item(
  dispatch : Dispatch[Msg],
  action : MoonCodeActionPlanItem,
) -> @rabbita.Html {
  let target = if action.context_path == "" {
    action.target
  } else {
    action.context_path
  }
  div(class="mooncode-review-item " + mooncode_action_plan_item_class(action), [
    div(class="mooncode-review-head", [
      div([
        strong(action.action + " -> " + action.state),
        small(action.runtime_state + " / " + action.created_at),
      ]),
      div(class="toolbar-actions", [
        if action.context_path == "" {
          span(class="hidden-inline", "")
        } else {
          button(
            class="secondary-button",
            on_click=dispatch(OpenQuickPath(action.context_path)),
            "Open",
          )
        },
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("run_tests", target)),
          "Test",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("run_build", target)),
          "Build",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("package", target)),
          "Package",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("commit", target)),
          "Commit",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("accept", target)),
          "Accept",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("reject", target)),
          "Reject",
        ),
      ]),
    ]),
    div(class="mooncode-stats", [
      info_chip("Approval", action.approval),
      info_chip("Dispatch", action.dispatch),
      info_chip("Lanes", action.expected_lanes.length().to_string()),
      info_chip("Tools", action.tool_hints.length().to_string()),
      info_chip("Evidence", action.runtime_evidence_status),
      info_chip(
        "Proof",
        "\{action.proven_required_event_count}/\{action.required_event_count}",
      ),
      info_chip(
        "Tool Proof",
        mooncode_optional_ratio_label(
          action.tool_harness_proven_tool_count,
          action.tool_harness_expected_tool_count,
        ),
      ),
      info_chip(
        "Tool Harness",
        mooncode_optional_text_label(action.tool_harness_status),
      ),
    ]),
    code(if target == "" { action.command_id } else { target }),
    div(class="mooncode-output-roots", [
      small("Required gates"),
      p(if action.required_gates.length() == 0 {
        "none"
      } else {
        action.required_gates.join(", ")
      }),
    ]),
    render_mooncode_action_plan_evidence(action),
    if action.blocking_reason == "" {
      p(class="mooncode-event-detail", action.next_step)
    } else {
      p(class="mooncode-event-detail", action.blocking_reason)
    },
    small(class="status-line", action.command_id),
  ])
}

///|
fn render_mooncode_action_plan_evidence(
  action : MoonCodeActionPlanItem
) -> @rabbita.Html {
  if action.required_event_count == 0 {
    return span(class="hidden-inline", "")
  }
  div(class="mooncode-output-roots", [
    small("Runtime evidence"),
    p(
      "required " +
      action.required_event_count.to_string() +
      ", proven " +
      action.proven_required_event_count.to_string() +
      mooncode_action_plan_event_gap_text(
        action.missing_required_events, "missing",
      ) +
      mooncode_action_plan_event_gap_text(
        action.failed_required_events, "failed",
      ),
    ),
    if action.tool_harness_status is Some(_) {
      p(
        class="mooncode-event-detail",
        "tool harness " +
        mooncode_optional_text_label(action.tool_harness_status) +
        " / proven " +
        mooncode_optional_ratio_label(
          action.tool_harness_proven_tool_count,
          action.tool_harness_expected_tool_count,
        ) +
        " / missing " +
        mooncode_optional_int_label(action.tool_harness_missing_tool_count) +
        " / failed " +
        mooncode_optional_int_label(action.tool_harness_failed_tool_count),
      )
    } else {
      span(class="hidden-inline", "")
    },
  ])
}

///|
fn mooncode_action_plan_event_gap_text(
  events : Array[String],
  label : String,
) -> String {
  if events.length() == 0 {
    ""
  } else {
    "; " + label + " " + events.join(", ")
  }
}

///|
fn mooncode_action_plan_item_class(action : MoonCodeActionPlanItem) -> String {
  match action.state {
    "completed" => "accepted"
    "ready-for-review" => "pending"
    "blocked" | "runtime-retry" => "rejected"
    "awaiting-proof" => "running"
    "running" => "running"
    "queued-for-runtime" => "queued"
    _ => "queued"
  }
}

///|
fn render_mooncode_runtime_evidence_panel(model : Model) -> @rabbita.Html {
  section(class="mooncode-review-board runtime-evidence-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "session proof contract"),
        h3("Runtime Evidence"),
      ]),
      span(class="record-kind", model.mooncode_runtime_evidence_status),
    ]),
    match model.mooncode_runtime_evidence {
      Some(evidence) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Status", evidence.status),
            info_chip("Commands", evidence.command_count.to_string()),
            info_chip("Proven", evidence.proven_command_count.to_string()),
            info_chip(
              "Missing",
              evidence.missing_evidence_command_count.to_string(),
            ),
            info_chip("Failed", evidence.failed_evidence_command_count.to_string()),
            info_chip(
              "Proof",
              "\{evidence.proven_required_event_count}/\{evidence.required_event_count}",
            ),
            info_chip(
              "Tool Proof",
              mooncode_optional_ratio_label(
                evidence.tool_harness_proven_tool_count,
                evidence.tool_harness_expected_tool_count,
              ),
            ),
            info_chip(
              "Tool Missing",
              mooncode_optional_int_label(
                evidence.tool_harness_missing_tool_count,
              ),
            ),
            info_chip(
              "Tool Failed",
              mooncode_optional_int_label(
                evidence.tool_harness_failed_tool_count,
              ),
            ),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Recorded", empty_label(evidence.recorded_at)),
            info_row(
              "Tool Harness",
              mooncode_optional_text_label(evidence.tool_harness_status),
            ),
            info_row("Manifest", empty_label(evidence.manifest_path)),
            info_row("Commands Log", empty_label(evidence.command_log_path)),
            info_row(
              "Runtime Feed",
              empty_label(evidence.runtime_command_log_path),
            ),
            info_row("Event Log", empty_label(evidence.event_log_path)),
            info_row(
              "Artifact",
              empty_label(evidence.absolute_manifest_path),
            ),
            info_row("Runtime", empty_label(evidence.runtime_session_id)),
          ]),
          if evidence.items.length() == 0 {
            p(class="status-line", "no commands have runtime evidence yet")
          } else {
            div(
              class="mooncode-review-list runtime-evidence-list",
              evidence.items[:mooncode_runtime_evidence_limit(evidence.items)].map(item =>
                render_mooncode_runtime_evidence_item(item)
              ),
            )
          },
          p(class="mooncode-event-detail", evidence.rule),
        ])
      None =>
        p(
          class="status-line",
          "No MoonCode runtime evidence has been loaded for this session yet.",
        )
    },
  ])
}

///|
fn mooncode_runtime_evidence_limit(
  items : Array[MoonCodeRuntimeEvidenceItem]
) -> Int {
  if items.length() > 8 {
    8
  } else {
    items.length()
  }
}

///|
fn render_mooncode_runtime_evidence_item(
  item : MoonCodeRuntimeEvidenceItem
) -> @rabbita.Html {
  let target = if item.context_path == "" {
    item.command_id
  } else {
    item.context_path
  }
  div(class="mooncode-review-item " + mooncode_runtime_evidence_item_class(item), [
    div(class="mooncode-review-head", [
      div([
        strong(item.action + " -> " + item.status),
        small(item.created_at),
      ]),
      span(
        class="record-kind",
        if item.runtime_command_recorded {
          "runtime command"
        } else {
          "missing runtime command"
        },
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip(
        "Proof",
        "\{item.proven_required_event_count}/\{item.required_event_count}",
      ),
      info_chip(
        "Tools",
        mooncode_optional_ratio_label(
          item.tool_harness_proven_tool_count,
          item.tool_harness_expected_tool_count,
        ),
      ),
      info_chip(
        "Tool Harness",
        mooncode_optional_text_label(item.tool_harness_status),
      ),
      info_chip("Missing", item.missing_required_events.length().to_string()),
      info_chip("Failed", item.failed_required_events.length().to_string()),
    ]),
    code(target),
    if item.message == "" {
      span(class="hidden-inline", "")
    } else {
      p(class="mooncode-event-detail", item.message)
    },
    if item.required_event_count == 0 {
      p(class="mooncode-event-detail", "no required runtime events")
    } else {
      p(
        class="mooncode-event-detail",
        "required " +
        item.required_event_count.to_string() +
        ", proven " +
        item.proven_required_event_count.to_string() +
        mooncode_action_plan_event_gap_text(
          item.missing_required_events, "missing",
        ) +
        mooncode_action_plan_event_gap_text(
          item.failed_required_events, "failed",
        ),
      )
    },
  ])
}

///|
fn mooncode_runtime_evidence_item_class(
  item : MoonCodeRuntimeEvidenceItem
) -> String {
  match item.status {
    "proven" => "accepted"
    "failed" => "rejected"
    "missing-evidence" => "running"
    _ => "queued"
  }
}

///|
