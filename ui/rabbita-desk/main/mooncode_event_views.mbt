///|
fn render_mooncode_event_lanes(
  model : Model,
  session : MoonCodeSession,
) -> @rabbita.Html {
  let summary = session.mooncode_summary
  section(class="mooncode-stream", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", summary.protocol),
        h3("MoonCode Stream"),
      ]),
      span(
        class=if summary.has_packaging_candidate {
          "record-kind good"
        } else {
          "record-kind"
        },
        if summary.has_packaging_candidate {
          "package ready"
        } else {
          "\{summary.event_count} events"
        },
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip("Tools", summary.tool_count.to_string()),
      info_chip("Diffs", summary.diff_count.to_string()),
      info_chip("Tests", summary.test_count.to_string()),
      info_chip("Verified", summary.verified_test_count.to_string()),
      info_chip("Artifacts", summary.artifact_count.to_string()),
      info_chip("Source-bound", summary.source_bound_package_count.to_string()),
      info_chip("Review", summary.review_count.to_string()),
      info_chip("Pending", summary.pending_diff_count.to_string()),
      info_chip("Deferred Steers", summary.deferred_steer_count.to_string()),
      info_chip("Cursor", model.mooncode_stream_cursor.to_string()),
    ]),
    render_mooncode_live_tail(model),
    div(class="mooncode-lane-grid", [
      render_mooncode_lane(session, "tool", "Tools"),
      render_mooncode_lane(session, "diff", "Diffs"),
      render_mooncode_lane(session, "test", "Tests"),
      render_mooncode_lane(session, "artifact", "Artifacts"),
      render_mooncode_lane(session, "review", "Review"),
    ]),
  ])
}

///|
fn render_mooncode_live_tail(model : Model) -> @rabbita.Html {
  div(class="mooncode-live-tail", [
    div(class="mooncode-lane-title", [
      strong("Live Tail"),
      span(class="record-kind", model.mooncode_stream_status),
      span(class="record-kind", model.mooncode_stream_checkpoint_status),
    ]),
    if model.mooncode_stream_events.length() == 0 {
      p(class="status-line", "waiting for incremental stream events")
    } else {
      div(
        class="mooncode-event-list compact",
        model.mooncode_stream_events[:mooncode_lane_limit(
          model.mooncode_stream_events,
        )].map(event => render_mooncode_event(event)),
      )
    },
  ])
}

///|
fn info_chip(label : String, value : String) -> @rabbita.Html {
  span(class="info-chip", [strong(value), small(label)])
}

///|
fn render_mooncode_lane(
  session : MoonCodeSession,
  lane : String,
  title : String,
) -> @rabbita.Html {
  let events = mooncode_lane_events(session, lane)
  div(class="mooncode-lane " + lane, [
    div(class="mooncode-lane-title", [
      strong(title),
      span(class="record-kind", events.length().to_string()),
    ]),
    if events.length() == 0 {
      p(class="status-line", "waiting")
    } else {
      div(
        class="mooncode-event-list",
        events[:mooncode_lane_limit(events)].map(event =>
          render_mooncode_event(event)),
      )
    },
  ])
}
