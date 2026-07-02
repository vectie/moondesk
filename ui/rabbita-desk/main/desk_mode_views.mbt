///|
fn render_desk_mode(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  div(
    class="desk-main file-desk-main",
    attrs=@html.Attrs::build().data_set("testid", "desk-mode"),
    [
      render_desk_workspace_sidebar(dispatch, model),
      render_desk_file_browser(dispatch, model),
      render_desk_details(dispatch, model),
    ],
  )
}

///|
fn render_desk_workspace_sidebar(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  aside(class="desk-sidebar", [
    div(class="pane-heading", [
      div([p(class="eyebrow", "library"), h2("MoonBooks")]),
      button(
        class="secondary-button compact-button",
        title="Refresh",
        on_click=dispatch(RefreshAll),
        "Refresh",
      ),
    ]),
    render_desk_library_location(model),
    render_new_moonbook_panel(dispatch, model),
    div(
      class="desk-workspace-list",
      attrs=@html.Attrs::build().data_set("testid", "desk-workspace-list"),
      if model.workspaces.length() == 0 {
        [
          div(class="desk-empty-state", [
            strong("No MoonBooks in this workspace"),
            p("Create or import a MoonBook and it will appear here."),
          ]),
        ]
      } else {
        model.workspaces.map(workspace => {
          let class_name = if workspace.id == model.selected_workspace_id {
            "desk-workspace-row active " + workspace_status_class(workspace.status)
          } else {
            "desk-workspace-row " + workspace_status_class(workspace.status)
          }
          let meta_children : Array[@rabbita.Html] = [
            span(
              class="desk-workspace-kind",
              workspace_kind_label(workspace.kind),
            ),
          ]
          if workspace.status != Ready {
            meta_children.push(
              span(
                class="desk-workspace-status",
                workspace_status_label(workspace.status),
              ),
            )
          }
          button(
            class=class_name,
            title=workspace.root_path,
            attrs=@html.Attrs::build()
              .data_set("testid", "desk-workspace-row")
              .data_set("workspace-id", workspace.id)
              .data_set("status", workspace_status_key(workspace.status)),
            on_click=dispatch(SelectWorkspace(workspace.id)),
            [
              div(class="desk-workspace-meta", meta_children),
              strong(workspace.name),
              small(workspace.root_path),
            ],
          )
        })
      },
    ),
    render_desk_quick_access(dispatch, model),
    render_desk_folder_outline(dispatch, model),
  ])
}

///|
fn render_desk_quick_access(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(
    class="desk-quick-access",
    attrs=@html.Attrs::build().data_set("testid", "desk-quick-access"),
    [
      div(class="pane-heading compact-heading", [
        div([p(class="eyebrow", "quick access"), h2("Favorites")]),
      ]),
      render_desk_quick_path_group(
        dispatch,
        model,
        "Favorites",
        "desk-favorite-row",
        model.favorites,
      ),
      render_desk_quick_path_group(
        dispatch,
        model,
        "Recent",
        "desk-recent-row",
        model.recent_paths,
      ),
    ],
  )
}

///|
fn render_desk_quick_path_group(
  dispatch : Dispatch[Msg],
  model : Model,
  label : String,
  testid : String,
  paths : Array[String],
) -> @rabbita.Html {
  div(class="desk-quick-group", [
    strong(label),
    if paths.length() == 0 {
      p(class="status-line", "No " + label.to_lower())
    } else {
      div(
        class="desk-quick-list",
        paths.map(path => {
          button(
            class=desk_quick_path_row_class(model, path),
            title=path,
            attrs=@html.Attrs::build()
              .data_set("testid", testid)
              .data_set("path", path),
            on_click=dispatch(OpenQuickPath(path)),
            [
              span(
                class="tree-icon",
                icon_for_kind(quick_path_kind(model, path)),
              ),
              span(class="folder-label", empty_root_path(path)),
            ],
          )
        }),
      )
    },
  ])
}

///|
fn desk_quick_path_row_class(model : Model, path : String) -> String {
  if model.selected_path == path {
    "desk-quick-row active"
  } else {
    "desk-quick-row"
  }
}

///|
fn quick_path_kind(model : Model, path : String) -> @desk.EntryKind {
  match find_entry(model, path) {
    Some(entry) => entry.kind
    None => Unknown
  }
}

///|
fn render_desk_library_location(model : Model) -> @rabbita.Html {
  section(
    class="desk-library-location",
    attrs=@html.Attrs::build().data_set("testid", "desk-library-root"),
    [
      div([
        p(class="eyebrow", "user data root"),
        strong(workspace_library_root(model)),
      ]),
      small(workspace_library_count_label(model)),
      code(workspace_moonbook_library_path(model)),
      render_desk_product_summary(model),
    ],
  )
}

///|
fn render_desk_product_summary(model : Model) -> @rabbita.Html {
  let products = workspace_core_products(model)
  if products.length() == 0 {
    p(class="status-line", "Product registry pending")
  } else {
    div(class="desk-product-summary", [
      small(workspace_product_count_label(model)),
      div(
        class="desk-product-strip",
        products.map(product => {
          span(
            class="desk-product-chip status-" + product.status,
            title=product.state_path + "\n" + product.service_path,
            [
              span(class="status-dot live", ""),
              span(product.name),
            ],
          )
        }),
      ),
    ])
  }
}

///|
fn render_new_moonbook_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="desk-new-book-panel", [
    div(class="desk-library-action", [
      strong("Create MoonBook"),
      input(
        class="line-input",
        attrs=@html.Attrs::build().data_set("testid", "desk-new-book-name"),
        value=model.new_book_name,
        placeholder="MoonBook name",
        on_input=fn(value) { dispatch(SetNewBookName(value)) },
      ),
      input(
        class="line-input",
        attrs=@html.Attrs::build().data_set("testid", "desk-new-book-id"),
        value=model.new_book_id,
        placeholder="book id",
        on_input=fn(value) { dispatch(SetNewBookId(value)) },
      ),
      button(
        class="primary-button full",
        attrs=@html.Attrs::build().data_set("testid", "desk-create-book"),
        title="Create MoonBook in the Moondesk workspace library",
        disabled=desk_create_book_disabled(model),
        on_click=dispatch(CreateBlankMoonBook),
        "Create MoonBook",
      ),
      p(class="status-line", model.new_book_status),
    ]),
    div(class="desk-library-action", [
      strong("Import Folder"),
      input(
        class="line-input",
        attrs=@html.Attrs::build().data_set("testid", "desk-import-book-path"),
        value=model.import_book_path,
        placeholder="/path/to/existing/moonbook",
        on_input=fn(value) { dispatch(SetImportBookPath(value)) },
      ),
      button(
        class="secondary-button full",
        attrs=@html.Attrs::build().data_set("testid", "desk-import-book"),
        title="Copy an existing MoonBook folder into the Moondesk workspace library",
        disabled=desk_import_book_disabled(model),
        on_click=dispatch(ImportMoonBook),
        "Import MoonBook",
      ),
      button(
        class="secondary-button full",
        attrs=@html.Attrs::build().data_set("testid", "desk-import-book-folder"),
        title="Choose a MoonBook folder to import into the Moondesk workspace library",
        on_click=dispatch(PickImportMoonBookFolder),
        "Choose Folder",
      ),
      button(
        class="secondary-button full",
        attrs=@html.Attrs::build().data_set(
          "testid", "desk-import-book-archive",
        ),
        title="Choose a zipped MoonBook archive to import into the Moondesk workspace library",
        on_click=dispatch(PickImportMoonBookArchive),
        "Choose Archive",
      ),
      p(class="status-line", model.import_book_status),
    ]),
  ])
}

///|
fn desk_create_book_disabled(model : Model) -> Bool {
  model.new_book_name.trim().to_owned() == "" &&
  model.new_book_id.trim().to_owned() == ""
}

///|
fn desk_import_book_disabled(model : Model) -> Bool {
  model.import_book_path.trim().to_owned() == ""
}

///|
fn desk_workspace_action_disabled(model : Model) -> Bool {
  model.selected_workspace_id == ""
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
      attrs=@html.Attrs::build().data_set("testid", "desk-folder-list"),
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
  let visible_entries = sorted_desk_entries(model)
  section(class="desk-browser", [
    div(class="desk-browser-head", [
      div([
        p(class="eyebrow", "desk"),
        h2(desk_directory_title(model.current_directory)),
      ]),
      div(class="toolbar-actions", [
        input(
          class="line-input compact-input",
          attrs=@html.Attrs::build()
            .data_set("testid", "desk-new-item-name")
            .disabled(desk_workspace_action_disabled(model)),
          value=model.desk_new_item_name,
          placeholder="New item name",
          on_input=fn(value) { dispatch(SetDeskNewItemName(value)) },
        ),
        button(
          class="secondary-button compact-button",
          attrs=@html.Attrs::build().data_set("testid", "desk-new-folder"),
          title="Create folder in the current directory",
          disabled=desk_workspace_action_disabled(model),
          on_click=dispatch(CreateDeskFolder),
          "New Folder",
        ),
        button(
          class="secondary-button compact-button",
          attrs=@html.Attrs::build().data_set("testid", "desk-new-note"),
          title="Create Markdown note in the current directory",
          disabled=desk_workspace_action_disabled(model),
          on_click=dispatch(CreateDeskMarkdown),
          "New Note",
        ),
        input(
          class="line-input compact-input desk-filter-input",
          attrs=@html.Attrs::build()
            .data_set("testid", "desk-filter-query")
            .disabled(desk_workspace_action_disabled(model)),
          value=model.desk_filter_query,
          placeholder="Filter current folder",
          on_input=fn(value) { dispatch(SetDeskFilterQuery(value)) },
        ),
        button(
          class="secondary-button compact-button",
          attrs=@html.Attrs::build().data_set("testid", "desk-clear-filter"),
          title="Clear current folder filter",
          disabled=desk_workspace_action_disabled(model) ||
            model.desk_filter_query.trim().to_owned() == "",
          on_click=dispatch(SetDeskFilterQuery("")),
          "Clear Filter",
        ),
        render_desk_density_control(dispatch, model),
        button(
          class="secondary-button compact-button",
          attrs=@html.Attrs::build().data_set("testid", "desk-import-files"),
          title="Import local files into the current directory",
          disabled=desk_workspace_action_disabled(model),
          on_click=dispatch(ImportLocalFilesToDesk),
          "Import Files",
        ),
        button(
          class="secondary-button compact-button",
          attrs=@html.Attrs::build().data_set("testid", "desk-import-folder"),
          title="Import a local folder into the current directory",
          disabled=desk_workspace_action_disabled(model),
          on_click=dispatch(ImportLocalFolderToDesk),
          "Import Folder",
        ),
        button(
          class="secondary-button compact-button",
          attrs=@html.Attrs::build().data_set("testid", "desk-refresh"),
          title="Refresh current MoonBook directory",
          on_click=dispatch(RefreshAll),
          "Refresh",
        ),
        button(
          class="secondary-button compact-button",
          attrs=@html.Attrs::build().data_set("testid", "desk-back"),
          title="Go to previous directory",
          disabled=desk_workspace_action_disabled(model) ||
            model.desk_back_stack.length() == 0,
          on_click=dispatch(NavigateDeskBack),
          "Back",
        ),
        button(
          class="secondary-button compact-button",
          attrs=@html.Attrs::build().data_set("testid", "desk-forward"),
          title="Go to next directory",
          disabled=desk_workspace_action_disabled(model) ||
            model.desk_forward_stack.length() == 0,
          on_click=dispatch(NavigateDeskForward),
          "Forward",
        ),
        button(
          class="secondary-button compact-button",
          attrs=@html.Attrs::build().data_set("testid", "desk-up"),
          title="Open parent directory",
          disabled=desk_workspace_action_disabled(model) ||
            model.current_directory == "",
          on_click=dispatch(OpenDirectory(parent_path(model.current_directory))),
          "Up",
        ),
        button(
          class="secondary-button compact-button",
          attrs=@html.Attrs::build().data_set("testid", "desk-root"),
          title="Open root directory",
          disabled=desk_workspace_action_disabled(model) ||
            model.current_directory == "",
          on_click=dispatch(OpenDirectory("")),
          "Root",
        ),
      ]),
    ]),
    render_desk_breadcrumb(dispatch, model.current_directory),
    render_desk_location_bar(dispatch, model),
    p(class="desk-create-status", model.desk_new_item_status),
    div(class=desk_file_table_class(model), [
      div(class="desk-file-row desk-file-header", [
        desk_sort_header_button(dispatch, model, SortByName, "Name"),
        desk_sort_header_button(dispatch, model, SortByKind, "Kind"),
        desk_sort_header_button(dispatch, model, SortByLayer, "Layer"),
        desk_sort_header_button(dispatch, model, SortByModified, "Modified"),
        desk_sort_header_button(dispatch, model, SortBySize, "Size"),
      ]),
      div(
        class="desk-file-rows",
        attrs=@html.Attrs::build()
          .data_set("testid", "desk-file-list")
          .tabindex(0)
          .role("listbox")
          .aria_label("Desk file list")
          .aria_multiselectable("true"),
        on_keydown=fn(keyboard) { dispatch(desk_keyboard_msg(keyboard)) },
        if model.entries.length() == 0 {
          render_desk_empty_folder_state(model)
        } else if visible_entries.length() == 0 {
          [
            div(class="desk-empty", [
              strong("No matching files"),
              p("Clear the filter to show all items in this folder."),
            ]),
          ]
        } else {
          visible_entries.map(entry => {
            render_desk_file_row(dispatch, model, entry)
          })
        },
      ),
    ]),
  ])
}

///|
fn render_desk_empty_folder_state(model : Model) -> Array[@rabbita.Html] {
  [
    div(
      class="desk-empty",
      attrs=@html.Attrs::build().data_set("testid", "desk-empty-folder"),
      [
        strong(desk_empty_folder_title(model)),
        p(desk_empty_folder_message(model)),
      ],
    ),
  ]
}

///|
fn desk_empty_folder_title(model : Model) -> String {
  if model.selected_workspace_id == "" {
    "No MoonBook selected"
  } else if model.current_directory == "" {
    "This MoonBook root is empty"
  } else {
    "This folder is empty"
  }
}

///|
fn desk_empty_folder_message(model : Model) -> String {
  if model.selected_workspace_id == "" {
    "Select or create a MoonBook to browse its files."
  } else if model.current_directory == "" {
    "Create a folder, create a note, import files, or paste items into this MoonBook."
  } else {
    "Create a folder, create a note, import files, or paste items into \{empty_root_path(model.current_directory)}."
  }
}

///|
fn render_desk_density_control(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  div(
    class="desk-density-control",
    attrs=@html.Attrs::build()
      .data_set("testid", "desk-density-control")
      .role("group")
      .aria_label("Desk row density"),
    [
      button(
        class=desk_density_button_class(model, DeskDensityComfortable),
        attrs=@html.Attrs::build().data_set(
          "testid", "desk-density-comfortable",
        ),
        title="Use comfortable Desk row spacing",
        on_click=dispatch(SetDeskDensity(DeskDensityComfortable)),
        "Comfort",
      ),
      button(
        class=desk_density_button_class(model, DeskDensityCompact),
        attrs=@html.Attrs::build().data_set("testid", "desk-density-compact"),
        title="Use compact Desk row spacing",
        on_click=dispatch(SetDeskDensity(DeskDensityCompact)),
        "Compact",
      ),
    ],
  )
}

///|
fn desk_file_table_class(model : Model) -> String {
  match model.desk_density {
    DeskDensityComfortable => "desk-file-table density-comfortable"
    DeskDensityCompact => "desk-file-table density-compact"
  }
}

///|
fn desk_density_button_class(model : Model, density : DeskDensity) -> String {
  if model.desk_density == density {
    "secondary-button compact-button density-button active"
  } else {
    "secondary-button compact-button density-button"
  }
}

///|
fn desk_sort_header_button(
  dispatch : Dispatch[Msg],
  model : Model,
  key : DeskSortKey,
  label : String,
) -> @rabbita.Html {
  button(
    class=desk_sort_header_class(model, key),
    title="Sort by " + label,
    on_click=dispatch(SetDeskSort(key)),
    desk_sort_header_label(model, key, label),
  )
}

///|
fn desk_sort_header_class(model : Model, key : DeskSortKey) -> String {
  if model.desk_sort_key == key {
    "desk-sort-button active"
  } else {
    "desk-sort-button"
  }
}

///|
fn desk_sort_header_label(
  model : Model,
  key : DeskSortKey,
  label : String,
) -> String {
  if model.desk_sort_key != key {
    label
  } else if model.desk_sort_desc {
    label + " v"
  } else {
    label + " ^"
  }
}

///|
fn sorted_desk_entries(model : Model) -> Array[@desk.DeskFileEntry] {
  let entries = filtered_desk_entries(model)
  let sorted : Array[@desk.DeskFileEntry] = []
  let added : Array[String] = []
  while sorted.length() < entries.length() {
    let mut best : @desk.DeskFileEntry? = None
    for entry in entries {
      if added.contains(entry.id) {
        continue
      }
      match best {
        Some(current) =>
          if desk_entry_before(entry, current, model) {
            best = Some(entry)
          }
        None => best = Some(entry)
      }
    }
    match best {
      Some(entry) => {
        sorted.push(entry)
        added.push(entry.id)
      }
      None => break
    }
  }
  sorted
}

///|
fn filtered_desk_entries(model : Model) -> Array[@desk.DeskFileEntry] {
  let query = model.desk_filter_query.trim().to_owned().to_lower()
  if query == "" {
    model.entries
  } else {
    model.entries.filter(entry => desk_entry_matches_filter(entry, query))
  }
}

///|
fn desk_entry_matches_filter(
  entry : @desk.DeskFileEntry,
  query : String,
) -> Bool {
  entry.display_name.to_lower().contains(query) ||
  entry.path.to_lower().contains(query)
}

///|
fn desk_entry_before(
  left : @desk.DeskFileEntry,
  right : @desk.DeskFileEntry,
  model : Model,
) -> Bool {
  let left_directory = left.kind is Directory
  let right_directory = right.kind is Directory
  if left_directory && !right_directory {
    return true
  }
  if !left_directory && right_directory {
    return false
  }
  let order = desk_entry_sort_compare(left, right, model.desk_sort_key)
  let directional = if model.desk_sort_desc { 0 - order } else { order }
  directional < 0
}

///|
fn desk_entry_sort_compare(
  left : @desk.DeskFileEntry,
  right : @desk.DeskFileEntry,
  key : DeskSortKey,
) -> Int {
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
fn desk_optional_string_compare(left : String?, right : String?) -> Int {
  match (left, right) {
    (Some(left), Some(right)) => desk_string_compare(left, right)
    (Some(_), None) => -1
    (None, Some(_)) => 1
    (None, None) => 0
  }
}

///|
fn desk_optional_int_compare(left : Int?, right : Int?) -> Int {
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
fn desk_string_compare(left : String, right : String) -> Int {
  let left_chars = desk_string_chars(left.to_lower())
  let right_chars = desk_string_chars(right.to_lower())
  let limit = if left_chars.length() < right_chars.length() {
    left_chars.length()
  } else {
    right_chars.length()
  }
  for index in 0..<limit {
    let left_code = left_chars[index].to_int()
    let right_code = right_chars[index].to_int()
    if left_code < right_code {
      return -1
    }
    if left_code > right_code {
      return 1
    }
  }
  if left_chars.length() < right_chars.length() {
    -1
  } else if left_chars.length() > right_chars.length() {
    1
  } else {
    0
  }
}

///|
fn desk_string_chars(value : String) -> Array[Char] {
  let chars : Array[Char] = []
  for ch in value {
    chars.push(ch)
  }
  chars
}

///|
fn render_desk_location_bar(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let visible_entries = filtered_desk_entries(model)
  let counts = desk_entry_counts(visible_entries)
  div(class="desk-location-bar", [
    div(class="desk-location-path", [
      span(class="desk-location-label", "Location"),
      input(
        class="line-input desk-location-input",
        attrs=@html.Attrs::build()
          .data_set("testid", "desk-location-input")
          .disabled(desk_workspace_action_disabled(model)),
        value=model.desk_location_input,
        placeholder=empty_root_path(model.current_directory),
        on_input=fn(value) { dispatch(SetDeskLocationInput(value)) },
      ),
      button(
        class="secondary-button compact-button",
        attrs=@html.Attrs::build().data_set("testid", "desk-location-go"),
        title="Open the typed Desk location",
        disabled=desk_workspace_action_disabled(model),
        on_click=dispatch(OpenDeskLocation),
        "Go",
      ),
    ]),
    div(class="desk-location-meta", [
      span(
        desk_entry_count_label_for_model(
          model,
          counts,
          visible_entries.length(),
        ),
      ),
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
  let class_name = desk_file_row_class(model, entry)
  let selected_value = if desk_entry_is_selected(model, entry.path) {
    "true"
  } else {
    "false"
  }
  let open_msg = if entry.kind is Directory {
    OpenDirectory(entry.path)
  } else {
    SelectPath(entry.path)
  }
  div(
    class=class_name,
    title=entry.path,
    attrs=@html.Attrs::build()
      .data_set("testid", "desk-file-row")
      .data_set("path", entry.path)
      .role("option")
      .aria_selected(selected_value)
      .on_mousedown(fn(event) {
        dispatch(desk_mouse_event_msg(entry.path, event))
      })
      .on_dblclick(fn(_) { dispatch(open_msg) }),
    [
      span(class="desk-file-name", [
        span(class="tree-icon", icon_for_kind(entry.kind)),
        if model.desk_rename_editing_path == entry.path {
          desk_inline_rename_input(dispatch, model, entry)
        } else {
          strong(entry.display_name)
        },
      ]),
      span(kind_label(entry.kind)),
      span(layer_label(entry.source_layer)),
      span(optional_text(entry.modified_at, "unknown")),
      span(size_label(entry.size_bytes)),
    ],
  )
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
  aside(
    class="desk-details",
    attrs=@html.Attrs::build().data_set("testid", "desk-details"),
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
                h3(entry.display_name),
              ]),
              info_row("Virtual Path", empty_root_path(entry.path)),
              info_row("Kind", kind_label(entry.kind)),
              info_row("Layer", layer_label(entry.source_layer)),
              info_row("Modified", optional_text(entry.modified_at, "unknown")),
              info_row("Size", size_label(entry.size_bytes)),
              info_row("Readable", yes_no(entry.readable)),
              info_row("Writable", yes_no(entry.writable)),
              render_desk_inline_preview(model),
              div(class="desk-detail-actions", [
                input(
                  class="line-input",
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
                p(class="status-line", model.desk_rename_status),
                input(
                  class="line-input",
                  value=model.desk_move_target_directory,
                  placeholder="Target directory",
                  on_input=fn(value) {
                    dispatch(SetDeskMoveTargetDirectory(value))
                  },
                ),
                button(
                  class="secondary-button full",
                  title="Move selected item to target directory",
                  on_click=dispatch(MoveDeskSelection),
                  "Move",
                ),
                p(class="status-line", model.desk_move_status),
                button(
                  class="secondary-button full",
                  title="Duplicate selected item in its current directory",
                  on_click=dispatch(DuplicateDeskSelection),
                  "Duplicate",
                ),
                p(class="status-line", model.desk_copy_status),
                button(
                  class="secondary-button full",
                  attrs=@html.Attrs::build().data_set(
                    "testid", "desk-copy-selection",
                  ),
                  title="Copy selected item to the Desk clipboard",
                  on_click=dispatch(CopyDeskSelection),
                  "Copy",
                ),
                button(
                  class="secondary-button full",
                  attrs=@html.Attrs::build().data_set(
                    "testid", "desk-cut-selection",
                  ),
                  title="Cut selected item to move it with Paste Here",
                  on_click=dispatch(CutDeskSelection),
                  "Cut",
                ),
                button(
                  class="secondary-button full",
                  attrs=@html.Attrs::build().data_set(
                    "testid", "desk-paste-clipboard",
                  ),
                  title="Paste copied items into the current directory",
                  disabled=desk_workspace_action_disabled(model),
                  on_click=dispatch(PasteDeskClipboard),
                  "Paste Here",
                ),
                p(class="status-line", model.desk_clipboard_status),
                button(
                  class=desk_favorite_button_class(model, entry.path),
                  attrs=@html.Attrs::build().data_set(
                    "testid", "desk-toggle-favorite",
                  ),
                  title="Add or remove selected path from Desk favorites",
                  on_click=dispatch(ToggleFavorite(entry.path)),
                  desk_favorite_button_label(model, entry.path),
                ),
                button(
                  class="secondary-button full",
                  attrs=@html.Attrs::build().data_set(
                    "testid", "desk-copy-path",
                  ),
                  title="Copy selected virtual path",
                  on_click=dispatch(CopyDeskPath),
                  "Copy Path",
                ),
                p(class="status-line", model.desk_path_status),
                button(
                  class="secondary-button full",
                  title="Move selected item to scoped MoonBook trash",
                  on_click=dispatch(TrashDeskSelection),
                  "Move to Trash",
                ),
                button(
                  class="secondary-button full",
                  title="Restore the most recently trashed item",
                  on_click=dispatch(RestoreLastTrashedDeskEntry),
                  "Restore Last",
                ),
                p(class="status-line", model.desk_trash_status),
                render_desk_trash_panel(dispatch, model),
                button(
                  class="secondary-button full",
                  attrs=@html.Attrs::build().data_set(
                    "testid", "desk-reveal-selection",
                  ),
                  title="Reveal selected item in the system file manager",
                  on_click=dispatch(RevealSelection),
                  "Reveal in File Manager",
                ),
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
                button(
                  class="secondary-button full",
                  on_click=dispatch(ClearDeskSelection),
                  "Clear Selection",
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
              info_row("Mode", "scoped file manager"),
              div(class="desk-detail-actions", [
                button(
                  class="secondary-button full",
                  attrs=@html.Attrs::build().data_set(
                    "testid", "desk-paste-clipboard",
                  ),
                  title="Paste copied items into the current directory",
                  disabled=desk_workspace_action_disabled(model),
                  on_click=dispatch(PasteDeskClipboard),
                  "Paste Here",
                ),
                p(class="status-line", model.desk_clipboard_status),
                button(
                  class="secondary-button full",
                  attrs=@html.Attrs::build().data_set(
                    "testid", "desk-copy-path",
                  ),
                  title="Copy current directory virtual path",
                  disabled=desk_workspace_action_disabled(model),
                  on_click=dispatch(CopyDeskPath),
                  "Copy Folder Path",
                ),
                p(class="status-line", model.desk_path_status),
                button(
                  class="secondary-button full",
                  attrs=@html.Attrs::build().data_set(
                    "testid", "desk-reveal-current-directory",
                  ),
                  title="Reveal current folder in the system file manager",
                  disabled=desk_workspace_action_disabled(model),
                  on_click=dispatch(RevealSelection),
                  "Reveal Folder",
                ),
                button(
                  class="secondary-button full",
                  title="Restore the most recently trashed item",
                  disabled=desk_workspace_action_disabled(model),
                  on_click=dispatch(RestoreLastTrashedDeskEntry),
                  "Restore Last",
                ),
                p(class="status-line", model.desk_trash_status),
                render_desk_trash_panel(dispatch, model),
              ]),
            ])
        }
      },
    ],
  )
}

///|
fn render_desk_inline_preview(model : Model) -> @rabbita.Html {
  section(
    class="desk-inline-preview",
    attrs=@html.Attrs::build().data_set("testid", "desk-preview"),
    match model.preview {
      Some(preview) =>
        match preview.renderer {
          Markdown
          | Text
          | Json
          | DirectoryListing
          | Unsupported
          | ArtifactSummary =>
            [
              strong(preview.title),
              pre(class="source-block compact", code(preview.body)),
            ]
          Image =>
            [strong(preview.title), img(src=preview.body, alt=preview.title)]
          Html =>
            [
              strong(preview.title),
              a(
                class="mini-link",
                href=html_preview_url(model, model.selected_path),
                target=Blank,
                "Open preview",
              ),
            ]
        }
      None => [p(class="status-line", model.preview_status)]
    },
  )
}

///|
fn render_desk_multi_selection_details(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="desk-detail-panel", [
    div(class="desk-detail-title", [
      span(class="tree-icon", "*"),
      h3("\{model.desk_selected_paths.length()} items selected"),
    ]),
    info_row("Focused", empty_root_path(model.selected_path)),
    info_row("Directory", empty_root_path(model.current_directory)),
    info_row("Selection", desk_multi_selection_count_label(model)),
    info_row("Total Size", desk_multi_selection_size_label(model)),
    info_row("Items", desk_selected_paths_summary(model)),
    div(class="desk-detail-actions", [
      input(
        class="line-input",
        value=model.desk_move_target_directory,
        placeholder="Target directory",
        on_input=fn(value) { dispatch(SetDeskMoveTargetDirectory(value)) },
      ),
      button(
        class="secondary-button full",
        title="Move selected items to target directory",
        on_click=dispatch(MoveDeskSelection),
        "Move",
      ),
      p(class="status-line", model.desk_move_status),
      button(
        class="secondary-button full",
        title="Duplicate selected items in their current directories",
        on_click=dispatch(DuplicateDeskSelection),
        "Duplicate",
      ),
      p(class="status-line", model.desk_copy_status),
      button(
        class="secondary-button full",
        attrs=@html.Attrs::build().data_set("testid", "desk-copy-selection"),
        title="Copy selected items to the Desk clipboard",
        on_click=dispatch(CopyDeskSelection),
        "Copy",
      ),
      button(
        class="secondary-button full",
        attrs=@html.Attrs::build().data_set("testid", "desk-cut-selection"),
        title="Cut selected items to move them with Paste Here",
        on_click=dispatch(CutDeskSelection),
        "Cut",
      ),
      button(
        class="secondary-button full",
        attrs=@html.Attrs::build().data_set("testid", "desk-paste-clipboard"),
        title="Paste copied items into the current directory",
        on_click=dispatch(PasteDeskClipboard),
        "Paste Here",
      ),
      p(class="status-line", model.desk_clipboard_status),
      button(
        class="secondary-button full",
        attrs=@html.Attrs::build().data_set("testid", "desk-copy-path"),
        title="Copy selected virtual paths",
        on_click=dispatch(CopyDeskPath),
        "Copy Paths",
      ),
      p(class="status-line", model.desk_path_status),
      button(
        class="secondary-button full",
        title="Move selected items to scoped MoonBook trash",
        on_click=dispatch(TrashDeskSelection),
        "Move to Trash",
      ),
      button(
        class="secondary-button full",
        title="Restore the most recently trashed item",
        on_click=dispatch(RestoreLastTrashedDeskEntry),
        "Restore Last",
      ),
      p(class="status-line", model.desk_trash_status),
      render_desk_trash_panel(dispatch, model),
      button(
        class="secondary-button full",
        attrs=@html.Attrs::build().data_set("testid", "desk-reveal-selection"),
        on_click=dispatch(RevealSelection),
        "Reveal Focused",
      ),
      button(
        class="secondary-button full",
        on_click=dispatch(ClearDeskSelection),
        "Clear Selection",
      ),
    ]),
  ])
}

///|
fn desk_favorite_button_class(model : Model, path : String) -> String {
  if has_string(model.favorites, path) {
    "secondary-button full active"
  } else {
    "secondary-button full"
  }
}

///|
fn desk_favorite_button_label(model : Model, path : String) -> String {
  if has_string(model.favorites, path) {
    "Remove Favorite"
  } else {
    "Add Favorite"
  }
}

///|
fn desk_multi_selection_count_label(model : Model) -> String {
  let entries = desk_selected_entries(model)
  if entries.length() == 0 {
    "\{model.desk_selected_paths.length()} selected"
  } else {
    desk_entry_count_label(desk_entry_counts(entries))
  }
}

///|
fn desk_multi_selection_size_label(model : Model) -> String {
  let entries = desk_selected_entries(model)
  let mut known = 0
  let mut total = 0
  for entry in entries {
    match entry.size_bytes {
      Some(bytes) => {
        known += 1
        total += bytes
      }
      None => ()
    }
  }
  if known == 0 {
    "-"
  } else if known == entries.length() {
    size_label(Some(total))
  } else {
    size_label(Some(total)) + " known"
  }
}

///|
fn desk_selected_entries(model : Model) -> Array[@desk.DeskFileEntry] {
  let entries : Array[@desk.DeskFileEntry] = []
  for path in model.desk_selected_paths {
    match find_entry(model, path) {
      Some(entry) => entries.push(entry)
      None => ()
    }
  }
  entries
}

///|
fn render_desk_trash_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(
    class="desk-trash-panel",
    attrs=@html.Attrs::build().data_set("testid", "desk-trash-panel"),
    [
      strong("Trash"),
      if model.desk_trash_entries.length() == 0 {
        p(class="status-line", "Trash is empty")
      } else {
        div(
          class="desk-trash-list",
          model.desk_trash_entries.map(entry => {
            button(
              class="desk-trash-row",
              attrs=@html.Attrs::build()
                .data_set("testid", "desk-trash-row")
                .data_set("workspace-id", entry.workspace_id)
                .data_set("trash-path", entry.trash_path)
                .data_set("receipt-path", entry.receipt_path)
                .data_set("original-path", entry.original_path),
              title="Restore " + entry.original_path,
              on_click=dispatch(RestoreDeskTrashEntry(entry.trash_path)),
              [span(entry.original_path), small(entry.trashed_at)],
            )
          }),
        )
      },
    ],
  )
}

///|
fn desk_selected_paths_summary(model : Model) -> String {
  let limit = if model.desk_selected_paths.length() < 4 {
    model.desk_selected_paths.length()
  } else {
    4
  }
  let parts : Array[String] = []
  for index in 0..<limit {
    parts.push(empty_root_path(model.desk_selected_paths[index]))
  }
  if model.desk_selected_paths.length() > limit {
    parts.push("+\{model.desk_selected_paths.length() - limit} more")
  }
  parts.join(", ")
}

///|
fn selected_desk_entry(model : Model) -> @desk.DeskFileEntry? {
  find_entry(model, model.selected_path)
}

///|
fn desk_entry_counts(entries : Array[@desk.DeskFileEntry]) -> (Int, Int, Int) {
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
  "\{count_noun(total, "item")}, \{count_noun(directories, "folder")}, \{count_noun(files, "file")}"
}

///|
fn count_noun(count : Int, noun : String) -> String {
  if count == 1 {
    "\{count} \{noun}"
  } else {
    "\{count} \{noun}s"
  }
}

///|
fn desk_entry_count_label_for_model(
  model : Model,
  counts : (Int, Int, Int),
  visible_count : Int,
) -> String {
  if model.desk_filter_query.trim().to_owned() == "" {
    desk_entry_count_label(counts)
  } else {
    "\{visible_count} of \{model.entries.length()} shown"
  }
}

///|
fn desk_selection_label(model : Model) -> String {
  if model.desk_selected_paths.length() > 1 {
    "\{model.desk_selected_paths.length()} selected"
  } else if model.selected_path == "" {
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
    "MoonBook Root"
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
    Some(size) if size >= 1024 * 1024 => "\{size / (1024 * 1024)} MB"
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
