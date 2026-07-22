///|
fn render_files_pane(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  let directory = if model.current_directory == "" {
    "wiki"
  } else {
    model.current_directory
  }
  aside(class="activity-pane user-pane", [
    div(class="pane-heading", [
      div([h2("Wiki")]),
      button(
        class="secondary-button compact-button",
        title="Refresh",
        on_click=dispatch(RefreshAll),
        "Refresh",
      ),
    ]),
    render_wiki_book_switcher(dispatch, model),
    button(
      class="primary-button full wiki-new-note",
      attrs=@html.Attrs::build().data_set("testid", "wiki-new-note"),
      title="Capture a note in this book's inbox",
      on_click=dispatch(SelectActivity(Inbox)),
      "+ New note",
    ),
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
        class=if directory == "wiki" && model.current_directory != "" {
          "section-pill active"
        } else {
          "section-pill"
        },
        on_click=dispatch(OpenDirectory("wiki")),
        "Pages",
      ),
      button(
        class=if directory == "raw" {
          "section-pill active"
        } else {
          "section-pill"
        },
        on_click=dispatch(OpenDirectory("raw")),
        "Sources",
      ),
      button(
        class=if directory == "inbox" {
          "section-pill active"
        } else {
          "section-pill"
        },
        on_click=dispatch(OpenDirectory("inbox")),
        "Inbox",
      ),
      button(
        class=if directory == "book/site/generated" {
          "section-pill active"
        } else {
          "section-pill"
        },
        on_click=dispatch(OpenDirectory("book/site/generated")),
        "Published",
      ),
    ]),
    if model.current_directory == "" {
      render_wiki_book_home(dispatch, model)
    } else {
      render_tree(dispatch, model)
    },
  ])
}

///|
fn render_wiki_book_home(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let cards : Array[(String, String, String, String)] = [
    ("wiki", "Pages", "Notes and documents written for people", "wiki"),
    ("raw", "Sources", "Original material and evidence", "raw"),
    ("inbox", "Inbox", "Draft notes waiting to be organized", "inbox"),
    (
      "book/site/generated", "Published", "The generated site for this book", "book/site/generated",
    ),
  ]
  div(
    class="wiki-book-home",
    cards.map(card => {
      let (_, title, detail, directory) = card
      button(
        class="wiki-home-card",
        on_click=dispatch(OpenDirectory(directory)),
        [strong(title), small(detail)],
      )
    }),
  )
}

///|
fn render_wiki_book_switcher(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  div(class="workspace-stack wiki-book-switcher", [
    span(class="wiki-book-switcher-label", "MoonBook"),
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
            span(
              class="status-dot " +
                (if workspace.id == model.selected_workspace_id {
                  "live"
                } else {
                  "idle"
                }),
              "",
            ),
            span(workspace.name),
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
      p(class="eyebrow", "MoonDesk"),
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
    ],
  )
}

///|
fn render_tree(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  let entries = wiki_library_entries(model)
  if entries.length() == 0 {
    div(class="empty-state wiki-library-empty", [
      strong(
        if wiki_book_is_empty(model) {
          "This book is empty"
        } else {
          "Nothing here yet"
        },
      ),
      p(
        if wiki_book_is_empty(model) {
          "Capture a first note to begin building this book."
        } else {
          "Choose another section or add a note."
        },
      ),
      button(
        class="primary-button full",
        on_click=dispatch(SelectActivity(Inbox)),
        "Create first note",
      ),
    ])
  } else {
    ul(
      class="tree-list",
      entries.map(entry => {
        let selected = entry.path == model.selected_path
        let class_name = if selected { "tree-row selected" } else { "tree-row" }
        li(class=class_name, on_click=dispatch(SelectPath(entry.path)), [
          span(class="tree-indent depth-0", ""),
          span(class="tree-label", entry.display_name),
        ])
      }),
    )
  }
}

///|
fn wiki_book_is_empty(model : Model) -> Bool {
  let preview_unavailable = match model.preview {
    None => model.preview_status.to_lower().contains("not available")
    Some(_) => false
  }
  model.selected_workspace_id != "" &&
  model.entries.length() == 0 &&
  model.host_status == "workspace indexed" &&
  preview_unavailable
}

///|
fn wiki_library_entries(model : Model) -> Array[@desk.DeskFileEntry] {
  if model.current_directory != "" {
    model.entries
  } else {
    model.entries.filter(entry => wiki_library_overview_path_visible(entry.path))
  }
}

///|
fn wiki_library_overview_path_visible(path : String) -> Bool {
  path == "wiki" ||
  path == "raw" ||
  path == "inbox" ||
  path == "book/site/generated"
}
