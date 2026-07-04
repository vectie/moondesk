///|
struct MoonCodeCanonicalTurn {
  mut client_turn_id : String
  mut user : MoonCodeTranscriptRow?
  body_items : Array[MoonCodeTranscriptItem]
}

///|
fn mooncode_canonical_transcript_items(
  model : Model,
  session : MoonCodeSession,
) -> Array[MoonCodeTranscriptItem] {
  mooncode_canonical_conversation_items(model, session)
}

///|
fn mooncode_canonical_conversation_items(
  model : Model,
  session : MoonCodeSession,
) -> Array[MoonCodeTranscriptItem] {
  let turns = mooncode_canonical_turns_from_backend_conversation(session)
  mooncode_canonical_append_local_conversation_rows(turns, model, session.id)
  if turns.length() == 0 {
    return []
  }
  let items : Array[MoonCodeTranscriptItem] = []
  for turn in turns {
    mooncode_canonical_push_turn_items(items, turn)
  }
  mooncode_compact_folded_thinking_items(
    mooncode_fold_resolved_thinking_items(items),
  )
}

///|
fn mooncode_canonical_turns_from_backend_conversation(
  session : MoonCodeSession,
) -> Array[MoonCodeCanonicalTurn] {
  let turns : Array[MoonCodeCanonicalTurn] = []
  match session.mooncode_conversation {
    Some(conversation) => {
      mooncode_canonical_note_conversation_metadata(conversation)
      for backend_turn in conversation.turns {
        mooncode_canonical_note_turn_metadata(backend_turn)
        let turn = mooncode_canonical_empty_turn()
        turn.client_turn_id = backend_turn.client_turn_id
        match mooncode_canonical_message_row_from_json(backend_turn.user) {
          Some(row) => turn.user = Some(row)
          None => ()
        }
        for progress in backend_turn.progress {
          match mooncode_canonical_progress_item_from_json(progress) {
            Some(item) => turn.body_items.push(item)
            None => ()
          }
        }
        match mooncode_canonical_message_row_from_json(backend_turn.assistant) {
          Some(row) => {
            turn.body_items.push(mooncode_transcript_message_item(row))
          }
          None => ()
        }
        if turn.user is Some(_) || turn.body_items.length() > 0 {
          turns.push(turn)
        }
      }
    }
    None => ()
  }
  turns
}

///|
fn mooncode_canonical_note_conversation_metadata(
  conversation : MoonCodeConversation,
) -> Unit {
  ignore(conversation.kind)
  ignore(conversation.protocol)
  ignore(conversation.session_id)
  ignore(conversation.workspace_id)
  ignore(conversation.workspace_name)
  ignore(conversation.turn_count)
  ignore(conversation.source_event_count)
}

///|
fn mooncode_canonical_note_turn_metadata(
  turn : MoonCodeConversationTurn,
) -> Unit {
  ignore(turn.kind)
  ignore(turn.turn_id)
  ignore(turn.client_turn_id)
  ignore(turn.command_id)
  ignore(turn.status)
  ignore(turn.started_at)
  ignore(turn.updated_at)
  ignore(turn.items)
}

///|
fn mooncode_canonical_message_row_from_json(
  value : Json,
) -> MoonCodeTranscriptRow? {
  let content = json_field_string(value, "content", default="").trim().to_owned()
  if content == "" {
    return None
  }
  Some({
    role: mooncode_transcript_message_role(
      json_field_string(value, "role", default="assistant"),
    ),
    content,
    status: json_field_string(value, "status", default="done"),
  })
}

///|
fn mooncode_canonical_progress_item_from_json(
  value : Json,
) -> MoonCodeTranscriptItem? {
  let title = mooncode_canonical_first_json_text(
    value,
    ["title", "summary", "content", "detail"],
  )
  let detail = mooncode_canonical_first_json_text(value, ["detail", "content"])
  if title == "" && detail == "" {
    return None
  }
  let status = json_field_string(value, "status", default="running")
  Some(
    mooncode_transcript_activity_item({
      tone: if status == "failed" { "failed" } else { "thinking" },
      label: "Progress",
      title: if title == "" { "Working on it" } else { title },
      detail,
      status,
      folded: status != "running",
    }),
  )
}

///|
fn mooncode_canonical_first_json_text(
  value : Json,
  keys : Array[String],
) -> String {
  for key in keys {
    let text = json_field_string(value, key, default="").trim().to_owned()
    if text != "" {
      return text
    }
  }
  ""
}

///|
fn mooncode_canonical_empty_turn() -> MoonCodeCanonicalTurn {
  {
    client_turn_id: "",
    user: None,
    body_items: [],
  }
}

///|
fn mooncode_canonical_append_local_conversation_rows(
  turns : Array[MoonCodeCanonicalTurn],
  model : Model,
  session_id : String,
) -> Unit {
  for row in model.mooncode_conversation_rows {
    if row.session_id != session_id {
      continue
    }
    let role = mooncode_transcript_message_role(row.role)
    let content = row.content.trim().to_owned()
    if content == "" {
      continue
    }
    if role == "user" {
      if row.key != "" &&
        mooncode_canonical_turns_have_client_turn_id(turns, row.key) {
        continue
      }
      let turn = mooncode_canonical_empty_turn()
      turn.client_turn_id = row.key
      turn.user = Some({ role: "user", content, status: row.status })
      turns.push(turn)
    }
  }
}

///|
fn mooncode_canonical_turns_have_client_turn_id(
  turns : Array[MoonCodeCanonicalTurn],
  client_turn_id : String,
) -> Bool {
  if client_turn_id == "" {
    return false
  }
  for turn in turns {
    if turn.client_turn_id == client_turn_id {
      return true
    }
  }
  false
}

///|
fn mooncode_canonical_push_turn_items(
  items : Array[MoonCodeTranscriptItem],
  turn : MoonCodeCanonicalTurn,
) -> Unit {
  match turn.user {
    Some(row) => items.push(mooncode_transcript_message_item(row))
    None => ()
  }
  for item in turn.body_items {
    items.push(item)
  }
}
