///|
fn desk_entries_state_key(state : SurfaceState) -> String {
  surface_state_key(state)
}

///|
fn desk_entries_state_title(state : SurfaceState, model : Model) -> String {
  match state {
    FirstUseEmpty => "No MoonBook selected"
    LegitimateZero => desk_empty_folder_title(model)
    Loading => "Loading files"
    Stale => "Showing previously loaded files"
    Disconnected => "Files are unavailable offline"
    CapabilityLimited => "File listing is unavailable"
    RecoverableError => "Couldn’t load this folder"
    TerminalError => "This folder can’t be opened"
  }
}

///|
fn desk_entries_state_detail(state : SurfaceState, model : Model) -> String {
  match state {
    FirstUseEmpty => "Select or create a MoonBook to browse its files."
    LegitimateZero => desk_empty_folder_message(model)
    Loading => "MoonDesk is refreshing this folder."
    Stale => "These files are retained from the last successful refresh."
    Disconnected => "Reconnect, then try loading this folder again."
    CapabilityLimited => "The current setup cannot list this folder."
    RecoverableError => "Try loading this folder again."
    TerminalError => "Return Home and choose another MoonBook or folder."
  }
}

///|
fn desk_entries_state_action(state : SurfaceState) -> String? {
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
fn desk_entries_state_shows_technical_detail(state : SurfaceState) -> Bool {
  match state {
    Stale | Disconnected | RecoverableError | TerminalError => true
    FirstUseEmpty | LegitimateZero | Loading | CapabilityLimited => false
  }
}

///|
fn desk_entries_rows_while_loading(
  model : Model,
  workspace_id : String,
  directory : String,
) -> Array[@desk.DeskFileEntry] {
  if workspace_id == model.selected_workspace_id &&
    directory == model.current_directory {
    model.entries
  } else {
    []
  }
}

///|
fn desk_entries_request_is_current(
  model : Model,
  workspace_id : String,
  directory : String,
) -> Bool {
  workspace_id == model.selected_workspace_id &&
  directory == model.current_directory
}

///|
fn desk_entries_response_is_current(
  model : Model,
  workspace_id : String,
  directory : String,
  generation : Int,
) -> Bool {
  desk_entries_request_is_current(model, workspace_id, directory) &&
  generation == model.desk_entries_request_generation
}

///|
fn desk_entries_failure_state(model : Model) -> SurfaceState {
  if model.entries.is_empty() {
    RecoverableError
  } else {
    Stale
  }
}
