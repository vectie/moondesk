///|
/// Bounded Desk cold-start presentation derived only from Model evidence.
/// Workspace catalog transport state is intentionally surface-owned and must
/// not be inferred from broad host-status display text.
priv enum ColdStartState {
  Connecting
  LibraryUnavailable
  CatalogUnavailable
  EmptyLibrary
  OneBook
  ManyBooks
}

///|
/// The single honest primary recovery offered by each cold-start state.
priv enum ColdStartPrimaryAction {
  Refresh
  ChooseLibrary
  AddMoonBook
  OpenMoonBook
  ChooseMoonBook
}

///|
fn cold_start_has_library_metadata(model : Model) -> Bool {
  model.workspace_books_root_path != "" ||
  model.workspace_library_path != "" ||
  model.workspace_suite_root_path != "" ||
  model.workspace_root_path != ""
}

///| Classify cold start with strict precedence: loading, missing library,

///|
/// known empty library, one book, then many books.
fn classify_cold_start(model : Model) -> ColdStartState {
  if model.workspaces.length() > 0 {
    if model.workspaces.length() == 1 {
      OneBook
    } else {
      ManyBooks
    }
  } else if model.workspace_catalog_state is Some(Loading) {
    Connecting
  } else if !cold_start_has_library_metadata(model) {
    LibraryUnavailable
  } else if model.workspace_catalog_state is Some(RecoverableError) {
    CatalogUnavailable
  } else if model.workspace_catalog_state is Some(LegitimateZero) {
    EmptyLibrary
  } else {
    CatalogUnavailable
  }
}

///|
fn cold_start_state_key(state : ColdStartState) -> String {
  match state {
    Connecting => "connecting"
    LibraryUnavailable => "library-unavailable"
    CatalogUnavailable => "catalog-unavailable"
    EmptyLibrary => "empty-library"
    OneBook => "one-book"
    ManyBooks => "many-books"
  }
}

///|
fn cold_start_title(state : ColdStartState) -> String {
  match state {
    Connecting => "Connecting to your library"
    LibraryUnavailable => "MoonBook library unavailable"
    CatalogUnavailable => "MoonBook library could not be checked"
    EmptyLibrary => "No MoonBooks yet"
    OneBook => "Your MoonBook is ready"
    ManyBooks => "Choose a MoonBook"
  }
}

///|
fn cold_start_detail(state : ColdStartState) -> String {
  match state {
    Connecting => "MoonDesk is checking your MoonBook library."
    LibraryUnavailable =>
      "Choose a folder where MoonDesk can keep your MoonBooks."
    CatalogUnavailable =>
      "MoonDesk could not check this library. Refresh to try again."
    EmptyLibrary => "Create a MoonBook or import an existing one."
    OneBook => "Open your MoonBook to continue."
    ManyBooks => "Select a MoonBook to continue."
  }
}

///|
fn cold_start_primary_action(state : ColdStartState) -> ColdStartPrimaryAction {
  match state {
    Connecting => Refresh
    LibraryUnavailable => ChooseLibrary
    CatalogUnavailable => Refresh
    EmptyLibrary => AddMoonBook
    OneBook => OpenMoonBook
    ManyBooks => ChooseMoonBook
  }
}

///|
fn cold_start_primary_action_label(action : ColdStartPrimaryAction) -> String {
  match action {
    Refresh => "Refresh"
    ChooseLibrary => "Choose library folder"
    AddMoonBook => "Add MoonBook"
    OpenMoonBook => "Open MoonBook"
    ChooseMoonBook => "Choose MoonBook"
  }
}

///|
fn workspace_catalog_state_title(state : SurfaceState) -> String {
  match state {
    Loading => "Refreshing your MoonBooks"
    Stale => "Showing MoonBooks from the last successful check"
    RecoverableError => "MoonBook library could not be checked"
    LegitimateZero => "No MoonBooks yet"
    FirstUseEmpty => "MoonBooks have not been checked"
    Disconnected => "MoonBook library is disconnected"
    CapabilityLimited => "MoonBook library access is limited"
    TerminalError => "MoonBook library cannot be checked"
  }
}

///|
fn workspace_catalog_state_detail(state : SurfaceState) -> String {
  match state {
    Loading => "Known MoonBooks remain available while the list is refreshed."
    Stale => "These MoonBooks may be out of date. Refresh to check again."
    RecoverableError => "Refresh to try checking this library again."
    LegitimateZero => "Create a MoonBook or import an existing one."
    FirstUseEmpty => "Check the configured library to find its MoonBooks."
    Disconnected => "Reconnect before checking this library again."
    CapabilityLimited => "Choose a library that MoonDesk can access."
    TerminalError => "Review the technical details before continuing."
  }
}

///|
fn workspace_catalog_state_action(state : SurfaceState) -> String? {
  match state {
    Stale | RecoverableError | Disconnected => Some("Refresh")
    FirstUseEmpty => Some("Check library")
    LegitimateZero | Loading | CapabilityLimited | TerminalError => None
  }
}

///|
fn workspace_catalog_state_shows_technical_details(
  state : SurfaceState,
) -> Bool {
  match state {
    Stale
    | Disconnected
    | CapabilityLimited
    | RecoverableError
    | TerminalError => true
    FirstUseEmpty | LegitimateZero | Loading => false
  }
}
