///|
/// Sanitized limits from the grant-bound execution profile. These values are
/// evidence only: MoonDesk never turns them into a local process policy.
pub(all) struct MoonCodeSandboxLimits {
  wall_clock_ms : Int
  cpu_seconds : Int
  memory_mib : Int
  disk_mib : Int
  processes : Int
  output_bytes : Int
} derive(Debug, Eq)

///|
/// A single scratch-relative change. Only a regular file present after the run
/// can be selected for reviewed promotion.
pub(all) struct MoonCodeSandboxChange {
  relative_path : String
  change : String
  before_fingerprint : String?
  after_fingerprint : String?
  after_size_bytes : Int64?
  promotable : Bool
} derive(Debug, Eq)

///|
/// Sanitized ExecutionSandbox evidence carried through MoonClaw. Host paths,
/// audit paths, command text, environment values, and secrets are deliberately
/// absent from this model.
pub(all) struct MoonCodeSandboxReceipt {
  backend : String
  enforcement : String
  cleanup_verified : Bool
  network : String
  limits : MoonCodeSandboxLimits
  unverified_limits : Array[String]
  approval_digest : String
  command_digest : String
  profile_digest : String
  changed_paths : Array[String]
  changes : Array[MoonCodeSandboxChange]
  artifacts : Array[String]
  retention_id : String?
} derive(Debug, Eq)

///|
const SandboxEvidenceMaxEntries : Int = 1_024

///|
fn sandbox_evidence_string(
  json : Json,
  key : String,
  default : String,
) -> String {
  match json {
    Object(fields) =>
      match fields.get(key) {
        Some(String(value)) => value
        _ => default
      }
    _ => default
  }
}

///|
fn sandbox_evidence_bool(json : Json, key : String, default : Bool) -> Bool {
  match json {
    Object(fields) =>
      match fields.get(key) {
        Some(True) => true
        Some(False) => false
        _ => default
      }
    _ => default
  }
}

///|
fn sandbox_evidence_int(json : Json, key : String, default : Int) -> Int {
  match json {
    Object(fields) =>
      match fields.get(key) {
        Some(Number(value, ..)) => value.to_int()
        _ => default
      }
    _ => default
  }
}

///|
fn sandbox_evidence_int64(json : Json, key : String) -> Int64? {
  match json {
    Object(fields) =>
      match fields.get(key) {
        Some(Number(value, ..)) => Some(value.to_int64())
        _ => None
      }
    _ => None
  }
}

///|
fn sandbox_evidence_object(json : Json, key : String) -> Json? {
  match json {
    Object(fields) =>
      match fields.get(key) {
        Some(Object(value)) => Some(Json::object(value))
        _ => None
      }
    _ => None
  }
}

///|
fn sandbox_evidence_array(json : Json, key : String) -> Array[Json]? {
  match json {
    Object(fields) =>
      match fields.get(key) {
        Some(Array(value)) => Some(value)
        _ => None
      }
    _ => None
  }
}

///|
fn sandbox_evidence_digest(value : String) -> Bool {
  value.length() == 64 &&
  value.all(character => {
    character.is_ascii_digit() || (character >= 'a' && character <= 'f')
  })
}

///|
fn sandbox_evidence_opaque_id(value : String) -> Bool {
  value.length() >= 1 &&
  value.length() <= 128 &&
  value.all(character => {
    character.is_ascii_alphabetic() ||
    character.is_ascii_digit() ||
    character == '-' ||
    character == '_'
  })
}

///|
pub fn mooncode_sandbox_relative_path(value : String) -> Bool {
  value.length() >= 1 &&
  value.length() <= 4_096 &&
  !value.has_prefix("/") &&
  !value.has_suffix("/") &&
  !value.contains("//") &&
  !value.contains("\\") &&
  !value.contains("\u{0}") &&
  !value.split("/").any(component => component == "." || component == "..")
}

///|
fn sandbox_evidence_path_array(
  json : Json,
  key : String,
) -> Result[Array[String], String] {
  guard sandbox_evidence_array(json, key) is Some(items) &&
    items.length() <= SandboxEvidenceMaxEntries else {
    return Err("sandbox receipt ’s path inventory is invalid")
  }
  let paths : Array[String] = []
  for item in items {
    guard item is String(path) &&
      mooncode_sandbox_relative_path(path) &&
      !paths.contains(path) else {
      return Err("sandbox receipt contains an unsafe or duplicate path")
    }
    paths.push(path)
  }
  Ok(paths)
}

///|
fn sandbox_evidence_limit_names(json : Json) -> Result[Array[String], String] {
  guard sandbox_evidence_array(json, "unverified_limits") is Some(items) &&
    items.length() <= 32 else {
    return Err("sandbox receipt residual limits are invalid")
  }
  let limits : Array[String] = []
  for item in items {
    guard item is String(value) &&
      value.length() >= 1 &&
      value.length() <= 64 &&
      value.all(character => {
        character.is_ascii_alphabetic() ||
        character.is_ascii_digit() ||
        character == '-' ||
        character == '_'
      }) &&
      !limits.contains(value) else {
      return Err("sandbox receipt residual limits are invalid")
    }
    limits.push(value)
  }
  Ok(limits)
}

///|
fn sandbox_evidence_fingerprint(entry : Json?) -> Result[String?, String] {
  guard entry is Some(entry) else { return Ok(None) }
  let kind = sandbox_evidence_string(entry, "kind", "")
  let fingerprint = sandbox_evidence_string(entry, "fingerprint", "")
  guard ["RegularFile", "DirectoryEntry", "SymbolicLink"].contains(kind) else {
    return Err("sandbox receipt contains an invalid scratch entry")
  }
  if kind == "RegularFile" {
    if sandbox_evidence_digest(fingerprint) {
      Ok(Some(fingerprint))
    } else {
      Err("sandbox receipt contains an invalid regular-file fingerprint")
    }
  } else if fingerprint == "" {
    Ok(None)
  } else if sandbox_evidence_digest(fingerprint) {
    Ok(Some(fingerprint))
  } else {
    Err("sandbox receipt contains an invalid scratch entry fingerprint")
  }
}

///|
fn sandbox_evidence_changes(
  json : Json,
) -> Result[Array[MoonCodeSandboxChange], String] {
  guard sandbox_evidence_array(json, "changes") is Some(items) &&
    items.length() <= SandboxEvidenceMaxEntries else {
    return Err("sandbox receipt change inventory is invalid")
  }
  let changes : Array[MoonCodeSandboxChange] = []
  for item in items {
    let path = sandbox_evidence_string(item, "relative_path", "")
    let change = sandbox_evidence_string(item, "change", "")
    guard mooncode_sandbox_relative_path(path) &&
      !changes.any(existing => existing.relative_path == path) &&
      ["Added", "Modified", "Removed"].contains(change) else {
      return Err("sandbox receipt contains an unsafe or duplicate change")
    }
    let before = sandbox_evidence_object(item, "before")
    let after = sandbox_evidence_object(item, "after")
    let before_fingerprint = match sandbox_evidence_fingerprint(before) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let after_fingerprint = match sandbox_evidence_fingerprint(after) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let after_kind = match after {
      Some(value) => sandbox_evidence_string(value, "kind", "")
      None => ""
    }
    let after_size_bytes = match after {
      Some(value) => sandbox_evidence_int64(value, "size_bytes")
      None => None
    }
    if after_size_bytes is Some(size) && size < 0L {
      return Err("sandbox receipt contains an invalid file size")
    }
    changes.push({
      relative_path: path,
      change,
      before_fingerprint,
      after_fingerprint,
      after_size_bytes,
      promotable: (change == "Added" || change == "Modified") &&
      after_kind == "RegularFile" &&
      after_fingerprint is Some(_),
    })
  }
  Ok(changes)
}

///|
fn sandbox_evidence_limits(
  json : Json,
) -> Result[MoonCodeSandboxLimits, String] {
  let limits = {
    wall_clock_ms: sandbox_evidence_int(json, "wall_clock_ms", 0),
    cpu_seconds: sandbox_evidence_int(json, "cpu_seconds", 0),
    memory_mib: sandbox_evidence_int(json, "memory_mib", 0),
    disk_mib: sandbox_evidence_int(json, "disk_mib", 0),
    processes: sandbox_evidence_int(json, "processes", 0),
    output_bytes: sandbox_evidence_int(json, "output_bytes", 0),
  }
  guard limits.wall_clock_ms > 0 &&
    limits.cpu_seconds > 0 &&
    limits.memory_mib > 0 &&
    limits.disk_mib > 0 &&
    limits.processes > 0 &&
    limits.output_bytes > 0 else {
    return Err("sandbox receipt limits are missing or invalid")
  }
  Ok(limits)
}

///|
/// Decode only the evidence fields MoonDesk is allowed to render or return to
/// the promotion broker. Unsupported and malformed states are rejected.
pub fn decode_mooncode_sandbox_receipt(
  json : Json,
) -> Result[MoonCodeSandboxReceipt, String] {
  let backend = sandbox_evidence_string(json, "backend", "")
  let enforcement = sandbox_evidence_string(json, "enforcement", "")
  let network = sandbox_evidence_string(json, "network", "")
  guard ["LocalOs", "MicroVm"].contains(backend) &&
    ["Enforced", "Degraded", "Refused"].contains(enforcement) &&
    ["Deny", "AllowList"].contains(network) else {
    return Err("sandbox receipt uses an unsupported enforcement state")
  }
  let approval_digest = sandbox_evidence_string(json, "approval_digest", "")
  let command_digest = sandbox_evidence_string(json, "command_digest", "")
  let profile_digest = sandbox_evidence_string(json, "profile_digest", "")
  guard sandbox_evidence_digest(approval_digest) &&
    sandbox_evidence_digest(command_digest) &&
    sandbox_evidence_digest(profile_digest) else {
    return Err("sandbox receipt digests are invalid")
  }
  let changed_paths = match sandbox_evidence_path_array(json, "changed_paths") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let changes = match sandbox_evidence_changes(json) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  guard changed_paths.length() == changes.length() &&
    changes.all(change => changed_paths.contains(change.relative_path)) else {
    return Err(
      "sandbox receipt path and structured change inventories disagree",
    )
  }
  let artifacts = match sandbox_evidence_path_array(json, "artifacts") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let limits = match
    sandbox_evidence_limits(
      sandbox_evidence_object(json, "limits").unwrap_or(Json::empty_object()),
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let unverified_limits = match sandbox_evidence_limit_names(json) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let retention_id = match sandbox_evidence_string(json, "retention_id", "") {
    "" => None
    value if sandbox_evidence_opaque_id(value) => Some(value)
    _ => return Err("sandbox receipt retention id is invalid")
  }
  Ok({
    backend,
    enforcement,
    cleanup_verified: sandbox_evidence_bool(json, "cleanup_verified", false),
    network,
    limits,
    unverified_limits,
    approval_digest,
    command_digest,
    profile_digest,
    changed_paths,
    changes,
    artifacts,
    retention_id,
  })
}

///|
pub fn MoonCodeSandboxReceipt::review_key(
  self : MoonCodeSandboxReceipt,
) -> String {
  self.retention_id.unwrap_or("") + ":" + self.command_digest
}

///|
pub fn MoonCodeSandboxReceipt::promotion_ready(
  self : MoonCodeSandboxReceipt,
) -> Bool {
  self.enforcement == "Enforced" &&
  self.cleanup_verified &&
  self.unverified_limits.length() == 0 &&
  self.retention_id is Some(_) &&
  self.changes.any(change => change.promotable)
}
