///|
fn render_files_pane(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(class="explorer-pane", [
    div(class="pane-heading", [
      div([
        p(class="eyebrow", "wiki mode"),
        h2("Books"),
        p(class="pane-help", "Open a book, read AI-written pages, and save useful notes."),
      ]),
      button(
        class="icon-button",
        title="Refresh",
        on_click=dispatch(RefreshAll),
        "R",
      ),
    ]),
    render_workspace_card(dispatch, model),
    div(class="explorer-section-tabs", [
      button(
        class=if model.current_directory == "" {
          "section-pill active"
        } else {
          "section-pill"
        },
        on_click=dispatch(OpenDirectory("")),
        "Home",
      ),
      button(
        class=if model.current_directory == "wiki" {
          "section-pill active"
        } else {
          "section-pill"
        },
        on_click=dispatch(OpenDirectory("wiki")),
        "Documents",
      ),
      button(
        class=if model.current_directory == "inbox" {
          "section-pill active"
        } else {
          "section-pill"
        },
        on_click=dispatch(OpenDirectory("inbox")),
        "Notes",
      ),
      button(
        class=if model.current_directory == "book/site/generated" {
          "section-pill active"
        } else {
          "section-pill"
        },
        on_click=dispatch(OpenDirectory("book/site/generated")),
        "Generated",
      ),
    ]),
    render_tree(dispatch, model),
  ])
}

///|
fn render_workspace_card(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  div(class="workspace-stack", [
    div(class="workspace-card", [
      span(class="status-dot live", ""),
      div([h3(workspace_name(model)), p(workspace_root(model))]),
    ]),
    div(
      class="workspace-list",
      model.workspaces.map(workspace => {
        let class_name = if workspace.id == model.selected_workspace_id {
          "workspace-row active"
        } else {
          "workspace-row"
        }
        button(
          class=class_name,
          title=workspace.root_path,
          on_click=dispatch(SelectWorkspace(workspace.id)),
          [span(workspace.name), small(workspace_kind_label(workspace.kind))],
        )
      }),
    ),
  ])
}

///|
fn render_tree(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  if model.entries.length() == 0 {
    div(class="empty-state", [strong("No entries loaded"), p(model.host_status)])
  } else {
    ul(
      class="tree-list",
      model.entries.map(entry => {
        let selected = entry.path == model.selected_path
        let class_name = if selected { "tree-row selected" } else { "tree-row" }
        li(class=class_name, on_click=dispatch(SelectPath(entry.path)), [
          span(class="tree-indent depth-0", ""),
          span(class="tree-icon", icon_for_kind(entry.kind)),
          span(class="tree-label", entry.display_name),
          span(class="tree-layer", layer_label(entry.source_layer)),
        ])
      }),
    )
  }
}
