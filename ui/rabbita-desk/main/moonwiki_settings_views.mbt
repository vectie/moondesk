///|
fn render_settings_pane(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  aside(class="activity-pane user-pane more-pane", [
    div(class="pane-heading", [
      div([p(class="eyebrow", "Book tools"), h2("More")]),
    ]),
    section(class="side-section attention-summary", [
      h3("Needs your attention"),
      div(class="attention-counts", [
        div([
          strong(model.review_items.length().to_string()),
          span("Waiting for review"),
        ]),
        div([strong(model.runs.length().to_string()), span("Recent results")]),
        div([
          strong(model.standing_goals.length().to_string()),
          span("Automations"),
        ]),
      ]),
      div(class="toolbar-actions stack-actions", [
        button(
          class="secondary-button",
          on_click=dispatch(SelectActivity(Runs)),
          "Open review",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(SelectActivity(Town)),
          "Open activity",
        ),
      ]),
    ]),
    render_saved_views_panel(dispatch, model),
    details(class="wiki-disclosure", [
      summary(class="wiki-disclosure-summary", "Calendar and notifications"),
      div(class="wiki-disclosure-body", [
        button(
          class="secondary-button full",
          on_click=dispatch(NotifyDaily),
          "Send activity summary",
        ),
        p(
          class="status-line",
          wiki_notification_status(model.notification_status),
        ),
        a(
          class="secondary-button link-button full",
          href=@desk.town_calendar_url(),
          target=Blank,
          rel="noreferrer",
          "Open calendar export",
        ),
      ]),
    ]),
    render_diagnostics_disclosure(dispatch, model),
  ])
}

///|
fn render_saved_views_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="side-section", [
    h3("Saved views"),
    input(class="line-input", value=model.view_title, placeholder="View name", on_input=fn(
      value,
    ) {
      dispatch(SetViewTitle(value))
    }),
    button(
      class="secondary-button full",
      on_click=dispatch(SaveCurrentView),
      "Save current view",
    ),
    if model.saved_views.length() == 0 {
      p(class="status-line", "No saved views yet.")
    } else {
      div(
        class="saved-view-list",
        model.saved_views.map(view => {
          button(
            class="saved-view-row",
            title="\{view.id} | \{view.created_at} | \{view.updated_at}",
            on_click=dispatch(SelectSearchHit(view.workspace_id, view.path)),
            [
              strong(view.title),
              small(
                if view.query == "" {
                  "Saved page"
                } else {
                  "Saved search"
                },
              ),
            ],
          )
        }),
      )
    },
  ])
}

///|
fn wiki_notification_status(status : String) -> String {
  let value = status.trim().to_lower()
  if value.contains("requested") {
    "Summary requested."
  } else if value.contains("idle") || value == "" {
    ""
  } else {
    status
  }
}
