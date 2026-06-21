///|
fn render_mooncode_pane(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(class="explorer-pane", [
    div(class="pane-heading", [
      div([
        p(class="eyebrow", "code mode"),
        h2("Code Sessions"),
        p(class="pane-help", "Chat with an agent to add tools, miniapps, tests, and executable book code."),
      ]),
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
      h3("Start Here"),
      button(
        class="primary-button full",
        on_click=dispatch(NewMoonCodeSession),
        "New Code Chat",
      ),
      p(class="status-line", model.mooncode_composer_status),
    ]),
    section(class="side-section quiet-section", [
      h3("Agent"),
      render_moonclaw_daemon_state(model),
    ]),
    section(class="side-section", [
      h3("Recent Chats"),
      div(
        class="mooncode-session-list",
        if model.mooncode_sessions.length() == 0 {
          [p(class="status-line", "No code chats yet.")]
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
      span(
        class="path-pill",
        "Code mode / \{selected_mooncode_runtime_label(model)} / \{model.selected_path}",
      ),
      div(class="toolbar-actions", [
        button(
          class="primary-button",
          on_click=dispatch(NewMoonCodeSession),
          "New Chat",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(PollMoonCodeSessions),
          "Refresh",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("run_tests")),
          "Run Tests",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("steer")),
          "Steer",
        ),
      ]),
    ]),
    section(class="mooncode-chat-surface", [
      match session {
        Some(session) => div(class="mooncode-session-surface", [
          render_mooncode_session_header(dispatch, model, session),
          render_mooncode_transcript(model, session),
          render_mooncode_advanced_panels(dispatch, model, session),
        ])
        None =>
          div(class="mooncode-empty", [
            h1("Start a Code Chat"),
            p(
              class="lead",
              "Ask the agent to inspect this MoonBook, edit executable code, run tests, or package a miniapp.",
            ),
          ])
      },
      div(class="mooncode-composer", [
        textarea(
          class="mooncode-input",
          rows=7,
          value=model.mooncode_prompt,
          placeholder="Ask for a code change, test, tool, miniapp, or explanation for this selected MoonBook.",
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
fn render_mooncode_advanced_panels(
  dispatch : Dispatch[Msg],
  model : Model,
  session : MoonCodeSession,
) -> @rabbita.Html {
  div(class="hidden-advanced", [
    render_mooncode_preflight_panel(dispatch, model),
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
    render_mooncode_resume_lifecycle(session.mooncode_summary),
    render_mooncode_steering_lifecycle(session.mooncode_summary),
    render_mooncode_cancel_lifecycle(session.mooncode_summary),
    render_mooncode_patch_lifecycle(session.mooncode_summary),
    render_mooncode_package_lifecycle(session.mooncode_summary),
    span(
      class="hidden-inline",
      mooncode_summary_pending_steer_label(session.mooncode_summary),
    ),
    span(
      class="hidden-inline",
      session.mooncode_summary.pending_cancel_count.to_string(),
    ),
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
  div(class="mooncode-session-header", [
    div(class="mooncode-session-title", [
      div([
        p(class="eyebrow", "code chat"),
        h2(session.title),
        small(
          "\{workspace_name(model)} / \{mooncode_session_runtime_line(session)}",
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
      info_chip("status", session.status),
      info_chip("events", summary.event_count.to_string()),
      info_chip("diffs", summary.pending_diff_count.to_string()),
      info_chip("tests", summary.verified_test_count.to_string()),
    ]),
  ])
}
