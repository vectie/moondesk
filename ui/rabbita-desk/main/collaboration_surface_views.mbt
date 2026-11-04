///|
fn collaboration_principal_label(
  reference : CollaborationPrincipalRef,
) -> String {
  reference.principal_id + " · " + collaboration_system_label(reference.kind)
}

///|
fn collaboration_system_label(value : String) -> String {
  match value {
    "human" => interface_label("collaboration.human", "Person")
    "agent" => interface_label("collaboration.agent", "Agent")
    "active" => interface_label("collaboration.active", "Active")
    "owner" => interface_label("collaboration.owner", "Owner")
    "reviewer" => interface_label("collaboration.reviewer", "Reviewer")
    "member" => interface_label("collaboration.member", "Member")
    "viewer" => interface_label("collaboration.viewer", "Viewer")
    "contributor" => interface_label("collaboration.contributor", "Contributor")
    _ => value
  }
}

///|
fn collaboration_operation_label(
  reference : CollaborationOperationRef,
) -> String {
  reference.product_id + "/" + reference.tool_id + "@" + reference.pack_version
}

///|
fn render_collaboration_empty() -> @rabbita.Html {
  div(
    class="collaboration-empty",
    attrs=@html.Attrs::build().role("status").aria_live("polite"),
    [ui_icon("chat"), strong("No shared records yet")],
  )
}

///|
fn render_collaboration_recovery(
  _dispatch : Dispatch[Msg],
  status : String,
  message : String,
  next_action : String,
) -> @rabbita.Html {
  div(
    class="collaboration-empty collaboration-recovery-state " + status,
    attrs=@html.Attrs::build()
      .data_set("collaboration-status", status)
      .data_set("next-action", next_action)
      .role("status")
      .aria_live("polite"),
    [
      ui_icon(if status == "loading" { "running" } else { "info" }),
      div([
        strong(
          match status {
            "loading" => "Validating collaboration"
            "not_initialized" => "Collaboration is not initialized"
            "quarantined" => "Collaboration needs recovery"
            "owner_unavailable" => "MoonFlow is unavailable"
            "owner_timeout" => "MoonFlow validation timed out"
            _ => "Select a MoonBook"
          },
        ),
        if status == "not_initialized" || status == "loading" || message == "" {
          @html.nothing
        } else {
          p(message)
        },
      ]),
    ],
  )
}

///|
fn render_collaboration_people(
  people : Array[CollaborationPersonProjection],
) -> @rabbita.Html {
  if people.is_empty() {
    @html.nothing
  } else {
    article(class="collaboration-lane", [
      header([h3("People")]),
      ul(
        people.map(person => {
          li(class="collaboration-person-row", [
            strong(
              attrs=@html.Attrs::build()
                .data_set("i18n-scope", "content")
                .title(collaboration_principal_label(person.principal_ref)),
              person.principal_ref.principal_id,
            ),
            small(person.roles.map(collaboration_system_label).join(", ")),
            if person.status == "active" {
              @html.nothing
            } else {
              span(
                class="collaboration-person-status",
                collaboration_system_label(person.status),
              )
            },
          ])
        }),
      ),
    ])
  }
}

///|
fn render_collaboration_assignments(
  assignments : Array[CollaborationAssignmentProjection],
) -> @rabbita.Html {
  if assignments.is_empty() {
    @html.nothing
  } else {
    article(class="collaboration-lane", [
      header([
        span(attrs=@html.Attrs::build().aria_hidden("true"), "↗"),
        h3("Assignments"),
      ]),
      ul(
        assignments.map(assignment => {
          li([
            strong(collaboration_operation_label(assignment.operation_ref)),
            span(
              collaboration_principal_label(assignment.assignee_principal) +
              " · " +
              assignment.state,
            ),
            small(assignment.assignment_id + " · " + assignment.head_digest),
          ])
        }),
      ),
    ])
  }
}

///|
fn render_collaboration_reviews(
  reviews : Array[CollaborationReviewProjection],
) -> @rabbita.Html {
  if reviews.is_empty() {
    @html.nothing
  } else {
    article(class="collaboration-lane", [
      header([
        span(attrs=@html.Attrs::build().aria_hidden("true"), "✓"),
        h3("Review inbox"),
      ]),
      ul(
        reviews.map(review => {
          li([
            strong(review.review_id),
            span(
              collaboration_principal_label(review.assigned_reviewer) +
              " · " +
              review.state,
            ),
            small(
              if review.separation_of_duty_ok {
                "Separation of duty confirmed"
              } else {
                "Separation of duty unresolved"
              },
            ),
          ])
        }),
      ),
    ])
  }
}

///|
fn render_collaboration_comments(
  comments : Array[CollaborationCommentProjection],
) -> @rabbita.Html {
  if comments.is_empty() {
    @html.nothing
  } else {
    article(class="collaboration-lane", [
      header([
        span(attrs=@html.Attrs::build().aria_hidden("true"), "◇"),
        h3("Anchored comments"),
      ]),
      ul(
        comments.map(comment => {
          li([
            strong(comment.anchor_ref),
            span(collaboration_principal_label(comment.author_principal)),
            small(comment.created_at + " · " + comment.body_digest),
          ])
        }),
      ),
    ])
  }
}

///|
fn render_collaboration_handovers(
  handovers : Array[CollaborationHandoverProjection],
) -> @rabbita.Html {
  if handovers.is_empty() {
    @html.nothing
  } else {
    article(class="collaboration-lane collaboration-handover-lane", [
      header([
        span(attrs=@html.Attrs::build().aria_hidden("true"), "⇄"),
        h3("Agent handovers"),
      ]),
      ul(
        handovers.map(handover => {
          let head_label = if handover.head_digest == "" {
            "unavailable"
          } else {
            handover.head_digest
          }
          li([
            div(class="collaboration-handover-heading", [
              strong(handover.handover_id),
              span(handover.state),
            ]),
            p(
              if handover.valid {
                "Validated by MoonFlow owner replay"
              } else {
                "Quarantined by MoonFlow; inspect before continuing"
              },
            ),
            small("Head " + head_label),
            code(handover.envelope_digest.unwrap_or("digest unavailable")),
          ])
        }),
      ),
    ])
  }
}

///|
fn render_collaboration_surface(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let surface = model.collaboration_surface
  section(
    class="collaboration-surface",
    attrs=@html.Attrs::build()
      .data_set("testid", "collaboration-surface")
      .data_set("principal-contract", "moonsuite.principal-ref.v1")
      .data_set("workspace-contract", "moonsuite.workspace-ref.v1")
      .data_set("handover-contract", "moonsuite.handover-control.v1")
      .aria_label("Collaboration"),
    [
      header(class="collaboration-toolbar", [
        span(
          title="Read only in MoonDesk. Delegation, authority decisions, mutations, conflict resolution, and continuation remain with MoonFlow and the owning product.",
          "Read-only",
        ),
        button(
          class="moon-icon-button",
          attrs=@html.Attrs::build()
            .data_set("testid", "collaboration-refresh")
            .aria_label("Refresh collaboration")
            .title("Refresh collaboration"),
          on_click=dispatch(RefreshAll),
          [ui_icon("refresh")],
        ),
      ]),
      if model.collaboration_status != "ready" {
        render_collaboration_recovery(
          dispatch,
          model.collaboration_status,
          model.collaboration_message,
          model.collaboration_next_action,
        )
      } else if surface.is_empty() {
        render_collaboration_empty()
      } else {
        div(class="collaboration-grid", [
          render_collaboration_people(surface.people),
          render_collaboration_assignments(surface.assignments),
          render_collaboration_reviews(surface.reviews),
          render_collaboration_comments(surface.comments),
          render_collaboration_handovers(surface.handovers),
        ])
      },
    ],
  )
}
