///|
fn render_desk_file_browser(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let visible_entries = sorted_desk_entries(model)
  section(class="desk-browser", [
    div(class="desk-browser-head", [
      div(class="desk-browser-title", [
        div(class="desk-browser-location", [
          if model.selected_workspace_id == "" {
            span(class="desk-browser-workspace-empty", "")
          } else {
            small(class="desk-browser-workspace", workspace_name(model))
          },
          h2(
            attrs=@html.Attrs::build().data_set(
              "i18n-scope",
              if model.current_directory == "" {
                "interface"
              } else {
                "content"
              },
            ),
            desk_directory_title(model.current_directory),
          ),
        ]),
        button(
          class="secondary-button compact-button moon-icon-button",
          attrs=@html.Attrs::build()
            .aria_label("Refresh this folder")
            .data_set("testid", "desk-refresh"),
          title="Refresh this folder",
          on_click=dispatch(RefreshAll),
          [ui_icon("refresh")],
        ),
        details(
          class="desk-inspector",
          attrs=@html.Attrs::build().data_set("popup", "desk-inspector"),
          [
            summary(
              class="moon-icon-button",
              attrs=@html.Attrs::build().aria_label("Selection details"),
              [ui_icon("panel-right")],
            ),
            render_desk_details(dispatch, model),
          ],
        ),
      ]),
      if model.selected_workspace_id == "" {
        @html.nothing
      } else {
        div(class="toolbar-actions", [
          div(class="desk-navigation-actions", [
            button(
              class="secondary-button compact-button moon-icon-button",
              attrs=@html.Attrs::build()
                .aria_label("Back")
                .data_set("testid", "desk-back"),
              title="Back",
              disabled=desk_workspace_action_disabled(model) ||
                model.desk_back_stack.length() == 0,
              on_click=dispatch(NavigateDeskBack),
              [ui_icon("chevron-left")],
            ),
            button(
              class="secondary-button compact-button moon-icon-button",
              attrs=@html.Attrs::build()
                .aria_label("Forward")
                .data_set("testid", "desk-forward"),
              title="Forward",
              disabled=desk_workspace_action_disabled(model) ||
                model.desk_forward_stack.length() == 0,
              on_click=dispatch(NavigateDeskForward),
              [ui_icon("chevron-right")],
            ),
            button(
              class="secondary-button compact-button moon-icon-button",
              attrs=@html.Attrs::build()
                .aria_label("Open parent folder")
                .data_set("testid", "desk-up"),
              title="Open parent folder",
              disabled=desk_workspace_action_disabled(model) ||
                model.current_directory == "",
              on_click=dispatch(
                OpenDirectory(parent_path(model.current_directory)),
              ),
              [ui_icon("chevron-up")],
            ),
            button(
              class="secondary-button compact-button moon-icon-button",
              attrs=@html.Attrs::build()
                .aria_label("Open MoonBook home")
                .data_set("testid", "desk-root"),
              title="Open MoonBook home",
              disabled=desk_workspace_action_disabled(model) ||
                model.current_directory == "",
              on_click=dispatch(OpenDirectory("")),
              [ui_icon("home")],
            ),
          ]),
          div(class="desk-folder-search", [
            ui_icon("search"),
            input(
              class="line-input compact-input desk-filter-input",
              attrs=@html.Attrs::build()
                .data_set("testid", "desk-filter-query")
                .aria_label("Search this folder")
                .disabled(desk_workspace_action_disabled(model)),
              value=model.desk_filter_query,
              placeholder="Search this folder",
              on_input=fn(value) { dispatch(SetDeskFilterQuery(value)) },
            ),
            button(
              class="secondary-button compact-button moon-icon-button",
              attrs=@html.Attrs::build()
                .aria_label("Clear folder search")
                .data_set("testid", "desk-clear-filter"),
              title="Clear folder search",
              disabled=desk_workspace_action_disabled(model) ||
                model.desk_filter_query.trim().to_owned() == "",
              on_click=dispatch(SetDeskFilterQuery("")),
              [ui_icon("close")],
            ),
          ]),
          render_desk_new_item_disclosure(dispatch, model),
          render_desk_import_disclosure(dispatch, model),
          desk_disclosure(
            "desk-toolbar-disclosure desk-view-disclosure",
            "desk-view-options",
            "View",
            [
              render_desk_density_control(dispatch, model),
              button(
                class="secondary-button compact-button",
                attrs=@html.Attrs::build().data_set(
                  "testid", "desk-sort-source-area",
                ),
                title="Sort by source area",
                on_click=dispatch(SetDeskSort(SortByLayer)),
                "Sort by source area",
              ),
              render_desk_hidden_toggle(dispatch, model),
            ],
          ),
        ])
      },
    ]),
    if model.selected_workspace_id == "" {
      @html.nothing
    } else {
      @html.fragment([
        render_desk_breadcrumb(dispatch, model.current_directory),
        render_desk_location_bar(dispatch, model),
      ])
    },
    render_desk_operation_status(
      "desk-create-status",
      model.desk_new_item_status,
    ),
    div(class=desk_file_table_class(model), [
      if model.selected_workspace_id == "" {
        @html.nothing
      } else {
        div(class="desk-file-row desk-file-header", [
          desk_sort_header_button(dispatch, model, SortByName, "Name"),
          desk_sort_header_button(dispatch, model, SortByKind, "Type"),
          desk_sort_header_button(dispatch, model, SortByModified, "Modified"),
          desk_sort_header_button(dispatch, model, SortBySize, "Size"),
        ])
      },
      div(
        class="desk-file-rows",
        attrs=@html.Attrs::build()
          .data_set("testid", "desk-file-list")
          .tabindex(0)
          .role("listbox")
          .aria_label("Desk file list")
          .aria_multiselectable("true"),
        on_keydown=fn(keyboard) { dispatch(desk_keyboard_msg(keyboard)) },
        render_desk_file_rows(dispatch, model, visible_entries),
      ),
    ]),
  ])
}

///|
fn render_desk_file_rows(
  dispatch : Dispatch[Msg],
  model : Model,
  visible_entries : Array[@desk.DeskFileEntry],
) -> Array[@rabbita.Html] {
  let rows : Array[@rabbita.Html] = []
  match model.desk_entries_state {
    Some(state) => {
      rows.push(render_desk_entries_state_panel(dispatch, model, state))
      if (state is Loading || state is Stale) && !visible_entries.is_empty() {
        for entry in visible_entries {
          rows.push(render_desk_file_row(dispatch, model, entry))
        }
      }
    }
    None =>
      if model.entries.is_empty() {
        rows.push(
          render_desk_entries_state_panel(dispatch, model, RecoverableError),
        )
      } else if visible_entries.is_empty() {
        rows.push(
          div(class="desk-empty", [
            strong("No matching files"),
            p("Clear the filter to show all items in this folder."),
          ]),
        )
      } else {
        for entry in visible_entries {
          rows.push(render_desk_file_row(dispatch, model, entry))
        }
      }
  }
  rows
}

///|
fn render_desk_entries_state_panel(
  dispatch : Dispatch[Msg],
  model : Model,
  state : SurfaceState,
) -> @rabbita.Html {
  let children : Array[@rabbita.Html] = if state is LegitimateZero {
    [
      div(attrs=@html.Attrs::build().data_set("testid", "desk-empty-folder"), [
        render_polite_state_announcement(
          "desk-entries-state-announcement",
          desk_entries_state_title(state, model),
          desk_entries_state_detail(state, model),
        ),
        strong("This folder is empty"),
        p("Create a note or import files to get started."),
      ]),
    ]
  } else {
    [
      render_polite_state_announcement(
        "desk-entries-state-announcement",
        desk_entries_state_title(state, model),
        desk_entries_state_detail(state, model),
      ),
    ]
  }
  match desk_entries_state_action(state) {
    Some(label) =>
      children.push(
        button(
          class="secondary-button compact-button",
          attrs=@html.Attrs::build().data_set(
            "testid", "desk-entries-state-action",
          ),
          on_click=dispatch(RefreshAll),
          label,
        ),
      )
    None => ()
  }
  if desk_entries_state_shows_technical_detail(state) &&
    model.desk_entries_error != "" {
    children.push(
      details(class="desk-state-technical", [
        summary("Technical details"),
        code(model.desk_entries_error),
      ]),
    )
  }
  div(
    class="desk-empty desk-entries-state",
    attrs=@html.Attrs::build()
      .data_set("testid", "desk-entries-state-panel")
      .data_set("state", desk_entries_state_key(state)),
    children,
  )
}

///|
fn render_desk_new_item_disclosure(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  desk_disclosure("desk-toolbar-disclosure", "desk-new-menu", "New", [
    input(
      class="line-input compact-input",
      attrs=@html.Attrs::build()
        .data_set("testid", "desk-new-item-name")
        .aria_label("New item name")
        .disabled(desk_workspace_action_disabled(model)),
      value=model.desk_new_item_name,
      placeholder="Name",
      on_input=fn(value) { dispatch(SetDeskNewItemName(value)) },
    ),
    div(class="desk-disclosure-actions", [
      button(
        class="secondary-button compact-button",
        attrs=@html.Attrs::build().data_set("testid", "desk-new-folder"),
        title="Create folder here",
        disabled=desk_workspace_action_disabled(model),
        on_click=dispatch(CreateDeskFolder),
        [ui_icon("folder"), span("Folder")],
      ),
      button(
        class="secondary-button compact-button",
        attrs=@html.Attrs::build().data_set("testid", "desk-new-note"),
        title="Create Markdown note here",
        disabled=desk_workspace_action_disabled(model),
        on_click=dispatch(CreateDeskMarkdown),
        [ui_icon("files"), span("Note")],
      ),
    ]),
  ])
}

///|
fn render_desk_import_disclosure(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  desk_disclosure("desk-toolbar-disclosure", "desk-import-menu", "Import", [
    button(
      class="secondary-button compact-button",
      attrs=@html.Attrs::build().data_set("testid", "desk-import-files"),
      title="Import files here",
      disabled=desk_workspace_action_disabled(model),
      on_click=dispatch(ImportLocalFilesToDesk),
      [ui_icon("files"), span("Files")],
    ),
    button(
      class="secondary-button compact-button",
      attrs=@html.Attrs::build().data_set("testid", "desk-import-folder"),
      title="Import a folder here",
      disabled=desk_workspace_action_disabled(model),
      on_click=dispatch(ImportLocalFolderToDesk),
      [ui_icon("folder"), span("Folder")],
    ),
  ])
}

///|
fn render_desk_operation_status(
  class_name : String,
  status : String,
) -> @rabbita.Html {
  if status == "" || status.has_prefix("ready to ") {
    span(class="desk-status-empty", "")
  } else {
    p(
      class=class_name,
      attrs=@html.Attrs::build().role("status").aria_live("polite"),
      status,
    )
  }
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
fn render_desk_hidden_toggle(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let hidden_count = desk_hidden_entry_count(model)
  button(
    class="secondary-button compact-button",
    attrs=@html.Attrs::build()
      .data_set("testid", "desk-toggle-hidden")
      .aria_pressed(if model.desk_show_hidden { "true" } else { "false" }),
    title=if model.desk_show_hidden {
      "Hide hidden files and dot folders"
    } else {
      "Show hidden files and dot folders"
    },
    on_click=dispatch(ToggleDeskShowHidden),
    [
      span(
        attrs=@html.Attrs::build().data_set(
          "i18n",
          if model.desk_show_hidden {
            "desk.hide_hidden_files"
          } else {
            "desk.show_hidden_files"
          },
        ),
        if model.desk_show_hidden {
          "Hide hidden files"
        } else {
          "Show hidden files"
        },
      ),
      if hidden_count > 0 {
        span(class="desk-hidden-count", " (\{hidden_count})")
      } else {
        @html.nothing
      },
    ],
  )
}

///|
fn desk_is_hidden_entry(entry : @desk.DeskFileEntry) -> Bool {
  if entry.display_name.has_prefix(".") {
    return true
  }
  for part in entry.path.split("/") {
    if part.has_prefix(".") {
      return true
    }
  }
  false
}

///|
fn desk_hidden_entry_count(model : Model) -> Int {
  let mut count = 0
  for entry in model.entries {
    if desk_is_hidden_entry(entry) {
      count = count + 1
    }
  }
  count
}

///|
fn sorted_desk_entries(model : Model) -> Array[@desk.DeskFileEntry] {
  let sorted = filtered_desk_entries(model).copy()
  sorted.sort_by((left, right) => desk_entry_compare(left, right, model))
  sorted
}

///|
fn filtered_desk_entries(model : Model) -> Array[@desk.DeskFileEntry] {
  let visible = if model.desk_show_hidden {
    model.entries
  } else {
    model.entries.filter(entry => !desk_is_hidden_entry(entry))
  }
  let query = model.desk_filter_query.trim().to_owned().to_lower()
  if query == "" {
    visible
  } else {
    visible.filter(entry => desk_entry_matches_filter(entry, query))
  }
}

