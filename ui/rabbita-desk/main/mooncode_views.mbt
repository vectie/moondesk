///|
fn render_mooncode_pane(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(class="explorer-pane", [
    div(class="pane-heading", [
      div([p(class="eyebrow", "mooncode"), h2("MoonCode")]),
      div(class="toolbar-actions", [
        button(
          class="icon-button",
          title="New Session",
          on_click=dispatch(NewMoonCodeSession),
          "N",
        ),
        button(
          class="icon-button",
          title="Refresh MoonCode sessions",
          on_click=dispatch(PollMoonCodeSessions),
          "R",
        ),
      ]),
    ]),
    section(class="side-section", [
      h3("Daemon"),
      render_moonclaw_daemon_state(model),
      p(class="status-line", model.mooncode_composer_status),
    ]),
    section(class="side-section", [
      h3("MoonCode Sessions"),
      button(
        class="primary-button full",
        on_click=dispatch(NewMoonCodeSession),
        "New Session",
      ),
      div(
        class="mooncode-session-list",
        if model.mooncode_sessions.length() == 0 {
          [p(class="status-line", "no MoonCode sessions yet")]
        } else {
          model.mooncode_sessions.map(session => {
            let selected = selected_mooncode_session(model)
              .map(fn(item) { item.id })
              .unwrap_or("") ==
              session.id
            button(
              class=if selected {
                "mooncode-session active"
              } else {
                "mooncode-session"
              },
              title="\{session.id} / \{session.cwd}",
              on_click=dispatch(SelectMoonCodeSession(session.id)),
              [
                span(class="record-kind", session.status),
                strong(session.title),
                small(
                  "\{session.workspace_name} / \{mooncode_session_runtime_line(session)}",
                ),
                small(
                  "\{session.transcript.length()} messages / \{session.updated_at}",
                ),
              ],
            )
          })
        },
      ),
    ]),
  ])
}

///|
fn render_moonclaw_daemon_state(model : Model) -> @rabbita.Html {
  match model.moonclaw_daemon {
    Some(daemon) =>
      div(class="daemon-state", [
        info_row("Running", if daemon.running { "yes" } else { "no" }),
        info_row(
          "Port",
          if daemon.port > 0 {
            daemon.port.to_string()
          } else {
            "none"
          },
        ),
        info_row(
          "PID",
          if daemon.pid > 0 {
            daemon.pid.to_string()
          } else {
            "none"
          },
        ),
        info_row("Root", empty_label(daemon.moonclaw_root)),
        info_row("Info", daemon.info_path),
      ])
    None =>
      div(class="daemon-state", [
        info_row("Running", "unknown"),
        info_row("Port", "none"),
      ])
  }
}

///|
fn mooncode_session_runtime_line(session : MoonCodeSession) -> String {
  let model = if session.model == "" { "default" } else { session.model }
  let runtime_id = mooncode_session_runtime_id(session)
  let runtime = if runtime_id == "" {
    "not attached"
  } else {
    runtime_id
  }
  "\{model} / \{runtime} / queued \{session.queued_count}"
}

fn render_mooncode_center(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let session = selected_mooncode_session(model)
  main_(class="preview-center mooncode-center", [
    div(class="preview-toolbar", [
      span(class="path-pill", selected_mooncode_runtime_label(model)),
      div(class="toolbar-actions", [
        button(
          class="secondary-button",
          on_click=dispatch(NewMoonCodeSession),
          "New",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(PollMoonCodeSessions),
          "Refresh",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeRuntimeLoop),
          "Run Native Loop",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("run_tests")),
          "Run Tests",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("run_build")),
          "Run Build",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("run_eval")),
          "Run Eval",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("package")),
          "Package",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("commit")),
          "Commit",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("accept")),
          "Accept",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("reject")),
          "Reject",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("cancel")),
          "Cancel",
        ),
      ]),
    ]),
    section(class="mooncode-chat-surface", [
      match session {
        Some(session) => div(class="mooncode-session-surface", [
          render_mooncode_session_header(dispatch, model, session),
          render_mooncode_preflight_panel(dispatch, model),
          render_mooncode_transcript(model, session),
          render_mooncode_command_queue_panel(dispatch, model),
          render_mooncode_runtime_command_feed_panel(model),
          render_mooncode_runtime_replay_panel(model),
          render_mooncode_runtime_event_sink_panel(model),
          render_mooncode_action_plan_panel(dispatch, model),
          render_mooncode_runtime_evidence_panel(model),
          render_mooncode_runtime_claim_panel(dispatch, model),
          render_mooncode_runtime_receipt_panel(model),
          render_mooncode_eval_report_panel(dispatch, model),
          render_mooncode_runtime_handoff_panel(model),
          render_mooncode_review_queue(dispatch, session),
          render_mooncode_change_set_panel(model),
          render_mooncode_test_runs_panel(dispatch, model),
          render_mooncode_package_candidates_panel(dispatch, model),
          render_mooncode_patch_set_panel(dispatch, model),
          render_mooncode_tool_authorization_panel(dispatch, model),
          render_mooncode_tool_approvals_panel(dispatch, model),
          render_mooncode_event_lanes(model, session),
        ])
        None =>
          div(class="mooncode-empty", [
            h1("MoonCode"),
            p(
              class="lead",
              "Start a book-scoped MoonCode session backed by MoonClaw.",
            ),
          ])
      },
      div(class="mooncode-composer", [
        textarea(
          class="mooncode-input",
          rows=7,
          value=model.mooncode_prompt,
          placeholder="Ask MoonClaw to inspect, code, refactor, test, or explain this book/code workspace.",
          on_input=fn(value) { dispatch(SetMoonCodePrompt(value)) },
          "",
        ),
        div(class="composer-options", [
          span(class="option-chip active", workspace_name(model)),
          span(class="option-chip", model.selected_path),
          button(
            class=if model.mooncode_web_search {
              "secondary-button active"
            } else {
              "secondary-button"
            },
            on_click=dispatch(ToggleMoonCodeWebSearch),
            if model.mooncode_web_search {
              "Web On"
            } else {
              "Web Off"
            },
          ),
          button(
            class="primary-button",
            on_click=dispatch(SendMoonCodeMessage),
            mooncode_composer_button_label(model, session),
          ),
        ]),
        p(class="status-line", model.mooncode_composer_status),
      ]),
    ]),
  ])
}

///|
fn mooncode_command_message_from_prompt(
  model : Model,
  action : String
) -> String {
  match action {
    "prompt" | "steer" => model.mooncode_prompt.trim().to_owned()
    _ => ""
  }
}

///|
fn mooncode_composer_button_label(
  model : Model,
  session : MoonCodeSession?
) -> String {
  match session {
    Some(active) if mooncode_session_accepts_steer(model, active) => "Steer"
    Some(_) => "Prompt"
    None => "Start"
  }
}

///|
fn render_mooncode_session_header(
  dispatch : Dispatch[Msg],
  model : Model,
  session : MoonCodeSession,
) -> @rabbita.Html {
  let summary = session.mooncode_summary
  let action_state = match model.mooncode_action_plan {
    Some(plan) => "\{plan.status} / \{plan.next_required_action}"
    None => model.mooncode_action_plan_status
  }
  let receipt_state = match model.mooncode_runtime_receipt {
    Some(receipt_state) =>
      "\{receipt_state.runtime_receipt_count} receipt(s), \{receipt_state.runtime_receipt_pending_count} pending"
    None => model.mooncode_runtime_receipt_status
  }
  let readiness_next_action = json_string_value(
    summary.readiness,
    "next_action",
    default="inspect_readiness_check",
  )
  let readiness_next_owner = json_string_value(
    summary.readiness,
    "next_owner",
    default="mooncode",
  )
  div(class="mooncode-session-header", [
    div(class="mooncode-session-title", [
      div([
        p(class="eyebrow", "mooncode session"),
        h2(session.title),
        small(
          "\{session.workspace_name} / \{mooncode_session_runtime_line(session)}",
        ),
      ]),
      div(class="toolbar-actions", [
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("steer")),
          "Steer",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("cancel")),
          "Cancel",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeRuntimeLoop),
          "Run Native Loop",
        ),
        button(
          class="primary-button",
          on_click=dispatch(RunMoonCodeCommand("run_tests")),
          "Run Tests",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("run_build")),
          "Run Build",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("run_eval")),
          "Run Eval",
        ),
      ]),
    ]),
    div(class="mooncode-session-grid", [
      info_chip("next action", action_state),
      info_chip(
        "readiness next",
        "\{readiness_next_action} / \{readiness_next_owner}",
      ),
      info_chip("stream", "\{summary.stream_source} / \{summary.stream_mode}"),
      info_chip("runtime", "\{summary.runtime_mode} / \{receipt_state}"),
      info_chip("pending steers", mooncode_summary_pending_steer_label(summary)),
      info_chip("pending cancels", summary.pending_cancel_count.to_string()),
      info_chip("events", summary.event_count.to_string()),
      info_chip("diffs pending", summary.pending_diff_count.to_string()),
      info_chip("tests verified", summary.verified_test_count.to_string()),
      info_chip("tool approvals", summary.pending_tool_approval_count.to_string()),
      info_chip("packages", summary.source_bound_package_count.to_string()),
    ]),
    div(class="mooncode-session-evidence", [
      info_row("Session", session.id),
      info_row("Snapshot", empty_label(summary.session_snapshot_path)),
      info_row("Command Log", empty_label(summary.command_log_path)),
      info_row("Runtime Feed", empty_label(summary.runtime_command_log_path)),
      info_row("Event Log", empty_label(summary.event_log_path)),
      info_row(
        "Eval",
        "\{summary.eval_passed_check_count}/\{summary.eval_check_count} passed, \{summary.eval_missing_check_count} missing",
      ),
    ]),
    render_mooncode_resume_lifecycle(summary),
    render_mooncode_steering_lifecycle(summary),
    render_mooncode_cancel_lifecycle(summary),
    render_mooncode_patch_lifecycle(summary),
    render_mooncode_package_lifecycle(summary),
  ])
}
