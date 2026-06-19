///|
fn render_bottom_drawer(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="bottom-drawer", [
    div(
      class="drawer-tabs",
      drawer_tabs().map(tab => {
        let class_name = if tab.key == model.drawer_tab {
          "drawer-tab active"
        } else {
          "drawer-tab"
        }
        button(
          class=class_name,
          on_click=dispatch(SelectDrawerTab(tab.key)),
          tab.label,
        )
      }),
    ),
    div(
      class="drawer-records drawer-records-single",
      match model.drawer_tab {
        DrawerRequests => [render_request_drawer(model)]
        DrawerMessages => [render_message_drawer(model)]
        DrawerRuns => [render_run_drawer(dispatch, model)]
        DrawerMoonCode => [render_mooncode_drawer(dispatch, model)]
        DrawerRecent => [render_recent_drawer(dispatch, model)]
      },
    ),
  ])
}

///|
fn render_request_drawer(model : Model) -> @rabbita.Html {
  div(class="drawer-record", [
    span(class="record-kind", "requests"),
    div([
      h3("\{model.requests.length()} staged"),
      p(
        if model.requests.length() == 0 {
          "No Moondesk requests staged yet."
        } else {
          request_title(model.requests[model.requests.length() - 1])
        },
      ),
    ]),
  ])
}

///|
fn render_message_drawer(model : Model) -> @rabbita.Html {
  div(class="drawer-record", [
    span(class="record-kind", "town"),
    div([
      h3("\{model.town_messages.length()} messages"),
      p(
        if model.town_messages.length() == 0 {
          "No recent town messages."
        } else {
          let message = model.town_messages[model.town_messages.length() - 1]
          "\{message.kind} \{message.id}: \{message.title} (\{message.path})"
        },
      ),
    ]),
  ])
}

///|
fn render_run_drawer(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  div(class="drawer-record", [
    span(class="record-kind", "runs"),
    div([
      h3("\{model.runs.length()} runs"),
      match first_run_report_path(model) {
        Some(path) =>
          button(
            class="mini-link inline",
            on_click=dispatch(OpenQuickPath(path)),
            "Open latest report",
          )
        None => p("No run reports found.")
      },
    ]),
  ])
}

///|
fn render_recent_drawer(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  div(class="drawer-record", [
    span(class="record-kind", "recent"),
    div([
      h3("\{model.recent_paths.length()} paths"),
      if model.recent_paths.length() == 0 {
        p("No recent paths yet.")
      } else {
        div(
          class="mini-list",
          model.recent_paths.map(path => {
            button(
              class="mini-link",
              on_click=dispatch(OpenQuickPath(path)),
              path,
            )
          }),
        )
      },
    ]),
  ])
}
