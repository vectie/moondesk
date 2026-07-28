///|
priv enum CapabilityState {
  DetectedRunning
  InstalledStopped
  NotInstalled
  Misconfigured
  UnsupportedPlatform
  TemporarilyUnavailable
}

///|
priv enum CodeCapabilityPrimaryAction {
  NoPrimaryAction
  StartCapability
  InstallCapability
  OpenConfiguration
  RetryCapabilityCheck
}

///|
priv enum RequestsCapabilityPrimaryAction {
  NoRequestsCapabilityAction
  StartRequestsAutomation
  ReviewRequestsSetup
  RetryRequestsCapabilityCheck
}

///|
/// Classifies capability evidence in a fixed order.
fn classify_capability(
  supported : Bool,
  probe_available : Bool,
  running : Bool,
  installed : Bool,
  configured : Bool,
) -> CapabilityState {
  if !supported {
    UnsupportedPlatform
  } else if !probe_available {
    TemporarilyUnavailable
  } else if running {
    DetectedRunning
  } else if !installed {
    NotInstalled
  } else if !configured {
    Misconfigured
  } else {
    InstalledStopped
  }
}

///|
/// Maps the available daemon DTO without inferring state from message text.
fn moonclaw_capability_state(daemon : MoonClawDaemonStatus?) -> CapabilityState {
  match daemon {
    None => TemporarilyUnavailable
    Some(daemon) => {
      let installed = match daemon.installation_evidence {
        Some(evidence) => evidence.installed
        None =>
          match daemon.managed_install {
            Some(installed) => installed
            None => daemon.service_configured || daemon.running
          }
      }
      let configured = match daemon.configuration_evidence {
        Some(evidence) => evidence.configured && evidence.valid
        None => daemon.service_configured || daemon.running
      }
      classify_capability(
        match daemon.platform_evidence {
          Some(evidence) => evidence.supported
          None => true
        },
        true,
        daemon.running,
        installed,
        configured,
      )
    }
  }
}

///|
fn code_capability_title_i18n_key(state : CapabilityState) -> String {
  match state {
    DetectedRunning => "code.assistance_title_detected_running"
    InstalledStopped => "code.assistance_title_installed_stopped"
    NotInstalled => "code.assistance_title_not_installed"
    Misconfigured => "code.assistance_title_misconfigured"
    UnsupportedPlatform => "code.assistance_title_unsupported_platform"
    TemporarilyUnavailable => "code.assistance_title_temporarily_unavailable"
  }
}

///|
fn code_capability_detail_i18n_key(state : CapabilityState) -> String {
  match state {
    DetectedRunning => "code.assistance_detail_detected_running"
    InstalledStopped => "code.assistance_detail_installed_stopped"
    NotInstalled => "code.assistance_detail_not_installed"
    Misconfigured => "code.assistance_detail_misconfigured"
    UnsupportedPlatform => "code.assistance_detail_unsupported_platform"
    TemporarilyUnavailable => "code.assistance_detail_temporarily_unavailable"
  }
}

///|
fn code_capability_status_i18n_key(state : CapabilityState) -> String {
  match state {
    DetectedRunning => "code.assistance_status_running"
    InstalledStopped => "code.assistance_status_installed_stopped"
    NotInstalled => "code.assistance_status_not_installed"
    Misconfigured => "code.assistance_status_needs_configuration"
    UnsupportedPlatform => "code.assistance_status_not_supported"
    TemporarilyUnavailable => "code.assistance_status_checking"
  }
}

///|
fn code_capability_title(state : CapabilityState) -> String {
  match state {
    DetectedRunning => "Code assistance is ready"
    InstalledStopped => "Code assistance is stopped"
    NotInstalled => "Code assistance is not installed"
    Misconfigured => "Code assistance needs configuration"
    UnsupportedPlatform => "Code assistance is not supported here"
    TemporarilyUnavailable => "Code assistance status is unavailable"
  }
}

///|
fn capability_state_key(state : CapabilityState) -> String {
  match state {
    DetectedRunning => "detected-running"
    InstalledStopped => "installed-stopped"
    NotInstalled => "not-installed"
    Misconfigured => "misconfigured"
    UnsupportedPlatform => "unsupported-platform"
    TemporarilyUnavailable => "temporarily-unavailable"
  }
}

///|
fn capability_status_key(state : CapabilityState) -> String {
  match state {
    DetectedRunning => "ready"
    TemporarilyUnavailable => "unknown"
    InstalledStopped | NotInstalled | Misconfigured | UnsupportedPlatform =>
      "missing"
  }
}

///|
fn capability_status_label(state : CapabilityState) -> String {
  match state {
    DetectedRunning => "running"
    InstalledStopped => "installed, stopped"
    NotInstalled => "not installed"
    Misconfigured => "needs configuration"
    UnsupportedPlatform => "not supported"
    TemporarilyUnavailable => "checking"
  }
}

///|
fn code_capability_detail(state : CapabilityState) -> String {
  match state {
    DetectedRunning => "You can start or continue Code conversations."
    InstalledStopped => "Start Code assistance before beginning a conversation."
    NotInstalled => "Install Code assistance to use Code conversations."
    Misconfigured => "Review the configuration before using Code assistance."
    UnsupportedPlatform =>
      "You can continue with Pages and files without local Code assistance."
    TemporarilyUnavailable =>
      "Check again when status information is available. Pages and files remain available."
  }
}

///|
fn code_capability_primary_action(
  state : CapabilityState,
) -> CodeCapabilityPrimaryAction {
  match state {
    DetectedRunning => NoPrimaryAction
    InstalledStopped => StartCapability
    NotInstalled => InstallCapability
    Misconfigured => OpenConfiguration
    UnsupportedPlatform => NoPrimaryAction
    TemporarilyUnavailable => RetryCapabilityCheck
  }
}

///|
fn code_capability_primary_action_i18n_key(
  action : CodeCapabilityPrimaryAction,
) -> String {
  match action {
    NoPrimaryAction => ""
    StartCapability => "code.assistance_action_start"
    InstallCapability => "code.assistance_action_install"
    OpenConfiguration => "code.assistance_action_open_configuration"
    RetryCapabilityCheck => "code.assistance_action_retry"
  }
}

///|
fn code_capability_primary_action_label(
  action : CodeCapabilityPrimaryAction,
) -> String {
  match action {
    NoPrimaryAction => ""
    StartCapability => "Start Code assistance"
    InstallCapability => "Install Code assistance"
    OpenConfiguration => "Review configuration"
    RetryCapabilityCheck => "Check again"
  }
}

///| Requests can always be staged. This classifies only their optional

///|
/// automation capability from explicit lifecycle evidence.
fn requests_capability_state(
  lifecycle : DaemonLifecycleResult?,
  probe_available : Bool,
) -> CapabilityState {
  if !probe_available {
    return TemporarilyUnavailable
  }
  match lifecycle {
    None => TemporarilyUnavailable
    Some(result) => {
      let supported = match result.platform_evidence {
        Some(evidence) => evidence.supported
        None => true
      }
      let installed = match result.installation_evidence {
        Some(evidence) => evidence.installed
        // Older responses classified unconfigured services as Misconfigured.
        None => true
      }
      classify_capability(
        supported,
        true,
        result.running,
        installed,
        match result.configuration_evidence {
          Some(evidence) => evidence.configured && evidence.valid
          // Preserve the pre-evidence behavior for older lifecycle responses,
          // except that operation success is never configuration evidence.
          None => result.service_configured || result.running
        },
      )
    }
  }
}

///|
fn requests_capability_title(state : CapabilityState) -> String {
  match state {
    DetectedRunning => "Request automation is ready"
    InstalledStopped => "Request automation is stopped"
    NotInstalled | Misconfigured => "Request automation needs setup"
    UnsupportedPlatform => "Request automation is not supported here"
    TemporarilyUnavailable => "Request automation status is unavailable"
  }
}

///|
fn requests_capability_detail(state : CapabilityState) -> String {
  match state {
    DetectedRunning =>
      "Requests can be saved now and automation can process scheduled work."
    InstalledStopped =>
      "Requests can still be saved. Start automation for scheduled work."
    NotInstalled | Misconfigured =>
      "Requests can still be saved. Review setup before using scheduled work."
    UnsupportedPlatform =>
      "Requests can still be saved without local scheduled automation."
    TemporarilyUnavailable =>
      "Requests can still be saved. Check automation status again when available."
  }
}

///|
fn requests_capability_primary_action(
  state : CapabilityState,
) -> RequestsCapabilityPrimaryAction {
  match state {
    DetectedRunning | UnsupportedPlatform => NoRequestsCapabilityAction
    InstalledStopped => StartRequestsAutomation
    NotInstalled | Misconfigured => ReviewRequestsSetup
    TemporarilyUnavailable => RetryRequestsCapabilityCheck
  }
}

///|
fn requests_capability_primary_action_label(
  action : RequestsCapabilityPrimaryAction,
) -> String {
  match action {
    NoRequestsCapabilityAction => ""
    StartRequestsAutomation => "Start automation"
    ReviewRequestsSetup => "Review setup"
    RetryRequestsCapabilityCheck => "Check again"
  }
}

///|
fn capability_platform_technical_detail(
  daemon : MoonClawDaemonStatus,
) -> String? {
  match daemon.platform_evidence {
    Some(evidence) =>
      Some(
        "Platform: " +
        evidence.platform +
        "; architecture: " +
        evidence.architecture +
        "; supported: " +
        evidence.supported.to_string(),
      )
    None => None
  }
}
