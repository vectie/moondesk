///|
fn render_mooncode_eval_report_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="mooncode-review-board eval-report-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "MoonCode evidence"),
        h3("Eval Report"),
      ]),
      div(class="toolbar-actions", [
        span(class="record-kind", model.mooncode_eval_report_status),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("run_eval")),
          "Run Eval",
        ),
      ]),
    ]),
    match model.mooncode_eval_report {
      Some(report) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Passed", report.passed_check_count.to_string()),
            info_chip("Missing", report.missing_check_count.to_string()),
            info_chip("Checks", report.check_count.to_string()),
            info_chip(
              "Native",
              if report.native_eval_evidence_ready { "ready" } else { "missing" },
            ),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Status", report.status),
            info_row("Runtime", report.runtime_owner),
            info_row("UI", report.ui_owner),
            info_row("Artifact", report.artifact_owner),
            info_row("Standalone", report.standalone_component),
            info_row("Native Source", report.native_eval_source),
            info_row("Native Endpoint", report.native_eval_endpoint),
            info_row(
              "Native Ingest",
              report.native_eval_ingest_method +
              " " +
              report.native_eval_ingest_endpoint,
            ),
            info_row("Manifest", empty_label(report.manifest_path)),
            info_row("Recorded", empty_label(report.recorded_at)),
            info_row("Runtime", empty_label(report.runtime_session_id)),
          ]),
          p(class="mooncode-event-detail", report.current_gap),
          div(class="mooncode-output-roots", [
            small("Required native harnesses"),
            p(report.required_native_harnesses.join(", ")),
          ]),
          ul(
            class="mooncode-evidence-list",
            report.minimum_native_evidence.map(item => li(item)),
          ),
          render_mooncode_eval_checks(report.checks),
        ])
      None =>
        p(
          class="status-line",
          "No MoonCode eval report has been loaded for this session yet.",
        )
    },
  ])
}
