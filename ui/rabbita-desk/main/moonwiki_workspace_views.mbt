///|
fn render_files_pane(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(class="activity-pane", [
    div(class="pane-heading", [
      div([p(class="eyebrow", "MoonWiki"), h2("MoonBooks")]),
      button(
        class="secondary-button compact-button",
        title="Refresh",
        on_click=dispatch(RefreshAll),
        "Refresh",
      ),
    ]),
    render_workspace_card(dispatch, model),
    div(class="activity-section-tabs", [
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
        "Wiki",
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
        "Site",
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
      div([
        h3(workspace_name(model)),
        p(class="workspace-root-muted", workspace_visible_location_label(model)),
      ]),
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
          title=workspace.name +
            " / " +
            workspace_display_book_location(model, workspace),
          on_click=dispatch(SelectWorkspace(workspace.id)),
          [
            span(workspace.name),
            small(workspace_display_book_location(model, workspace)),
          ],
        )
      }),
    ),
  ])
}

///|
fn render_wiki_bootstrap(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  main_(class="bootstrap-center", [
    section(class="bootstrap-panel", [
      p(class="eyebrow", "Moondesk"),
      h1("Start with a MoonBook"),
      p(class="lead", "Choose a book to read, create, or make executable."),
      render_wiki_bootstrap_suite_summary(model),
      div(class="bootstrap-choice-list", [
        button(
          class="bootstrap-choice primary",
          on_click=dispatch(RefreshAll),
          [strong("Open MoonBook"), span("Continue from an existing workspace")],
        ),
        button(
          class="bootstrap-choice",
          on_click=dispatch(SelectActivity(Town)),
          [
            strong("Create MoonBook"),
            span("Start from a reusable book pattern"),
          ],
        ),
        button(
          class="bootstrap-choice",
          on_click=dispatch(SelectWorkspaceMode(MoonCode)),
          [
            strong("Use MoonCode"),
            span("Build tools and miniapps inside a book"),
          ],
        ),
      ]),
      p(class="status-line", model.host_status),
    ]),
  ])
}

///|
fn render_wiki_bootstrap_suite_summary(model : Model) -> @rabbita.Html {
  section(
    class="desk-library-location bootstrap-suite-location",
    attrs=@html.Attrs::build().data_set("testid", "bootstrap-suite-root"),
    [
      div([
        p(class="eyebrow", "active moonsuite"),
        strong(workspace_suite_display_name(model)),
      ]),
      small(workspace_library_count_label(model)),
      code(workspace_books_display_label(model)),
      render_desk_product_summary(model),
    ],
  )
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
