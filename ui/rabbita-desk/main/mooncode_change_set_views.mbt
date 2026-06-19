///|
fn render_mooncode_change_set_panel(model : Model) -> @rabbita.Html {
  section(class="mooncode-review-board change-set-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "moonbook review object"),
        h3("Change Set"),
      ]),
      span(class="record-kind", model.mooncode_change_set_status),
    ]),
    match model.mooncode_change_set {
      Some(change_set) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Diffs", change_set.diff_count.to_string()),
            info_chip("Tests", change_set.test_count.to_string()),
            info_chip("Verified", change_set.verified_test_count.to_string()),
            info_chip("Failed", change_set.failed_test_count.to_string()),
            info_chip("Artifacts", change_set.artifact_count.to_string()),
            info_chip("Reviews", change_set.review_count.to_string()),
            info_chip("Pending", change_set.pending_diff_count.to_string()),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Manifest", change_set.manifest_path),
            info_row("Recorded", change_set.recorded_at),
            info_row("Status", change_set.status),
          ]),
          div(class="mooncode-lane-grid change-set-grid", [
            render_mooncode_change_set_group("Diffs", change_set.diffs),
            render_mooncode_change_set_group("Tests", change_set.tests),
            render_mooncode_change_set_group("Artifacts", change_set.artifacts),
            render_mooncode_change_set_group("Review", change_set.reviews),
          ]),
        ])
      None =>
        p(
          class="status-line",
          "No durable MoonBook change set has been recorded for this session yet.",
        )
    },
  ])
}

///|
fn render_mooncode_change_set_group(
  title : String,
  entries : Array[MoonCodeChangeSetEntry],
) -> @rabbita.Html {
  div(class="mooncode-lane change-set-group", [
    div(class="mooncode-lane-title", [
      strong(title),
      span(class="record-kind", entries.length().to_string()),
    ]),
    if entries.length() == 0 {
      p(class="status-line", "none")
    } else {
      div(
        class="mooncode-event-list compact",
        entries[:mooncode_change_set_limit(entries)].map(entry =>
          render_mooncode_change_set_entry(entry)
        ),
      )
    },
  ])
}

///|
fn mooncode_change_set_limit(
  entries : Array[MoonCodeChangeSetEntry]
) -> Int {
  if entries.length() > 3 {
    3
  } else {
    entries.length()
  }
}

///|
fn render_mooncode_change_set_entry(
  entry : MoonCodeChangeSetEntry
) -> @rabbita.Html {
  div(class="mooncode-event " + entry.status, [
    div(class="mooncode-event-head", [
      span(class="record-kind", entry.status),
      strong(if entry.path == "" { entry.title } else { entry.path }),
    ]),
    if entry.command == "" {
      span(class="hidden-inline", "")
    } else {
      code(entry.command + " -> " + entry.exit_code.to_string())
    },
    if entry.diff == "" {
      p(class="mooncode-event-detail", entry.detail)
    } else {
      pre(class="source-block compact", code(entry.diff))
    },
  ])
}
