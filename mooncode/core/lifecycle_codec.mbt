///|
pub(all) enum MoonCodeLifecycleAction {
  Rename(String)
  Archive
  Restore
  Delete
} derive(Debug, Eq)

///|
fn MoonCodeLifecycleAction::name(self : MoonCodeLifecycleAction) -> String {
  match self {
    Rename(_) => "rename"
    Archive => "archive"
    Restore => "restore"
    Delete => "delete"
  }
}

///|
pub fn decode_mooncode_lifecycle_action(
  payload : Json,
) -> Result[MoonCodeLifecycleAction, MoonCodeFailure] {
  guard payload is Object(fields) else {
    return Err(Malformed("Unsupported MoonCode session lifecycle action"))
  }
  guard fields.get("action") is Some(String(action)) else {
    return Err(Malformed("Unsupported MoonCode session lifecycle action"))
  }
  match action {
    "rename" => {
      guard fields.get("title") is Some(String(raw_title)) else {
        return Err(Malformed("A non-empty session title is required"))
      }
      let title = raw_title.trim().to_owned()
      if title == "" {
        Err(Malformed("A non-empty session title is required"))
      } else if title.length() > 160 {
        Err(Malformed("Session titles may not exceed 160 characters"))
      } else {
        Ok(Rename(title))
      }
    }
    "archive" => Ok(Archive)
    "restore" => Ok(Restore)
    "delete" => Ok(Delete)
    _ => Err(Malformed("Unsupported MoonCode session lifecycle action"))
  }
}

///|
pub fn encode_mooncode_lifecycle_action(
  action : MoonCodeLifecycleAction,
  book_root? : String,
) -> Json {
  let fields : Map[String, Json] = { "action": action.name().to_json() }
  if action is Rename(title) {
    fields["title"] = title.to_json()
  }
  match book_root {
    Some(root) => fields["book_root"] = root.to_json()
    None => ()
  }
  fields.to_json()
}

///|
pub fn mooncode_lifecycle_transition(
  action : MoonCodeLifecycleAction,
  status : MoonCodeSessionStatus,
  archived~ : Bool,
) -> Result[Unit, MoonCodeFailure] {
  match action {
    Rename(_) if archived => Err(Absent)
    Rename(_) => Ok(())
    Archive if archived => Err(Absent)
    Archive if status is Running || status is Queued =>
      Err(Malformed("MoonCode session lifecycle conflict"))
    Archive => Ok(())
    Restore if !archived => Err(Absent)
    Restore => Ok(())
    Delete if status is Running || status is Queued =>
      Err(Malformed("MoonCode session lifecycle conflict"))
    Delete => Ok(())
  }
}

///|
fn lifecycle_string(fields : Map[String, Json], key : String) -> String? {
  match fields.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn lifecycle_bool(fields : Map[String, Json], key : String) -> Bool? {
  match fields.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}

///|
pub fn decode_mooncode_lifecycle_result(
  payload : Json,
  expected_session_id~ : MoonCodeSessionId,
) -> Result[
  (MoonCodeLifecycleAction, MoonCodeSessionId, String, Bool, Bool),
  MoonCodeFailure,
] {
  guard payload is Object(fields) else {
    return Err(Malformed("Lifecycle result must be an object"))
  }
  guard lifecycle_string(fields, "kind")
    is Some("mooncode-session-lifecycle-result") else {
    return Err(Malformed("Invalid lifecycle result kind"))
  }
  guard lifecycle_string(fields, "protocol") is Some(protocol) else {
    return Err(Malformed("Lifecycle protocol must be a string"))
  }
  if protocol != protocol_version() {
    return Err(UnsupportedProtocol(protocol))
  }
  guard lifecycle_string(fields, "owner") is Some(owner) else {
    return Err(Malformed("Lifecycle owner must be a string"))
  }
  if owner != "moonclaw" {
    return Err(Malformed("Unexpected MoonCode lifecycle owner \{owner}"))
  }
  guard lifecycle_string(fields, "session_id") is Some(raw_session_id) else {
    return Err(Malformed("Lifecycle session_id is invalid"))
  }
  guard MoonCodeSessionId::parse(raw_session_id) is Some(session_id) else {
    return Err(Malformed("Lifecycle session_id is invalid"))
  }
  if expected_session_id != session_id {
    return Err(
      Malformed(
        "MoonCode lifecycle session mismatch: expected \{expected_session_id.to_string()}, got \{session_id.to_string()}",
      ),
    )
  }
  guard lifecycle_string(fields, "action") is Some(raw_action) else {
    return Err(Malformed("Unsupported MoonCode session lifecycle action"))
  }
  let action_payload : Json = match lifecycle_string(fields, "title") {
    Some(title) => { "action": raw_action, "title": title }
    None => { "action": raw_action }
  }
  let action = match decode_mooncode_lifecycle_action(action_payload) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  guard lifecycle_string(fields, "title") is Some(title) else {
    return Err(Malformed("Lifecycle title must be a string"))
  }
  guard lifecycle_bool(fields, "archived") is Some(archived) else {
    return Err(Malformed("Lifecycle archived state must be a boolean"))
  }
  guard lifecycle_bool(fields, "deleted") is Some(deleted) else {
    return Err(Malformed("Lifecycle deleted state must be a boolean"))
  }
  if (action is Archive && !archived) ||
    (action is Restore && archived) ||
    (action is Delete && !deleted) {
    return Err(Malformed("Lifecycle result state contradicts action"))
  }
  Ok((action, session_id, title, archived, deleted))
}
