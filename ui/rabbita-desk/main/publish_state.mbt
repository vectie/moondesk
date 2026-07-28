///| Publish owns readiness state independently from Review. A ready state

///| means only that the last explicit review-readiness response was nonempty;

///|
/// it is not evidence that generated output exists or is current.
fn publish_state_key(state : SurfaceState?) -> String {
  match state {
    None => "ready"
    Some(state) => surface_state_key(state)
  }
}

///|
fn publish_state_title(state : SurfaceState) -> String {
  match state {
    FirstUseEmpty => "Check publishing readiness"
    LegitimateZero => "No review items are blocking this book"
    Loading => "Checking publishing readiness"
    Stale => "Showing earlier readiness evidence"
    Disconnected => "Publishing readiness is offline"
    CapabilityLimited => "Publishing readiness isn’t available"
    RecoverableError => "Publishing readiness couldn’t be checked"
    TerminalError => "Publishing readiness can’t continue"
  }
}

///|
fn publish_state_detail(state : SurfaceState, has_items : Bool) -> String {
  match state {
    FirstUseEmpty =>
      "Check this book’s review queue before checking its generated output."
    LegitimateZero =>
      "The review queue returned no blockers. The generated output must still be checked at its known location."
    Loading =>
      if has_items {
        "Refreshing while the last successful review evidence remains visible."
      } else {
        "Checking this book’s review queue."
      }
    Stale =>
      "The last successful review evidence remains visible. Refresh before relying on it."
    Disconnected => "Reconnect, then retry the publishing readiness check."
    CapabilityLimited =>
      "The current contract does not provide publishing readiness for this book."
    RecoverableError => "Retry the publishing readiness check for this book."
    TerminalError => "Return to Pages and choose another action."
  }
}

///|
fn publish_state_action(state : SurfaceState) -> String? {
  match state {
    FirstUseEmpty => Some("Check")
    LegitimateZero => None
    Loading => None
    Stale => Some("Refresh")
    Disconnected => Some("Retry")
    CapabilityLimited => None
    RecoverableError => Some("Retry")
    TerminalError => None
  }
}

///|
fn publish_state_technical_detail(state : SurfaceState) -> String? {
  match state {
    FirstUseEmpty | LegitimateZero | Loading => None
    Stale =>
      Some(
        "The last successful review-readiness response is no longer current.",
      )
    Disconnected => Some("The readiness source could not be reached.")
    CapabilityLimited =>
      Some("The required readiness capability was not reported as available.")
    RecoverableError =>
      Some("The readiness request failed and may succeed when retried.")
    TerminalError => Some("The readiness check cannot safely continue.")
  }
}

///|
fn publish_state_keeps_evidence(state : SurfaceState?) -> Bool {
  match state {
    None => true
    Some(LegitimateZero | Loading | Stale) => true
    Some(_) => false
  }
}

///|
fn publish_evidence_is_current(state : SurfaceState?) -> Bool {
  state is None || state is Some(LegitimateZero)
}

///|
fn publish_state_shows_raw_error(state : SurfaceState) -> Bool {
  state == Stale ||
  state == Disconnected ||
  state == CapabilityLimited ||
  state == RecoverableError ||
  state == TerminalError
}
