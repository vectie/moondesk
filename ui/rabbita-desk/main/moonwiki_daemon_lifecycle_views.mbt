///|
fn render_diagnostics_disclosure(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  details(class="wiki-disclosure diagnostics-disclosure", [
    summary(class="wiki-disclosure-summary", "Diagnostics"),
    div(class="wiki-disclosure-body diagnostics-body", [
      p(
        class="diagnostics-intro",
        "Technical service information for troubleshooting. Normal Wiki work should not require these controls.",
      ),
      render_town_progress_panel(model),
      render_event_panel(model),
      render_runtime_diagnostics(model),
      render_standing_goal_list(model),
      render_request_list(model),
      render_daemon_lifecycle_panel(dispatch, model),
    ]),
  ])
}

///|
fn render_runtime_diagnostics(model : Model) -> @rabbita.Html {
  section(class="side-section", [
    h3("Runtime summary"),
    match model.analytics {
      Some(analytics) =>
        div([
          info_row("Tick", analytics.daemon_tick.to_string()),
          info_row("Goals", analytics.standing_goal_count.to_string()),
          info_row("Due", analytics.due_goal_count.to_string()),
          info_row("Active", analytics.active_goal_count.to_string()),
          info_row("Requests", analytics.request_count.to_string()),
          info_row("Messages", analytics.message_count.to_string()),
          info_row("Runs", analytics.run_count.to_string()),
          info_row("Watcher Runs", analytics.watcher_run_count.to_string()),
          info_row("Updates", analytics.updates.to_string()),
          info_row("No Change", analytics.no_changes.to_string()),
          info_row("Needs Review", analytics.needs_review.to_string()),
          info_row("Failures", analytics.failures.to_string()),
          info_row("Deferred", analytics.deferred.to_string()),
          info_row("Events", analytics.event_count.to_string()),
          info_row("Failure Events", analytics.failure_event_count.to_string()),
          info_row("Review Events", analytics.review_event_count.to_string()),
          info_row("Review Items", analytics.review_item_count.to_string()),
          info_row("Next Due", analytics.next_due_tick.to_string()),
          info_row("Last Failure", empty_label(analytics.last_failure)),
        ])
      None => p(class="status-line", "analytics unavailable")
    },
    match model.moonclaw_progress {
      Some(progress) =>
        div([
          info_row("Worker Runs", progress.run_count.to_string()),
          info_row("Ready", progress.ready_count.to_string()),
          info_row("Artifacts", progress.artifact_count.to_string()),
          info_row("Latest Run", empty_label(progress.latest_run)),
          info_row("Latest Status", empty_label(progress.latest_status)),
        ])
      None => p(class="status-line", "worker progress unavailable")
    },
    info_row("Messages Loaded", model.town_messages.length().to_string()),
    if model.town_messages.length() == 0 {
      @html.nothing
    } else {
      info_row(
        "Latest Message",
        model.town_messages[model.town_messages.length() - 1].title,
      )
    },
  ])
}

///|
fn render_daemon_lifecycle_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="side-section", [
    h3("Daemon Lifecycle"),
    match model.daemon_lifecycle {
      Some(result) =>
        div(class="daemon-state", [
          info_row("Result", if result.ok { "ok" } else { "failed" }),
          info_row("Action", result.action),
          info_row(
            "Status",
            if result.running {
              "running"
            } else {
              result.status
            },
          ),
          info_row(
            "PID",
            if result.pid > 0 {
              result.pid.to_string()
            } else {
              "none"
            },
          ),
          info_row("Command", result.command),
          info_row("CWD", result.cwd),
          info_row(
            "Started",
            if result.started_at == "" {
              "none"
            } else {
              result.started_at
            },
          ),
          info_row(
            "Stopped",
            if result.stopped_at == "" {
              "none"
            } else {
              result.stopped_at
            },
          ),
          info_row("Desired", result.desired_state),
          info_row(
            "Supervision",
            if result.supervision_enabled {
              "enabled"
            } else {
              "disabled"
            },
          ),
          info_row("Restarts", result.restart_count.to_string()),
          info_row(
            "Health",
            if result.last_health_check == "" {
              "none"
            } else {
              result.last_health_check
            },
          ),
          info_row("State File", result.pid_file),
          info_row("Policy File", result.policy_file),
          info_row("Logs", daemon_log_label(result)),
        ])
      None =>
        div(class="daemon-state", [
          info_row("Status", "unknown"),
          info_row("PID", "none"),
        ])
    },
    div(class="toolbar-actions stack-actions", [
      button(class="secondary-button", on_click=dispatch(StartDaemon), "Start"),
      button(class="secondary-button", on_click=dispatch(StopDaemon), "Stop"),
      button(
        class="secondary-button",
        on_click=dispatch(RestartDaemon),
        "Restart",
      ),
      button(
        class="secondary-button",
        on_click=dispatch(FetchDaemonLifecycle),
        "Status",
      ),
      button(
        class="secondary-button",
        on_click=dispatch(EnableDaemonSupervision),
        "Supervise",
      ),
      button(
        class="secondary-button",
        on_click=dispatch(DisableDaemonSupervision),
        "Unsupervise",
      ),
      button(
        class="secondary-button",
        on_click=dispatch(InstallLaunchAgent),
        "Install LaunchAgent",
      ),
      button(
        class="secondary-button",
        on_click=dispatch(UninstallLaunchAgent),
        "Remove LaunchAgent",
      ),
    ]),
    render_launch_agent_state(model),
    p(class="status-line", model.daemon_status),
  ])
}

///|
fn render_launch_agent_state(model : Model) -> @rabbita.Html {
  match model.launch_agent {
    Some(launch_agent) =>
      div(class="daemon-state", [
        info_row(
          "LaunchAgent",
          if launch_agent.installed {
            if launch_agent.loaded {
              "loaded"
            } else {
              "installed"
            }
          } else {
            "none"
          },
        ),
        info_row(
          "Result",
          if launch_agent.ok {
            "ok"
          } else {
            "failed \{launch_agent.exit_code}"
          },
        ),
        info_row("Action", launch_agent.action),
        info_row("Label", launch_agent.label),
        info_row("Plist", launch_agent.plist_path),
        info_row("Command", launch_agent.command),
        info_row("CWD", launch_agent.cwd),
      ])
    None => div(class="daemon-state", [info_row("LaunchAgent", "unknown")])
  }
}

///|
fn daemon_log_label(result : DaemonLifecycleResult) -> String {
  if result.stdout_path == "" && result.stderr_path == "" {
    "none"
  } else if result.stderr_path == "" {
    result.stdout_path
  } else {
    result.stdout_path + " / " + result.stderr_path
  }
}
