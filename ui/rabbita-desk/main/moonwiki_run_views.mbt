///|
fn render_runs_pane(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(class="explorer-pane", [
    div(class="pane-heading", [
      div([p(class="eyebrow", "moonclaw"), h2("Runs")]),
      button(
        class="icon-button",
        title="Refresh Runs",
        on_click=dispatch(SelectWorkspace(model.selected_workspace_id)),
        "R",
      ),
    ]),
    render_moonclaw_progress_panel(model),
    div(
      class="side-records",
      model.runs.map(run => {
        div(class="run-record", [
          div([
            span(class="record-kind", run.status),
            strong(run.run_id),
            small(run.summary),
          ]),
          div(
            class="artifact-list",
            run.artifacts.map(artifact => {
              button(
                class="artifact-link",
                title=artifact.path,
                on_click=dispatch(OpenQuickPath(artifact.path)),
                [
                  span(class="artifact-icon", icon_for_kind(artifact.kind)),
                  span(artifact.title),
                ],
              )
            }),
          ),
        ])
      }),
    ),
  ])
}

///|
fn render_moonclaw_progress_panel(model : Model) -> @rabbita.Html {
  match model.moonclaw_progress {
    Some(progress) =>
      section(class="side-section", [
        h3("Progress"),
        info_row(
          "Runs",
          "\{progress.ready_count} ready / \{progress.run_count} total",
        ),
        info_row("Artifacts", progress.artifact_count.to_string()),
        info_row(
          "Latest",
          if progress.latest_run == "" {
            "none"
          } else {
            "\{progress.latest_run} / \{progress.latest_status}"
          },
        ),
      ])
    None =>
      section(class="side-section", [
        h3("Progress"),
        p(class="status-line", "waiting for run progress"),
      ])
  }
}
