///|
pub struct MoonCodeSessionId(String) derive(Debug, Eq)

///|
pub fn MoonCodeSessionId::parse(value : String) -> MoonCodeSessionId? {
  if value.trim() == "" {
    None
  } else {
    Some(MoonCodeSessionId(value))
  }
}

///|
pub fn MoonCodeSessionId::to_string(self : MoonCodeSessionId) -> String {
  let MoonCodeSessionId(value) = self
  value
}

///|
pub(all) enum MoonCodeSessionStatus {
  Created
  Queued
  Running
  Idle
  Done
  Failed
  Cancelled
  Durable
} derive(Debug, Eq)

///|
pub fn MoonCodeSessionStatus::parse(value : String) -> MoonCodeSessionStatus? {
  match value {
    "created" => Some(Created)
    "queued" => Some(Queued)
    "running" => Some(Running)
    "idle" => Some(Idle)
    "done" => Some(Done)
    "failed" => Some(Failed)
    "cancelled" => Some(Cancelled)
    "durable" => Some(Durable)
    _ => None
  }
}

///|
pub fn MoonCodeSessionStatus::to_string(self : MoonCodeSessionStatus) -> String {
  match self {
    Created => "created"
    Queued => "queued"
    Running => "running"
    Idle => "idle"
    Done => "done"
    Failed => "failed"
    Cancelled => "cancelled"
    Durable => "durable"
  }
}

///|
pub(all) struct MoonCodeSessionSummary {
  id : MoonCodeSessionId
  workspace_id : String
  workspace_name : String
  cwd : String
  source : String?
  runtime_session_id : String?
  title : String
  updated_at : String?
  model : String
  status : MoonCodeSessionStatus
  queued_count : Int
  last_message : String?
  archived : Bool
  extensions : Map[String, Json]
} derive(Debug, Eq)

///|
pub(all) enum MoonCodeSessionListingDecodeResult {
  Supported(Array[MoonCodeSessionSummary])
  UnsupportedVersion(Int)
  Malformed(String)
} derive(Debug, Eq)

///|
pub(all) enum MoonCodeSelectedSessionDecodeResult {
  Supported(MoonCodeSessionSummary)
  UnsupportedVersion(Int)
  Malformed(String)
} derive(Debug, Eq)

///|
fn listing_string(fields : Map[String, Json], key : String) -> String? {
  match fields.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn listing_int(fields : Map[String, Json], key : String, default : Int) -> Int? {
  match fields.get(key) {
    None => Some(default)
    Some(Number(value, ..)) => Some(value.to_int())
    _ => None
  }
}

///|
fn listing_bool(
  fields : Map[String, Json],
  key : String,
  default : Bool,
) -> Bool? {
  match fields.get(key) {
    None => Some(default)
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}

///|
fn listing_version(protocol : String) -> Int? {
  guard protocol.has_prefix("mooncode.v") else { return None }
  try @string.parse_int(protocol["mooncode.v".length():].to_owned()) catch {
    _ => None
  } noraise {
    version => Some(version)
  }
}

///|
fn decode_listing_row(row : Json) -> Result[MoonCodeSessionSummary, String] {
  guard row is Object(fields) else {
    return Err("session row must be an object")
  }
  guard listing_string(fields, "id") is Some(raw_id) else {
    return Err("session id must be a string")
  }
  guard MoonCodeSessionId::parse(raw_id) is Some(id) else {
    return Err("session id is invalid")
  }
  guard listing_string(fields, "status") is Some(raw_status) else {
    return Err("session status must be a string")
  }
  guard MoonCodeSessionStatus::parse(raw_status) is Some(status) else {
    return Err("session status is invalid")
  }
  let string_fields = [
    "workspace_id", "workspace_name", "cwd", "source", "mooncode_runtime_session_id",
    "title", "updated_at", "model", "last_message",
  ]
  for key in string_fields {
    match fields.get(key) {
      None | Some(String(_)) => ()
      _ => return Err("\{key} must be a string")
    }
  }
  guard listing_int(fields, "queued_count", 0) is Some(queued_count) else {
    return Err("queued_count must be an integer")
  }
  guard listing_bool(fields, "archived", false) is Some(archived) else {
    return Err("archived must be a boolean")
  }
  let workspace_id = listing_string(fields, "workspace_id").unwrap_or("")
  let workspace_name = listing_string(fields, "workspace_name").unwrap_or("")
  let cwd = listing_string(fields, "cwd").unwrap_or("")
  let title = listing_string(fields, "title").unwrap_or(raw_id)
  let model = listing_string(fields, "model").unwrap_or("")
  let extensions : Map[String, Json] = Map([])
  for key, value in fields {
    if ![
        "id", "workspace_id", "workspace_name", "cwd", "source", "mooncode_runtime_session_id",
        "title", "updated_at", "model", "status", "queued_count", "last_message",
        "archived",
      ].contains(key) {
      extensions[key] = value
    }
  }
  Ok({
    id,
    workspace_id,
    workspace_name,
    cwd,
    source: listing_string(fields, "source"),
    runtime_session_id: listing_string(fields, "mooncode_runtime_session_id"),
    title,
    updated_at: listing_string(fields, "updated_at"),
    model,
    status,
    queued_count,
    last_message: listing_string(fields, "last_message"),
    archived,
    extensions,
  })
}

///|
pub fn decode_mooncode_selected_session(
  payload : Json,
) -> MoonCodeSelectedSessionDecodeResult {
  guard payload is Object(fields) else {
    return Malformed("selected session payload must be an object")
  }
  match fields.get("protocol") {
    None => ()
    Some(String(protocol)) => {
      guard listing_version(protocol) is Some(version) else {
        return Malformed(
          "selected session protocol must identify a MoonCode version",
        )
      }
      if version != 1 {
        return UnsupportedVersion(version)
      }
    }
    _ => return Malformed("selected session protocol must be a string")
  }
  match decode_listing_row(payload) {
    Ok(summary) => Supported(summary)
    Err(error) => Malformed(error)
  }
}

///|
pub fn decode_mooncode_session_listing(
  payload : Json,
) -> MoonCodeSessionListingDecodeResult {
  let rows = match payload {
    Array(rows) => rows
    Object(fields) => {
      guard fields.get("sessions") is Some(Array(rows)) else {
        return Malformed("listing sessions must be an array")
      }
      rows
    }
    _ => return Malformed("listing payload must be an array or object")
  }
  if payload is Object(fields) {
    match fields.get("protocol") {
      None => ()
      Some(String(protocol)) => {
        guard listing_version(protocol) is Some(version) else {
          return Malformed("listing protocol must identify a MoonCode version")
        }
        if version != 1 {
          return UnsupportedVersion(version)
        }
      }
      _ => return Malformed("listing protocol must be a string")
    }
  }
  let summaries : Array[MoonCodeSessionSummary] = []
  for row in rows {
    match decode_listing_row(row) {
      Ok(summary) => summaries.push(summary)
      Err(error) => return Malformed(error)
    }
  }
  Supported(summaries)
}

///|
pub fn encode_mooncode_session_summary(
  summary : MoonCodeSessionSummary,
) -> Json {
  let fields : Map[String, Json] = Map([])
  for key, value in summary.extensions {
    fields[key] = value
  }
  fields["id"] = summary.id.to_string().to_json()
  fields["workspace_id"] = summary.workspace_id.to_json()
  fields["workspace_name"] = summary.workspace_name.to_json()
  fields["cwd"] = summary.cwd.to_json()
  fields["title"] = summary.title.to_json()
  fields["model"] = summary.model.to_json()
  fields["status"] = summary.status.to_string().to_json()
  fields["queued_count"] = summary.queued_count.to_json()
  fields["archived"] = summary.archived.to_json()
  match summary.source {
    Some(value) => fields["source"] = value.to_json()
    None => ()
  }
  match summary.runtime_session_id {
    Some(value) => fields["mooncode_runtime_session_id"] = value.to_json()
    None => ()
  }
  match summary.updated_at {
    Some(value) => fields["updated_at"] = value.to_json()
    None => ()
  }
  match summary.last_message {
    Some(value) => fields["last_message"] = value.to_json()
    None => ()
  }
  Json::object(fields)
}
