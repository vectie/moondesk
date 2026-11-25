///|
fn desk_entry_matches_filter(
  entry : @desk.DeskFileEntry,
  query : String,
) -> Bool {
  entry.display_name.to_lower().contains(query) ||
  entry.path.to_lower().contains(query) ||
  (match desk_system_entry_i18n_key(entry) {
    Some(key) =>
      interface_label(key, entry.display_name).to_lower().contains(query)
    None => false
  })
}

///|
#warnings("-unused_value")
fn desk_entry_before(
  left : @desk.DeskFileEntry,
  right : @desk.DeskFileEntry,
  model : Model,
) -> Bool {
  desk_entry_compare(left, right, model) < 0
}

///|
fn desk_entry_compare(
  left : @desk.DeskFileEntry,
  right : @desk.DeskFileEntry,
  model : Model,
) -> Int32 {
  let left_directory = left.kind is Directory
  let right_directory = right.kind is Directory
  if left_directory && !right_directory {
    return -1
  }
  if !left_directory && right_directory {
    return 1
  }
  let order = desk_entry_sort_compare(left, right, model.desk_sort_key)
  if model.desk_sort_desc {
    0 - order
  } else {
    order
  }
}

///|
fn desk_entry_sort_compare(
  left : @desk.DeskFileEntry,
  right : @desk.DeskFileEntry,
  key : DeskSortKey,
) -> Int32 {
  let primary = match key {
    SortByName => desk_string_compare(left.display_name, right.display_name)
    SortByKind =>
      desk_string_compare(kind_label(left.kind), kind_label(right.kind))
    SortByLayer =>
      desk_string_compare(
        layer_label(left.source_layer),
        layer_label(right.source_layer),
      )
    SortByModified =>
      desk_optional_string_compare(left.modified_at, right.modified_at)
    SortBySize => desk_optional_int_compare(left.size_bytes, right.size_bytes)
  }
  if primary != 0 {
    primary
  } else {
    let name = desk_string_compare(left.display_name, right.display_name)
    if name != 0 {
      name
    } else {
      desk_string_compare(left.path, right.path)
    }
  }
}

///|
fn desk_optional_string_compare(left : String?, right : String?) -> Int32 {
  match (left, right) {
    (Some(left), Some(right)) => desk_string_compare(left, right)
    (Some(_), None) => -1
    (None, Some(_)) => 1
    (None, None) => 0
  }
}

///|
fn desk_optional_int_compare(left : Int32?, right : Int32?) -> Int32 {
  match (left, right) {
    (Some(left), Some(right)) =>
      if left < right {
        -1
      } else if left > right {
        1
      } else {
        0
      }
    (Some(_), None) => -1
    (None, Some(_)) => 1
    (None, None) => 0
  }
}

///|
fn desk_string_compare(left : String, right : String) -> Int32 {
  left.to_lower().lexical_compare(right.to_lower())
}

///|
fn render_desk_location_bar(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let visible_entries = filtered_desk_entries(model)
  let counts = desk_entry_counts(visible_entries)
  div(class="desk-location-bar", [
    div(class="desk-location-meta", [
      span(
        desk_entry_count_label_for_model(
          model,
          counts,
          visible_entries.length(),
        ),
      ),
      if model.desk_selected_paths.length() > 0 {
        span(desk_selection_label(model))
      } else {
        @html.nothing
      },
    ]),
    desk_disclosure(
      "desk-location-disclosure",
      "desk-go-to-folder",
      "Go to folder",
      [
        div(class="desk-location-path", [
          input(
            class="line-input desk-location-input",
            attrs=@html.Attrs::build()
              .data_set("testid", "desk-location-input")
              .disabled(desk_workspace_action_disabled(model)),
            value=model.desk_location_input,
            placeholder="Folder path",
            on_input=fn(value) { dispatch(SetDeskLocationInput(value)) },
          ),
          button(
            class="secondary-button compact-button",
            attrs=@html.Attrs::build().data_set("testid", "desk-location-go"),
            title="Open folder",
            disabled=desk_workspace_action_disabled(model),
            on_click=dispatch(OpenDeskLocation),
            "Go",
          ),
        ]),
      ],
    ),
  ])
}

///|
fn render_desk_file_row(
  dispatch : Dispatch[Msg],
  model : Model,
  entry : @desk.DeskFileEntry,
) -> @rabbita.Html {
  let class_name = desk_file_row_class(model, entry)
  let selected_value = if desk_entry_is_selected(model, entry.path) {
    "true"
  } else {
    "false"
  }
  let open_msg = if entry.kind is Directory {
    OpenDirectory(entry.path)
  } else {
    OpenWorkFile(entry.path)
  }
  let row_attrs = @html.Attrs::build()
    .data_set("testid", "desk-file-row")
    .data_set("i18n-preserve", "title")
    .data_set("path", entry.path)
    .role("option")
    .aria_selected(selected_value)
    .on_mousedown(fn(event) {
      dispatch(desk_mouse_event_msg(entry.path, event))
    })
    .on_dblclick(fn(_) { dispatch(open_msg) })
  let row_attrs = if entry.kind is Directory {
    row_attrs
  } else {
    row_attrs
    .draggable("true")
    .on_dragstart(fn(event) { wiki_chat_drag_start_cmd(entry.path, event) })
  }
  div(class=class_name, title=entry.path, attrs=row_attrs, [
    span(
      class="desk-file-name",
      attrs=@html.Attrs::build().data_set(
        "i18n-scope",
        if desk_system_entry_i18n_key(entry) is Some(_) {
          "interface"
        } else {
          "content"
        },
      ),
      [
        ui_icon(if entry.kind is Directory { "folder" } else { "files" }),
        if model.desk_rename_editing_path == entry.path {
          desk_inline_rename_input(dispatch, model, entry)
        } else {
          strong(
            attrs=desk_name_attrs(desk_system_entry_i18n_key(entry)),
            entry.display_name,
          )
        },
      ],
    ),
    span(kind_label(entry.kind)),
    span(optional_text(entry.modified_at, "—")),
    span(size_label(entry.size_bytes)),
  ])
}

///|
fn desk_inline_rename_input(
  dispatch : Dispatch[Msg],
  model : Model,
  entry : @desk.DeskFileEntry,
) -> @rabbita.Html {
  input(
    class="line-input inline-rename-input",
    attrs=@html.Attrs::build()
      .data_set("testid", "desk-inline-rename")
      .data_set("i18n-scope", "content")
      .data_set("path", entry.path),
    value=model.desk_rename_name,
    placeholder=entry.display_name,
    on_input=fn(value) { dispatch(SetDeskRenameName(value)) },
  )
}

///|
fn desk_file_row_class(model : Model, entry : @desk.DeskFileEntry) -> String {
  let selected = desk_entry_is_selected(model, entry.path)
  let focused = entry.path == model.selected_path
  if selected && focused {
    "desk-file-row selected focused"
  } else if selected {
    "desk-file-row selected"
  } else {
    "desk-file-row"
  }
}

///|
fn desk_entry_is_selected(model : Model, path : String) -> Bool {
  if model.desk_selected_paths.length() == 0 {
    path == model.selected_path
  } else {
    model.desk_selected_paths.contains(path)
  }
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
        attrs=@html.Attrs::build().data_set("i18n-preserve", "title"),
        title=empty_root_path(path),
        on_click=dispatch(OpenDirectory(path)),
        // Only the root marker is a UI label; other segments are real names.
        span(
          attrs=desk_name_attrs(
            if path == "" {
              Some("desk.section_root")
            } else {
              None
            },
          ),
          label,
        ),
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
) -> Array[(String, String, Bool, Int32)] {
  let items : Array[(String, String, Bool, Int32)] = [
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
fn desk_outline_child_depth(directory : String) -> Int32 {
  if directory == "" {
    1
  } else {
    directory.split("/").filter(part => part != "").count() + 1
  }
}

///|
fn desk_folder_outline_row_class(active : Bool, depth : Int32) -> String {
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
  aside(
    class="desk-details",
    attrs=@html.Attrs::build()
      .aria_label("Selection details")
      .data_set("testid", "desk-details"),
    [
      div(class="pane-heading", [
        div([p(class="eyebrow", "selection"), h2("Details")]),
      ]),
      if model.desk_selected_paths.length() > 1 {
        render_desk_multi_selection_details(dispatch, model)
      } else {
        match selected_desk_entry(model) {
          Some(entry) =>
            section(class="desk-detail-panel", [
              div(class="desk-detail-title", [
                span(class="tree-icon", icon_for_kind(entry.kind)),
                h3(
                  attrs=desk_name_attrs(desk_system_entry_i18n_key(entry)),
                  entry.display_name,
                ),
              ]),
              div(class="info-row", [span("Type"), span(kind_label(entry.kind))]),
              info_row(
                "Modified",
                optional_text(entry.modified_at, "Not available"),
              ),
              info_row("Size", size_label(entry.size_bytes)),
              div(class="info-row", [
                span("Access"),
                span(desk_access_label(Some(entry))),
              ]),
              desk_disclosure(
                "desk-technical-details",
                "desk-selection-technical-details",
                "Technical details",
                [
                  info_row("Path", empty_root_path(entry.path)),
                  info_row("Source area", layer_label(entry.source_layer)),
                  div(class="info-row", [
                    span("Readable"),
                    span(yes_no(entry.readable)),
                  ]),
                  div(class="info-row", [
                    span("Writable"),
                    span(yes_no(entry.writable)),
                  ]),
                ],
              ),
              render_desk_inline_preview(dispatch, model),
              div(class="desk-detail-actions", [
                input(
                  class="line-input",
                  attrs=@html.Attrs::build().data_set("i18n-scope", "content"),
                  value=model.desk_rename_name,
                  placeholder=entry.display_name,
                  on_input=fn(value) { dispatch(SetDeskRenameName(value)) },
                ),
                button(
                  class="secondary-button full",
                  title="Rename selected item",
                  on_click=dispatch(RenameDeskSelection),
                  "Rename",
                ),
                render_desk_operation_status(
                  "status-line",
                  model.desk_rename_status,
                ),
                button(
                  class="secondary-button full",
                  attrs=@html.Attrs::build().data_set(
                    "testid", "desk-reveal-selection",
                  ),
                  title="Reveal selected item in the system file manager",
                  on_click=dispatch(RevealSelection),
                  "Reveal in File Manager",
                ),
                if entry.kind is Directory {
                  button(
                    class="secondary-button full",
                    on_click=dispatch(OpenDirectory(entry.path)),
                    "Browse folder",
                  )
                } else if wiki_document_path_supported(entry.path) {
                  button(
                    class="secondary-button full",
                    on_click=dispatch(SelectWorkspaceMode(MoonWiki)),
                    "Open in Wiki",
                  )
                } else {
                  button(
                    class="secondary-button full",
                    title="This file is available in the Desk preview; the Wiki document workspace supports Office, PDF, and living artifacts",
                    on_click=dispatch(SelectPath(entry.path)),
                    "Preview in Desk",
                  )
                },
                render_desk_single_selection_more_actions(
                  dispatch, model, entry,
                ),
              ]),
            ])
          None =>
            if desk_workspace_action_disabled(model) {
              section(class="desk-detail-panel desk-detail-panel-empty", [
                div(class="desk-detail-title", [
                  span(class="tree-icon", "D"),
                  h3("No MoonBook selected"),
                ]),
              ])
            } else {
              section(class="desk-detail-panel", [
                div(class="desk-detail-title", [
                  span(class="tree-icon", "D"),
                  h3(workspace_name(model)),
                ]),
                info_row("Folder", empty_root_path(model.current_directory)),
                info_row("Items", model.entries.length().to_string()),
                desk_disclosure(
                  "desk-technical-details",
                  "desk-folder-technical-details",
                  "Technical details",
                  [
                    info_row("MoonBook", workspace_name(model)),
                    info_row("Storage path", workspace_root(model)),
                  ],
                ),
                div(class="desk-detail-actions", [
                  button(
                    class="secondary-button full",
                    attrs=@html.Attrs::build().data_set(
                      "testid", "desk-reveal-current-directory",
                    ),
                    title="Reveal current folder in the system file manager",
                    on_click=dispatch(RevealSelection),
                    "Reveal Folder",
                  ),
                  render_desk_folder_more_actions(dispatch, model),
                ]),
              ])
            }
        }
      },
    ],
  )
}
