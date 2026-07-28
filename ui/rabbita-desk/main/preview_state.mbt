///|
fn preview_request_is_current_selection(
  model : Model,
  workspace_id : String,
  path : String,
) -> Bool {
  workspace_id != "" &&
  workspace_id == model.selected_workspace_id &&
  path == model.selected_path
}

///|
fn preview_response_is_current(
  model : Model,
  workspace_id : String,
  path : String,
  generation : Int,
) -> Bool {
  workspace_id == model.preview_request_workspace_id &&
  path == model.preview_request_path &&
  generation == model.preview_request_generation &&
  preview_request_is_current_selection(model, workspace_id, path)
}

///|
fn preview_request_keeps_content(
  model : Model,
  workspace_id : String,
  path : String,
) -> Bool {
  workspace_id == model.preview_request_workspace_id &&
  path == model.preview_request_path
}

///|
fn preview_failure_state(model : Model) -> SurfaceState {
  match model.preview {
    Some(_) => Stale
    None => RecoverableError
  }
}

///|
fn preview_state_title(state : SurfaceState) -> String {
  match state {
    FirstUseEmpty => "Choose a file or page"
    Loading => "Opening preview"
    Stale => "Showing an earlier preview"
    RecoverableError => "Preview couldn’t be opened"
    Disconnected => "Preview service is unavailable"
    TerminalError => "Preview can’t be opened"
    CapabilityLimited => "Preview isn’t supported here"
    LegitimateZero => "Nothing to preview"
  }
}

///|
fn preview_state_detail(state : SurfaceState) -> String {
  match state {
    FirstUseEmpty => "Select an item to inspect it here."
    Loading => "Loading the selected item."
    Stale => "The retained preview may be out of date. Refresh to try again."
    RecoverableError => "Retry without leaving the selected item."
    Disconnected => "Reconnect and retry the selected item."
    TerminalError => "Choose another item or open Technical details."
    CapabilityLimited => "Choose another item to continue."
    LegitimateZero => "Choose another item to continue."
  }
}

///|
fn preview_state_action(state : SurfaceState) -> String? {
  match state {
    Stale => Some("Refresh")
    Disconnected | RecoverableError => Some("Retry")
    FirstUseEmpty
    | LegitimateZero
    | Loading
    | CapabilityLimited
    | TerminalError => None
  }
}

///|
fn preview_state_shows_technical_detail(state : SurfaceState) -> Bool {
  state == Stale ||
  state == Disconnected ||
  state == RecoverableError ||
  state == TerminalError
}

///|
fn render_preview_state_panel(
  dispatch : Dispatch[Msg],
  model : Model,
  state : SurfaceState,
) -> @rabbita.Html {
  section(
    class="surface-state-panel preview-state-panel",
    attrs=@html.Attrs::build()
      .data_set("testid", "preview-state")
      .data_set("state", surface_state_key(state)),
    [
      render_polite_state_announcement(
        "preview-state-announcement",
        preview_state_title(state),
        preview_state_detail(state),
      ),
      match preview_state_action(state) {
        Some(label) =>
          button(class="secondary-button", on_click=dispatch(RefreshAll), label)
        None => @html.nothing
      },
      if preview_state_shows_technical_detail(state) &&
        model.preview_error != "" {
        details(class="technical-details", [
          summary("Technical details"),
          pre(class="source-block compact", code(model.preview_error)),
        ])
      } else {
        @html.nothing
      },
    ],
  )
}
