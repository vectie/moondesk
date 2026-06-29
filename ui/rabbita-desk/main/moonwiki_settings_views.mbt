///|
fn render_settings_pane(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  aside(class="activity-pane", [
    div(class="pane-heading", [
      div([p(class="eyebrow", "daily"), h2("Operating Surface")]),
      button(
        class="icon-button",
        title="Notify",
        on_click=dispatch(NotifyDaily),
        "N",
      ),
    ]),
    section(class="side-section", [
      h3("Today"),
      info_row("Requests", model.requests.length().to_string()),
      info_row("Runs", model.runs.length().to_string()),
      info_row("Messages", model.town_messages.length().to_string()),
      info_row("Latest", latest_town_message_label(model)),
      info_row("Goals", model.standing_goals.length().to_string()),
      info_row("Favorites", model.favorites.length().to_string()),
      button(
        class="primary-button full",
        on_click=dispatch(NotifyDaily),
        "Notify Summary",
      ),
      p(class="status-line", model.notification_status),
    ]),
    render_saved_views_panel(dispatch, model),
    render_review_queue_panel(dispatch, model),
    section(class="side-section", [
      h3("Calendar Export"),
      a(
        class="secondary-button link-button full",
        href="/api/town/calendar.ics",
        target=Blank,
        rel="noreferrer",
        "Open ICS",
      ),
    ]),
    render_cadence_panel(model),
    render_cadence_calendar(model),
    render_analytics_panel(model),
    section(class="side-section", [
      h3("Export Snapshot"),
      pre(class="source-block compact", code(export_snapshot(model))),
    ]),
  ])
}

///|
fn render_saved_views_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="side-section", [
    h3("Saved Views"),
    input(
      class="line-input",
      value=model.view_title,
      placeholder="View title",
      on_input=fn(value) { dispatch(SetViewTitle(value)) },
    ),
    button(
      class="secondary-button full",
      on_click=dispatch(SaveCurrentView),
      "Save Current View",
    ),
    div(
      class="mini-list",
      model.saved_views.map(view => {
        button(
          class="mini-link",
          title="\{view.id} / \{view.updated_at}",
          on_click=dispatch(SelectSearchHit(view.workspace_id, view.path)),
          [
            span(view.title),
            small(
              if view.query == "" {
                "\{view.path} / \{view.created_at}"
              } else {
                "\{view.query} / \{view.path}"
              },
            ),
          ],
        )
      }),
    ),
  ])
}

///|
fn render_review_queue_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="side-section", [
    h3("Review Queue"),
    if model.review_items.length() == 0 {
      p(class="status-line", "none")
    } else {
      div(
        class="mini-list",
        model.review_items[:review_limit(model.review_items)].map(item => {
          let msg = if item.workspace_id == "" {
            SelectActivity(Town)
          } else {
            SelectSearchHit(item.workspace_id, item.path)
          }
          button(
            class="mini-link",
            title="\{item.id} / \{item.kind} / \{item.detail}",
            on_click=dispatch(msg),
            [span(item.title), small("\{item.status} / \{item.path}")],
          )
        }),
      )
    },
  ])
}

///|
fn review_limit(items : Array[ReviewItem]) -> Int {
  if items.length() > 8 {
    8
  } else {
    items.length()
  }
}

///|
fn render_cadence_panel(model : Model) -> @rabbita.Html {
  section(class="side-section", [
    h3("Cadence"),
    div(
      class="cadence-list",
      model.standing_goals.map(goal => {
        let due_label = match model.analytics {
          Some(analytics) if analytics.daemon_tick >= goal.next_due_tick =>
            "due"
          Some(analytics) =>
            "\{goal.next_due_tick - analytics.daemon_tick} ticks"
          None => "next \{goal.next_due_tick}"
        }
        div(class="cadence-row", [
          span(class="record-kind", due_label),
          div([
            strong(goal.title),
            small("\{goal.source_policy} / every \{goal.cadence_ticks}"),
          ]),
        ])
      }),
    ),
  ])
}

///|
fn render_cadence_calendar(model : Model) -> @rabbita.Html {
  let tick = match model.analytics {
    Some(analytics) => analytics.daemon_tick
    None => 0
  }
  let cells = if model.standing_goals.length() == 0 {
    [p(class="status-line", "no standing watches")]
  } else {
    model.standing_goals.map(goal => {
      let class_name = "calendar-cell " + cadence_state(tick, goal)
      div(class=class_name, [
        span(class="record-kind", cadence_due_label(tick, goal.next_due_tick)),
        strong(goal.title),
        small("tick \{goal.next_due_tick}"),
        small("every \{goal.cadence_ticks} ticks"),
      ])
    })
  }
  section(class="side-section", [
    h3("Calendar"),
    div(class="calendar-grid", cells),
  ])
}

///|
fn cadence_state(tick : Int, goal : StandingGoalRecord) -> String {
  if tick > 0 && tick >= goal.next_due_tick {
    "due"
  } else if tick > 0 && goal.next_due_tick - tick <= 12 {
    "soon"
  } else {
    "scheduled"
  }
}

///|
fn cadence_due_label(tick : Int, next_due_tick : Int) -> String {
  if tick > 0 {
    let delta = next_due_tick - tick
    if delta <= 0 {
      "due"
    } else {
      "+\{delta}"
    }
  } else {
    "tick"
  }
}

///|
fn render_analytics_panel(model : Model) -> @rabbita.Html {
  match model.analytics {
    Some(analytics) => {
      let outcomes = analytics.no_changes +
        analytics.updates +
        analytics.needs_review +
        analytics.failures +
        analytics.deferred
      section(class="side-section", [
        h3("Analytics"),
        info_row("Daemon", "tick \{analytics.daemon_tick}"),
        info_row("Goals", "\{analytics.standing_goal_count} total"),
        info_row(
          "Due",
          "\{analytics.due_goal_count} / active \{analytics.active_goal_count}",
        ),
        info_row("Next Due", analytics.next_due_tick.to_string()),
        info_row("Requests", analytics.request_count.to_string()),
        info_row("Messages", analytics.message_count.to_string()),
        info_row("Runs", analytics.run_count.to_string()),
        info_row("Watcher", "\{analytics.watcher_run_count} runs"),
        info_row("No-change", analytics.no_changes.to_string()),
        info_row("Updates", analytics.updates.to_string()),
        info_row("Review", analytics.needs_review.to_string()),
        info_row("Failures", analytics.failures.to_string()),
        info_row("Deferred", analytics.deferred.to_string()),
        info_row("Events", analytics.event_count.to_string()),
        info_row("Failure Events", analytics.failure_event_count.to_string()),
        info_row("Review Events", analytics.review_event_count.to_string()),
        info_row("Review Queue", analytics.review_item_count.to_string()),
        info_row("Last Failure", empty_label(analytics.last_failure)),
        div(class="outcome-mix", [
          outcome_row("updates", analytics.updates, outcomes, "updates"),
          outcome_row("no-change", analytics.no_changes, outcomes, "quiet"),
          outcome_row("review", analytics.needs_review, outcomes, "review"),
          outcome_row("failures", analytics.failures, outcomes, "failure"),
          outcome_row("deferred", analytics.deferred, outcomes, "deferred"),
        ]),
      ])
    }
    None =>
      section(class="side-section", [
        h3("Analytics"),
        p(class="status-line", "waiting for town analytics"),
      ])
  }
}

///|
fn outcome_row(
  label : String,
  value : Int,
  total : Int,
  tone : String,
) -> @rabbita.Html {
  div(class="outcome-row " + tone, [
    span(label),
    code("\{value} / \{percent_text(value, total)}"),
  ])
}

///|
fn percent_text(value : Int, total : Int) -> String {
  if total <= 0 {
    "0%"
  } else {
    "\{value * 100 / total}%"
  }
}

///|
fn daemon_snapshot_label(model : Model) -> String {
  match model.analytics {
    Some(analytics) => "tick \{analytics.daemon_tick}"
    None => "unknown"
  }
}

///|
fn latest_town_message_label(model : Model) -> String {
  if model.town_messages.length() == 0 {
    "none"
  } else {
    let message = model.town_messages[model.town_messages.length() - 1]
    "\{message.kind} \{message.id}: \{message.title} (\{message.path})"
  }
}

///|
fn export_snapshot(model : Model) -> String {
  "Moondesk snapshot\n" +
  "workspace: \{workspace_name(model)}\n" +
  "selected: \{model.selected_path}\n" +
  "requests: \{model.requests.length()}\n" +
  "runs: \{model.runs.length()}\n" +
  "messages: \{model.town_messages.length()}\n" +
  "latest message: \{latest_town_message_label(model)}\n" +
  "standing goals: \{model.standing_goals.length()}\n" +
  "daemon: \{daemon_snapshot_label(model)}\n" +
  "favorites: \{model.favorites.join(", ")}\n"
}
