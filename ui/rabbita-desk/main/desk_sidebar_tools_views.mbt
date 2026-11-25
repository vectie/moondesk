///|
fn render_desk_quick_access(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let groups : Array[@rabbita.Html] = []
  let recent_paths = model.recent_paths.filter(path => {
    !model.favorites.contains(path)
  })
  if model.favorites.length() > 0 {
    groups.push(
      render_desk_quick_path_group(
        dispatch,
        model,
        "Favorites",
        "desk-favorite-row",
        model.favorites,
      ),
    )
  }
  if recent_paths.length() > 0 {
    groups.push(
      render_desk_quick_path_group(
        dispatch, model, "Recent", "desk-recent-row", recent_paths,
      ),
    )
  }
  if groups.is_empty() {
    groups.push(
      p(
        class="status-line",
        attrs=@html.Attrs::build().data_set("testid", "desk-quick-access-empty"),
        "No favorites or recent files yet.",
      ),
    )
  }
  section(
    class="desk-quick-access",
    attrs=@html.Attrs::build().data_set("testid", "desk-quick-access"),
    [
      div(class="pane-heading compact-heading", [div([h2("Quick Access")])]),
      div(class="desk-quick-groups", groups),
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
    div(
      class="desk-quick-list",
      paths.map(path => {
        button(
          class=desk_quick_path_row_class(model, path),
          title=path,
          attrs=@html.Attrs::build()
            .data_set("testid", testid)
            .data_set("path", path),
          on_click=dispatch(
            OpenDeskQuickPath(desk_quick_access_scope(model), path),
          ),
          [
            span(class="tree-icon", icon_for_kind(quick_path_kind(model, path))),
            span(class="folder-label", empty_root_path(path)),
          ],
        )
      }),
    ),
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
fn render_desk_library_location(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(
    class="desk-library-location",
    attrs=@html.Attrs::build().data_set("testid", "desk-library-root"),
    [
      div(class="desk-library-summary", [
        div([p(class="eyebrow", "Library"), strong("My MoonBooks")]),
        span(class="desk-library-count", workspace_library_count_label(model)),
      ]),
      render_desk_library_diagnostics(dispatch, model),
    ],
  )
}

///|
fn render_desk_library_diagnostics(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  desk_disclosure(
    "desk-library-diagnostics",
    "desk-library-storage-details",
    "Storage & services",
    [
      div(class="desk-technical-list", [
        info_row("Library", workspace_moonbook_library_path(model)),
        info_row("Suite", workspace_library_root(model)),
      ]),
      button(
        class="secondary-button compact-button",
        attrs=@html.Attrs::build().data_set(
          "testid", "desk-change-library-folder",
        ),
        title="Choose a different MoonBook library folder",
        on_click=dispatch(PickLibraryFolder),
        "Change library folder",
      ),
      p(
        class="status-line",
        attrs=@html.Attrs::build().data_set(
          "testid", "desk-library-selection-status",
        ),
        model.host_status,
      ),
      render_desk_service_status(model),
      render_desk_product_summary(model),
    ],
  )
}

///|
fn desk_disclosure(
  class_name : String,
  testid : String,
  label : String,
  children : Array[@rabbita.Html],
) -> @rabbita.Html {
  desk_disclosure_with_open(class_name, testid, label, false, children)
}

///|
fn desk_disclosure_with_open(
  class_name : String,
  testid : String,
  label : String,
  open : Bool,
  children : Array[@rabbita.Html],
) -> @rabbita.Html {
  let menu_icon = match testid {
    "desk-new-menu" => "plus"
    "desk-import-menu" => "upload"
    "desk-view-options" => "eye"
    "desk-go-to-folder" => "folder"
    _ => ""
  }
  @html.node(
    "details",
    @html.Attrs::build().class(class_name).data_set("testid", testid).open(open),
    [
      @html.node(
        "summary",
        @html.Attrs::build().class("desk-disclosure-summary"),
        if menu_icon == "" {
          [span(label)]
        } else {
          [ui_icon(menu_icon), span(label), ui_icon("chevron-down")]
        },
      ),
      div(class="desk-disclosure-body", children),
    ],
  )
}

///|
fn render_desk_service_status(model : Model) -> @rabbita.Html {
  section(
    class="desk-service-status",
    attrs=@html.Attrs::build().data_set("testid", "desk-service-status"),
    [
      strong(class="desk-technical-heading", "Services"),
      div(
        class="desk-service-list",
        workspace_service_status_items(model).map(item => {
          let (name, status, detail) = item
          div(
            class="desk-service-row status-" + status,
            attrs=@html.Attrs::build()
              .data_set("testid", "desk-service-row")
              .data_set("service", name)
              .data_set("status", status),
            [
              span(class="status-dot " + service_status_dot_class(status), ""),
              strong(name),
              small(detail),
            ],
          )
        }),
      ),
    ],
  )
}

///|
fn service_status_dot_class(status : String) -> String {
  match status {
    "ready" => "live"
    "missing" => "idle"
    _ => "idle"
  }
}

///|
fn render_desk_product_summary(model : Model) -> @rabbita.Html {
  let products = workspace_display_products(model)
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
            title=workspace_product_chip_title(product),
            [
              span(class="status-dot live", ""),
              span(product.name),
              small(workspace_product_status_label(product)),
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
  render_new_moonbook_panel_with_open(dispatch, model, false)
}

///|
fn render_new_moonbook_panel_open(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  render_new_moonbook_panel_with_open(dispatch, model, true)
}

///|
fn render_new_moonbook_panel_with_open(
  dispatch : Dispatch[Msg],
  model : Model,
  open : Bool,
) -> @rabbita.Html {
  desk_disclosure_with_open(
    "desk-add-book-disclosure",
    "desk-add-moonbook",
    "Add MoonBook",
    open,
    [
      section(class="desk-new-book-panel", [
        div(class="desk-library-action", [
          strong("Create new"),
          input(
            class="line-input",
            attrs=@html.Attrs::build()
              .data_set("testid", "desk-new-book-name")
              .aria_label("MoonBook name"),
            value=model.new_book_name,
            placeholder="MoonBook name",
            on_input=fn(value) { dispatch(SetNewBookName(value)) },
          ),
          input(
            class="line-input",
            attrs=@html.Attrs::build()
              .data_set("testid", "desk-new-book-id")
              .aria_label("Optional folder name"),
            value=model.new_book_id,
            placeholder="Optional folder name",
            on_input=fn(value) { dispatch(SetNewBookId(value)) },
          ),
          button(
            class="primary-button full",
            attrs=@html.Attrs::build().data_set("testid", "desk-create-book"),
            title="Create MoonBook",
            disabled=desk_create_book_disabled(model),
            on_click=dispatch(CreateBlankMoonBook),
            "Create MoonBook",
          ),
          render_desk_operation_status("status-line", model.new_book_status),
        ]),
        div(class="desk-library-action", [
          strong("Import existing"),
          button(
            class="secondary-button full",
            attrs=@html.Attrs::build().data_set(
              "testid", "desk-import-book-folder",
            ),
            title="Choose a MoonBook folder",
            on_click=dispatch(PickImportMoonBookFolder),
            "Choose Folder",
          ),
          button(
            class="secondary-button full",
            attrs=@html.Attrs::build().data_set(
              "testid", "desk-import-book-archive",
            ),
            title="Choose a zipped MoonBook archive",
            on_click=dispatch(PickImportMoonBookArchive),
            "Choose Archive",
          ),
          desk_disclosure(
            "desk-advanced-import",
            "desk-import-from-path",
            "Import from path",
            [
              input(
                class="line-input",
                attrs=@html.Attrs::build().data_set(
                  "testid", "desk-import-book-path",
                ),
                value=model.import_book_path,
                placeholder="Folder path",
                on_input=fn(value) { dispatch(SetImportBookPath(value)) },
              ),
              button(
                class="secondary-button full",
                attrs=@html.Attrs::build().data_set(
                  "testid", "desk-import-book",
                ),
                title="Import a MoonBook from a folder path",
                disabled=desk_import_book_disabled(model),
                on_click=dispatch(ImportMoonBook),
                "Import Path",
              ),
            ],
          ),
          render_desk_operation_status("status-line", model.import_book_status),
        ]),
        render_agent_import(dispatch, model),
      ]),
    ],
  )
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
  let visible_entries = filtered_desk_entries(model)
  section(class="desk-folder-outline", [
    div(class="pane-heading compact-heading", [div([h2("Directory")])]),
    div(
      class="desk-folder-list",
      attrs=@html.Attrs::build().data_set("testid", "desk-folder-list"),
      desk_folder_outline(model.current_directory, visible_entries).map(item => {
        let (label, path, active, depth) = item
        button(
          class=desk_folder_outline_row_class(active, depth),
          attrs=@html.Attrs::build().data_set("i18n-preserve", "title"),
          title=empty_root_path(path),
          on_click=dispatch(OpenDirectory(path)),
          [
            span(class="folder-indent", ""),
            ui_icon("folder"),
            span(
              class="folder-label",
              attrs=desk_name_attrs(
                desk_outline_label_i18n_key(label, path, visible_entries),
              ),
              label,
            ),
          ],
        )
      }),
    ),
  ])
}
