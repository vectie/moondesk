///|
/// Saved-view catalog presentation is deliberately independent from save-operation
/// feedback. Ready rows use `None`, matching the shared SurfaceState convention.
fn saved_views_state_after_success(row_count : Int) -> SurfaceState? {
  if row_count == 0 {
    Some(LegitimateZero)
  } else {
    None
  }
}

///|
fn saved_views_state_after_failure(has_rows : Bool) -> SurfaceState? {
  if has_rows {
    Some(Stale)
  } else {
    Some(RecoverableError)
  }
}

///|
fn saved_views_state_key(state : SurfaceState?) -> String {
  match state {
    Some(FirstUseEmpty) => "first-use-empty"
    Some(LegitimateZero) => "legitimate-zero"
    Some(Loading) => "loading"
    Some(Stale) => "stale"
    Some(Disconnected) => "disconnected"
    Some(CapabilityLimited) => "capability-limited"
    Some(RecoverableError) => "recoverable-error"
    Some(TerminalError) => "terminal-error"
    None => "ready"
  }
}

///|
fn saved_views_state_title(state : SurfaceState?) -> String {
  match state {
    Some(FirstUseEmpty) => "Saved views have not been checked"
    Some(LegitimateZero) => "No saved views yet"
    Some(Loading) => "Loading saved views"
    Some(Stale) => "Showing saved views from the last successful check"
    Some(Disconnected) => "Saved views are disconnected"
    Some(CapabilityLimited) => "Saved views are unavailable in this setup"
    Some(RecoverableError) => "Saved views could not be loaded"
    Some(TerminalError) => "Saved views cannot be loaded"
    None => "Saved views are ready"
  }
}

///|
fn saved_views_state_detail(state : SurfaceState?) -> String {
  match state {
    Some(FirstUseEmpty) => "Open Settings to check your saved views."
    Some(LegitimateZero) =>
      "Save the current page or search when you want to return to it."
    Some(Loading) => "Checking the saved-view catalog now."
    Some(Stale) => "The retained rows may be out of date."
    Some(Disconnected) => "Reconnect before checking the catalog again."
    Some(CapabilityLimited) => "This setup cannot list saved views."
    Some(RecoverableError) => "Try loading the catalog again."
    Some(TerminalError) => "Review the technical details before continuing."
    None => "Choose a saved view to open it."
  }
}

///|
fn saved_views_state_action(state : SurfaceState?) -> String? {
  match state {
    Some(FirstUseEmpty) => Some("Check saved views")
    Some(LegitimateZero) => None
    Some(Loading) => None
    Some(Stale) => Some("Refresh")
    Some(Disconnected) => Some("Retry")
    Some(CapabilityLimited) => None
    Some(RecoverableError) => Some("Retry")
    Some(TerminalError) => None
    None => Some("Refresh")
  }
}

///|
fn saved_views_state_keeps_rows(state : SurfaceState?) -> Bool {
  match state {
    Some(Loading) | Some(Stale) | None => true
    _ => false
  }
}

///|
fn saved_views_state_shows_technical_details(state : SurfaceState?) -> Bool {
  match state {
    Some(Stale)
    | Some(Disconnected)
    | Some(CapabilityLimited)
    | Some(RecoverableError)
    | Some(TerminalError) => true
    _ => false
  }
}
