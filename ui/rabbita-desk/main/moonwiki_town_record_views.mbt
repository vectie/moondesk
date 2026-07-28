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
        small(
          "source \{goal.source_policy} / review \{goal.review_policy} / \{goal.prompt}",
        ),
      ])
    }),
  )
}

///|
fn last_run_label(goal : StandingGoalRecord) -> String {
  let tick : Int = @json.from_json(goal.last_run_tick) catch {
    _ => return "never"
  }
  tick.to_string()
}

///|
fn requests_state_key(state : SurfaceState?) -> String {
  match state {
    None => "ready"
    Some(state) => surface_state_key(state)
  }
}

///|
fn requests_state_keeps_items(state : SurfaceState?) -> Bool {
  match state {
    None | Some(Loading | Stale) => true
    Some(_) => false
  }
}

///|
fn requests_state_title(state : SurfaceState) -> String {
  match state {
    FirstUseEmpty => "Check recent requests"
    LegitimateZero => "No requests yet"
    Loading => "Loading requests"
    Stale => "Showing earlier requests"
    Disconnected => "Requests are offline"
    CapabilityLimited => "Requests aren’t available"
    RecoverableError => "Requests couldn’t be loaded"
    TerminalError => "Requests can’t continue"
  }
}

///|
fn requests_state_detail(state : SurfaceState, has_items : Bool) -> String {
  match state {
    FirstUseEmpty =>
      "Check this book for requests that have already been saved."
    LegitimateZero =>
      "This book has no saved requests yet. Start one above whenever you’re ready."
    Loading =>
      if has_items {
        "Refreshing while the last successful request list remains visible."
      } else {
        "Checking this book for saved requests."
      }
    Stale =>
      "The last successful request list remains visible. Refresh to check for newer requests."
    Disconnected => "Reconnect, then retry loading this book’s requests."
    CapabilityLimited =>
      "This book cannot provide its request list in the current setup."
    RecoverableError => "Retry without losing the request you are composing."
    TerminalError => "Return to Pages and choose another action."
  }
}

///|
fn requests_state_action(state : SurfaceState) -> String? {
  match state {
    FirstUseEmpty => Some("Check")
    Stale => Some("Refresh")
    Disconnected | RecoverableError => Some("Retry")
    LegitimateZero | Loading | CapabilityLimited | TerminalError => None
  }
}

///|
fn requests_state_technical_detail(
  state : SurfaceState,
  error : String,
) -> String? {
  match state {
    Stale
    | Disconnected
    | CapabilityLimited
    | RecoverableError
    | TerminalError => if error == "" { None } else { Some(error) }
    FirstUseEmpty | LegitimateZero | Loading => None
  }
}

///|
fn render_requests_state(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  match model.requests_state {
    None => @html.nothing
    Some(state) => {
      let action = requests_state_action(state)
      let technical = requests_state_technical_detail(
        state,
        model.requests_error,
      )
      section(class="side-section surface-state-panel", [
        render_polite_state_announcement(
          "requests-state-announcement",
          requests_state_title(state),
          requests_state_detail(state, model.requests.length() > 0),
        ),
        match action {
          Some(label) =>
            button(
              class="secondary-button",
              on_click=dispatch(SelectActivity(Town)),
              label,
            )
          None => @html.nothing
        },
        match technical {
          Some(detail) =>
            details(class="technical-details", [
              summary("Technical details"),
              code(detail),
            ])
          None => @html.nothing
        },
      ])
    }
  }
}

///|
fn render_request_list(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  div(
    class="requests-ledger",
    attrs=@html.Attrs::build()
      .data_set("testid", "requests-state-panel")
      .data_set("state", requests_state_key(model.requests_state)),
    [render_requests_state(dispatch, model)],
  )
}

///|
fn render_request_diagnostics(model : Model) -> @rabbita.Html {
  section(class="side-section", [
    h3("Request ledger"),
    if model.requests.length() == 0 {
      p(class="status-line", "No request records loaded")
    } else {
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
    },
  ])
}

///|
