///|
fn render_mooncode_package_candidates_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="mooncode-review-board package-candidate-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "MoonBook package candidates"),
        h3("Package Candidates"),
      ]),
      span(class="record-kind", model.mooncode_package_candidates_status),
    ]),
    match model.mooncode_package_candidates {
      Some(candidates) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Packages", candidates.package_count.to_string()),
            info_chip("Source-bound", candidates.source_bound_package_count.to_string()),
            info_chip("Missing source", candidates.missing_source_package_count.to_string()),
            info_chip(
              "Runtime verified",
              candidates.runtime_verified_package_count.to_string(),
            ),
            info_chip(
              "Runtime proof",
              candidates.runtime_package_proof_count.to_string(),
            ),
            info_chip(
              "Executable-ready",
              candidates.package_index_executable_ready_count.to_string(),
            ),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Status", candidates.status),
            info_row("Index", candidates.package_index_status),
            info_row("Index Path", empty_label(candidates.package_index_path)),
            info_row(
              "Index Sources",
              candidates.package_index_source_bound_count.to_string(),
            ),
            info_row(
              "Entry Points",
              if candidates.package_index_entry_points.length() == 0 {
                "none yet"
              } else {
                candidates.package_index_entry_points.join(", ")
              },
            ),
            info_row("Session", candidates.session_id),
            info_row("Runtime", empty_label(candidates.runtime_session_id)),
            info_row("Rule", candidates.rule),
          ]),
          if candidates.packages.length() == 0 {
            p(
              class="status-line",
              "no MoonBook package candidate has been recorded for this session yet",
            )
          } else {
            div(
              class="mooncode-review-list package-candidate-list",
              candidates.packages[:mooncode_package_candidate_limit(candidates.packages)].map(
                candidate =>
                  render_mooncode_package_candidate(dispatch, candidate),
              ),
            )
          },
        ])
      None =>
        p(
          class="status-line",
          "No durable MoonBook package-candidate projection has been loaded for this session yet.",
        )
    },
  ])
}

///|
fn mooncode_package_candidate_limit(
  entries : Array[MoonCodePackageCandidate]
) -> Int {
  if entries.length() > 6 {
    6
  } else {
    entries.length()
  }
}

///|
fn render_mooncode_package_candidate(
  dispatch : Dispatch[Msg],
  candidate : MoonCodePackageCandidate,
) -> @rabbita.Html {
  let target = if candidate.context_path == "" {
    candidate.manifest_path
  } else {
    candidate.context_path
  }
  div(class="mooncode-review-item " + candidate.source_inventory_status, [
    div(class="mooncode-review-head", [
      div([
        strong(if target == "" { candidate.package_kind } else { target }),
        small(
          candidate.package_kind +
          " / " +
          candidate.source_inventory_status +
          " / " +
          candidate.recorded_at,
        ),
      ]),
      div(class="toolbar-actions", [
        if candidate.manifest_path == "" {
          span(class="hidden-inline", "")
        } else {
          button(
            class="secondary-button",
            on_click=dispatch(OpenQuickPath(candidate.manifest_path)),
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
          on_click=dispatch(RunMoonCodeCommandForPath("accept", target)),
          "Accept",
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
      info_chip("Sources", candidate.source_inventory_count.to_string()),
      info_chip("Ready", candidate.source_present_count.to_string()),
      info_chip("Command", empty_label(candidate.command_id)),
    ]),
    div(class="daemon-state compact-state", [
            info_row("Manifest", candidate.manifest_path),
            info_row("Receipt", empty_label(candidate.review_receipt_path)),
            info_row("Context", empty_label(candidate.context_path)),
            info_row("Execution", candidate.execution_state),
            info_row("Candidates", mooncode_candidate_paths_label(candidate.candidate_paths)),
          ]),
    div(class="mooncode-stats", [
      info_chip("Runtime built", candidate.runtime_built_count.to_string()),
      info_chip("Runtime verified", candidate.runtime_verified_count.to_string()),
      info_chip("Runtime proof", candidate.runtime_proof_count.to_string()),
      info_chip("Verified", if candidate.execution_verified { "yes" } else { "no" }),
    ]),
    render_mooncode_package_source_inventory(candidate.source_inventory),
    p(class="mooncode-event-detail", candidate.detail),
  ])
}

///|
fn mooncode_candidate_paths_label(paths : Array[String]) -> String {
  if paths.length() == 0 {
    "none"
  } else if paths.length() <= 3 {
    paths.join(", ")
  } else {
    paths[:3].join(", ") + " +" + (paths.length() - 3).to_string()
  }
}

///|
fn render_mooncode_package_source_inventory(
  records : Array[MoonCodePackageSourceRecord]
) -> @rabbita.Html {
  if records.length() == 0 {
    p(class="status-line", "no source inventory recorded")
  } else {
    div(
      class="mooncode-event-list compact package-source-list",
      records[:mooncode_package_source_limit(records)].map(record => {
        div(class="mooncode-event " + mooncode_package_source_state(record), [
          div(class="mooncode-event-head", [
            span(class="record-kind", record.kind),
            strong(record.path),
          ]),
          div(class="mooncode-stats", [
            info_chip("Exists", if record.exists { "yes" } else { "no" }),
            info_chip(
              "Ready",
              if record.package_ready { "yes" } else { "no" },
            ),
            info_chip("Size", mooncode_optional_int_label(record.size_bytes)),
            info_chip("SHA", mooncode_optional_hash_label(record.sha256)),
          ]),
        ])
      }),
    )
  }
}

///|
fn mooncode_package_source_limit(
  records : Array[MoonCodePackageSourceRecord]
) -> Int {
  if records.length() > 4 {
    4
  } else {
    records.length()
  }
}

///|
fn mooncode_package_source_state(
  record : MoonCodePackageSourceRecord
) -> String {
  if record.package_ready {
    "ready"
  } else if record.exists {
    "partial"
  } else {
    "missing"
  }
}

///|
fn mooncode_optional_int_label(value : Int?) -> String {
  match value {
    Some(number) => number.to_string()
    None => "none"
  }
}

///|
fn mooncode_optional_ratio_label(
  numerator : Int?,
  denominator : Int?,
) -> String {
  match (numerator, denominator) {
    (Some(proven), Some(expected)) => "\{proven}/\{expected}"
    _ => "none"
  }
}

///|
fn mooncode_optional_hash_label(value : String?) -> String {
  match value {
    Some(text) =>
      if text.length() > 12 {
        text[:12].to_owned()
      } else {
        text
      }
    None => "none"
  }
}
