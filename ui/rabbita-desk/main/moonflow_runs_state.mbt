///|
fn moonflow_runs_state_key(state : SurfaceState?) -> String {
  match state {
    None => "ready"
    Some(value) => surface_state_key(value)
  }
}

///|
fn moonflow_effective_runs_state(model : Model) -> SurfaceState? {
  match model.moonflow_capability_evidence {
    Some(evidence) if !evidence.available => Some(CapabilityLimited)
    _ => model.moonflow_runs_state
  }
}

///|
fn moonflow_capability_technical_detail(model : Model) -> String {
  match model.moonflow_capability_evidence {
    Some(evidence) => {
      let platform = match evidence.platform_evidence {
        Some(value) => value.platform + "/" + value.architecture
        None => "unknown"
      }
      let installation = match evidence.installation_evidence {
        Some(value) => value.source + "/" + value.reason
        None => "unknown"
      }
      let configuration = match evidence.configuration_evidence {
        Some(value) => value.reason
        None => "unknown"
      }
      "Reason: " +
      evidence.reason +
      "; platform: " +
      platform +
      "; installation: " +
      installation +
      "; configuration: " +
      configuration +
      "; root: " +
      evidence.root
    }
    None => model.moonflow_capability_error.unwrap_or("")
  }
}

///|
fn moonflow_runs_state_keeps_records(state : SurfaceState?) -> Bool {
  match state {
    None | Some(Loading | Stale | CapabilityLimited) => true
    Some(_) => false
  }
}

///|
fn moonflow_runs_state_shows_empty_action(state : SurfaceState?) -> Bool {
  match state {
    None | Some(LegitimateZero) => true
    Some(_) => false
  }
}

///|
fn moonflow_runs_state_title(
  state : SurfaceState,
  has_records : Bool,
) -> String {
  match state {
    FirstUseEmpty => "Choose a book to view executable work"
    LegitimateZero => "No executable work yet"
    Loading =>
      if has_records {
        "Refreshing executable work"
      } else {
        "Checking executable work"
      }
    Stale => "Showing earlier executable work"
    Disconnected => "Executable work is offline"
    CapabilityLimited => "Executable work isn’t available"
    RecoverableError => "Executable work couldn’t be loaded"
    TerminalError => "Executable work can’t continue"
  }
}

///|
fn moonflow_runs_state_detail(
  state : SurfaceState,
  has_records : Bool,
) -> String {
  match state {
    FirstUseEmpty => "Choose a MoonBook before checking its governed runs."
    LegitimateZero =>
      "Start governed work when this book has an executable document."
    Loading =>
      if has_records {
        "The last successful run list remains visible while Flow checks for updates."
      } else {
        "Flow is checking this book for governed runs."
      }
    Stale =>
      "The last successful run list remains visible. Retry to check for newer work."
    Disconnected => "Reconnect, then retry this book’s executable work."
    CapabilityLimited =>
      "This setup cannot provide governed runs for the selected book."
    RecoverableError => "Retry without leaving the selected book."
    TerminalError => "Return Home and choose another book."
  }
}

///|
fn moonflow_runs_state_action(state : SurfaceState) -> String? {
  match state {
    Stale | Disconnected | RecoverableError => Some("Retry")
    FirstUseEmpty
    | LegitimateZero
    | Loading
    | CapabilityLimited
    | TerminalError => None
  }
}

///|
fn moonflow_runs_state_shows_details(state : SurfaceState) -> Bool {
  state == Stale ||
  state == Disconnected ||
  state == CapabilityLimited ||
  state == RecoverableError ||
  state == TerminalError
}
