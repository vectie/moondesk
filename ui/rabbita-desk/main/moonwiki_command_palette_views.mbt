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
            value="",
            placeholder="Open Book, Import Files, Search, Submit...",
            "",
          ),
          button(
            class="icon-button palette-close",
            title="Close command palette",
            attrs=@html.Attrs::build().aria_label("Close command palette"),
            on_click=dispatch(ToggleCommand),
            "X",
          ),
        ]),
        div(class="palette-list", [
          palette_command(
            dispatch,
            "Search Books",
            "Find files across MoonBooks",
            SelectActivity(Search),
          ),
          palette_command(
            dispatch,
            "Create Inbox Note",
            "Stage a safe draft in inbox",
            SelectActivity(Inbox),
          ),
          palette_command(
            dispatch,
            "Import URL",
            "Open the inbox importer",
            SelectActivity(Inbox),
          ),
          palette_command(
            dispatch,
            "Open MoonCode",
            "Open a book-scoped MoonCode coding session",
            SelectActivity(MoonCode),
          ),
          palette_command(
            dispatch,
            "Submit to Town",
            "Send selected context to Moontown",
            SubmitRequest,
          ),
          palette_command(
            dispatch,
            "New Book Pattern",
            "Publish a research-book from a registered source, analysis, and standing-watch pattern",
            SelectActivity(Town),
          ),
          palette_command(
            dispatch,
            "Run Daemon Tick",
            "Control one Moontown scheduler tick",
            ControlDaemonTick,
          ),
          palette_command(
            dispatch,
            "Start Daemon",
            "Start the managed Moontown daemon loop",
            StartDaemon,
          ),
          palette_command(
            dispatch,
            "Enable Supervision",
            "Restart the daemon when the policy says it should run",
            EnableDaemonSupervision,
          ),
          palette_command(
            dispatch,
            "Stop Daemon",
            "Stop the managed Moontown daemon loop",
            StopDaemon,
          ),
          palette_command(
            dispatch,
            "Show Run Artifacts",
            "Open MoonClaw run projection",
            SelectActivity(Runs),
          ),
          palette_command(
            dispatch,
            "Daily Surface",
            "Open operating summary",
            SelectActivity(Settings),
          ),
        ]),
      ]),
    ])
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
  let raw_status = if model.loading {
    "loading workspace"
  } else {
    model.host_status
  }
  let status = title_bar_status_label(raw_status)
  header(class="title-bar", [
    div(class="workspace-mode-toggle", [
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
    div(class="sync-status", [
      span(class=title_bar_status_dot_class(raw_status), ""),
      span(status),
    ]),
  ])
}

///|
fn title_bar_status_label(status : String) -> String {
  let text = status.trim().to_owned()
  if text == "" {
    "local preview connected"
  } else if title_bar_status_is_transport_error(text) {
    "local preview connected"
  } else {
    text
  }
}

///|
fn title_bar_status_dot_class(status : String) -> String {
  let text = status.trim().to_owned()
  if text == "" || title_bar_status_is_transport_error(text) {
    "status-dot idle"
  } else {
    "status-dot live"
  }
}

///|
fn title_bar_status_is_transport_error(status : String) -> Bool {
  status.contains("JSON") ||
  status.contains("Json") ||
  status.contains("parse") ||
  status.contains("Invalid") ||
  status.contains("Unexpected token") ||
  status.contains("<!DOCTYPE")
}

///|
fn workspace_mode_button_class(model : Model, mode : WorkspaceMode) -> String {
  if model.workspace_mode == mode {
    "mode-button active"
  } else {
    "mode-button"
  }
}
