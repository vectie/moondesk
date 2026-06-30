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
    render_desk_folder_outline(dispatch, model),
  ])
}

///|
fn render_desk_folder_outline(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="desk-folder-outline", [
    div(class="pane-heading compact-heading", [
      div([p(class="eyebrow", "folders"), h2("Directory")]),
    ]),
    div(
      class="desk-folder-list",
      desk_folder_outline(model.current_directory, model.entries).map(item => {
        let (label, path, active, depth) = item
        button(
          class=desk_folder_outline_row_class(active, depth),
          title=empty_root_path(path),
          on_click=dispatch(OpenDirectory(path)),
          [
            span(class="folder-indent", ""),
            span(class="tree-icon", "D"),
            span(class="folder-label", label),
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
    render_desk_location_bar(model),
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
fn render_desk_location_bar(model : Model) -> @rabbita.Html {
  let counts = desk_entry_counts(model.entries)
  div(class="desk-location-bar", [
    div(class="desk-location-path", [
      span(class="desk-location-label", "Location"),
      code(empty_root_path(model.current_directory)),
    ]),
    div(class="desk-location-meta", [
      span(desk_entry_count_label(counts)),
      span(desk_selection_label(model)),
      span(desk_access_label(selected_desk_entry(model))),
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
        class=if active { "breadcrumb-chip active" } else { "breadcrumb-chip" },
        title=empty_root_path(path),
        on_click=dispatch(OpenDirectory(path)),
        label,
      )
    }),
  )
}

///|
fn desk_breadcrumbs(directory : String) -> Array[(String, String, Bool)] {
  let crumbs : Array[(String, String, Bool)] = [("root", "", directory == "")]
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
fn desk_folder_outline(
  directory : String,
  entries : Array[@desk.DeskFileEntry],
) -> Array[(String, String, Bool, Int)] {
  let items : Array[(String, String, Bool, Int)] = [
    ("root", "", directory == "", 0),
  ]
  if directory != "" {
    let mut current = ""
    let mut depth = 1
    for part in directory.split("/") {
      if part == "" {
        continue
      }
      current = if current == "" {
        part.to_owned()
      } else {
        current + "/" + part.to_owned()
      }
      items.push((part.to_owned(), current, current == directory, depth))
      depth += 1
    }
  }
  for entry in entries {
    if !(entry.kind is Directory) || entry.path == directory {
      continue
    }
    if parent_path(entry.path) == directory {
      items.push(
        (
          entry.display_name,
          entry.path,
          false,
          desk_outline_child_depth(directory),
        ),
      )
    }
  }
  items
}

///|
fn desk_outline_child_depth(directory : String) -> Int {
  if directory == "" {
    1
  } else {
    directory.split("/").filter(part => part != "").length() + 1
  }
}

///|
fn desk_folder_outline_row_class(active : Bool, depth : Int) -> String {
  let capped_depth = if depth > 4 { 4 } else { depth }
  if active {
    "desk-folder-row active depth-\{capped_depth}"
  } else {
    "desk-folder-row depth-\{capped_depth}"
  }
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
fn desk_entry_counts(
  entries : Array[@desk.DeskFileEntry],
) -> (Int, Int, Int) {
  let mut directories = 0
  let mut files = 0
  for entry in entries {
    if entry.kind is Directory {
      directories += 1
    } else {
      files += 1
    }
  }
  (entries.length(), directories, files)
}

///|
fn desk_entry_count_label(counts : (Int, Int, Int)) -> String {
  let (total, directories, files) = counts
  "\{total} items, \{directories} folders, \{files} files"
}

///|
fn desk_selection_label(model : Model) -> String {
  if model.selected_path == "" {
    "No selection"
  } else {
    "Selected " + empty_root_path(model.selected_path)
  }
}

///|
fn desk_access_label(entry : @desk.DeskFileEntry?) -> String {
  match entry {
    Some(entry) if entry.writable => "Writable"
    Some(_) => "Read-only"
    None => "Browse only"
  }
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
    Some(size) if size >= 1024 * 1024 =>
      "\{size / (1024 * 1024)} MB"
    Some(size) if size >= 1024 => "\{size / 1024} KB"
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
