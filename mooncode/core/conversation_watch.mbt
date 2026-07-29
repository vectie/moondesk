///|
pub struct MoonCodeWatchCursor {
  revision : String
  sequence : String
} derive(Debug, Eq)

///|
pub fn mooncode_watch_cursor(
  revision : String,
  sequence : String,
) -> MoonCodeWatchCursor raise {
  if !canonical_decimal_is_valid(revision) ||
    !watch_sequence_is_canonical(sequence) {
    fail(
      "MoonCode watch cursor must have a nonnegative revision and canonical sequence",
    )
  }
  { revision, sequence }
}

///|
pub fn mooncode_watch_origin_cursor() -> MoonCodeWatchCursor {
  { revision: "0", sequence: "0" }
}

///|
fn watch_sequence_is_canonical(value : String) -> Bool {
  if value == "0" {
    return true
  }
  if value == "" || value[0] == '0' {
    return false
  }
  for code in value {
    if code < '0' || code > '9' {
      return false
    }
  }
  true
}

///|
pub fn MoonCodeWatchCursor::revision(self : MoonCodeWatchCursor) -> String {
  self.revision
}

///|
pub fn MoonCodeWatchCursor::sequence(self : MoonCodeWatchCursor) -> String {
  self.sequence
}

///|
fn watch_advance_cursor(
  current : MoonCodeWatchCursor,
  revision : String,
  sequence : String,
  accept_revision? : Bool = true,
) -> MoonCodeWatchCursor {
  {
    revision: if accept_revision &&
      canonical_decimal_compare(revision, current.revision) > 0 {
      revision
    } else {
      current.revision
    },
    sequence: if watch_sequence_compare(sequence, current.sequence) > 0 {
      sequence
    } else {
      current.sequence
    },
  }
}

///|
pub fn MoonCodeWatchCursor::advance_sequence(
  self : MoonCodeWatchCursor,
  sequence : String,
) -> MoonCodeWatchCursor raise {
  if !watch_sequence_is_canonical(sequence) {
    fail("MoonCode watch cursor sequence must be canonical")
  }
  watch_advance_cursor(self, self.revision, sequence, accept_revision=false)
}

///|
fn watch_sequence_compare(left : String, right : String) -> Int {
  if left.length() < right.length() {
    -1
  } else if left.length() > right.length() {
    1
  } else {
    left.compare(right)
  }
}

///|
pub(all) enum MoonCodeWatchResult {
  Snapshot(
    cursor~ : MoonCodeWatchCursor,
    session~ : MoonCodeSessionSummary,
    conversation~ : MoonCodeConversation,
    terminal~ : Bool
  )
  Heartbeat(
    cursor~ : MoonCodeWatchCursor,
    session_id~ : String,
    retry_after_ms~ : Int,
    terminal~ : Bool
  )
  Duplicate(cursor~ : MoonCodeWatchCursor, session_id~ : String)
  Rollback(
    cursor~ : MoonCodeWatchCursor,
    session_id~ : String,
    received_revision~ : String
  )
  Disconnected(cursor~ : MoonCodeWatchCursor, reason~ : String)
  Malformed(cursor~ : MoonCodeWatchCursor, reason~ : String)
} derive(Debug, Eq)

///|
pub fn MoonCodeWatchResult::cursor(
  self : MoonCodeWatchResult,
) -> MoonCodeWatchCursor {
  match self {
    Snapshot(cursor~, ..)
    | Heartbeat(cursor~, ..)
    | Duplicate(cursor~, ..)
    | Rollback(cursor~, ..)
    | Disconnected(cursor~, ..)
    | Malformed(cursor~, ..) => cursor
  }
}

///|
fn watch_required_string(
  fields : Map[String, Json],
  key : String,
) -> Result[String, String] {
  match fields.get(key) {
    Some(String(value)) => Ok(value)
    Some(_) => Err("watch \{key} must be a string")
    None => Err("watch \{key} is required")
  }
}

///|
fn watch_required_nonnegative_int(
  fields : Map[String, Json],
  key : String,
) -> Result[Int, String] {
  match fields.get(key) {
    Some(Number(value, ..)) => {
      let parsed = value.to_int()
      if parsed < 0 || value != Double::from_int(parsed) {
        Err("watch \{key} must be a nonnegative integer")
      } else {
        Ok(parsed)
      }
    }
    Some(_) => Err("watch \{key} must be a nonnegative integer")
    None => Err("watch \{key} is required")
  }
}

///|
fn watch_required_bool(
  fields : Map[String, Json],
  key : String,
) -> Result[Bool, String] {
  match fields.get(key) {
    Some(True) => Ok(true)
    Some(False) => Ok(false)
    Some(_) => Err("watch \{key} must be a boolean")
    None => Err("watch \{key} is required")
  }
}

///|
pub fn decode_mooncode_watch_result(
  payload : Json,
  current~ : MoonCodeWatchCursor,
  expected_session_id? : String = "",
) -> MoonCodeWatchResult {
  guard payload is Object(fields) else {
    return Malformed(cursor=current, reason="watch response must be an object")
  }
  let kind = match watch_required_string(fields, "kind") {
    Ok(value) => value
    Err(reason) => return Malformed(cursor=current, reason~)
  }
  if kind != conversation_watch_kind() {
    return Malformed(cursor=current, reason="watch kind is invalid")
  }
  let contract_id = match watch_required_string(fields, "contract_id") {
    Ok(value) => value
    Err(reason) => return Malformed(cursor=current, reason~)
  }
  if contract_id != conversation_watch_contract_id() &&
    contract_id != "moonsuite-conversation-watch.v1" {
    return Malformed(cursor=current, reason="watch contract_id is unsupported")
  }
  let session_id = match watch_required_string(fields, "session_id") {
    Ok(value) => value
    Err(reason) => return Malformed(cursor=current, reason~)
  }
  if expected_session_id != "" && session_id != expected_session_id {
    return Malformed(cursor=current, reason="watch session_id does not match")
  }
  let revision = if contract_id == conversation_watch_contract_id() {
    match fields.get("revision") {
      Some(String(value)) if canonical_decimal_is_valid(value) => value
      Some(_) =>
        return Malformed(
          cursor=current,
          reason="watch revision must be a canonical nonnegative decimal string",
        )
      None =>
        return Malformed(cursor=current, reason="watch revision is required")
    }
  } else {
    match watch_required_nonnegative_int(fields, "revision") {
      Ok(value) => value.to_string()
      Err(reason) => return Malformed(cursor=current, reason~)
    }
  }
  let next_sequence = if contract_id == conversation_watch_contract_id() {
    match fields.get("next_sequence") {
      Some(String(value)) if canonical_decimal_is_valid(value) => value
      Some(_) =>
        return Malformed(
          cursor=current,
          reason="watch next_sequence must be a canonical nonnegative decimal string",
        )
      None =>
        return Malformed(
          cursor=current,
          reason="watch next_sequence is required",
        )
    }
  } else {
    match watch_required_nonnegative_int(fields, "next_sequence") {
      Ok(value) => value.to_string()
      Err(reason) => return Malformed(cursor=current, reason~)
    }
  }
  let changed = match watch_required_bool(fields, "changed") {
    Ok(value) => value
    Err(reason) => return Malformed(cursor=current, reason~)
  }
  let heartbeat = match watch_required_bool(fields, "heartbeat") {
    Ok(value) => value
    Err(reason) => return Malformed(cursor=current, reason~)
  }
  let terminal = match watch_required_bool(fields, "terminal") {
    Ok(value) => value
    Err(reason) => return Malformed(cursor=current, reason~)
  }
  let retry_after_ms = match
    watch_required_nonnegative_int(fields, "retry_after_ms") {
    Ok(value) => value
    Err(reason) => return Malformed(cursor=current, reason~)
  }
  if changed == heartbeat {
    return Malformed(
      cursor=current,
      reason="watch response must be either changed or heartbeat",
    )
  }
  let next_cursor = watch_advance_cursor(
    current,
    revision,
    next_sequence,
    accept_revision=changed,
  )
  if canonical_decimal_compare(revision, current.revision) < 0 {
    return Rollback(cursor=next_cursor, session_id~, received_revision=revision)
  }
  if changed {
    match fields.get("snapshot") {
      Some(Null) | None =>
        Malformed(
          cursor=current,
          reason="changed watch response requires snapshot",
        )
      Some(snapshot) => {
        let session = match decode_mooncode_selected_session(snapshot) {
          Supported(session) => session
          UnsupportedVersion(version) =>
            return Malformed(
              cursor=current,
              reason="watch snapshot uses unsupported session version \{version}",
            )
          Malformed(reason) => return Malformed(cursor=current, reason~)
        }
        if session.id.to_string() != session_id {
          return Malformed(
            cursor=current,
            reason="watch snapshot session_id does not match",
          )
        }
        let conversation_payload = match snapshot {
          Object(snapshot_fields) =>
            snapshot_fields.get("mooncode_conversation").unwrap_or(Json::null())
          _ => Json::null()
        }
        match decode_mooncode_conversation(conversation_payload) {
          Supported(conversation) if conversation.session_id == session_id &&
            conversation.revision == revision =>
            if revision == current.revision {
              Duplicate(cursor=next_cursor, session_id~)
            } else {
              Snapshot(cursor=next_cursor, session~, conversation~, terminal~)
            }
          Malformed(reason) =>
            Malformed(cursor=current, reason="watch snapshot \{reason}")
          _ =>
            Malformed(
              cursor=current,
              reason="watch snapshot conversation is unsupported",
            )
        }
      }
    }
  } else {
    match fields.get("snapshot") {
      Some(Null) | None =>
        Heartbeat(cursor=next_cursor, session_id~, retry_after_ms~, terminal~)
      Some(_) =>
        Malformed(cursor=current, reason="heartbeat snapshot must be null")
    }
  }
}

///|
pub fn decode_mooncode_watch_text(
  text : String,
  current~ : MoonCodeWatchCursor,
  expected_session_id? : String = "",
) -> MoonCodeWatchResult {
  let payload = @json.parse(text) catch {
    error =>
      return Malformed(
        cursor=current,
        reason="invalid watch response: \{error}",
      )
  }
  decode_mooncode_watch_result(payload, current~, expected_session_id~)
}

///|
pub fn mooncode_watch_disconnected(
  current~ : MoonCodeWatchCursor,
  reason~ : String,
) -> MoonCodeWatchResult {
  Disconnected(cursor=current, reason~)
}

///|
pub(all) enum MoonCodeStreamCursorDecodeResult {
  Advanced(MoonCodeWatchCursor)
  Unchanged(MoonCodeWatchCursor)
  Malformed(cursor~ : MoonCodeWatchCursor, reason~ : String)
} derive(Debug, Eq)

///|
pub fn decode_mooncode_stream_cursor(
  text : String,
  current~ : MoonCodeWatchCursor,
) -> MoonCodeStreamCursorDecodeResult {
  let mut next = current
  for line in text.split("\n") {
    let trimmed = line.trim().to_owned()
    if trimmed != "" {
      let record = @json.parse(trimmed) catch {
        error =>
          return Malformed(
            cursor=current,
            reason="invalid stream record: \{error}",
          )
      }
      guard record is Object(fields) else {
        return Malformed(
          cursor=current,
          reason="stream record must be an object",
        )
      }
      let type_ = match watch_required_string(fields, "type") {
        Ok(value) => value
        Err(reason) => return Malformed(cursor=current, reason~)
      }
      let sequence_key = if type_ == "meta" { "next_since" } else { "sequence" }
      if type_ == "meta" || type_ == "event" || type_ == "done" {
        let sequence = match fields.get(sequence_key) {
          Some(String(value)) if watch_sequence_is_canonical(value) => value
          Some(_) =>
            return Malformed(
              cursor=current,
              reason="stream \{sequence_key} must be a canonical nonnegative decimal string",
            )
          None =>
            return Malformed(
              cursor=current,
              reason="stream \{sequence_key} is required",
            )
        }
        next = watch_advance_cursor(
          next,
          next.revision,
          sequence,
          accept_revision=false,
        )
      } else {
        return Malformed(cursor=current, reason="stream type is unsupported")
      }
    }
  }
  if watch_sequence_compare(next.sequence, current.sequence) == 0 {
    Unchanged(next)
  } else {
    Advanced(next)
  }
}

///|
pub fn conversation_watch_response_for_cursor(
  session_id~ : String,
  cursor~ : MoonCodeWatchCursor,
  changed~ : Bool,
  heartbeat~ : Bool,
  terminal~ : Bool,
  retry_after_ms~ : Int,
  snapshot~ : Json,
) -> Json {
  let encoded = conversation_watch_response(
    session_id~,
    revision=cursor.revision(),
    next_sequence=cursor.sequence(),
    changed~,
    heartbeat~,
    terminal~,
    retry_after_ms~,
    snapshot~,
  )
  encoded
}

///|
pub fn conversation_watch_contract_id() -> String {
  "moonsuite-conversation-watch.v2"
}

///|
pub fn conversation_watch_kind() -> String {
  @conversation.watch_kind()
}

///|
pub fn conversation_watch_contract_json() -> Json {
  {
    "kind": "moonsuite-conversation-watch-contract",
    "contract_id": conversation_watch_contract_id(),
    "required_fields": [
      "contract_id", "session_id", "revision", "next_sequence", "changed", "heartbeat",
      "terminal", "retry_after_ms", "snapshot",
    ],
    "cursor_encoding": "canonical nonnegative decimal JSON string",
    "resume_rule": "Resume with the last accepted revision and next_sequence; arbitrary-precision cursors may advance but never move backward.",
    "payload_rule": "Changed responses carry one canonical snapshot. Heartbeats carry no transcript rows, runtime events, or diagnostic records.",
    "contract_owner": "mooncode",
    "base_contract_owner": "moonlib",
  }
}

///|
pub fn conversation_watch_response(
  session_id~ : String,
  revision~ : String,
  next_sequence~ : String,
  changed~ : Bool,
  heartbeat~ : Bool,
  terminal~ : Bool,
  retry_after_ms~ : Int,
  snapshot~ : Json,
) -> Json {
  {
    "kind": conversation_watch_kind(),
    "contract_id": conversation_watch_contract_id(),
    "session_id": session_id,
    "revision": revision,
    "next_sequence": next_sequence,
    "changed": changed,
    "heartbeat": heartbeat,
    "terminal": terminal,
    "retry_after_ms": @conversation.watch_retry_after_ms_value(retry_after_ms),
    "snapshot": snapshot,
  }
}
