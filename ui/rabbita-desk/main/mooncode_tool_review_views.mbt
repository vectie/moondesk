///|
fn render_mooncode_tool_authorization_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="mooncode-review-board tool-authorization-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "runtime authorization gate"),
        h3("Tool Authorization"),
      ]),
      span(class="record-kind", model.mooncode_tool_authorization_status),
    ]),
    div(class="toolbar-actions", [
      button(
        class="secondary-button",
        on_click=dispatch(ProbeMoonCodeToolAuthorization("read")),
        "Probe Read",
      ),
      button(
        class="secondary-button",
        on_click=dispatch(ProbeMoonCodeToolAuthorization("write")),
        "Probe Write",
      ),
      button(
        class="secondary-button",
        on_click=dispatch(ProbeMoonCodeToolAuthorization("shell")),
        "Probe Shell",
      ),
    ]),
    match model.mooncode_tool_authorization {
      Some(authorization) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Decision", authorization.decision),
            info_chip("Approval", authorization.approval),
            info_chip("State", authorization.approval_state),
            info_chip("Tool", authorization.tool_id),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Session", authorization.session_id),
            info_row("Target", empty_label(authorization.target)),
            info_row("Path", empty_label(authorization.path)),
            info_row("Command", empty_label(authorization.command)),
            info_row("Tool Call", empty_label(authorization.tool_call_id)),
            info_row(
              "Flags",
              "allowed=\{authorization.allowed}, requires_approval=\{authorization.requires_approval}, blocked=\{authorization.blocked}",
            ),
          ]),
          p(class="mooncode-event-detail", authorization.reason),
          render_mooncode_tool_authorization_approval_entry(authorization),
        ])
      None =>
        p(
          class="status-line",
          "Probe read, write, or shell to ask the MoonCode authorization endpoint for the current decision.",
        )
    },
  ])
}

///|
fn render_mooncode_tool_authorization_approval_entry(
  authorization : MoonCodeToolAuthorization
) -> @rabbita.Html {
  let entry = authorization.approval_entry
  let entry_state = json_field_string(entry, "approval_state", default="")
  if entry_state == "" {
    span(class="hidden-inline", "")
  } else {
    div(class="mooncode-protocol-block", [
      div(class="mooncode-tool-head", [
        strong("Matching Approval"),
        span(class="record-kind", entry_state),
      ]),
      div(class="daemon-state compact-state", [
        info_row("Approval", json_field_string(entry, "approval", default="")),
        info_row("Tool", json_field_string(entry, "tool_id", default="")),
        info_row("Target", json_field_string(entry, "target", default="")),
        info_row("Path", json_field_string(entry, "path", default="")),
        info_row("Command", json_field_string(entry, "command", default="")),
      ]),
    ])
  }
}

///|
fn render_mooncode_tool_approvals_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="mooncode-review-board tool-approval-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "tool approval object"),
        h3("Tool Approvals"),
      ]),
      span(class="record-kind", model.mooncode_tool_approvals_status),
    ]),
    match model.mooncode_tool_approvals {
      Some(approvals) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Tools", approvals.approval_count.to_string()),
            info_chip("Pending", approvals.pending_approval_count.to_string()),
            info_chip("Approved", approvals.approved_approval_count.to_string()),
            info_chip("Rejected", approvals.rejected_approval_count.to_string()),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Manifest", approvals.manifest_path),
            info_row("Recorded", approvals.recorded_at),
            info_row("Status", approvals.status),
          ]),
          if approvals.approvals.length() == 0 {
            p(class="status-line", "no policy or review-gated tool calls")
          } else {
            div(
              class="mooncode-review-list tool-approval-list",
              approvals.approvals[:mooncode_tool_approval_limit(approvals.approvals)].map(
                approval =>
                  render_mooncode_tool_approval_entry(dispatch, approval),
              ),
            )
          },
        ])
      None =>
        p(
          class="status-line",
          "No durable MoonBook tool approval manifest has been recorded for this session yet.",
        )
    },
  ])
}

///|
fn mooncode_tool_approval_limit(
  entries : Array[MoonCodeToolApprovalEntry]
) -> Int {
  if entries.length() > 6 {
    6
  } else {
    entries.length()
  }
}

///|
fn render_mooncode_tool_approval_entry(
  dispatch : Dispatch[Msg],
  approval : MoonCodeToolApprovalEntry,
) -> @rabbita.Html {
  let target = if approval.target == "" {
    approval.event_id
  } else {
    approval.target
  }
  div(class="mooncode-review-item " + approval.approval_state, [
    div(class="mooncode-review-head", [
      div([
        strong(approval.title),
        small(
          approval.tool_id +
          " / " +
          approval.approval +
          " / " +
          approval.approval_state,
        ),
      ]),
      div(class="toolbar-actions", [
        if approval.path == "" {
          span(class="hidden-inline", "")
        } else {
          button(
            class="secondary-button",
            on_click=dispatch(OpenQuickPath(approval.path)),
            "Open",
          )
        },
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("approve_tool", target)),
          "Approve",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("reject_tool", target)),
          "Reject",
        ),
      ]),
    ]),
    div(class="mooncode-stats", [
      info_chip("Approves", approval.approved_review_count.to_string()),
      info_chip("Rejects", approval.rejected_review_count.to_string()),
    ]),
    div(class="mooncode-stats", [
      info_chip("Target", approval.target_kind),
      info_chip("Call", approval.target),
    ]),
    code(
      if approval.target_label != "" {
        approval.target_label
      } else if approval.path != "" {
        approval.path
      } else if approval.command != "" {
        approval.command
      } else {
        approval.event_id
      },
    ),
    p(class="mooncode-event-detail", approval.detail),
  ])
}
