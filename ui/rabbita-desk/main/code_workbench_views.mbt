///|
fn code_workbench_button(value : String, label : String) -> @rabbita.Html {
  let icon = match value {
    "source" => "files"
    "review" => "changes"
    _ => value
  }
  button(
    class="code-workbench-tab moon-icon-button",
    attrs=@html.Attrs::build()
      .id("code-workbench-tab-" + value)
      .role("tab")
      .data_set("workbench-view", value)
      .data_set("i18n-title", "code.pane_" + value)
      .data_set("i18n-aria-label", "code.pane_" + value)
      .aria_label(label)
      .title(label)
      .aria_controls("code-workbench-panel")
      .aria_selected(if value == "source" { "true" } else { "false" })
      .tabindex(if value == "source" { 0 } else { -1 }),
    [
      ui_icon(icon),
      span(
        class="code-workbench-tab-label",
        attrs=@html.Attrs::build().data_set("i18n", "code.pane_" + value),
        label,
      ),
    ],
  )
}

///|
fn render_code_workbench_toolbar() -> @rabbita.Html {
  div(
    class="code-workbench-toolbar",
    attrs=@html.Attrs::build().aria_label("Coding workspace"),
    [
      div(
        class="code-workbench-tabs",
        attrs=@html.Attrs::build()
          .role("tablist")
          .aria_label("Workspace panels")
          .aria_orientation("horizontal"),
        [
          code_workbench_button("source", "Files"),
          code_workbench_button("review", "Changes"),
          code_workbench_button("browser", "Preview"),
          code_workbench_button("terminal", "Terminal"),
          code_workbench_button("compare", "Compare"),
        ],
      ),
      div(class="code-workbench-actions", [
        button(
          class="moon-icon-button",
          attrs=@html.Attrs::build()
            .data_set("workbench-action", "selection")
            .data_set("i18n-title", "code.add_selection")
            .data_set("i18n-aria-label", "code.add_selection")
            .aria_label("Add selection")
            .title("Add selected source, text or output to your message"),
          [ui_icon("selection")],
        ),
        button(
          class="moon-icon-button",
          attrs=@html.Attrs::build()
            .data_set("workbench-action", "focus")
            .data_set("i18n-title", "code.close_panel")
            .data_set("i18n-aria-label", "code.close_panel")
            .aria_label("Close workspace panel")
            .title("Close workspace panel")
            .aria_pressed("false"),
          [ui_icon("panel-right")],
        ),
        button(
          class="moon-icon-button",
          attrs=@html.Attrs::build()
            .data_set("workbench-action", "restore")
            .data_set("i18n-title", "code.open_panel")
            .data_set("i18n-aria-label", "code.open_panel")
            .aria_label("Open workspace panel")
            .title("Open workspace panel"),
          [ui_icon("panel-right")],
        ),
      ]),
    ],
  )
}
