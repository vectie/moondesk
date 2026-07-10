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
    Desk =>
      [
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
        ("Submit to Town", "Send selected context to Moontown", SubmitRequest),
        (
          "New Book Pattern",
          "Publish a research-book from a registered source, analysis, and standing-watch pattern",
          SelectActivity(Town),
        ),
        (
          "Run Daemon Tick",
          "Control one Moontown scheduler tick",
          ControlDaemonTick,
        ),
        ("Start Daemon", "Start the managed Moontown daemon loop", StartDaemon),
        (
          "Enable Supervision",
          "Restart the daemon when the policy says it should run",
          EnableDaemonSupervision,
        ),
        ("Stop Daemon", "Stop the managed Moontown daemon loop", StopDaemon),
        (
          "Show Run Artifacts",
          "Open MoonClaw run projection",
          SelectActivity(Runs),
        ),
        ("Daily Surface", "Open operating summary", SelectActivity(Settings)),
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
        title="Switch to Desk mode",
        on_click=dispatch(SelectWorkspaceMode(Desk)),
        "Desk",
      ),
      button(
        class=workspace_mode_button_class(model, MoonWiki),
        title="Switch to Wiki mode",
        on_click=dispatch(SelectWorkspaceMode(MoonWiki)),
        "Wiki",
      ),
      button(
        class=workspace_mode_button_class(model, MoonCode),
        title="Switch to Code mode",
        on_click=dispatch(SelectWorkspaceMode(MoonCode)),
        "Code",
      ),
    ]),
    div(class="title-copy", [
      span(class="app-dot", ""),
      h1("Moondesk"),
      span(class="workspace-switcher", workspace_name(model)),
      span(class="mode-caption", workspace_mode_summary(model.workspace_mode)),
    ]),
    button(
      class="command-button",
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
