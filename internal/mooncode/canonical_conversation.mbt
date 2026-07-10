///|
pub fn session_canonical_conversation(session : Json) -> Json {
  let supplied = summary_json_object_field_or_empty(
    session, "mooncode_conversation",
  )
  if session_canonical_conversation_belongs_to_session(session, supplied) {
    supplied
  } else {
    empty_canonical_conversation(session)
  }
}

///|
pub fn empty_canonical_conversation(session : Json) -> Json {
  {
    "kind": conversation_kind(),
    "protocol": protocol_version(),
    "contract_id": conversation_contract_id(),
    "session_id": json_string(session, "id", default=""),
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "revision": 0,
    "last_sequence": 0,
    "turn_count": 0,
    "source_event_count": 0,
    "turns": [],
    "owner": {
      "projection": "moonclaw",
      "runtime": "moonclaw",
      "ui": "moondesk",
    },
  }
}

///|
pub fn conversation_ownership_contract_json() -> Json {
  @mooncode_core.conversation_ownership_contract_json()
}

///|
fn session_canonical_conversation_belongs_to_session(
  session : Json,
  conversation : Json,
) -> Bool {
  let session_id = json_string(session, "id", default="")
  session_id != "" &&
  json_string(conversation, "kind", default="") == conversation_kind() &&
  json_string(conversation, "contract_id", default="") ==
  conversation_contract_id() &&
  json_string(conversation, "session_id", default="") == session_id
}
