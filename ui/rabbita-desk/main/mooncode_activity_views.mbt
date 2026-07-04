///|
struct MoonCodeActivityRow {
  tone : String
  label : String
  title : String
  detail : String
  status : String
  folded : Bool
  command_id : String
  client_turn_id : String
}

///|
fn render_mooncode_activity_row(row : MoonCodeActivityRow) -> @rabbita.Html {
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
          span(row.status),
        ]),
        render_mooncode_activity_body(row),
      ]),
    ],
  )
}

///|
fn render_mooncode_activity_body(row : MoonCodeActivityRow) -> @rabbita.Html {
  if row.folded {
    render_mooncode_activity_disclosure(row)
  } else {
    div(class="mooncode-activity-body", [
      p(class="mooncode-activity-title", row.title),
      if row.detail == "" {
        span(class="mooncode-activity-detail empty", "")
      } else {
        pre(class="mooncode-activity-detail", row.detail)
      },
    ])
  }
}

///|
fn render_mooncode_activity_disclosure(
  row : MoonCodeActivityRow,
) -> @rabbita.Html {
  let disclosure_suffix = if row.detail == "" { " empty-detail" } else { "" }
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
  ])
}
