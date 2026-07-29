///|
priv enum MoonCodeCapabilityState {
  CapabilityPending
  CapabilitySupported(@mooncode_core.MoonCodeCapability)
  CapabilityUnsupportedVersion(Int)
  CapabilityMalformed(String)
  CapabilityUnavailable(String)
}

///|
fn mooncode_capability_state(payload : Json) -> MoonCodeCapabilityState {
  match payload {
    {
      "capability_status": "unsupported-version",
      "capability_version": Number(version, ..),
      ..
    } => CapabilityUnsupportedVersion(version.to_int())
    { "capability_status": "malformed", "capability_error": String(reason), .. } =>
      CapabilityMalformed(reason)
    {
      "capability_status": "unavailable",
      "capability_error": String(reason),
      ..
    } => CapabilityUnavailable(reason)
    _ =>
      match @mooncode_core.decode_mooncode_capability(payload) {
        Ok(capability) => CapabilitySupported(capability)
        Err(UnsupportedVersion(version)) =>
          CapabilityUnsupportedVersion(version)
        Err(Malformed(reason)) => CapabilityMalformed(reason)
        Err(Absent) => abort("capability decoder does not return Absent")
        Err(UnsupportedProtocol(_)) =>
          abort("capability decoder does not return UnsupportedProtocol")
        Err(UnsupportedContract(_)) =>
          abort("capability decoder does not return UnsupportedContract")
        Err(Stale(_)) => abort("capability decoder does not return Stale")
      }
  }
}

///|
fn mooncode_capability_available(state : MoonCodeCapabilityState) -> Bool {
  state is CapabilitySupported(_)
}

///|
fn mooncode_capability_title(state : MoonCodeCapabilityState) -> String {
  match state {
    CapabilityPending => "Checking Code runtime"
    CapabilitySupported(_) => "Code runtime is ready"
    CapabilityUnsupportedVersion(_) => "Code runtime version is incompatible"
    CapabilityMalformed(_) => "Code runtime response is malformed"
    CapabilityUnavailable(_) => "Code runtime is unavailable"
  }
}

///|
fn mooncode_capability_state_key(state : MoonCodeCapabilityState) -> String {
  match state {
    CapabilityPending => "pending"
    CapabilitySupported(_) => "supported"
    CapabilityUnsupportedVersion(_) => "unsupported-version"
    CapabilityMalformed(_) => "malformed"
    CapabilityUnavailable(_) => "unavailable"
  }
}
