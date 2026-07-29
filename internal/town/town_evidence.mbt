///|
pub fn platform_evidence_from_values(
  platform : String,
  architecture : String,
) -> Json {
  let normalized_platform = match platform.trim().to_lower() {
    "darwin" | "macos" => "macos"
    "linux" => "linux"
    value => value.to_owned()
  }
  let normalized_architecture = match architecture.trim().to_lower() {
    "aarch64" | "arm64" => "arm64"
    "amd64" | "x86_64" => "x86_64"
    value => value.to_owned()
  }
  {
    "supported": (
      normalized_platform == "macos" || normalized_platform == "linux"
    ) &&
    (normalized_architecture == "arm64" || normalized_architecture == "x86_64"),
    "platform": normalized_platform,
    "architecture": normalized_architecture,
  }
}

///|
pub fn installation_evidence_from_values(
  configured : Bool,
  launch_agent_matches : Bool,
) -> Json {
  {
    "installed": configured || launch_agent_matches,
    "source": if configured {
      "service-configured"
    } else if launch_agent_matches {
      "launch-agent"
    } else {
      "none"
    },
  }
}

///|
pub fn configuration_evidence_from_values(
  installed : Bool,
  configured : Bool,
  configuration_valid? : Bool = true,
  configuration_reason? : String = "",
) -> Json {
  {
    "configured": configured,
    "valid": !installed || (configured && configuration_valid),
    "reason": if !installed {
      "not-installed"
    } else if !configured {
      "service-configuration-missing"
    } else if configuration_reason != "" {
      configuration_reason
    } else if configuration_valid {
      "service-configured"
    } else {
      "command-unavailable"
    },
  }
}
