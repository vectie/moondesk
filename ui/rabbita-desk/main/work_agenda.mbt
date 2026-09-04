///|
enum WorkAgendaState {
  AgendaDue
  AgendaUpcoming
  AgendaPaused
} derive(Debug, Eq)

///|
struct WorkAgendaItem {
  goal : StandingGoalRecord
  state : WorkAgendaState
  relative_label : String
}

///|
fn work_agenda_state(
  goal : StandingGoalRecord,
  current_tick : Int,
) -> WorkAgendaState {
  if !goal.enabled {
    AgendaPaused
  } else if goal.next_due_tick <= current_tick {
    AgendaDue
  } else {
    AgendaUpcoming
  }
}

///|
fn work_agenda_relative_label(state : WorkAgendaState) -> String {
  match state {
    AgendaDue => "Due now"
    AgendaUpcoming => "Upcoming"
    AgendaPaused => "Paused"
  }
}

///|
fn work_agenda_item(
  goal : StandingGoalRecord,
  current_tick : Int,
) -> WorkAgendaItem {
  let state = work_agenda_state(goal, current_tick)
  { goal, state, relative_label: work_agenda_relative_label(state) }
}

///|
fn work_agenda_items(
  goals : Array[StandingGoalRecord],
  current_tick : Int,
) -> Array[WorkAgendaItem] {
  let due : Array[WorkAgendaItem] = []
  let upcoming : Array[WorkAgendaItem] = []
  let paused : Array[WorkAgendaItem] = []
  for goal in goals {
    let item = work_agenda_item(goal, current_tick)
    match item.state {
      AgendaDue => due.push(item)
      AgendaUpcoming => upcoming.push(item)
      AgendaPaused => paused.push(item)
    }
  }
  due + upcoming + paused
}

///|
fn work_agenda_current_tick(model : Model) -> Int {
  match model.analytics {
    Some(analytics) => analytics.daemon_tick
    None =>
      match model.town_progress {
        Some(progress) => progress.daemon_tick
        None => 0
      }
  }
}

///|
fn work_agenda_state_class(state : WorkAgendaState) -> String {
  match state {
    AgendaDue => "due"
    AgendaUpcoming => "upcoming"
    AgendaPaused => "paused"
  }
}

///|
fn work_agenda_recent_runs(
  runs : Array[@desk.DeskRunProjection],
) -> Array[@desk.DeskRunProjection] {
  runs[:runs.length().min(3)].to_owned()
}

///|
fn work_agenda_run_status(run : @desk.DeskRunProjection) -> String {
  match run.status.to_lower() {
    "completed" | "ready" | "succeeded" | "success" => "Completed"
    "failed" | "error" => "Needs attention"
    "running" | "active" => "In progress"
    _ => "Recent result"
  }
}

///|
fn render_work_agenda(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  let items = work_agenda_items(
    model.standing_goals,
    work_agenda_current_tick(model),
  )
  let recent_runs = work_agenda_recent_runs(model.runs)
  section(
    class="side-section work-agenda",
    attrs=@html.Attrs::build().data_set("testid", "work-agenda"),
    [
      header(class="work-agenda-heading", [
        div([p(class="eyebrow", "Background work"), h3("Agenda")]),
        button(
          class="secondary-button compact-button",
          on_click=dispatch(SelectActivity(Town)),
          "Manage",
        ),
      ]),
      p(
        class="work-agenda-intro",
        "See what your books need now, what is coming next, and what recently finished.",
      ),
      if items.is_empty() {
        div(class="work-agenda-empty", [
          strong("Nothing scheduled"),
          small(
            "Ask in chat to keep checking something, or create an automation.",
          ),
        ])
      } else {
        div(
          class="work-agenda-list",
          items.map(item => {
            div(
              class="work-agenda-row " + work_agenda_state_class(item.state),
              attrs=@html.Attrs::build().data_set(
                "agenda-state",
                work_agenda_state_class(item.state),
              ),
              [
                span(class="work-agenda-dot", ""),
                div([strong(item.goal.title), small(item.goal.target_book_id)]),
                span(item.relative_label),
              ],
            )
          }),
        )
      },
      if recent_runs.is_empty() {
        @html.nothing
      } else {
        div(class="work-agenda-results", [
          header([
            strong("Recent results"),
            button(
              class="link-button",
              on_click=dispatch(SelectActivity(Runs)),
              "View all",
            ),
          ]),
          div(
            recent_runs.map(run => {
              button(
                class="work-agenda-result",
                on_click=dispatch(SelectActivity(Runs)),
                [
                  div([
                    strong(
                      if run.summary == "" {
                        run.run_id
                      } else {
                        run.summary
                      },
                    ),
                    small(run.book_id),
                  ]),
                  span(work_agenda_run_status(run)),
                ],
              )
            }),
          ),
        ])
      },
    ],
  )
}
