///|
fn render_mooncode_review_queue(
  dispatch : Dispatch[Msg],
  session : MoonCodeSession,
) -> @rabbita.Html {
  let summary = session.mooncode_summary
  let diffs = mooncode_lane_events(session, "diff")
  section(class="mooncode-review-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "review"),
        h3("Code Review"),
      ]),
      span(
        class=match summary.review_state {
          "accepted" => "record-kind good"
          "rejected" => "record-kind"
          "pending" => "record-kind"
          _ => "record-kind"
        },
        summary.review_state,
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip("Diffs", summary.diff_count.to_string()),
      info_chip("Pending", summary.pending_diff_count.to_string()),
      info_chip("Accepted", summary.accepted_review_count.to_string()),
      info_chip("Rejected", summary.rejected_review_count.to_string()),
      info_chip("Change Sets", summary.moonbook_change_set_manifest_count.to_string()),
      info_chip("Patch Sets", summary.moonbook_patch_set_manifest_count.to_string()),
    ]),
    if diffs.length() == 0 {
      p(class="status-line", "no diff candidates")
    } else {
      div(
        class="mooncode-review-list",
        diffs[:mooncode_review_limit(diffs)].map(event =>
          render_mooncode_review_item(dispatch, event)
        ),
      )
    },
  ])
}

///|
fn mooncode_review_limit(events : Array[MoonCodeEvent]) -> Int {
  if events.length() > 6 {
    6
  } else {
    events.length()
  }
}

///|
fn render_mooncode_review_item(
  dispatch : Dispatch[Msg],
  event : MoonCodeEvent,
) -> @rabbita.Html {
  div(class="mooncode-review-item " + event.status, [
    div(class="mooncode-review-head", [
      div([
        strong(if event.path == "" { event.title } else { event.path }),
        small(event.status + " / " + event.created_at),
      ]),
      div(class="toolbar-actions", [
        if event.path == "" {
          span(class="hidden-inline", "")
        } else {
          button(
            class="secondary-button",
            on_click=dispatch(OpenQuickPath(event.path)),
            "Open",
          )
        },
        button(
          class="secondary-button",
          on_click=if event.path == "" {
            dispatch(RunMoonCodeCommand("accept"))
          } else {
            dispatch(RunMoonCodeCommandForPath("accept", event.path))
          },
          "Accept",
        ),
        button(
          class="secondary-button",
          on_click=if event.path == "" {
            dispatch(RunMoonCodeCommand("reject"))
          } else {
            dispatch(RunMoonCodeCommandForPath("reject", event.path))
          },
          "Reject",
        ),
        button(
          class="secondary-button",
          on_click=if event.path == "" {
            dispatch(RunMoonCodeCommand("package"))
          } else {
            dispatch(RunMoonCodeCommandForPath("package", event.path))
          },
          "Package",
        ),
        button(
          class="secondary-button",
          on_click=if event.path == "" {
            dispatch(RunMoonCodeCommand("commit"))
          } else {
            dispatch(RunMoonCodeCommandForPath("commit", event.path))
          },
          "Commit",
        ),
      ]),
    ]),
    if event.diff == "" {
      p(class="mooncode-event-detail", event.detail)
    } else {
      pre(class="source-block compact", code(event.diff))
    },
  ])
}

///|
fn mooncode_lane_events(
  session : MoonCodeSession,
  lane : String,
) -> Array[MoonCodeEvent] {
  let events : Array[MoonCodeEvent] = []
  for event in session.mooncode_events {
    if event.lane == lane {
      events.push(event)
    }
  }
  events
}

///|
fn mooncode_lane_limit(events : Array[MoonCodeEvent]) -> Int {
  if events.length() > 4 {
    4
  } else {
    events.length()
  }
}

///|
fn mooncode_stream_buffer_limit() -> Int {
  80
}

///|
fn mooncode_merge_stream_events(
  existing : Array[MoonCodeEvent],
  incoming : Array[MoonCodeEvent],
) -> Array[MoonCodeEvent] {
  let merged : Array[MoonCodeEvent] = []
  for event in existing {
    mooncode_push_unique_stream_event(merged, event)
  }
  for event in incoming {
    mooncode_push_unique_stream_event(merged, event)
  }
  mooncode_trim_stream_events(merged, mooncode_stream_buffer_limit())
}

///|
fn mooncode_push_unique_stream_event(
  events : Array[MoonCodeEvent],
  event : MoonCodeEvent,
) -> Unit {
  if event.id != "" {
    for existing in events {
      if existing.id == event.id {
        return
      }
    }
  }
  events.push(event)
}

///|
fn mooncode_trim_stream_events(
  events : Array[MoonCodeEvent],
  limit : Int,
) -> Array[MoonCodeEvent] {
  if events.length() <= limit {
    events
  } else {
    let trimmed : Array[MoonCodeEvent] = []
    let start = events.length() - limit
    for index in start..<events.length() {
      trimmed.push(events[index])
    }
    trimmed
  }
}

///|
fn render_mooncode_event(event : MoonCodeEvent) -> @rabbita.Html {
  div(class="mooncode-event " + event.status, [
    div(class="mooncode-event-head", [
      span(class="record-kind", event.status),
      strong(event.title),
    ]),
    if event.path == "" {
      span(class="hidden-inline", "")
    } else {
      code(event.path)
    },
    if event.command == "" {
      span(class="hidden-inline", "")
    } else {
      code(event.command + " -> " + event.exit_code.to_string())
    },
    if event.diff == "" {
      p(class="mooncode-event-detail", event.detail)
    } else {
      pre(class="source-block compact", code(event.diff))
    },
  ])
}

///|
