///|
fn render_standing_goal_list(model : Model) -> @rabbita.Html {
  div(
    class="side-records",
    model.standing_goals.map(goal => {
      div(class="side-record", [
        span(
          class="record-kind",
          if goal.enabled {
            "enabled"
          } else {
            "paused"
          },
        ),
        strong(goal.title),
        small("\{goal.target_book_id} / every \{goal.cadence_ticks} ticks"),
        small("next \{goal.next_due_tick} / last \{last_run_label(goal)}"),
        small("review \{goal.review_policy} / \{goal.prompt}"),
      ])
    }),
  )
}

///|
fn last_run_label(goal : StandingGoalRecord) -> String {
  match goal.last_run_tick {
    Some(tick) => tick.to_string()
    None => "never"
  }
}

///|
fn render_request_list(model : Model) -> @rabbita.Html {
  div(
    class="side-records",
    model.requests.map(record => {
      div(class="side-record", [
        span(class="record-kind", record.status),
        strong(request_title(record)),
        small(record.path),
      ])
    }),
  )
}

///|
