/// Shared user-facing surface states. Runtime surfaces must only select states
/// supported by explicit evidence.

///|
#warnings("-unused_constructor")
enum SurfaceState {
  FirstUseEmpty
  LegitimateZero
  Loading
  Stale
  Disconnected
  CapabilityLimited
  RecoverableError
  TerminalError
} derive(Eq)

///|
fn surface_state_key(state : SurfaceState) -> String {
  match state {
    FirstUseEmpty => "first-use-empty"
    LegitimateZero => "legitimate-zero"
    Loading => "loading"
    Stale => "stale"
    Disconnected => "disconnected"
    CapabilityLimited => "capability-limited"
    RecoverableError => "recoverable-error"
    TerminalError => "terminal-error"
  }
}

///|
fn pages_search_state_title(state : SurfaceState) -> String {
  match state {
    FirstUseEmpty => "Start here"
    LegitimateZero => "No results"
    Loading => "Working on it"
    Stale => "This may be out of date"
    Disconnected => "You’re offline"
    CapabilityLimited => "This action isn’t available"
    RecoverableError => "Something went wrong"
    TerminalError => "This can’t continue"
  }
}

///|
fn pages_search_state_detail(state : SurfaceState) -> String {
  match state {
    FirstUseEmpty => "Enter a search to find pages, notes, and sources."
    LegitimateZero => "No matching pages, notes, or sources were found."
    Loading => "Searching your books."
    Stale => "Refresh to see the latest information."
    Disconnected => "Check your connection and try again."
    CapabilityLimited => "Your current setup doesn’t support this action."
    RecoverableError => "Try the search again."
    TerminalError => "Return to Pages and choose another action."
  }
}

///|
fn pages_search_state_primary_action(state : SurfaceState) -> String? {
  match state {
    FirstUseEmpty => Some("Search")
    Loading => None
    LegitimateZero => Some("Search")
    Stale => Some("Refresh")
    Disconnected => Some("Retry")
    CapabilityLimited => None
    RecoverableError => Some("Retry")
    TerminalError => None
  }
}

///|
fn pages_search_state_technical_detail(state : SurfaceState) -> String? {
  match state {
    FirstUseEmpty | LegitimateZero | Loading => None
    Stale => Some("The last successful response is no longer current.")
    Disconnected => Some("The service could not be reached.")
    CapabilityLimited =>
      Some("The required capability was not reported as available.")
    RecoverableError => Some("The request failed and may succeed when retried.")
    TerminalError => Some("The operation cannot safely continue.")
  }
}
