///|
pub(all) struct MoonCodeMessage {
  item_id : String
  role : String
  content : String
  status : String
  command_id : String
  client_turn_id : String
  extensions : Map[String, Json]
} derive(Debug, Eq)

///|
pub(all) struct MoonCodeTurn {
  kind : String
  turn_id : String
  client_turn_id : String
  command_id : String
  ordinal : Int
  status : String
  started_at : String
  updated_at : String
  user : MoonCodeMessage?
  work : Json
  approvals : Array[MoonCodeApproval]
  assistant : MoonCodeMessage?
  extensions : Map[String, Json]
} derive(Debug, Eq)

///|
pub(all) struct MoonCodeConversation {
  kind : String
  protocol : String
  contract_id : String
  session_id : String
  workspace_id : String
  workspace_name : String
  turn_count : Int
  revision : Int
  last_sequence : Int
  source_event_count : Int
  turns : Array[MoonCodeTurn]
  extensions : Map[String, Json]
} derive(Debug, Eq)

///|
pub(all) enum MoonCodeConversationDecodeResult {
  Absent
  Supported(MoonCodeConversation)
  UnsupportedProtocol(String)
  UnsupportedContract(String)
  Stale(revision~ : Int, current_revision~ : Int)
  Malformed(String)
} derive(Debug, Eq)

///|
fn conversation_string(fields : Map[String, Json], key : String) -> String? {
  match fields.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn conversation_optional_string(
  fields : Map[String, Json],
  key : String,
  default : String,
) -> String? {
  match fields.get(key) {
    None => Some(default)
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn conversation_optional_int(
  fields : Map[String, Json],
  key : String,
  default : Int,
) -> Int? {
  match fields.get(key) {
    None => Some(default)
    Some(Number(value, ..)) => Some(value.to_int())
    _ => None
  }
}

///|
fn conversation_extensions(
  fields : Map[String, Json],
  known : Array[String],
) -> Map[String, Json] {
  let extensions : Map[String, Json] = {}
  for key, value in fields {
    if !known.contains(key) {
      extensions[key] = value
    }
  }
  extensions
}

///|
fn decode_conversation_message(
  value : Json,
  expected_role : String,
) -> Result[MoonCodeMessage?, String] {
  if value is Null {
    return Ok(None)
  }
  guard value is Object(fields) else {
    return Err("conversation message must be an object or null")
  }
  guard conversation_string(fields, "item_id") is Some(item_id) else {
    return Err("conversation message item_id must be a string")
  }
  guard conversation_string(fields, "status") is Some(status) else {
    return Err("conversation message status must be a string")
  }
  guard conversation_optional_string(fields, "role", expected_role)
    is Some(role) else {
    return Err("conversation message role must be a string")
  }
  guard role == expected_role else {
    return Err("conversation message role is invalid")
  }
  guard conversation_optional_string(fields, "content", "") is Some(content) else {
    return Err("conversation message content must be a string")
  }
  let optional = ["command_id", "client_turn_id"]
  let values : Array[String] = []
  for key in optional {
    guard conversation_optional_string(fields, key, "") is Some(value) else {
      return Err("conversation message \{key} must be a string")
    }
    values.push(value)
  }
  Ok(
    Some({
      item_id,
      role,
      content,
      status,
      command_id: values[0],
      client_turn_id: values[1],
      extensions: conversation_extensions(fields, [
        "item_id", "role", "content", "status", "command_id", "client_turn_id",
      ]),
    }),
  )
}

///|
fn decode_conversation_approvals(
  work : Json,
  session_id : String,
  command_id : String,
) -> Result[Array[MoonCodeApproval], String] {
  let approvals : Array[MoonCodeApproval] = []
  guard work is Object(work_fields) else { return Ok(approvals) }
  guard work_fields.get("steps") is Some(Array(steps)) else {
    return Ok(approvals)
  }
  for step in steps {
    guard step is Object(step_fields) else { continue }
    guard step_fields.get("evidence") is Some(evidence) else { continue }
    guard evidence is Object(evidence_fields) else { continue }
    guard evidence_fields.get("kind") is Some(String("approval")) else {
      continue
    }
    match decode_mooncode_approval(evidence, session_id, command_id) {
      Ok(approval) => approvals.push(approval)
      Err(Malformed(message)) => return Err(message)
      Err(UnsupportedState(state)) =>
        return Err("unsupported approval state: \{state}")
    }
  }
  Ok(approvals)
}

///|
fn decode_conversation_turn(
  value : Json,
  session_id : String,
) -> Result[MoonCodeTurn, String] {
  guard value is Object(fields) else {
    return Err("conversation turn must be an object")
  }
  let required = ["kind", "turn_id", "client_turn_id", "command_id", "status"]
  let values : Array[String] = []
  for key in required {
    guard conversation_string(fields, key) is Some(value) else {
      return Err("conversation turn \{key} must be a string")
    }
    values.push(value)
  }
  guard values[0] == conversation_turn_kind() else {
    return Err("conversation turn kind is invalid")
  }
  guard fields.get("ordinal") is Some(Number(raw_ordinal, ..)) else {
    return Err("conversation turn ordinal must be a number")
  }
  let ordinal = raw_ordinal.to_int()
  guard conversation_optional_string(fields, "started_at", "")
    is Some(started_at) else {
    return Err("conversation turn started_at must be a string")
  }
  guard conversation_optional_string(fields, "updated_at", "")
    is Some(updated_at) else {
    return Err("conversation turn updated_at must be a string")
  }
  guard fields.get("user") is Some(user_value) else {
    return Err("conversation turn user is required")
  }
  guard fields.get("work") is Some(work) else {
    return Err("conversation turn work is required")
  }
  guard fields.get("assistant") is Some(assistant_value) else {
    return Err("conversation turn assistant is required")
  }
  let user = match decode_conversation_message(user_value, "user") {
    Ok(message) => message
    Err(error) => return Err(error)
  }
  let assistant = match
    decode_conversation_message(assistant_value, "assistant") {
    Ok(message) => message
    Err(error) => return Err(error)
  }
  guard work is Object(_) else {
    return Err("conversation turn work must be an object")
  }
  let approvals = match
    decode_conversation_approvals(work, session_id, values[3]) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({
    kind: values[0],
    turn_id: values[1],
    client_turn_id: values[2],
    command_id: values[3],
    ordinal,
    status: values[4],
    started_at,
    updated_at,
    user,
    work,
    approvals,
    assistant,
    extensions: conversation_extensions(fields, [
      "kind", "turn_id", "client_turn_id", "command_id", "ordinal", "status", "started_at",
      "updated_at", "user", "work", "assistant",
    ]),
  })
}

///|
pub fn decode_mooncode_conversation(
  payload : Json,
  current_revision? : Int = 0,
) -> MoonCodeConversationDecodeResult {
  if payload is Null {
    return Absent
  }
  guard payload is Object(fields) else {
    return Malformed("conversation must be an object or null")
  }
  guard conversation_string(fields, "protocol") is Some(protocol) else {
    return Malformed("conversation protocol must be a string")
  }
  if protocol != protocol_version() {
    return UnsupportedProtocol(protocol)
  }
  guard conversation_string(fields, "contract_id") is Some(contract_id) else {
    return Malformed("conversation contract_id must be a string")
  }
  if contract_id != conversation_contract_id() {
    return UnsupportedContract(contract_id)
  }
  guard conversation_string(fields, "kind") is Some(kind) else {
    return Malformed("conversation kind must be a string")
  }
  guard kind == conversation_kind() else {
    return Malformed("conversation kind is invalid")
  }
  guard conversation_string(fields, "session_id") is Some(session_id) else {
    return Malformed("conversation session_id must be a string")
  }
  guard fields.get("revision") is Some(Number(raw_revision, ..)) else {
    return Malformed("conversation revision must be a number")
  }
  let revision = raw_revision.to_int()
  if revision < current_revision {
    return Stale(revision~, current_revision~)
  }
  let optional_strings = ["workspace_id", "workspace_name"]
  let string_values : Array[String] = []
  for key in optional_strings {
    guard conversation_optional_string(fields, key, "") is Some(value) else {
      return Malformed("conversation \{key} must be a string")
    }
    string_values.push(value)
  }
  let optional_ints = ["turn_count", "source_event_count"]
  let int_values : Array[Int] = []
  for key in optional_ints {
    guard conversation_optional_int(fields, key, 0) is Some(value) else {
      return Malformed("conversation \{key} must be a number")
    }
    int_values.push(value)
  }
  guard fields.get("last_sequence") is Some(Number(raw_last_sequence, ..)) else {
    return Malformed("conversation last_sequence must be a number")
  }
  let last_sequence = raw_last_sequence.to_int()
  guard fields.get("turns") is Some(Array(raw_turns)) else {
    return Malformed("conversation turns must be an array")
  }
  let turns : Array[MoonCodeTurn] = []
  for value in raw_turns {
    match decode_conversation_turn(value, session_id) {
      Ok(turn) => turns.push(turn)
      Err(error) => return Malformed(error)
    }
  }
  Supported({
    kind,
    protocol,
    contract_id,
    session_id,
    workspace_id: string_values[0],
    workspace_name: string_values[1],
    turn_count: int_values[0],
    revision,
    last_sequence,
    source_event_count: int_values[1],
    turns,
    extensions: conversation_extensions(fields, [
      "kind", "protocol", "contract_id", "session_id", "workspace_id", "workspace_name",
      "turn_count", "revision", "last_sequence", "source_event_count", "turns",
    ]),
  })
}

///|
fn encode_mooncode_message(message : MoonCodeMessage?) -> Json {
  match message {
    None => Json::null()
    Some(message) => {
      let fields = message.extensions.copy()
      fields["item_id"] = message.item_id.to_json()
      fields["role"] = message.role.to_json()
      fields["content"] = message.content.to_json()
      fields["status"] = message.status.to_json()
      fields["command_id"] = message.command_id.to_json()
      fields["client_turn_id"] = message.client_turn_id.to_json()
      Json::object(fields)
    }
  }
}

///|
pub fn encode_mooncode_conversation(
  conversation : MoonCodeConversation,
) -> Json {
  let turns : Array[Json] = []
  for turn in conversation.turns {
    let fields = turn.extensions.copy()
    fields["kind"] = turn.kind.to_json()
    fields["turn_id"] = turn.turn_id.to_json()
    fields["client_turn_id"] = turn.client_turn_id.to_json()
    fields["command_id"] = turn.command_id.to_json()
    fields["ordinal"] = turn.ordinal.to_json()
    fields["status"] = turn.status.to_json()
    fields["started_at"] = turn.started_at.to_json()
    fields["updated_at"] = turn.updated_at.to_json()
    fields["user"] = encode_mooncode_message(turn.user)
    fields["work"] = turn.work
    fields["assistant"] = encode_mooncode_message(turn.assistant)
    turns.push(Json::object(fields))
  }
  let fields = conversation.extensions.copy()
  fields["kind"] = conversation.kind.to_json()
  fields["protocol"] = conversation.protocol.to_json()
  fields["contract_id"] = conversation.contract_id.to_json()
  fields["session_id"] = conversation.session_id.to_json()
  fields["workspace_id"] = conversation.workspace_id.to_json()
  fields["workspace_name"] = conversation.workspace_name.to_json()
  fields["turn_count"] = conversation.turn_count.to_json()
  fields["revision"] = conversation.revision.to_json()
  fields["last_sequence"] = conversation.last_sequence.to_json()
  fields["source_event_count"] = conversation.source_event_count.to_json()
  fields["turns"] = Json::array(turns)
  Json::object(fields)
}

///|
pub impl FromJson for MoonCodeConversation with fn from_json(value, path) {
  match decode_mooncode_conversation(value) {
    Supported(conversation) => conversation
    Absent =>
      raise @json.JsonDecodeError((path, "canonical conversation is absent"))
    UnsupportedProtocol(protocol) =>
      raise @json.JsonDecodeError(
        (path, "unsupported conversation protocol \{protocol}"),
      )
    UnsupportedContract(contract) =>
      raise @json.JsonDecodeError(
        (path, "unsupported conversation contract \{contract}"),
      )
    Stale(revision~, current_revision~) =>
      raise @json.JsonDecodeError(
        (path, "stale conversation revision \{revision} < \{current_revision}"),
      )
    Malformed(error) => raise @json.JsonDecodeError((path, error))
  }
}
