///| MoonCode session-list transport presentation. Capability presentation and

///|
/// canonical conversation ownership intentionally live elsewhere.
fn mooncode_sessions_state_key(state : SurfaceState) -> String {
  surface_state_key(state)
}

///|
fn mooncode_sessions_state_title(state : SurfaceState) -> String {
  match state {
    FirstUseEmpty => "Chat history has not been loaded"
    LegitimateZero => "No chats yet"
    Loading => "Loading chats"
    Stale => "Showing earlier chats"
    Disconnected => "Chat history is offline"
    CapabilityLimited => "Chat history isn’t available"
    RecoverableError => "Chat history couldn’t be loaded"
    TerminalError => "Chat history can’t continue"
  }
}

///|
fn mooncode_sessions_state_title_i18n_key(state : SurfaceState) -> String {
  match state {
    FirstUseEmpty => "code.history_not_loaded"
    LegitimateZero => "code.history_empty"
    Loading => "code.history_loading"
    Stale => "code.history_stale"
    Disconnected => "code.history_offline"
    CapabilityLimited => "code.history_unavailable"
    RecoverableError => "code.history_load_failed"
    TerminalError => "code.history_terminal"
  }
}

///|
fn mooncode_sessions_state_detail(
  state : SurfaceState,
  has_sessions : Bool,
) -> String {
  match state {
    FirstUseEmpty =>
      "When MoonCode is available, open Code to check its saved chats."
    LegitimateZero => "Start a new chat when you’re ready."
    Loading =>
      if has_sessions {
        "Refreshing while the last successful chat list remains visible."
      } else {
        "Checking for saved chats."
      }
    Stale =>
      "The last successful chat list remains visible. Refresh before relying on it."
    Disconnected => "Reconnect, then try again."
    CapabilityLimited =>
      "The current runtime contract cannot provide a chat listing."
    RecoverableError => "Retry without leaving Code."
    TerminalError => "Return Home and choose another action."
  }
}

///|
fn mooncode_sessions_state_detail_i18n_key(
  state : SurfaceState,
  has_sessions : Bool,
) -> String {
  match state {
    FirstUseEmpty => "code.history_not_loaded_detail"
    LegitimateZero => "code.history_empty_detail"
    Loading =>
      if has_sessions {
        "code.history_refreshing_detail"
      } else {
        "code.history_loading_detail"
      }
    Stale => "code.history_stale_detail"
    Disconnected => "code.history_offline_detail"
    CapabilityLimited => "code.history_unavailable_detail"
    RecoverableError => "code.history_load_failed_detail"
    TerminalError => "code.history_terminal_detail"
  }
}

///|
fn mooncode_sessions_state_action(state : SurfaceState) -> String? {
  match state {
    FirstUseEmpty | LegitimateZero | Loading => None
    Stale => Some("Refresh")
    Disconnected | RecoverableError => Some("Retry")
    CapabilityLimited | TerminalError => None
  }
}

///|
fn mooncode_sessions_state_shows_details(state : SurfaceState) -> Bool {
  state == Stale ||
  state == Disconnected ||
  state == CapabilityLimited ||
  state == RecoverableError ||
  state == TerminalError
}

///|
fn mooncode_sessions_listing_succeeded(state : SurfaceState?) -> Bool {
  state is None || state is Some(LegitimateZero)
}
