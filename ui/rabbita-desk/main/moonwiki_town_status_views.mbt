///|
fn render_town_progress_panel(model : Model) -> @rabbita.Html {
  match model.town_progress {
    Some(progress) =>
      section(class="side-section", [
        h3("Live Progress"),
        info_row(
          "Daemon",
          "\{progress.daemon_status} / tick \{progress.daemon_tick}",
        ),
        info_row("Running", if progress.daemon_running { "yes" } else { "no" }),
        info_row(
          "Supervision",
          if progress.supervision_enabled {
            "enabled"
          } else {
            "disabled"
          },
        ),
        info_row(
          "Due",
          "\{progress.due_goal_count} / next \{progress.next_due_tick}",
        ),
        info_row(
          "Queued",
          "\{progress.request_count} requests / \{progress.dispatch_count} dispatches",
        ),
        info_row(
          "Outputs",
          "\{progress.message_count} messages / \{progress.run_count} runs",
        ),
        info_row("Latest Request", empty_label(progress.latest_request)),
        info_row("Latest Message", empty_label(progress.latest_message)),
        info_row("Latest Dispatch", empty_label(progress.latest_dispatch)),
        info_row("Latest Run", latest_run_label(progress)),
      ])
    None =>
      section(class="side-section", [
        h3("Live Progress"),
        p(class="status-line", "waiting for progress"),
      ])
  }
}

///|
fn empty_label(value : String) -> String {
  if value == "" {
    "none"
  } else {
    value
  }
}

///|
fn string_list_label(values : Array[String]) -> String {
  if values.length() == 0 {
    "none"
  } else {
    values.join(", ")
  }
}

///|
fn latest_run_label(progress : TownProgress) -> String {
  if progress.latest_run == "" {
    "none"
  } else {
    "\{progress.latest_run} / \{progress.latest_run_status} / \{progress.latest_run_artifacts} artifacts"
  }
}

///|
fn render_event_panel(model : Model) -> @rabbita.Html {
  section(class="side-section", [
    h3("Events"),
    if model.events.length() == 0 {
      p(class="status-line", "no recent events")
    } else {
      div(
        class="event-list",
        model.events[:event_limit(model.events)].map(event => {
          div(class="event-row " + event.severity, [
            span(class="record-kind", event.severity),
            strong(event.title),
            small(
              "\{event.source} / \{event.kind} / \{event.id} / \{event_time_label(event)}",
            ),
            p(event.detail),
          ])
        }),
      )
    },
  ])
}

///|
fn event_limit(events : Array[DeskEvent]) -> Int {
  if events.length() > 8 {
    8
  } else {
    events.length()
  }
}

///|
fn event_time_label(event : DeskEvent) -> String {
  let tick = if event.tick > 0 { "tick \{event.tick}" } else { "no tick" }
  let run = if event.run_id == "" { "no run" } else { event.run_id }
  let time = if event.created_at == "" {
    empty_label(event.path)
  } else {
    event.created_at
  }
  "\{tick} / \{run} / \{time}"
}
