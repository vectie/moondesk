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
  mooncode_canonical_append_optimistic_rows(turns, model, session.id)
  if turns.length() == 0 {
    return []
  }
  let items : Array[MoonCodeTranscriptItem] = []
  for turn in turns {
    mooncode_canonical_push_turn_items(items, turn)
  }
  items
}

///|
fn mooncode_canonical_turns_from_backend_conversation(
  session : MoonCodeSession,
) -> Array[MoonCodeCanonicalTurn] {
  let turns : Array[MoonCodeCanonicalTurn] = []
  match session.mooncode_conversation {
    Some(conversation) => {
      if conversation.session_id != session.id {
        return turns
      }
      mooncode_canonical_note_conversation_metadata(conversation)
      for backend_turn in conversation.turns {
        mooncode_canonical_note_turn_metadata(backend_turn)
        let turn = mooncode_canonical_empty_turn()
        turn.client_turn_id = backend_turn.client_turn_id
        match mooncode_canonical_message_row_from_json(backend_turn.user) {
          Some(row) => turn.user = Some(row)
          None => ()
        }
        match
          mooncode_canonical_work_item_from_json(
            backend_turn.work,
            backend_turn.command_id,
            backend_turn.client_turn_id,
          ) {
          Some(item) => turn.body_items.push(item)
          None => ()
        }
        match mooncode_canonical_message_row_from_json(backend_turn.assistant) {
          Some(row) =>
            turn.body_items.push(mooncode_transcript_message_item(row))
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
  ignore(conversation.contract_id)
  ignore(conversation.session_id)
  ignore(conversation.workspace_id)
  ignore(conversation.workspace_name)
  ignore(conversation.turn_count)
  ignore(conversation.revision)
  ignore(conversation.last_sequence)
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
  ignore(turn.ordinal)
  ignore(turn.status)
  ignore(turn.started_at)
  ignore(turn.updated_at)
}

///|
fn mooncode_canonical_message_row_from_json(
  value : Json,
) -> MoonCodeTranscriptRow? {
  let content = json_field_string(value, "content", default="")
    .trim()
    .to_owned()
  if content == "" {
    return None
  }
  Some({
    role: mooncode_transcript_message_role(
      json_field_string(value, "role", default="assistant"),
    ),
    content,
    status: json_field_string(value, "status", default="done"),
    command_id: json_field_string(value, "command_id", default=""),
    client_turn_id: json_field_string(value, "client_turn_id", default=""),
  })
}

///|
fn mooncode_canonical_work_item_from_json(
  work : Json,
  command_id : String,
  client_turn_id : String,
) -> MoonCodeTranscriptItem? {
  let summary = json_field_string(work, "summary", default="").trim().to_owned()
  let status = json_field_string(work, "status", default="queued")
  let detail = mooncode_canonical_work_detail(work)
  if summary == "" && detail == "" {
    return None
  }
  Some(
    mooncode_transcript_activity_item({
      item_id: json_field_string(work, "item_id", default=""),
      tone: if status == "failed" {
        "failed"
      } else {
        "thinking"
      },
      label: "Work",
      title: if summary == "" {
        "Working on request"
      } else {
        summary
      },
      detail,
      status,
      folded: status == "done" || status == "failed" || status == "cancelled",
      command_id,
      client_turn_id,
    }),
  )
}

///|
fn mooncode_canonical_work_detail(work : Json) -> String {
  let lines : Array[String] = []
  for step in json_field_json_array_items(work, "steps") {
    let summary = json_field_string(step, "summary", default="")
      .trim()
      .to_owned()
    if summary != "" && !lines.contains(summary) {
      lines.push(summary)
    }
  }
  let live = mooncode_canonical_json_object_field(work, "live")
  let live_summary = json_field_string(live, "summary", default="")
    .trim()
    .to_owned()
  if live_summary != "" && !lines.contains(live_summary) {
    lines.push(live_summary)
  }
  lines.join("\n")
}

///|
fn mooncode_canonical_json_object_field(value : Json, key : String) -> Json {
  match value {
    Object(fields) =>
      match fields.get(key) {
        Some(object) => object
        None => Json::object({})
      }
    _ => Json::object({})
  }
}

///|
fn mooncode_canonical_empty_turn() -> MoonCodeCanonicalTurn {
  { client_turn_id: "", user: None, body_items: [] }
}

///|
fn mooncode_canonical_append_optimistic_rows(
  turns : Array[MoonCodeCanonicalTurn],
  model : Model,
  session_id : String,
) -> Unit {
  for row in model.mooncode_optimistic_rows {
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
      turn.user = Some({
        role: "user",
        content,
        status: row.status,
        command_id: "",
        client_turn_id: row.key,
      })
      turns.push(turn)
    } else if role == "assistant" {
      let message = {
        role: "assistant",
        content,
        status: row.status,
        command_id: "",
        client_turn_id: row.key,
      }
      match mooncode_canonical_turn_for_client_turn_id(turns, row.key) {
        Some(turn) =>
          turn.body_items.push(mooncode_transcript_message_item(message))
        None => {
          let turn = mooncode_canonical_empty_turn()
          turn.client_turn_id = row.key
          turn.body_items.push(mooncode_transcript_message_item(message))
          turns.push(turn)
        }
      }
    }
  }
}

///|
fn mooncode_canonical_turn_for_client_turn_id(
  turns : Array[MoonCodeCanonicalTurn],
  client_turn_id : String,
) -> MoonCodeCanonicalTurn? {
  if client_turn_id == "" {
    return None
  }
  for turn in turns {
    if turn.client_turn_id == client_turn_id {
      return Some(turn)
    }
  }
  None
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
