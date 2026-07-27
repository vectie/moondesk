///|
fn render_command_palette(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  if !model.command_open {
    @html.nothing
  } else {
    div(class="palette-backdrop", [
      div(
        class="command-palette",
        attrs=@html.Attrs::build()
          .role("dialog")
          .aria_modal("true")
          .aria_label("Commands")
          .data_set("testid", "command-palette-panel"),
        [
          div(class="palette-head", [
            input(
              class="palette-input",
              attrs=@html.Attrs::build()
                .aria_label("Search commands")
                .data_set("testid", "command-palette-input"),
              value=model.command_query,
              placeholder="Open Book, Import Files, Search, Submit...",
              on_input=fn(value) { dispatch(SetCommandQuery(value)) },
            ),
            button(
              class="icon-button palette-close",
              title="Close command palette",
              attrs=@html.Attrs::build()
                .aria_label("Close command palette")
                .data_set("testid", "command-palette-close"),
              on_click=dispatch(ToggleCommand),
              span(attrs=@html.Attrs::build().aria_hidden("true"), "X"),
            ),
          ]),
          div(
            class="palette-list",
            filtered_palette_commands_for_mode(
              model.workspace_mode,
              model.command_query,
            ).map(command => {
              let (title, detail, msg) = command
              palette_command(dispatch, title, detail, msg)
            }),
          ),
        ],
      ),
    ])
  }
}

///|
fn filtered_palette_commands_for_mode(
  mode : WorkspaceMode,
  query : String,
) -> Array[(String, String, Msg)] {
  let trimmed = query.trim().to_owned()
  if trimmed == "" {
    palette_commands_for_mode(mode)
  } else {
    let needle = trimmed.to_lower()
    palette_commands_for_mode(mode).filter(command => {
      let (title, detail, _) = command
      title.to_lower().contains(needle) ||
      palette_detail_matches(detail, needle)
    })
  }
}

///|
fn palette_detail_matches(detail : String, needle : String) -> Bool {
  let text = detail.to_lower()
  text.has_prefix(needle) ||
  text.contains(" " + needle) ||
  text.contains("-" + needle) ||
  text.contains("/" + needle)
}

///|
fn palette_commands_for_mode(
  mode : WorkspaceMode,
) -> Array[(String, String, Msg)] {
  let commands = primary_palette_commands()
  for command in secondary_tool_palette_commands() {
    commands.push(command)
  }
  for command in secondary_palette_commands_for_mode(mode) {
    if !shared_palette_command_title(command.0) {
      commands.push(command)
    }
  }
  commands
}

///|
fn primary_palette_commands() -> Array[(String, String, Msg)] {
  [
    ("Open Desk", "Browse books and outputs", SelectWorkspaceMode(Desk)),
    (
      "Open Wiki",
      "Read and organize the selected book",
      SelectWorkspaceMode(MoonWiki),
    ),
    (
      "Open Code",
      "Work with code in the selected book",
      SelectWorkspaceMode(MoonCode),
    ),
    (
      "Open Flow",
      "Track outcomes, blockers, evidence, and next actions",
      SelectWorkspaceMode(MoonFlow),
    ),
    (
      "Open Packs",
      "Launch installed domain applications",
      SelectWorkspaceMode(PackHome),
    ),
  ]
}

///|
fn secondary_tool_palette_commands() -> Array[(String, String, Msg)] {
  [
    (
      "Open Requests",
      "Open the Requests tab under Wiki",
      SelectWorkspaceMode(RequestsWorkspace),
    ),
    (
      "Open Runs",
      "Open the Runs tab under Wiki",
      SelectWorkspaceMode(RunsWorkspace),
    ),
    (
      "Open Review",
      "Open the Review tab under Wiki",
      SelectWorkspaceMode(ReviewWorkspace),
    ),
    (
      "Open Publish",
      "Open the Publish tab under Wiki",
      SelectWorkspaceMode(PublishWorkspace),
    ),
  ]
}

///|
fn shared_palette_command_title(title : String) -> Bool {
  title == "Open Desk" ||
  title == "Browse Desk" ||
  title == "Open Wiki" ||
  title == "Open Code" ||
  title == "Open Requests" ||
  title == "Open Runs" ||
  title == "Open Review" ||
  title == "Open Publish" ||
  title == "Open Flow" ||
  title == "Open Packs"
}

///|
fn secondary_palette_commands_for_mode(
  mode : WorkspaceMode,
) -> Array[(String, String, Msg)] {
  match mode {
    RequestsWorkspace | RunsWorkspace | ReviewWorkspace | PublishWorkspace => []
    PackHome =>
      [
        (
          "Open Packs",
          "Launch installed domain applications",
          SelectWorkspaceMode(PackHome),
        ),
        (
          "Open Flow",
          "See the selected MoonBook's executable product graph",
          SelectWorkspaceMode(MoonFlow),
        ),
        (
          "Browse Desk",
          "Open MoonBooks and pack-owned artifacts",
          SelectWorkspaceMode(Desk),
        ),
      ]
    Desk =>
      [
        (
          "Open Packs",
          "Launch installed domain applications",
          SelectWorkspaceMode(PackHome),
        ),
        (
          "Browse Desk",
          "Open the virtual filesystem for MoonBooks",
          SelectWorkspaceMode(Desk),
        ),
        (
          "Open Wiki",
          "Open pages for the selected book",
          SelectWorkspaceMode(MoonWiki),
        ),
        (
          "Open Code",
          "Open code assistance for the selected book",
          SelectWorkspaceMode(MoonCode),
        ),
        (
          "Open Flow",
          "Track outcomes, blockers, evidence, and next actions",
          SelectWorkspaceMode(MoonFlow),
        ),
      ]
    MoonWiki =>
      [
        ("Open Pages", "Read pages in the current book", SelectActivity(Files)),
        (
          "Search Books",
          "Find pages, notes, and sources",
          SelectActivity(Search),
        ),
        (
          "New Inbox Note",
          "Capture a note in the current book",
          SelectActivity(Inbox),
        ),
        ("Open Requests", "See tasks and their results", SelectActivity(Town)),
        (
          "Open Review",
          "Review proposed knowledge changes",
          SelectActivity(Runs),
        ),
        (
          "Open Settings",
          "Open automations, saved views, and diagnostics",
          SelectActivity(Settings),
        ),
        (
          "Open Code",
          "Open a book-scoped coding session",
          SelectWorkspaceMode(MoonCode),
        ),
        (
          "Open Flow",
          "Track executable work for this book",
          SelectWorkspaceMode(MoonFlow),
        ),
      ]
    MoonCode =>
      [
        (
          "Browse Desk",
          "Open the virtual filesystem for MoonBooks",
          SelectWorkspaceMode(Desk),
        ),
        ("Search Books", "Find files across MoonBooks", SelectActivity(Search)),
        (
          "Create Inbox Note",
          "Stage a safe draft in inbox",
          SelectActivity(Inbox),
        ),
        ("Import URL", "Open the inbox importer", SelectActivity(Inbox)),
        (
          "Open Code",
          "Open a book-scoped coding session",
          SelectWorkspaceMode(MoonCode),
        ),
        ("Submit Request", "Send selected context as a request", SubmitRequest),
        (
          "New Book Pattern",
          "Publish a research-book from a registered source, analysis, and standing-watch pattern",
          SelectActivity(Town),
        ),
        (
          "Run Daemon Tick",
          "Control one MoonTown scheduler tick",
          ControlDaemonTick,
        ),
        ("Start Daemon", "Start the managed MoonTown daemon loop", StartDaemon),
        (
          "Enable Supervision",
          "Restart the daemon when the policy says it should run",
          EnableDaemonSupervision,
        ),
        ("Stop Daemon", "Stop the managed MoonTown daemon loop", StopDaemon),
        (
          "Show Run Artifacts",
          "Open MoonClaw run projection",
          SelectActivity(Runs),
        ),
        ("Daily Surface", "Open operating summary", SelectActivity(Settings)),
        (
          "Open Flow",
          "Track executable work for this book",
          SelectWorkspaceMode(MoonFlow),
        ),
      ]
    MoonFlow =>
      [
        (
          "Refresh Flow",
          "Reload outcomes, blockers, evidence, and next actions",
          SelectWorkspaceMode(MoonFlow),
        ),
        (
          "Open Wiki",
          "Inspect the executable document behind this work",
          SelectWorkspaceMode(MoonWiki),
        ),
        (
          "Open Code",
          "Build helpers in the current book context",
          SelectWorkspaceMode(MoonCode),
        ),
        (
          "Browse Desk",
          "Inspect MoonBook files and generated artifacts",
          SelectWorkspaceMode(Desk),
        ),
      ]
  }
}

///|
fn palette_command(
  dispatch : Dispatch[Msg],
  title : String,
  detail : String,
  msg : Msg,
) -> @rabbita.Html {
  button(class="palette-command", on_click=dispatch(msg), [
    span(
      class="command-icon",
      attrs=@html.Attrs::build().aria_hidden("true"),
      ">",
    ),
    div([h3(title), p(detail)]),
  ])
}

///|
fn render_title_bar(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  header(class="title-bar", [
    div(
      class="workspace-mode-toggle primary-nav-desktop",
      attrs=@html.Attrs::build()
        .role("navigation")
        .aria_label("Primary destinations"),
      primary_navigation_items().map(item => {
        let (mode, _label, test_id, shortcut) = item
        render_primary_navigation_button(
          dispatch, model, mode, test_id, shortcut,
        )
      }),
    ),
    details(
      class="primary-nav-compact",
      attrs=@html.Attrs::build()
        .role("navigation")
        .aria_label("Primary destinations"),
      [
        summary(
          class="primary-nav-compact-summary",
          attrs=@html.Attrs::build()
            .data_set("testid", "primary-nav-summary")
            .aria_label(
              "Current destination: " +
              workspace_mode_label(
                primary_navigation_mode(model.workspace_mode),
              ) +
              ". Choose a destination",
            ),
          workspace_mode_label(primary_navigation_mode(model.workspace_mode)),
        ),
        div(
          class="primary-nav-compact-menu",
          primary_navigation_items().map(item => {
            let (mode, _label, test_id, shortcut) = item
            render_primary_navigation_button(
              dispatch,
              model,
              mode,
              "compact-" + test_id,
              shortcut,
            )
          }),
        ),
      ],
    ),
    render_wiki_workspace_tabs(dispatch, model),
    div(class="title-copy", [
      span(class="app-dot", ""),
      h1("MoonDesk"),
      span(class="workspace-switcher", workspace_name(model)),
      span(class="mode-caption", workspace_mode_summary(model.workspace_mode)),
    ]),
    span(
      class="language-preference-host",
      attrs=@html.Attrs::build().data_set("testid", "language-preference-host"),
      "",
    ),
    button(
      class="command-button",
      attrs=@html.Attrs::build()
        .aria_keyshortcuts("Meta+K Control+K")
        .aria_haspopup("dialog")
        .aria_expanded(if model.command_open { "true" } else { "false" })
        .data_set("testid", "command-palette-toggle"),
      title=if model.loading { "Workspace is loading" } else { "Open commands" },
      on_click=dispatch(ToggleCommand),
      "Commands",
    ),
    render_destination_announcement(model),
  ])
}

///|
fn primary_navigation_items() -> Array[(WorkspaceMode, String, String, String)] {
  [
    (Desk, "Desk", "mode-desk", "Meta+1 Control+1"),
    (MoonWiki, "Wiki", "mode-wiki", "Meta+2 Control+2"),
    (MoonCode, "Code", "mode-code", "Meta+3 Control+3"),
    (MoonFlow, "Flow", "mode-flow", "Meta+4 Control+4"),
    (PackHome, "Packs", "mode-packs", "Meta+5 Control+5"),
  ]
}

///|
fn primary_navigation_mode(mode : WorkspaceMode) -> WorkspaceMode {
  match mode {
    RequestsWorkspace | RunsWorkspace | ReviewWorkspace | PublishWorkspace =>
      MoonWiki
    _ => mode
  }
}

///|
fn wiki_workspace_tab_items() -> Array[(WorkspaceMode, String, String)] {
  [
    (MoonWiki, "Pages", "wiki-tab-pages"),
    (RequestsWorkspace, "Requests", "wiki-tab-requests"),
    (RunsWorkspace, "Runs", "wiki-tab-runs"),
    (ReviewWorkspace, "Review", "wiki-tab-review"),
    (PublishWorkspace, "Publish", "wiki-tab-publish"),
  ]
}

///|
fn render_wiki_workspace_tabs(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  if primary_navigation_mode(model.workspace_mode) != MoonWiki {
    return @html.nothing
  }
  div(
    class="workspace-tab-nav",
    attrs=@html.Attrs::build().role("navigation").aria_label("Wiki sections"),
    wiki_workspace_tab_items().map(item => {
      let (mode, label, test_id) = item
      let selected = model.workspace_mode == mode
      button(
        class=if selected { "workspace-tab active" } else { "workspace-tab" },
        attrs=@html.Attrs::build()
          .aria_pressed(if selected { "true" } else { "false" })
          .aria_current(if selected { "page" } else { "false" })
          .data_set("testid", test_id),
        title="Open " + label,
        on_click=dispatch(SelectWorkspaceMode(mode)),
        label,
      )
    }),
  )
}

///|
fn render_primary_navigation_button(
  dispatch : Dispatch[Msg],
  model : Model,
  mode : WorkspaceMode,
  test_id : String,
  shortcut : String,
) -> @rabbita.Html {
  let selected = primary_navigation_mode(model.workspace_mode) == mode
  button(
    class=if selected { "mode-button active" } else { "mode-button" },
    attrs=@html.Attrs::build()
      .aria_keyshortcuts(shortcut)
      .aria_pressed(if selected { "true" } else { "false" })
      .aria_current(if selected { "page" } else { "false" })
      .data_set("testid", test_id),
    title="Open " + workspace_mode_label(mode),
    on_click=dispatch(SelectWorkspaceMode(mode)),
    workspace_mode_label(mode),
  )
}
