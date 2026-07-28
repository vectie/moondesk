///|
pub(all) enum MoonCodeLifecycleAction {
  Rename(String)
  Archive
  Restore
  Delete
} derive(Debug, Eq)

///|
pub(all) enum MoonCodeLifecycleStopReason {
  CancelledBeforeRequest
  SessionActive
} derive(Debug, Eq)

///|
pub(all) enum MoonCodeLifecycleFailure {
  MalformedAction
  UnsupportedAction(String)
  InvalidTitle
  TitleTooLong
  NotFound
  Conflict
  RuntimeUnavailable
  RuntimeFailure
  InvalidResult(String)
  UnsupportedProtocol(String)
  WrongOwner(String)
  WrongSession(expected~ : String, actual~ : String)
} derive(Debug, Eq)

///|
pub struct MoonCodeLifecycleResult {
  action : MoonCodeLifecycleAction
  session_id : MoonCodeSessionId
  title : String
  archived : Bool
  deleted : Bool
}

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
) -> Result[MoonCodeLifecycleAction, MoonCodeLifecycleFailure] {
  guard payload is Object(fields) else { return Err(MalformedAction) }
  guard fields.get("action") is Some(String(action)) else {
    return Err(MalformedAction)
  }
  match action {
    "rename" => {
      guard fields.get("title") is Some(String(raw_title)) else {
        return Err(InvalidTitle)
      }
      let title = raw_title.trim().to_owned()
      if title == "" {
        Err(InvalidTitle)
      } else if title.length() > 160 {
        Err(TitleTooLong)
      } else {
        Ok(Rename(title))
      }
    }
    "archive" => Ok(Archive)
    "restore" => Ok(Restore)
    "delete" => Ok(Delete)
    unsupported => Err(UnsupportedAction(unsupported))
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
) -> Result[Unit, MoonCodeLifecycleFailure] {
  match action {
    Rename(_) if archived => Err(NotFound)
    Rename(_) => Ok(())
    Archive if archived => Err(NotFound)
    Archive if status is Running || status is Queued => Err(Conflict)
    Archive => Ok(())
    Restore if !archived => Err(NotFound)
    Restore => Ok(())
    Delete if status is Running || status is Queued => Err(Conflict)
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
) -> Result[MoonCodeLifecycleResult, MoonCodeLifecycleFailure] {
  guard payload is Object(fields) else {
    return Err(InvalidResult("Lifecycle result must be an object"))
  }
  guard lifecycle_string(fields, "kind")
    is Some("mooncode-session-lifecycle-result") else {
    return Err(InvalidResult("Invalid lifecycle result kind"))
  }
  guard lifecycle_string(fields, "protocol") is Some(protocol) else {
    return Err(InvalidResult("Lifecycle protocol must be a string"))
  }
  if protocol != protocol_version() {
    return Err(UnsupportedProtocol(protocol))
  }
  guard lifecycle_string(fields, "owner") is Some(owner) else {
    return Err(InvalidResult("Lifecycle owner must be a string"))
  }
  if owner != "moonclaw" {
    return Err(WrongOwner(owner))
  }
  guard lifecycle_string(fields, "session_id") is Some(raw_session_id) else {
    return Err(InvalidResult("Lifecycle session_id is invalid"))
  }
  guard MoonCodeSessionId::parse(raw_session_id) is Some(session_id) else {
    return Err(InvalidResult("Lifecycle session_id is invalid"))
  }
  if expected_session_id != session_id {
    return Err(
      WrongSession(
        expected=expected_session_id.to_string(),
        actual=session_id.to_string(),
      ),
    )
  }
  guard lifecycle_string(fields, "action") is Some(raw_action) else {
    return Err(MalformedAction)
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
    return Err(InvalidResult("Lifecycle title must be a string"))
  }
  guard lifecycle_bool(fields, "archived") is Some(archived) else {
    return Err(InvalidResult("Lifecycle archived state must be a boolean"))
  }
  guard lifecycle_bool(fields, "deleted") is Some(deleted) else {
    return Err(InvalidResult("Lifecycle deleted state must be a boolean"))
  }
  if (action is Archive && !archived) ||
    (action is Restore && archived) ||
    (action is Delete && !deleted) {
    return Err(InvalidResult("Lifecycle result state contradicts action"))
  }
  Ok({ action, session_id, title, archived, deleted })
}
