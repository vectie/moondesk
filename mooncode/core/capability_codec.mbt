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
pub(all) enum MoonCodeFailure {
  Absent
  UnsupportedVersion(Int)
  UnsupportedProtocol(String)
  UnsupportedContract(String)
  Stale(revision~ : String, current_revision~ : String)
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
    extensions: Map::from_array([
      ("capability_surface", native_capability_surface_json()),
      (
        "capability_surface_fingerprint",
        native_capability_surface_fingerprint().to_json(),
      ),
      (
        "executable_book_lifecycle_contract_id",
        executable_book_lifecycle_contract_id().to_json(),
      ),
      (
        "executable_book_lifecycle_contract",
        executable_book_lifecycle_contract_json(),
      ),
    ]),
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
fn capability_string_array_equals(
  value : Json,
  expected : Array[String],
) -> Bool {
  guard value is Array(items) && items.length() == expected.length() else {
    return false
  }
  for index, expected_value in expected {
    guard items[index] is String(actual) && actual == expected_value else {
      return false
    }
  }
  true
}

///|
fn validate_nested_capability_contracts(fields : Map[String, Json]) -> String? {
  guard fields.get("capability_surface") is Some(Object(surface)) else {
    return Some("capability_surface must be an object")
  }
  guard surface.get("capability_contract_id")
    is Some(String("mooncode-native-capability-surface.v2")) else {
    return Some("capability_surface contract is unsupported")
  }
  guard surface.get("conversation_contract") is Some(Object(conversation)) &&
    conversation.get("contract_id") is Some(String("moonsuite-conversation.v3")) &&
    conversation.get("sequence_encoding")
    is Some(String("canonical nonnegative decimal JSON string")) else {
    return Some("conversation contract declaration is invalid")
  }
  guard surface.get("conversation_watch_write_contract") is Some(Object(watch)) &&
    watch.get("contract_id") is Some(String("moonsuite-conversation-watch.v2")) else {
    return Some("conversation watch write contract is invalid")
  }
  guard surface.get("conversation_watch_read_contract_ids") is Some(watch_reads) &&
    capability_string_array_equals(watch_reads, [
      "moonsuite-conversation-watch.v1", "moonsuite-conversation-watch.v2",
    ]) else {
    return Some("conversation watch read contracts are invalid")
  }
  guard surface.get("journal_write_contract_id")
    is Some(String("moonsuite-conversation-journal.v2")) &&
    surface.get("journal_read_contract_ids") is Some(journal_reads) &&
    capability_string_array_equals(journal_reads, [
      "moonsuite-conversation-journal.v1", "moonsuite-conversation-journal.v2",
    ]) else {
    return Some("journal contracts are invalid")
  }
  guard surface.get("session_contracts") is Some(Object(sessions)) &&
    sessions.get("snapshot") is Some(String("mooncode-session-snapshot.v2")) &&
    sessions.get("record") is Some(String("mooncode-session-record.v2")) &&
    sessions.get("listing") is Some(String("mooncode-session-listing.v2")) else {
    return Some("session contracts are invalid")
  }
  guard fields.get("executable_book_lifecycle_contract_id")
    is Some(String("mooncode-executable-book-lifecycle.v2")) &&
    fields.get("executable_book_lifecycle_contract") is Some(Object(lifecycle)) &&
    lifecycle.get("contract_id")
    is Some(String("mooncode-executable-book-lifecycle.v2")) &&
    lifecycle.get("runtime_owner") is Some(String("moonclaw")) &&
    lifecycle.get("artifact_owner") is Some(String("moonbook")) &&
    lifecycle.get("acceptance_owner") is Some(String("bookkeeper")) else {
    return Some("executable book lifecycle contract is invalid")
  }
  None
}

///|
pub fn decode_mooncode_capability(
  payload : Json,
) -> Result[MoonCodeCapability, MoonCodeFailure] {
  guard payload is Object(fields) else {
    return Err(Malformed("capability payload must be an object"))
  }
  guard capability_string_field(payload, "component") is Some(component) else {
    return Err(Malformed("component must be a string"))
  }
  guard capability_string_field(payload, "provider") is Some(provider) else {
    return Err(Malformed("provider must be a string"))
  }
  guard capability_string_field(payload, "protocol") is Some(protocol) else {
    return Err(Malformed("protocol must be a string"))
  }
  if protocol != "mooncode.v1" {
    guard explicit_contract_version(protocol, "mooncode.v") is Some(version) else {
      return Err(
        Malformed("protocol must identify a MoonCode protocol version"),
      )
    }
    return Err(UnsupportedVersion(version))
  }
  guard capability_string_field(payload, "capability_contract_id")
    is Some(capability_contract_id) else {
    return Err(Malformed("capability_contract_id must be a string"))
  }
  if capability_contract_id != mooncode_capability_contract_id() {
    guard explicit_contract_version(
        capability_contract_id, "mooncode-native-capability-surface.v",
      )
      is Some(version) else {
      return Err(
        Malformed(
          "capability_contract_id must identify the native capability surface",
        ),
      )
    }
    return Err(UnsupportedVersion(version))
  }
  if validate_nested_capability_contracts(fields) is Some(reason) {
    return Err(Malformed(reason))
  }
  let native_runtime_ready = match fields.get("native_runtime_ready") {
    Some(True) => true
    Some(False) => false
    _ => return Err(Malformed("native_runtime_ready must be a boolean"))
  }
  guard capability_string_field(payload, "runtime_owner") is Some(runtime_owner) else {
    return Err(Malformed("runtime_owner must be a string"))
  }
  guard capability_string_field(payload, "session_owner") is Some(session_owner) else {
    return Err(Malformed("session_owner must be a string"))
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
    Some(_) => return Err(Malformed("ownership must be an object when present"))
  }
  Ok({
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
