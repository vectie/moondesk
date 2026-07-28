///|
fn render_review_pane(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(
    class="activity-pane user-pane review-pane",
    attrs=@html.Attrs::build()
      .aria_label("Review queue")
      .data_set("testid", "review-state-panel")
      .data_set("state", review_state_key(model.review_state)),
    [
      div(class="pane-heading", [
        div([p(class="eyebrow", "Decisions"), h2("Review")]),
        button(
          class="secondary-button compact-button",
          title="Refresh review",
          on_click=dispatch(SelectWorkspaceMode(ReviewWorkspace)),
          "Refresh",
        ),
      ]),
      render_review_state(dispatch, model),
      if review_state_keeps_items(model.review_state) &&
        model.review_items.length() > 0 {
        div([
          section(class="side-section review-note", [
            h3("Decision note"),
            textarea(
              class="side-textarea compact-textarea",
              rows=3,
              value=model.review_decision_note,
              placeholder="Optional context for this decision",
              on_input=fn(value) { dispatch(SetReviewDecisionNote(value)) },
              "",
            ),
            p(
              class="status-line",
              wiki_review_feedback(model.review_decision_status),
            ),
          ]),
          div(
            class="review-list",
            model.review_items[:review_limit(model.review_items)].map(item => {
              render_user_review_item(dispatch, item)
            }),
          ),
        ])
      } else {
        @html.nothing
      },
    ],
  )
}

///|
fn review_state_key(state : SurfaceState?) -> String {
  match state {
    None => "ready"
    Some(state) => surface_state_key(state)
  }
}

///|
fn review_state_keeps_items(state : SurfaceState?) -> Bool {
  match state {
    None => true
    Some(Loading | Stale) => true
    Some(_) => false
  }
}

///|
fn review_state_title(state : SurfaceState) -> String {
  match state {
    FirstUseEmpty => "Open Review"
    LegitimateZero => "Nothing needs review"
    Loading => "Loading review"
    Stale => "Showing earlier review items"
    Disconnected => "Review is offline"
    CapabilityLimited => "Review isn’t available"
    RecoverableError => "Review couldn’t be loaded"
    TerminalError => "Review can’t continue"
  }
}

///|
fn review_state_detail(state : SurfaceState, has_items : Bool) -> String {
  match state {
    FirstUseEmpty =>
      "Check this book for proposed changes that need a decision."
    LegitimateZero =>
      "Proposed knowledge changes will appear here before they become part of the book."
    Loading =>
      if has_items {
        "Refreshing while the last successful review list remains visible."
      } else {
        "Checking this book for proposed changes."
      }
    Stale =>
      "The last successful review list remains visible. Refresh to check for newer changes."
    Disconnected => "Reconnect, then retry Review."
    CapabilityLimited =>
      "This book cannot provide review items in the current setup."
    RecoverableError => "Retry without leaving this book."
    TerminalError => "Return to Pages and choose another action."
  }
}

///|
fn review_state_has_retry(state : SurfaceState) -> Bool {
  state == FirstUseEmpty ||
  state == Stale ||
  state == Disconnected ||
  state == RecoverableError
}

///|
fn review_state_shows_technical_detail(state : SurfaceState) -> Bool {
  state == Stale ||
  state == Disconnected ||
  state == CapabilityLimited ||
  state == RecoverableError ||
  state == TerminalError
}

///|
fn render_review_state(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  match model.review_state {
    None => @html.nothing
    Some(state) =>
      section(class="quiet-empty-state review-empty surface-state-panel", [
        render_polite_state_announcement(
          "review-state-announcement",
          review_state_title(state),
          review_state_detail(state, model.review_items.length() > 0),
        ),
        if wiki_review_feedback_visible(model.review_decision_status) {
          p(
            class="status-line decision-confirmation",
            wiki_review_feedback(model.review_decision_status),
          )
        } else {
          @html.nothing
        },
        if review_state_has_retry(state) {
          button(
            class="secondary-button full",
            on_click=dispatch(SelectWorkspaceMode(ReviewWorkspace)),
            if state == FirstUseEmpty {
              "Check for review items"
            } else if state == Stale {
              "Refresh"
            } else {
              "Retry"
            },
          )
        } else {
          @html.nothing
        },
        if state == LegitimateZero {
          button(
            class="secondary-button full",
            on_click=dispatch(SelectWorkspaceMode(RequestsWorkspace)),
            "View Requests",
          )
        } else {
          @html.nothing
        },
        if review_state_shows_technical_detail(state) && model.host_status != "" {
          details(class="technical-details", [
            summary("Technical details"),
            code(model.host_status),
          ])
        } else {
          @html.nothing
        },
      ])
  }
}

///|
fn render_user_review_item(
  dispatch : Dispatch[Msg],
  item : ReviewItem,
) -> @rabbita.Html {
  div(class="review-item", [
    div(class="review-item-heading", [
      strong(item.title),
      span(class="user-state review", wiki_review_status_label(item.status)),
    ]),
    p(wiki_review_detail(item)),
    button(
      class="secondary-button full",
      on_click=dispatch(SelectSearchHit(item.workspace_id, item.path)),
      "Open proposal",
    ),
    div(class="review-actions", [
      button(
        class="primary-button",
        title="Accept this proposed change",
        on_click=dispatch(DecideReviewItem(item, "accepted")),
        "Accept",
      ),
      button(
        class="secondary-button danger-button",
        title="Reject this proposed change",
        on_click=dispatch(DecideReviewItem(item, "rejected")),
        "Reject",
      ),
    ]),
    details(class="technical-details", [
      summary("Technical details"),
      code("\{item.kind} | \{item.id} | \{item.path}"),
    ]),
  ])
}

///|
fn review_limit(items : Array[ReviewItem]) -> Int {
  if items.length() > 12 {
    12
  } else {
    items.length()
  }
}
