///|
fn render_command_palette(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  if !model.command_open {
    @html.nothing
  } else {
    div(class="palette-backdrop", [
      div(class="command-palette", [
        div(class="palette-head", [
          input(
            class="palette-input",
            value=model.command_query,
            placeholder="Open Book, Import Files, Search, Submit...",
            on_input=fn(value) { dispatch(SetCommandQuery(value)) },
          ),
          button(
            class="icon-button palette-close",
            title="Close command palette",
            attrs=@html.Attrs::build().aria_label("Close command palette"),
            on_click=dispatch(ToggleCommand),
            "X",
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
      ]),
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
  match mode {
    PackHome =>
      [
        (
          "Open Pack Home",
          "Launch installed domain applications",
          SelectWorkspaceMode(PackHome),
        ),
        (
          "Inspect composition",
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
          "Open Pack Home",
          "Launch installed domain applications",
          SelectWorkspaceMode(PackHome),
        ),
        (
          "Browse Desk",
          "Open the virtual filesystem for MoonBooks",
          SelectWorkspaceMode(Desk),
        ),
        (
          "Open in Wiki",
          "Use the selected book context in MoonWiki",
          SelectWorkspaceMode(MoonWiki),
        ),
        (
          "Open MoonCode",
          "Use the selected book context in MoonCode",
          SelectWorkspaceMode(MoonCode),
        ),
        (
          "Open MoonFlow",
          "Track outcomes, blockers, evidence, and next actions",
          SelectWorkspaceMode(MoonFlow),
        ),
      ]
    MoonWiki =>
      [
        (
          "Open Library",
          "Read pages in the current book",
          SelectActivity(Files),
        ),
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
        ("Open Activity", "See tasks and their results", SelectActivity(Town)),
        (
          "Open Review",
          "Review proposed knowledge changes",
          SelectActivity(Runs),
        ),
        (
          "More",
          "Open automations, saved views, and diagnostics",
          SelectActivity(Settings),
        ),
        (
          "Open MoonCode",
          "Open a book-scoped coding session",
          SelectWorkspaceMode(MoonCode),
        ),
        (
          "Open MoonFlow",
          "Track executable work across Moon Suite",
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
          "Open MoonCode",
          "Open a book-scoped MoonCode coding session",
          SelectWorkspaceMode(MoonCode),
        ),
        ("Submit to Town", "Send selected context to MoonTown", SubmitRequest),
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
          "Open MoonFlow",
          "Track executable work across Moon Suite",
          SelectWorkspaceMode(MoonFlow),
        ),
      ]
    MoonFlow =>
      [
        (
          "Refresh MoonFlow",
          "Reload outcomes, blockers, evidence, and next actions",
          SelectWorkspaceMode(MoonFlow),
        ),
        (
          "Open in Wiki",
          "Inspect the executable document behind this work",
          SelectWorkspaceMode(MoonWiki),
        ),
        (
          "Open MoonCode",
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
    span(class="command-icon", ">"),
    div([h3(title), p(detail)]),
  ])
}

///|
fn render_title_bar(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  header(class="title-bar", [
    div(class="workspace-mode-toggle", [
      button(
        class=workspace_mode_button_class(model, Desk),
        attrs=@html.Attrs::build()
          .aria_keyshortcuts("Meta+1 Control+1")
          .aria_pressed(
            if model.workspace_mode == Desk {
              "true"
            } else {
              "false"
            },
          )
          .data_set("testid", "mode-desk"),
        title="Switch to Desk mode",
        on_click=dispatch(SelectWorkspaceMode(Desk)),
        "Desk",
      ),
      button(
        class=workspace_mode_button_class(model, MoonWiki),
        attrs=@html.Attrs::build()
          .aria_keyshortcuts("Meta+2 Control+2")
          .aria_pressed(
            if model.workspace_mode == MoonWiki {
              "true"
            } else {
              "false"
            },
          )
          .data_set("testid", "mode-wiki"),
        title="Switch to Wiki mode",
        on_click=dispatch(SelectWorkspaceMode(MoonWiki)),
        "Wiki",
      ),
      button(
        class=workspace_mode_button_class(model, MoonCode),
        attrs=@html.Attrs::build()
          .aria_keyshortcuts("Meta+3 Control+3")
          .aria_pressed(
            if model.workspace_mode == MoonCode {
              "true"
            } else {
              "false"
            },
          )
          .data_set("testid", "mode-code"),
        title="Switch to Code mode",
        on_click=dispatch(SelectWorkspaceMode(MoonCode)),
        "Code",
      ),
      button(
        class=workspace_mode_button_class(model, MoonFlow),
        attrs=@html.Attrs::build()
          .aria_keyshortcuts("Meta+4 Control+4")
          .aria_pressed(
            if model.workspace_mode == MoonFlow {
              "true"
            } else {
              "false"
            },
          )
          .data_set("testid", "mode-flow"),
        title="Switch to MoonFlow mode",
        on_click=dispatch(SelectWorkspaceMode(MoonFlow)),
        "Flow",
      ),
      button(
        class=workspace_mode_button_class(model, PackHome),
        attrs=@html.Attrs::build()
          .aria_keyshortcuts("Meta+5 Control+5")
          .aria_pressed(
            if model.workspace_mode == PackHome {
              "true"
            } else {
              "false"
            },
          )
          .data_set("testid", "mode-packs"),
        title="Open installed packs",
        on_click=dispatch(SelectWorkspaceMode(PackHome)),
        "Packs",
      ),
    ]),
    div(class="title-copy", [
      span(class="app-dot", ""),
      h1("MoonDesk"),
      span(class="workspace-switcher", workspace_name(model)),
      span(class="mode-caption", workspace_mode_summary(model.workspace_mode)),
    ]),
    button(
      class="command-button",
      attrs=@html.Attrs::build()
        .aria_keyshortcuts("Meta+K Control+K")
        .data_set("testid", "command-palette-toggle"),
      title=if model.loading { "Workspace is loading" } else { "Open commands" },
      on_click=dispatch(ToggleCommand),
      "Commands",
    ),
  ])
}

///|
fn workspace_mode_button_class(model : Model, mode : WorkspaceMode) -> String {
  if model.workspace_mode == mode {
    "mode-button active"
  } else {
    "mode-button"
  }
}
