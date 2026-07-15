///|
struct MoonCodeEvidenceRow {
  item_id : String
  kind : String
  state : String
  title : String
  path : String
  detail : String
  diff : String
  command : String
  output : String
  exit_code : Int
  truncated : Bool
  approval_id : String
  target_command_id : String
  tool_call_id : String
  arguments : String
}

///|
struct MoonCodeActivityRow {
  item_id : String
  tone : String
  label : String
  title : String
  detail : String
  status : String
  folded : Bool
  command_id : String
  client_turn_id : String
  session_id : String
  retry_prompt : String
  evidence : Array[MoonCodeEvidenceRow]
}

///|
fn render_mooncode_activity_row(
  dispatch : Dispatch[Msg],
  model : Model,
  row : MoonCodeActivityRow,
) -> @rabbita.Html {
  let folded_class = if row.folded { " folded" } else { "" }
  let row_class = "mooncode-activity-row " +
    row.tone +
    " " +
    row.status +
    folded_class
  div(
    class=row_class,
    attrs=@html.Attrs::build()
      .data_set("testid", "mooncode-activity")
      .data_set("item-id", row.item_id)
      .data_set("label", row.label)
      .data_set("status", row.status)
      .data_set("folded", if row.folded { "true" } else { "false" })
      .data_set("command-id", row.command_id)
      .data_set("client-turn-id", row.client_turn_id),
    [
      div(class="mooncode-activity-dot", ""),
      div(class="mooncode-activity-copy", [
        div(class="mooncode-activity-line", [
          strong(row.label),
          div(class="mooncode-activity-controls", [
            span(row.status),
            if row.status == "running" {
              button(
                class="mooncode-inline-action stop",
                attrs=@html.Attrs::build()
                  .aria_label("Stop this MoonCode request")
                  .data_set("testid", "mooncode-stop"),
                on_click=dispatch(
                  CancelMoonCodeWork(row.session_id, row.command_id),
                ),
                "Stop",
              )
            } else if (row.status == "failed" || row.status == "cancelled") &&
              row.retry_prompt != "" {
              button(
                class="mooncode-inline-action retry",
                attrs=@html.Attrs::build()
                  .aria_label("Retry this MoonCode request")
                  .data_set("testid", "mooncode-retry"),
                on_click=dispatch(
                  RetryMoonCodeTurn(row.session_id, row.retry_prompt),
                ),
                "Retry",
              )
            } else {
              @html.nothing
            },
          ]),
        ]),
        render_mooncode_activity_body(dispatch, model, row),
      ]),
    ],
  )
}

///|
fn render_mooncode_activity_body(
  dispatch : Dispatch[Msg],
  model : Model,
  row : MoonCodeActivityRow,
) -> @rabbita.Html {
  if row.folded {
    render_mooncode_activity_disclosure(dispatch, model, row)
  } else {
    div(class="mooncode-activity-body", [
      p(class="mooncode-activity-title", row.title),
      if row.detail == "" {
        span(class="mooncode-activity-detail empty", "")
      } else {
        pre(class="mooncode-activity-detail", row.detail)
      },
      render_mooncode_evidence_list(
        dispatch,
        model,
        row.session_id,
        row.evidence,
      ),
    ])
  }
}

///|
fn render_mooncode_activity_disclosure(
  dispatch : Dispatch[Msg],
  model : Model,
  row : MoonCodeActivityRow,
) -> @rabbita.Html {
  let disclosure_suffix = if row.detail == "" && row.evidence.length() == 0 {
    " empty-detail"
  } else {
    ""
  }
  let disclosure_class = "mooncode-activity-disclosure" + disclosure_suffix
  @html.node("details", @html.Attrs::build().class(disclosure_class), [
    @html.node(
      "summary",
      @html.Attrs::build().class("mooncode-activity-summary"),
      [
        span(class="mooncode-activity-summary-text", row.title),
        span(
          class="mooncode-activity-summary-action when-closed",
          "Show details",
        ),
        span(class="mooncode-activity-summary-action when-open", "Hide details"),
      ],
    ),
    if row.detail == "" {
      span(class="mooncode-activity-detail empty", "")
    } else {
      pre(class="mooncode-activity-detail", row.detail)
    },
    render_mooncode_evidence_list(
      dispatch,
      model,
      row.session_id,
      row.evidence,
    ),
  ])
}

///|
fn render_mooncode_evidence_list(
  dispatch : Dispatch[Msg],
  model : Model,
  session_id : String,
  evidence : Array[MoonCodeEvidenceRow],
) -> @rabbita.Html {
  if evidence.length() == 0 {
    return @html.nothing
  }
  let children : Array[@rabbita.Html] = []
  for row in evidence {
    children.push(render_mooncode_evidence(dispatch, model, session_id, row))
  }
  div(class="mooncode-evidence-list", children)
}

///|
fn render_mooncode_evidence(
  dispatch : Dispatch[Msg],
  model : Model,
  session_id : String,
  row : MoonCodeEvidenceRow,
) -> @rabbita.Html {
  if row.kind == "approval" {
    return render_mooncode_approval(dispatch, session_id, row)
  }
  let has_detail = row.diff != "" ||
    row.command != "" ||
    row.output != "" ||
    (row.detail != "" && row.detail != row.title)
  let summary = @html.node(
    "summary",
    @html.Attrs::build().class("mooncode-evidence-summary"),
    [
      span(
        class="mooncode-evidence-kind " + row.kind,
        mooncode_evidence_label(row),
      ),
      span(
        class="mooncode-evidence-title",
        if row.path == "" {
          row.title
        } else {
          row.path
        },
      ),
      span(class="mooncode-evidence-state " + row.state, row.state),
    ],
  )
  let children : Array[@rabbita.Html] = [summary]
  if row.detail != "" && row.detail != row.title {
    children.push(p(class="mooncode-evidence-detail", row.detail))
  }
  if row.diff != "" {
    children.push(
      render_mooncode_diff(dispatch, model, row.item_id + ":diff", row.diff),
    )
  }
  if row.command != "" {
    children.push(
      render_mooncode_evidence_text(
        dispatch,
        model,
        row.item_id + ":command",
        "Command",
        row.command,
      ),
    )
  }
  if row.output != "" {
    children.push(
      render_mooncode_evidence_text(
        dispatch,
        model,
        row.item_id + ":output",
        if row.exit_code >= 0 {
          "Output · exit \{row.exit_code}"
        } else {
          "Output"
        },
        row.output + (if row.truncated { "\n[output truncated]" } else { "" }),
      ),
    )
  }
  @html.node(
    "details",
    @html.Attrs::build()
    .class(
      "mooncode-evidence " +
      row.kind +
      (if has_detail { "" } else { " summary-only" }),
    )
    .data_set("testid", "mooncode-evidence")
    .data_set("kind", row.kind)
    .data_set("state", row.state),
    children,
  )
}

///|
fn mooncode_evidence_label(row : MoonCodeEvidenceRow) -> String {
  match row.kind {
    "edit" => "Edit"
    "test" => "Test"
    "artifact" => "Output"
    "approval" => "Approval"
    _ => "Tool"
  }
}

///|
fn render_mooncode_approval(
  dispatch : Dispatch[Msg],
  session_id : String,
  row : MoonCodeEvidenceRow,
) -> @rabbita.Html {
  let pending = row.state == "pending"
  div(
    class="mooncode-approval " + row.state,
    attrs=@html.Attrs::build()
      .data_set("testid", "mooncode-approval")
      .data_set("approval-id", row.approval_id)
      .data_set("state", row.state),
    [
      div(class="mooncode-approval-copy", [
        strong(if pending { "Approval needed" } else { row.title }),
        p(row.detail),
        if row.arguments == "" {
          @html.nothing
        } else {
          @html.node("details", @html.Attrs::build().class("mooncode-approval-detail"), [
            @html.node("summary", @html.Attrs::build(), [span("Review operation")]),
            pre(row.arguments),
          ])
        },
      ]),
      if pending {
        div(class="mooncode-approval-actions", [
          button(
            class="mooncode-inline-action reject",
            attrs=@html.Attrs::build()
              .aria_label("Reject this MoonCode tool call")
              .data_set("testid", "mooncode-reject-tool"),
            on_click=dispatch(
              DecideMoonCodeTool(
                session_id,
                "reject_tool",
                row.approval_id,
                row.target_command_id,
                row.tool_call_id,
              ),
            ),
            "Reject",
          ),
          button(
            class="mooncode-inline-action approve",
            attrs=@html.Attrs::build()
              .aria_label("Approve this MoonCode tool call")
              .data_set("testid", "mooncode-approve-tool"),
            on_click=dispatch(
              DecideMoonCodeTool(
                session_id,
                "approve_tool",
                row.approval_id,
                row.target_command_id,
                row.tool_call_id,
              ),
            ),
            "Approve",
          ),
        ])
      } else {
        span(class="mooncode-approval-state " + row.state, row.state)
      },
    ],
  )
}

///|
fn render_mooncode_evidence_text(
  dispatch : Dispatch[Msg],
  model : Model,
  item_id : String,
  label : String,
  content : String,
) -> @rabbita.Html {
  div(class="mooncode-evidence-text", [
    div(class="mooncode-evidence-toolbar", [
      span(label),
      button(
        class="mooncode-copy-button",
        attrs=@html.Attrs::build().aria_label(
          if model.mooncode_copied_item_id == item_id {
            "Copied \{label.to_lower()}"
          } else {
            "Copy \{label.to_lower()}"
          },
        ),
        on_click=dispatch(CopyMoonCodeText(item_id, content)),
        if model.mooncode_copied_item_id == item_id {
          "Copied"
        } else {
          "Copy"
        },
      ),
    ]),
    pre(content),
  ])
}

///|
fn render_mooncode_diff(
  dispatch : Dispatch[Msg],
  model : Model,
  item_id : String,
  diff : String,
) -> @rabbita.Html {
  let lines : Array[@rabbita.Html] = []
  for raw in diff.split("\n") {
    let line = raw.to_owned()
    let kind = if line.has_prefix("+++") ||
      line.has_prefix("---") ||
      line.has_prefix("@@") {
      "meta"
    } else if line.has_prefix("+") {
      "add"
    } else if line.has_prefix("-") {
      "delete"
    } else {
      "context"
    }
    lines.push(div(class="mooncode-diff-line " + kind, line))
  }
  div(class="mooncode-diff-shell", [
    div(class="mooncode-evidence-toolbar", [
      span("Changes"),
      button(
        class="mooncode-copy-button",
        attrs=@html.Attrs::build().aria_label(
          if model.mooncode_copied_item_id == item_id {
            "Copied changes"
          } else {
            "Copy changes"
          },
        ),
        on_click=dispatch(CopyMoonCodeText(item_id, diff)),
        if model.mooncode_copied_item_id == item_id {
          "Copied"
        } else {
          "Copy"
        },
      ),
    ]),
    div(
      class="mooncode-diff",
      attrs=@html.Attrs::build()
        .data_set("testid", "mooncode-diff")
        .aria_label("File changes"),
      lines,
    ),
  ])
}
