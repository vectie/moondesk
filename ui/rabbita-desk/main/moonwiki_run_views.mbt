///|
fn render_review_pane(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(class="activity-pane user-pane review-pane", [
    div(class="pane-heading", [
      div([p(class="eyebrow", "Decisions"), h2("Review")]),
      button(
        class="secondary-button compact-button",
        title="Refresh review",
        on_click=dispatch(SelectWorkspace(model.selected_workspace_id)),
        "Refresh",
      ),
    ]),
    if model.review_items.length() == 0 {
      div(class="quiet-empty-state review-empty", [
        strong("Nothing needs review"),
        p(
          "Proposed knowledge changes will appear here before they become part of the book.",
        ),
        if wiki_review_feedback_visible(model.review_decision_status) {
          p(
            class="status-line decision-confirmation",
            wiki_review_feedback(model.review_decision_status),
          )
        } else {
          @html.nothing
        },
        button(
          class="secondary-button full",
          on_click=dispatch(SelectActivity(Town)),
          "View activity",
        ),
      ])
    } else {
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
    },
  ])
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
