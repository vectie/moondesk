///|
fn render_desk_mode(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  div(class="desk-main file-desk-main", [
    render_desk_workspace_sidebar(dispatch, model),
    render_desk_file_browser(dispatch, model),
    render_desk_details(dispatch, model),
  ])
}

///|
fn render_desk_workspace_sidebar(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  aside(class="desk-sidebar", [
    div(class="pane-heading", [
      div([p(class="eyebrow", "virtual filesystem"), h2("MoonBooks")]),
      button(
        class="secondary-button compact-button",
        title="Refresh",
        on_click=dispatch(RefreshAll),
        "Refresh",
      ),
    ]),
    div(
      class="desk-workspace-list",
      model.workspaces.map(workspace => {
        let class_name = if workspace.id == model.selected_workspace_id {
          "desk-workspace-row active"
        } else {
          "desk-workspace-row"
        }
        button(
          class=class_name,
          title=workspace.root_path,
          on_click=dispatch(SelectWorkspace(workspace.id)),
          [
            span(
              class="desk-workspace-kind",
              workspace_kind_label(workspace.kind),
            ),
            strong(workspace.name),
            small(workspace.root_path),
          ],
        )
      }),
    ),
  ])
}

///|
fn render_desk_file_browser(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="desk-browser", [
    div(class="desk-browser-head", [
      div([
        p(class="eyebrow", "desk"),
        h2(desk_directory_title(model.current_directory)),
      ]),
      div(class="toolbar-actions", [
        button(
          class="secondary-button compact-button",
          title="Open parent directory",
          on_click=dispatch(OpenDirectory(parent_path(model.current_directory))),
          "Up",
        ),
        button(
          class="secondary-button compact-button",
          title="Open root directory",
          on_click=dispatch(OpenDirectory("")),
          "Root",
        ),
      ]),
    ]),
    render_desk_breadcrumb(dispatch, model.current_directory),
    div(class="desk-file-table", [
      div(class="desk-file-row desk-file-header", [
        span("Name"),
        span("Kind"),
        span("Layer"),
        span("Modified"),
        span("Size"),
      ]),
      if model.entries.length() == 0 {
        div(class="desk-empty", [
          strong("No virtual files loaded"),
          p(model.host_status),
        ])
      } else {
        div(
          class="desk-file-rows",
          model.entries.map(entry => {
            render_desk_file_row(dispatch, model, entry)
          }),
        )
      },
    ]),
  ])
}

///|
fn render_desk_file_row(
  dispatch : Dispatch[Msg],
  model : Model,
  entry : @desk.DeskFileEntry,
) -> @rabbita.Html {
  let selected = entry.path == model.selected_path
  let class_name = if selected {
    "desk-file-row selected"
  } else {
    "desk-file-row"
  }
  let open_msg = if entry.kind is Directory {
    OpenDirectory(entry.path)
  } else {
    SelectPath(entry.path)
  }
  button(class=class_name, title=entry.path, on_click=dispatch(open_msg), [
    span(class="desk-file-name", [
      span(class="tree-icon", icon_for_kind(entry.kind)),
      strong(entry.display_name),
    ]),
    span(kind_label(entry.kind)),
    span(layer_label(entry.source_layer)),
    span(optional_text(entry.modified_at, "unknown")),
    span(size_label(entry.size_bytes)),
  ])
}

///|
fn render_desk_breadcrumb(
  dispatch : Dispatch[Msg],
  directory : String,
) -> @rabbita.Html {
  div(
    class="desk-breadcrumb",
    desk_breadcrumbs(directory).map(crumb => {
      let (label, path, active) = crumb
      button(
        class=if active {
          "breadcrumb-chip active"
        } else {
          "breadcrumb-chip"
        },
        title=empty_root_path(path),
        on_click=dispatch(OpenDirectory(path)),
        label,
      )
    }),
  )
}

///|
fn desk_breadcrumbs(directory : String) -> Array[(String, String, Bool)] {
  let crumbs : Array[(String, String, Bool)] = [
    ("root", "", directory == ""),
  ]
  if directory == "" {
    return crumbs
  }
  let mut current = ""
  for part in directory.split("/") {
    if part == "" {
      continue
    }
    current = if current == "" {
      part.to_owned()
    } else {
      current + "/" + part.to_owned()
    }
    crumbs.push((part.to_owned(), current, current == directory))
  }
  crumbs
}

///|
fn render_desk_details(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  aside(class="desk-details", [
    div(class="pane-heading", [
      div([p(class="eyebrow", "selection"), h2("Details")]),
    ]),
    match selected_desk_entry(model) {
      Some(entry) =>
        section(class="desk-detail-panel", [
          div(class="desk-detail-title", [
            span(class="tree-icon", icon_for_kind(entry.kind)),
            h3(entry.display_name),
          ]),
          info_row("Virtual Path", empty_root_path(entry.path)),
          info_row("Kind", kind_label(entry.kind)),
          info_row("Layer", layer_label(entry.source_layer)),
          info_row("Modified", optional_text(entry.modified_at, "unknown")),
          info_row("Size", size_label(entry.size_bytes)),
          info_row("Readable", yes_no(entry.readable)),
          info_row("Writable", yes_no(entry.writable)),
          div(class="desk-detail-actions", [
            button(
              class="secondary-button full",
              on_click=dispatch(SelectWorkspaceMode(MoonWiki)),
              "Open in Wiki",
            ),
            button(
              class="secondary-button full",
              on_click=dispatch(SelectWorkspaceMode(MoonCode)),
              "Ask Code",
            ),
          ]),
        ])
      None =>
        section(class="desk-detail-panel", [
          div(class="desk-detail-title", [
            span(class="tree-icon", "D"),
            h3(workspace_name(model)),
          ]),
          info_row("Workspace", workspace_name(model)),
          info_row("Root", workspace_root(model)),
          info_row("Directory", empty_root_path(model.current_directory)),
          info_row("Entries", model.entries.length().to_string()),
          info_row("Mode", "read-only virtual filesystem"),
        ])
    },
  ])
}

///|
fn selected_desk_entry(model : Model) -> @desk.DeskFileEntry? {
  find_entry(model, model.selected_path)
}

///|
fn desk_directory_title(path : String) -> String {
  if path == "" {
    "Project Root"
  } else {
    path
  }
}

///|
fn parent_path(path : String) -> String {
  match path.rev_split_once("/") {
    Some((parent, _)) => parent.to_owned()
    None => ""
  }
}

///|
fn empty_root_path(path : String) -> String {
  if path == "" {
    "/"
  } else {
    path
  }
}

///|
fn optional_text(value : String?, fallback : String) -> String {
  match value {
    Some(text) if text != "" => text
    _ => fallback
  }
}

///|
fn size_label(value : Int?) -> String {
  match value {
    Some(size) => "\{size} B"
    None => "-"
  }
}

///|
fn yes_no(value : Bool) -> String {
  if value {
    "yes"
  } else {
    "no"
  }
}

///|
fn kind_label(kind : @desk.EntryKind) -> String {
  match kind {
    Directory => "folder"
    Markdown => "markdown"
    Html => "html"
    Json => "json"
    Image => "image"
    Artifact => "artifact"
    Text => "text"
    Unknown => "unknown"
  }
}
