///|
fn moonclaw_capability_payload() -> Json {
  {
    "component": "mooncode",
    "provider": "moonclaw",
    "protocol": @claw_core.protocol_version(),
    "capability_contract_id": @claw_core.native_capability_contract_id(),
    "capability_surface_fingerprint": @claw_core.native_capability_surface_fingerprint(),
    "capability_surface": @claw_core.native_capability_surface_json(),
    "executable_book_lifecycle_contract_id": @claw_core.executable_book_lifecycle_contract_id(),
    "executable_book_lifecycle_contract": @claw_core.executable_book_lifecycle_contract_json(),
    "native_runtime_ready": true,
    "runtime_owner": "moonclaw",
    "session_owner": "moonclaw",
  }
}

///|
fn main raise {
  match @desk_core.decode_mooncode_capability(moonclaw_capability_payload()) {
    Ok(capability) => {
      guard capability.component == "mooncode" &&
        capability.provider == "moonclaw" &&
        capability.protocol == "mooncode.v1" &&
        capability.capability_contract_id ==
        "mooncode-native-capability-surface.v2" &&
        capability.native_runtime_ready &&
        capability.runtime_owner == "moonclaw" &&
        capability.session_owner == "moonclaw" else {
        fail(
          "MoonClaw capability ownership or protocol identity is incompatible",
        )
      }
      println("MoonDesk accepted the MoonClaw capability contract.")
    }
    Err(error) =>
      fail("MoonDesk rejected the MoonClaw capability contract: \{Repr(error)}")
  }
}
