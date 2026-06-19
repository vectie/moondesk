///|
fn render_mooncode_test_runs_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="mooncode-review-board test-runs-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "test/build object"),
        h3("Test Runs"),
      ]),
      span(class="record-kind", model.mooncode_test_runs_status),
    ]),
    match model.mooncode_test_runs {
      Some(test_runs) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Runs", test_runs.run_count.to_string()),
            info_chip("Passed", test_runs.passed_run_count.to_string()),
            info_chip("Failed", test_runs.failed_run_count.to_string()),
            info_chip("Running", test_runs.running_run_count.to_string()),
            info_chip("Queued", test_runs.queued_run_count.to_string()),
            info_chip("Verified", test_runs.verified_run_count.to_string()),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Manifest", test_runs.manifest_path),
            info_row("Recorded", test_runs.recorded_at),
            info_row("Status", test_runs.status),
          ]),
          if test_runs.runs.length() == 0 {
            p(class="status-line", "no test/build runs recorded")
          } else {
            div(
              class="mooncode-review-list test-run-list",
              test_runs.runs[:mooncode_test_run_limit(test_runs.runs)].map(run =>
                render_mooncode_test_run_entry(dispatch, run)
              ),
            )
          },
        ])
      None =>
        p(
          class="status-line",
          "No durable MoonBook test-run manifest has been recorded for this session yet.",
        )
    },
  ])
}

///|
fn mooncode_test_run_limit(entries : Array[MoonCodeTestRunEntry]) -> Int {
  if entries.length() > 6 {
    6
  } else {
    entries.length()
  }
}

///|
fn render_mooncode_test_run_entry(
  dispatch : Dispatch[Msg],
  run : MoonCodeTestRunEntry,
) -> @rabbita.Html {
  let target = if run.target == "" {
    if run.path == "" { run.command } else { run.path }
  } else {
    run.target
  }
  div(class="mooncode-review-item " + run.run_state, [
    div(class="mooncode-review-head", [
      div([
        strong(if run.command == "" { run.title } else { run.command }),
        small(run.run_state + " / " + run.created_at),
      ]),
      div(class="toolbar-actions", [
        if run.path == "" {
          span(class="hidden-inline", "")
        } else {
          button(
            class="secondary-button",
            on_click=dispatch(OpenQuickPath(run.path)),
            "Open",
          )
        },
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("run_tests", target)),
          "Rerun",
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
      ]),
    ]),
    div(class="mooncode-stats", [
      info_chip("Exit", run.exit_code.to_string()),
      info_chip("Verified", if run.verified { "yes" } else { "no" }),
      info_chip("Kind", run.kind),
    ]),
    if run.path != "" {
      code(run.path)
    } else if run.command != "" {
      code(run.command)
    } else {
      code(run.id)
    },
    p(class="mooncode-event-detail", run.detail),
  ])
}
