///|
fn render_runs_state_action(
  dispatch : Dispatch[Msg],
  state : SurfaceState,
) -> @rabbita.Html {
  match runs_state_action(state) {
    Some(label) =>
      button(
        class="primary-button",
        attrs=@html.Attrs::build().data_set("testid", "runs-state-action"),
        on_click=if state == LegitimateZero {
          dispatch(SelectWorkspaceMode(RequestsWorkspace))
        } else {
          dispatch(SelectWorkspaceMode(RunsWorkspace))
        },
        label,
      )
    None => @html.nothing
  }
}

///|
fn render_runs_state(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  match model.runs_state {
    None => @html.nothing
    Some(state) =>
      div(class="quiet-empty-state", [
        render_polite_state_announcement(
          "runs-state-announcement",
          runs_state_title(state),
          runs_state_detail(state, model.runs.length() > 0),
        ),
        render_runs_state_action(dispatch, state),
        if runs_state_shows_details(state) && model.runs_error != "" {
          details(class="technical-details", [
            summary("Technical details"),
            code(model.runs_error),
          ])
        } else {
          @html.nothing
        },
      ])
  }
}

///|
fn render_runs_workspace(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  main_(
    class="desk-main primary-destination-main",
    attrs=main_content_attrs(RunsWorkspace).data_set("testid", "runs-workspace"),
    [
      section(class="primary-destination-card", [
        div(class="pane-heading", [
          div([p(class="eyebrow", "Execution history"), h1("Runs")]),
          button(
            class="secondary-button compact-button",
            attrs=@html.Attrs::build().data_set("testid", "runs-refresh"),
            title="Refresh runs",
            on_click=dispatch(SelectWorkspaceMode(RunsWorkspace)),
            "Refresh",
          ),
        ]),
        if model.selected_workspace_id == "" {
          div(class="quiet-empty-state runs-prerequisite", [
            strong("Choose a book to see its runs"),
            p("Runs are scoped to one book so their results stay attributable."),
            button(
              class="primary-button",
              on_click=dispatch(SelectWorkspaceMode(Desk)),
              "Choose a book",
            ),
          ])
        } else {
          section(
            class="surface-state-panel",
            attrs=@html.Attrs::build()
              .data_set("testid", "runs-state-panel")
              .data_set("state", runs_state_key(model.runs_state)),
            [
              render_runs_state(dispatch, model),
              if runs_state_keeps_records(model.runs_state) &&
                model.runs.length() > 0 {
                div(
                  class="primary-run-list",
                  model.runs.map(run => render_user_run(dispatch, run)),
                )
              } else {
                @html.nothing
              },
            ],
          )
        },
      ]),
    ],
  )
}

///|
fn publish_pending_review_count(items : Array[ReviewItem]) -> Int {
  items
  .filter(item => {
    let status = item.status.trim().to_lower()
    status != "accepted" && status != "rejected"
  })
  .length()
}

///|
fn render_publish_state_notice(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  match model.publish_state {
    None => @html.nothing
    Some(state) =>
      div(class="quiet-empty-state publish-state-notice", [
        render_polite_state_announcement(
          "publish-state-announcement",
          publish_state_title(state),
          publish_state_detail(state, model.review_items.length() > 0),
        ),
        match publish_state_action(state) {
          Some(label) =>
            button(
              class="primary-button",
              attrs=@html.Attrs::build().data_set(
                "testid", "publish-state-action",
              ),
              on_click=dispatch(SelectWorkspaceMode(PublishWorkspace)),
              label,
            )
          None => @html.nothing
        },
        match publish_state_technical_detail(state) {
          Some(detail) =>
            details(class="technical-details", [
              summary("Technical details"),
              p(detail),
              if publish_state_shows_raw_error(state) &&
                model.publish_error != "" {
                code(model.publish_error)
              } else {
                @html.nothing
              },
            ])
          None => @html.nothing
        },
      ])
  }
}

///|
fn render_publish_evidence(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let pending_review_count = publish_pending_review_count(model.review_items)
  let current = publish_evidence_is_current(model.publish_state)
  if pending_review_count > 0 {
    div(
      class="quiet-empty-state publish-review-required",
      attrs=@html.Attrs::build().data_set("testid", "publish-review-required"),
      [
        strong(
          if current {
            "Review required"
          } else {
            "Review was required in the last successful check"
          },
        ),
        p(
          if current {
            "\{pending_review_count} proposed change(s) need a decision before publishing."
          } else {
            "\{pending_review_count} retained proposed change(s) still need confirmation."
          },
        ),
        button(
          class="primary-button",
          on_click=dispatch(SelectWorkspaceMode(ReviewWorkspace)),
          "Open Review",
        ),
      ],
    )
  } else {
    div(
      class="quiet-empty-state publish-output-check",
      attrs=@html.Attrs::build().data_set("testid", "publish-output-check"),
      [
        strong(
          if current {
            "No review items are blocking this book"
          } else {
            "No blockers in the last successful check"
          },
        ),
        p(
          "Open the generated output location to check whether a publish result is present and current.",
        ),
        button(
          class="primary-button",
          on_click=dispatch(OpenQuickPath("book/site/generated")),
          "Open output location",
        ),
      ],
    )
  }
}

///|
fn render_publish_workspace(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  main_(
    class="desk-main primary-destination-main",
    attrs=main_content_attrs(PublishWorkspace).data_set(
      "testid", "publish-workspace",
    ),
    [
      section(class="primary-destination-card", [
        div(class="pane-heading", [
          div([p(class="eyebrow", "Book output"), h1("Publish")]),
          button(
            class="secondary-button compact-button",
            attrs=@html.Attrs::build().data_set("testid", "publish-refresh"),
            title="Refresh publishing readiness",
            disabled=model.selected_workspace_id == "",
            on_click=dispatch(SelectWorkspaceMode(PublishWorkspace)),
            "Refresh",
          ),
        ]),
        if model.selected_workspace_id == "" {
          div(class="quiet-empty-state", [
            strong("Choose a book to check publishing"),
            p(
              "Publishing readiness and output locations are scoped to the selected book.",
            ),
            button(
              class="primary-button",
              on_click=dispatch(SelectWorkspaceMode(Desk)),
              "Choose a book",
            ),
          ])
        } else {
          section(
            class="surface-state-panel",
            attrs=@html.Attrs::build()
              .data_set("testid", "publish-state-panel")
              .data_set("state", publish_state_key(model.publish_state)),
            [
              render_publish_state_notice(dispatch, model),
              if publish_state_keeps_evidence(model.publish_state) {
                render_publish_evidence(dispatch, model)
              } else {
                @html.nothing
              },
            ],
          )
        },
        details(class="technical-details publish-technical", [
          summary("Technical and portable exports"),
          p("Generated output path: book/site/generated"),
          button(
            class="secondary-button",
            on_click=dispatch(ExportAppToolPortable),
            "Export this book’s portable app",
          ),
          button(
            class="secondary-button",
            on_click=dispatch(ExportAllAppToolPortable),
            "Export all portable apps",
          ),
          if model.book_pattern_status == "" {
            @html.nothing
          } else {
            p(class="status-line", model.book_pattern_status)
          },
        ]),
      ]),
    ],
  )
}
