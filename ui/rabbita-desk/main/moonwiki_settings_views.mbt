///|
fn render_settings_pane(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  aside(
    class="activity-pane user-pane more-pane",
    attrs=@html.Attrs::build().aria_label("Pages settings"),
    [
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
    ],
  )
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
      class="primary-button full",
      on_click=dispatch(SaveCurrentView),
      "Save current view",
    ),
    if model.saved_view_action_status == "" {
      @html.nothing
    } else {
      p(class="status-line", model.saved_view_action_status)
    },
    match model.saved_views_state {
      Some(state) =>
        div(
          class="surface-state-panel",
          attrs=@html.Attrs::build()
            .data_set("testid", "saved-views-state-panel")
            .data_set("state", saved_views_state_key(Some(state))),
          [
            render_polite_state_announcement(
              "saved-views-state-announcement",
              saved_views_state_title(Some(state)),
              saved_views_state_detail(Some(state)),
            ),
            match saved_views_state_action(Some(state)) {
              Some(label) =>
                button(
                  class="secondary-button full",
                  on_click=dispatch(RefreshSavedViews),
                  label,
                )
              None => @html.nothing
            },
            if saved_views_state_shows_technical_details(Some(state)) &&
              model.saved_views_error != "" {
              details(class="wiki-disclosure", [
                summary("Technical details"),
                p(class="technical-detail", model.saved_views_error),
              ])
            } else {
              @html.nothing
            },
          ],
        )
      None => @html.nothing
    },
    if saved_views_state_keeps_rows(model.saved_views_state) &&
      !model.saved_views.is_empty() {
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
    } else {
      @html.nothing
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
