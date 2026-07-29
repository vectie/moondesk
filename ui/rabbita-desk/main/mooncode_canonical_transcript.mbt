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
        let mut retry_prompt = ""
        match mooncode_canonical_message_row(backend_turn.user) {
          Some(row) => {
            retry_prompt = row.content
            turn.user = Some(row)
          }
          None => ()
        }
        match
          mooncode_canonical_work_item(
            backend_turn.work,
            session.id,
            backend_turn.command_id,
            backend_turn.client_turn_id,
            retry_prompt,
            backend_turn.approvals,
          ) {
          Some(item) => turn.body_items.push(item)
          None => ()
        }
        match mooncode_canonical_message_row(backend_turn.assistant) {
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
  conversation : @mooncode_core.MoonCodeConversation,
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
  turn : @mooncode_core.MoonCodeTurn,
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
fn mooncode_canonical_message_row(
  message : @mooncode_core.MoonCodeMessage?,
) -> MoonCodeTranscriptRow? {
  guard message is Some(message) else { return None }
  let content = message.content.trim().to_owned()
  if content == "" {
    return None
  }
  Some({
    item_id: message.item_id,
    role: mooncode_transcript_message_role(message.role),
    content,
    status: if message.status == "" {
      "done"
    } else {
      message.status
    },
    command_id: message.command_id,
    client_turn_id: message.client_turn_id,
  })
}

///|
fn mooncode_canonical_work_item(
  work : @mooncode_core.MoonCodeWork,
  session_id : String,
  command_id : String,
  client_turn_id : String,
  retry_prompt : String,
  approvals : Array[@mooncode_core.MoonCodeApproval],
) -> MoonCodeTranscriptItem? {
  let summary = work.summary
  let status = work.status
  let detail = work.detail
  if summary == "" && detail == "" && approvals.length() == 0 {
    return None
  }
  Some(
    mooncode_transcript_activity_item({
      item_id: work.item_id,
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
      session_id,
      retry_prompt,
      evidence: mooncode_canonical_work_evidence(work, approvals),
    }),
  )
}

///|
fn mooncode_canonical_work_evidence(
  work : @mooncode_core.MoonCodeWork,
  approvals : Array[@mooncode_core.MoonCodeApproval],
) -> Array[MoonCodeEvidenceRow] {
  let rows : Array[MoonCodeEvidenceRow] = []
  let mut approval_index = 0
  for evidence in work.evidence {
    let kind = match evidence.kind {
      "edit" => "edit"
      "test" => "test"
      "approval" => "approval"
      "tool" => "tool"
      _ => "artifact"
    }
    let state = evidence.state
    let approval = match evidence.approval {
      Some(value) => Some(value)
      None if evidence.kind == "approval" => {
        let value = approvals.get(approval_index)
        if value is Some(_) {
          approval_index += 1
        }
        value
      }
      None => None
    }
    let state = if evidence.kind == "approval" { "" } else { state }
    if evidence.kind != "approval" &&
      evidence.path == "" &&
      evidence.diff == "" &&
      evidence.command == "" &&
      evidence.output == "" {
      continue
    }
    rows.push({
      item_id: evidence.item_id,
      kind,
      state,
      title: evidence.title,
      path: evidence.path,
      detail: evidence.detail,
      diff: evidence.diff,
      command: evidence.command,
      output: evidence.output,
      exit_code: evidence.exit_code,
      truncated: evidence.truncated,
      approval,
    })
  }
  rows
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
        item_id: row.key,
        role: "user",
        content,
        status: row.status,
        command_id: "",
        client_turn_id: row.key,
      })
      turns.push(turn)
    } else if role == "assistant" {
      let message = {
        item_id: row.key,
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
