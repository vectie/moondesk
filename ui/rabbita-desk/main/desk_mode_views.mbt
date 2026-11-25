///|
fn render_desk_mode(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  main_(
    class="desk-main file-desk-main",
    attrs=main_content_attrs(Desk).data_set("testid", "desk-mode"),
    [
      h1(class="visually-hidden", "Home"),
      render_desk_workspace_sidebar(dispatch, model),
      render_desk_file_browser(dispatch, model),
    ],
  )
}

///|
fn render_desk_workspace_sidebar(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let cold_start = classify_cold_start(model)
  aside(
    class="desk-sidebar",
    attrs=@html.Attrs::build()
      .aria_label("MoonBook library")
      .data_set("testid", "desk-book-controls"),
    [
      div(class="pane-heading", [
        div([h2("MoonBooks")]),
        button(
          class="secondary-button compact-button moon-icon-button",
          title="Refresh",
          attrs=@html.Attrs::build()
            .aria_label("Refresh MoonBooks")
            .data_set("testid", "desk-refresh-workspaces"),
          on_click=dispatch(RefreshAll),
          [ui_icon("refresh")],
        ),
      ]),
      if requested_workspace_unavailable(model) {
        render_requested_selection(dispatch, model)
      } else {
        @html.nothing
      },
      if !model.workspaces.is_empty() {
        div(class="moonbook-search", [
          ui_icon("search"),
          input(
            value=model.moonbook_query,
            placeholder="Find a MoonBook…",
            attrs=@html.Attrs::build().aria_label("Find a MoonBook"),
            on_input=fn(value) { dispatch(SetMoonBookQuery(value)) },
          ),
          if model.moonbook_query != "" {
            button(
              class="moon-icon-button",
              attrs=@html.Attrs::build().aria_label("Clear MoonBook search"),
              on_click=dispatch(SetMoonBookQuery("")),
              [ui_icon("close")],
            )
          } else {
            @html.nothing
          },
        ])
      } else {
        @html.nothing
      },
      div(
        class="desk-workspace-list",
        attrs=@html.Attrs::build().data_set("testid", "desk-workspace-list"),
        render_desk_workspace_rows(dispatch, model, cold_start),
      ),
      match cold_start {
        EmptyLibrary => render_new_moonbook_panel_open(dispatch, model)
        OneBook | ManyBooks => render_new_moonbook_panel(dispatch, model)
        Connecting | LibraryUnavailable | CatalogUnavailable => @html.nothing
      },
      details(class="workspace-disclosure desk-services", [
        summary([ui_icon("settings"), span("Storage & services")]),
        render_desk_library_location(dispatch, model),
        render_moongate_setup(dispatch, model),
      ]),
      if model.selected_workspace_id != "" {
        details(class="workspace-disclosure desk-sidebar-disclosure", [
          summary([ui_icon("star"), span("Quick Access")]),
          render_desk_quick_access(dispatch, model),
        ])
      } else {
        div(class="desk-quick-access-empty", [@html.nothing])
      },
      if model.selected_workspace_id == "" {
        @html.nothing
      } else {
        @html.fragment([
          details(class="workspace-disclosure desk-sidebar-disclosure", [
            summary([ui_icon("folder"), span("Directory")]),
            render_desk_folder_outline(dispatch, model),
          ]),
          details(class="workspace-disclosure", [
            summary([ui_icon("history"), span("Resume work")]),
            render_work_resume(dispatch, model),
          ]),
        ])
      },
    ],
  )
}

///|
fn render_desk_workspace_rows(
  dispatch : Dispatch[Msg],
  model : Model,
  cold_start : ColdStartState,
) -> Array[@rabbita.Html] {
  if model.workspaces.is_empty() {
    let content : Array[@rabbita.Html] = [
      render_polite_state_announcement(
        "workspace-catalog-state-announcement",
        desk_empty_library_title(model),
        desk_empty_library_message(model),
      ),
      strong(desk_empty_library_title(model)),
      p(desk_empty_library_message(model)),
      render_desk_cold_start_action(dispatch, cold_start),
    ]
    if cold_start is CatalogUnavailable && model.workspace_catalog_error != "" {
      content.push(
        details(class="technical-details", [
          summary("Technical details"),
          code(model.workspace_catalog_error),
        ]),
      )
    }
    let state_content = if cold_start is CatalogUnavailable {
      div(
        class="workspace-catalog-state",
        attrs=@html.Attrs::build()
          .data_set("testid", "workspace-catalog-state-panel")
          .data_set("state", surface_state_key(RecoverableError)),
        content,
      )
    } else {
      @html.fragment(content)
    }
    return [
      div(
        class="desk-empty-state",
        attrs=@html.Attrs::build()
          .data_set("testid", "desk-cold-start")
          .data_set("state", cold_start_state_key(cold_start)),
        [state_content],
      ),
    ]
  }
  let rows : Array[@rabbita.Html] = []
  match model.workspace_catalog_state {
    Some(Loading) =>
      rows.push(render_workspace_catalog_state_panel(dispatch, model, Loading))
    Some(Stale) =>
      rows.push(render_workspace_catalog_state_panel(dispatch, model, Stale))
    _ => ()
  }
  let workspaces = matching_moonbooks(model)
  if workspaces.is_empty() {
    rows.push(
      p(
        class="moonbook-search-empty",
        attrs=@html.Attrs::build().role("status"),
        "No matching MoonBooks",
      ),
    )
  }
  for workspace in workspaces {
    rows.push(render_desk_workspace_row(dispatch, model, workspace))
  }
  rows
}

///|
fn render_workspace_catalog_state_panel(
  dispatch : Dispatch[Msg],
  model : Model,
  state : SurfaceState,
) -> @rabbita.Html {
  let children : Array[@rabbita.Html] = [
    render_polite_state_announcement(
      "workspace-catalog-state-announcement",
      workspace_catalog_state_title(state),
      workspace_catalog_state_detail(state),
    ),
    strong(workspace_catalog_state_title(state)),
    p(workspace_catalog_state_detail(state)),
  ]
  match workspace_catalog_state_action(state) {
    Some(label) =>
      children.push(
        button(
          class="secondary-button compact-button",
          attrs=@html.Attrs::build().data_set(
            "testid", "workspace-catalog-state-action",
          ),
          on_click=dispatch(RefreshAll),
          label,
        ),
      )
    None => ()
  }
  if workspace_catalog_state_shows_technical_details(state) &&
    model.workspace_catalog_error != "" {
    children.push(
      details(class="technical-details", [
        summary("Technical details"),
        code(model.workspace_catalog_error),
      ]),
    )
  }
  div(
    class="workspace-catalog-state",
    attrs=@html.Attrs::build()
      .data_set("testid", "workspace-catalog-state-panel")
      .data_set("state", surface_state_key(state)),
    children,
  )
}

///|
fn render_desk_workspace_row(
  dispatch : Dispatch[Msg],
  model : Model,
  workspace : @desk.DeskWorkspace,
) -> @rabbita.Html {
  let selected = workspace.id == model.selected_workspace_id
  let class_name = if selected {
    "desk-workspace-row active " + workspace_status_class(workspace.status)
  } else {
    "desk-workspace-row " + workspace_status_class(workspace.status)
  }
  div(
    class="desk-moonbook-card" + (if selected { " active" } else { "" }),
    attrs=@html.Attrs::build()
      .data_set("testid", "moonbook-card")
      .data_set("workspace-id", workspace.id),
    [
      button(
        class=class_name,
        title=workspace.name +
          " / " +
          workspace_display_book_location(model, workspace) +
          " · " +
          workspace_status_label(workspace.status),
        attrs=@html.Attrs::build()
          .data_set("testid", "desk-workspace-row")
          .data_set("workspace-id", workspace.id)
          .data_set("status", workspace_status_key(workspace.status))
          .aria_label(
            "Select " +
            workspace.name +
            " · " +
            workspace_status_label(workspace.status),
          )
          .aria_pressed(if selected { "true" } else { "false" }),
        on_click=dispatch(SelectWorkspace(workspace.id)),
        [ui_icon("book"), strong(workspace.name)],
      ),
      div(class="moonbook-card-actions", [
        button(
          class="moon-icon-button",
          attrs=@html.Attrs::build()
            .data_set("testid", "moonbook-chat")
            .aria_label("Chat with " + workspace.name),
          on_click=dispatch(OpenMoonBook(workspace.id, Chat)),
          [ui_icon("chat")],
        ),
        button(
          class="moon-icon-button",
          attrs=@html.Attrs::build()
            .data_set("testid", "moonbook-start-task")
            .aria_label("Start a task with " + workspace.name),
          on_click=dispatch(OpenMoonBook(workspace.id, StartTask)),
          [ui_icon("plus")],
        ),
      ]),
    ],
  )
}

