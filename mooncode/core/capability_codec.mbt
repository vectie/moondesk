///|
pub(all) struct MoonCodeCapability {
  component : String
  provider : String
  protocol : String
  capability_contract_id : String
  native_runtime_ready : Bool
  runtime_owner : String
  session_owner : String
  extensions : Map[String, Json]
  ownership_extensions : Map[String, Json]
} derive(Debug, Eq)

///|
pub(all) enum MoonCodeCapabilityDecodeResult {
  Supported(MoonCodeCapability)
  UnsupportedVersion(Int)
  Malformed(String)
} derive(Debug, Eq)

///|
fn mooncode_capability_contract_id() -> String {
  "mooncode-native-capability-surface.v2"
}

///|
pub fn mooncode_capability() -> MoonCodeCapability {
  {
    component: "mooncode",
    provider: "moonclaw",
    protocol: "mooncode.v1",
    capability_contract_id: mooncode_capability_contract_id(),
    native_runtime_ready: true,
    runtime_owner: "moonclaw",
    session_owner: "moonclaw",
    extensions: Map([]),
    ownership_extensions: Map([]),
  }
}

///|
pub fn encode_mooncode_capability(capability : MoonCodeCapability) -> Json {
  let fields : Map[String, Json] = Map([])
  for key, value in capability.extensions {
    fields[key] = value
  }
  fields["component"] = capability.component.to_json()
  fields["provider"] = capability.provider.to_json()
  fields["protocol"] = capability.protocol.to_json()
  fields["capability_contract_id"] = capability.capability_contract_id.to_json()
  fields["native_runtime_ready"] = capability.native_runtime_ready.to_json()
  fields["runtime_owner"] = capability.runtime_owner.to_json()
  fields["session_owner"] = capability.session_owner.to_json()
  if capability.ownership_extensions.length() > 0 {
    let ownership : Map[String, Json] = Map([])
    for key, value in capability.ownership_extensions {
      ownership[key] = value
    }
    fields["ownership"] = Json::object(ownership)
  }
  Json::object(fields)
}

///|
fn capability_string_field(value : Json, field : String) -> String? {
  match value {
    Object(fields) =>
      match fields.get(field) {
        Some(String(value)) => Some(value)
        _ => None
      }
    _ => None
  }
}

///|
fn explicit_contract_version(value : String, prefix : String) -> Int? {
  guard value.has_prefix(prefix) else { return None }
  try @string.parse_int(value[prefix.length():].to_owned()) catch {
    _ => None
  } noraise {
    version => Some(version)
  }
}

///|
pub fn decode_mooncode_capability(
  payload : Json,
) -> MoonCodeCapabilityDecodeResult {
  guard payload is Object(fields) else {
    return Malformed("capability payload must be an object")
  }
  guard capability_string_field(payload, "component") is Some(component) else {
    return Malformed("component must be a string")
  }
  guard capability_string_field(payload, "provider") is Some(provider) else {
    return Malformed("provider must be a string")
  }
  guard capability_string_field(payload, "protocol") is Some(protocol) else {
    return Malformed("protocol must be a string")
  }
  if protocol != "mooncode.v1" && protocol != "mooncode.v2" {
    guard explicit_contract_version(protocol, "mooncode.v") is Some(version) else {
      return Malformed("protocol must identify a MoonCode protocol version")
    }
    return UnsupportedVersion(version)
  }
  guard capability_string_field(payload, "capability_contract_id")
    is Some(capability_contract_id) else {
    return Malformed("capability_contract_id must be a string")
  }
  if capability_contract_id != mooncode_capability_contract_id() {
    guard explicit_contract_version(
        capability_contract_id, "mooncode-native-capability-surface.v",
      )
      is Some(version) else {
      return Malformed(
        "capability_contract_id must identify the native capability surface",
      )
    }
    return UnsupportedVersion(version)
  }
  let native_runtime_ready = match fields.get("native_runtime_ready") {
    Some(True) => true
    Some(False) => false
    _ => return Malformed("native_runtime_ready must be a boolean")
  }
  guard capability_string_field(payload, "runtime_owner") is Some(runtime_owner) else {
    return Malformed("runtime_owner must be a string")
  }
  guard capability_string_field(payload, "session_owner") is Some(session_owner) else {
    return Malformed("session_owner must be a string")
  }
  let extensions : Map[String, Json] = Map([])
  for key, value in fields {
    if key != "component" &&
      key != "provider" &&
      key != "protocol" &&
      key != "capability_contract_id" &&
      key != "native_runtime_ready" &&
      key != "runtime_owner" &&
      key != "session_owner" &&
      key != "ownership" {
      extensions[key] = value
    }
  }
  let ownership_extensions : Map[String, Json] = Map([])
  match fields.get("ownership") {
    None => ()
    Some(Object(ownership)) =>
      for key, value in ownership {
        ownership_extensions[key] = value
      }
    Some(_) => return Malformed("ownership must be an object when present")
  }
  Supported({
    component,
    provider,
    protocol,
    capability_contract_id,
    native_runtime_ready,
    runtime_owner,
    session_owner,
    extensions,
    ownership_extensions,
  })
}
