///|
fn runs_state_key(state : SurfaceState?) -> String {
  match state {
    None => "ready"
    Some(value) => surface_state_key(value)
  }
}

///|
fn runs_state_keeps_records(state : SurfaceState?) -> Bool {
  match state {
    None | Some(Loading | Stale) => true
    Some(_) => false
  }
}

///|
fn runs_state_title(state : SurfaceState) -> String {
  match state {
    FirstUseEmpty => "Check this book’s runs"
    LegitimateZero => "No runs yet"
    Loading => "Checking runs"
    Stale => "Showing earlier runs"
    Disconnected => "Runs are offline"
    CapabilityLimited => "Runs aren’t available"
    RecoverableError => "Runs couldn’t be loaded"
    TerminalError => "Runs can’t continue"
  }
}

///|
fn runs_state_detail(state : SurfaceState, has_records : Bool) -> String {
  match state {
    FirstUseEmpty => "Check this book for execution history and result files."
    LegitimateZero =>
      "This book has no recorded runs. Start a request when you’re ready."
    Loading =>
      if has_records {
        "Refreshing while the last successful run list remains visible."
      } else {
        "Looking for this book’s execution history."
      }
    Stale =>
      "The last successful run list remains visible. Refresh to check for newer results."
    Disconnected => "Reconnect, then retry this book’s runs."
    CapabilityLimited =>
      "This setup cannot provide execution history for this book."
    RecoverableError => "Retry without leaving this book."
    TerminalError => "Return Home and choose another book."
  }
}

///|
fn runs_state_action(state : SurfaceState) -> String? {
  match state {
    FirstUseEmpty => Some("Check")
    LegitimateZero => Some("Start a request")
    Loading => None
    Stale => Some("Refresh")
    Disconnected | RecoverableError => Some("Retry")
    CapabilityLimited | TerminalError => None
  }
}

///|
fn runs_state_shows_details(state : SurfaceState) -> Bool {
  state == Stale ||
  state == Disconnected ||
  state == CapabilityLimited ||
  state == RecoverableError ||
  state == TerminalError
}
