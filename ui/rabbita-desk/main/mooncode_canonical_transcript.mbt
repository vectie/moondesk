///|
struct MoonCodeCanonicalTurn {
  mut command_id : String
  mut user : MoonCodeTranscriptRow?
  body_items : Array[MoonCodeTranscriptItem]
  activity_keys : Array[String]
  mut assistant : MoonCodeTranscriptRow?
  mut assistant_delta : String
  mut status : String
}

///|
fn mooncode_canonical_transcript_items(
  model : Model,
  session : MoonCodeSession,
) -> Array[MoonCodeTranscriptItem] {
  let conversation_items = mooncode_canonical_conversation_items(model, session)
  if conversation_items.length() > 0 {
    return conversation_items
  }
  let events = mooncode_canonical_transcript_events(model, session)
  if events.length() == 0 &&
    !mooncode_session_has_pending_prompt(model, session.id) &&
    !mooncode_conversation_has_session(
      model.mooncode_conversation_rows,
      session.id,
    ) {
    return []
  }
  let turns = mooncode_canonical_turns_from_events(model, session, events)
  let items : Array[MoonCodeTranscriptItem] = []
  for turn in turns {
    mooncode_canonical_push_turn_items(items, turn)
  }
  if items.length() == 0 {
    return []
  }
  mooncode_drop_recovered_failed_assistant_items(
    mooncode_drop_recovered_failed_thinking_items(
      mooncode_compact_folded_thinking_items(
        mooncode_fold_resolved_thinking_items(items),
      ),
    ),
  )
}

///|
fn mooncode_canonical_conversation_items(
  model : Model,
  session : MoonCodeSession,
) -> Array[MoonCodeTranscriptItem] {
  let turns = mooncode_canonical_turns_from_backend_conversation(session)
  if turns.length() == 0 &&
    mooncode_canonical_transcript_events(model, session).length() > 0 {
    return []
  }
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
        let turn = mooncode_canonical_empty_turn(backend_turn.command_id)
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
            turn.assistant = Some(row)
            turn.body_items.push(mooncode_transcript_message_item(row))
          }
          None => ()
        }
        turn.status = backend_turn.status
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
fn mooncode_canonical_transcript_events(
  model : Model,
  session : MoonCodeSession,
) -> Array[MoonCodeEvent] {
  let events = mooncode_merge_stream_events(session.mooncode_events, [])
  let with_stream = if model.mooncode_stream_session_id == session.id {
    mooncode_merge_stream_events(events, model.mooncode_stream_events)
  } else {
    events
  }
  match model.mooncode_runtime_event_sink {
    Some(sink) if model.mooncode_runtime_event_sink_session_id == session.id =>
      mooncode_merge_stream_events(with_stream, sink.events)
    _ => with_stream
  }
}

///|
fn mooncode_canonical_turns_from_events(
  model : Model,
  session : MoonCodeSession,
  events : Array[MoonCodeEvent],
) -> Array[MoonCodeCanonicalTurn] {
  let turns : Array[MoonCodeCanonicalTurn] = []
  let orphan_events : Array[MoonCodeEvent] = []
  let inserted_pending_keys : Array[String] = []
  let mut processed_count = 0
  for event in events {
    mooncode_canonical_insert_due_pending_prompts(
      turns,
      model,
      session.id,
      processed_count,
      inserted_pending_keys,
      force=false,
    )
    if mooncode_event_is_runtime_service_lifecycle(event) {
      processed_count = processed_count + 1
      continue
    }
    if mooncode_event_is_user_prompt(event) {
      let turn_index = mooncode_canonical_apply_user_event(turns, event)
      mooncode_canonical_apply_orphans_for_turn(
        turns,
        turn_index,
        orphan_events,
        mooncode_event_command_id(event),
      )
    } else {
      mooncode_canonical_apply_runtime_or_buffer(turns, orphan_events, event)
    }
    processed_count = processed_count + 1
  }
  mooncode_canonical_insert_due_pending_prompts(
    turns,
    model,
    session.id,
    processed_count,
    inserted_pending_keys,
    force=true,
  )
  mooncode_canonical_append_local_conversation_rows(turns, model, session.id)
  mooncode_canonical_apply_orphans_to_pending_tail(turns, orphan_events)
  turns
}

///|
fn mooncode_canonical_empty_turn(command_id : String) -> MoonCodeCanonicalTurn {
  {
    command_id,
    user: None,
    body_items: [],
    activity_keys: [],
    assistant: None,
    assistant_delta: "",
    status: "queued",
  }
}

///|
fn mooncode_canonical_insert_due_pending_prompts(
  turns : Array[MoonCodeCanonicalTurn],
  model : Model,
  session_id : String,
  processed_count : Int,
  inserted_keys : Array[String],
  force~ : Bool,
) -> Unit {
  for prompt in model.mooncode_pending_prompts {
    if prompt.session_id != session_id {
      continue
    }
    let key = mooncode_pending_prompt_key(prompt)
    if inserted_keys.contains(key) {
      continue
    }
    if !force &&
      (prompt.after_event_count == 0 || prompt.after_event_count > processed_count) {
      continue
    }
    inserted_keys.push(key)
    if mooncode_canonical_turns_have_user_content(turns, prompt.content) {
      continue
    }
    let turn = mooncode_canonical_empty_turn("")
    turn.user = Some({
      role: "user",
      content: prompt.content,
      status: prompt.status,
    })
    turn.status = prompt.status
    turns.push(turn)
  }
}

///|
fn mooncode_canonical_append_local_conversation_rows(
  turns : Array[MoonCodeCanonicalTurn],
  model : Model,
  session_id : String,
) -> Unit {
  let user_seen : Map[String, Int] = {}
  let assistant_seen : Map[String, Int] = {}
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
      let ordinal = mooncode_canonical_next_seen_ordinal(user_seen, content)
      if mooncode_canonical_user_occurrence_count(turns, content) >= ordinal {
        continue
      }
      let turn = mooncode_canonical_empty_turn("")
      turn.user = Some({ role: "user", content, status: row.status })
      turn.status = row.status
      turns.push(turn)
    } else if role == "assistant" {
      let ordinal = mooncode_canonical_next_seen_ordinal(assistant_seen, content)
      if mooncode_canonical_assistant_occurrence_count(turns, content) >= ordinal {
        continue
      }
      let assistant : MoonCodeTranscriptRow = {
        role: "assistant",
        content,
        status: row.status,
      }
      let turn_index = mooncode_canonical_open_pending_turn_index(turns)
      if turn_index >= 0 {
        let turn = turns[turn_index]
        turn.body_items.push(mooncode_transcript_message_item(assistant))
        turn.assistant = Some(assistant)
        turn.status = mooncode_canonical_merge_status(turn.status, row.status)
        turns[turn_index] = turn
      } else {
        let turn = mooncode_canonical_empty_turn("")
        turn.body_items.push(mooncode_transcript_message_item(assistant))
        turn.assistant = Some(assistant)
        turn.status = row.status
        turns.push(turn)
      }
    }
  }
}

///|
fn mooncode_canonical_next_seen_ordinal(
  seen : Map[String, Int],
  content : String,
) -> Int {
  let count = match seen.get(content) {
    Some(value) => value + 1
    None => 1
  }
  seen[content] = count
  count
}

///|
fn mooncode_canonical_user_occurrence_count(
  turns : Array[MoonCodeCanonicalTurn],
  content : String,
) -> Int {
  let normalized = content.trim().to_owned()
  let mut count = 0
  for turn in turns {
    match turn.user {
      Some(row) if row.content.trim().to_owned() == normalized =>
        count = count + 1
      _ => ()
    }
  }
  count
}

///|
fn mooncode_canonical_assistant_occurrence_count(
  turns : Array[MoonCodeCanonicalTurn],
  content : String,
) -> Int {
  let normalized = content.trim().to_owned()
  let mut count = 0
  for turn in turns {
    for item in turn.body_items {
      match item.message {
        Some(row) if row.role == "assistant" &&
          row.content.trim().to_owned() == normalized => count = count + 1
        _ => ()
      }
    }
  }
  count
}

///|
fn mooncode_canonical_apply_user_event(
  turns : Array[MoonCodeCanonicalTurn],
  event : MoonCodeEvent,
) -> Int {
  let command_id = mooncode_event_command_id(event)
  let existing = mooncode_canonical_turn_index_for_command(turns, command_id)
  let index = if existing >= 0 {
    existing
  } else {
    let pending = mooncode_canonical_pending_turn_index_for_user(
      turns,
      event.detail,
    )
    if pending >= 0 {
      pending
    } else {
      turns.push(mooncode_canonical_empty_turn(command_id))
      turns.length() - 1
    }
  }
  let turn = turns[index]
  if command_id != "" {
    turn.command_id = command_id
  }
  turn.user = Some({
    role: "user",
    content: event.detail,
    status: event.status,
  })
  turn.status = mooncode_canonical_merge_status(turn.status, event.status)
  turns[index] = turn
  index
}

///|
fn mooncode_canonical_apply_runtime_or_buffer(
  turns : Array[MoonCodeCanonicalTurn],
  orphan_events : Array[MoonCodeEvent],
  event : MoonCodeEvent,
) -> Unit {
  let command_id = mooncode_event_command_id(event)
  let command_index = mooncode_canonical_turn_index_for_command(turns, command_id)
  if command_index >= 0 {
    mooncode_canonical_apply_runtime_event(turns, command_index, event)
    return
  }
  let pending_index = mooncode_canonical_open_pending_turn_index(turns)
  if pending_index >= 0 {
    if command_id != "" {
      let turn = turns[pending_index]
      turn.command_id = command_id
      turns[pending_index] = turn
    }
    mooncode_canonical_apply_runtime_event(turns, pending_index, event)
    return
  }
  if command_id != "" {
    orphan_events.push(event)
    return
  }
  if turns.length() > 0 {
    mooncode_canonical_apply_runtime_event(turns, turns.length() - 1, event)
  }
}

///|
fn mooncode_canonical_apply_orphans_for_turn(
  turns : Array[MoonCodeCanonicalTurn],
  turn_index : Int,
  orphan_events : Array[MoonCodeEvent],
  command_id : String,
) -> Unit {
  if turn_index < 0 || command_id == "" {
    return
  }
  for event in orphan_events {
    if mooncode_event_command_id(event) == command_id {
      mooncode_canonical_apply_runtime_event(turns, turn_index, event)
    }
  }
  mooncode_canonical_remove_orphans_for_command(orphan_events, command_id)
}

///|
fn mooncode_canonical_apply_orphans_to_pending_tail(
  turns : Array[MoonCodeCanonicalTurn],
  orphan_events : Array[MoonCodeEvent],
) -> Unit {
  if orphan_events.length() == 0 {
    return
  }
  let pending_index = mooncode_canonical_open_pending_turn_index(turns)
  if pending_index < 0 {
    return
  }
  for event in orphan_events {
    let command_id = mooncode_event_command_id(event)
    if command_id != "" {
      let turn = turns[pending_index]
      if turn.command_id == "" {
        turn.command_id = command_id
        turns[pending_index] = turn
      }
    }
    mooncode_canonical_apply_runtime_event(turns, pending_index, event)
  }
  orphan_events.clear()
}

///|
fn mooncode_canonical_remove_orphans_for_command(
  orphan_events : Array[MoonCodeEvent],
  command_id : String,
) -> Unit {
  let keep : Array[MoonCodeEvent] = []
  for event in orphan_events {
    if mooncode_event_command_id(event) != command_id {
      keep.push(event)
    }
  }
  orphan_events.clear()
  for event in keep {
    orphan_events.push(event)
  }
}

///|
fn mooncode_canonical_apply_runtime_event(
  turns : Array[MoonCodeCanonicalTurn],
  index : Int,
  event : MoonCodeEvent,
) -> Unit {
  if index < 0 || index >= turns.length() {
    return
  }
  let turn = turns[index]
  if mooncode_event_is_assistant_delta(event) {
    let content = event.detail.trim().to_owned()
    if content != "" {
      mooncode_canonical_push_assistant_delta(turn, content)
      turn.status = mooncode_canonical_merge_status(turn.status, "running")
    }
  } else if mooncode_event_is_assistant_final(event) {
    let content = mooncode_canonical_final_content(turn, event)
    if content != "" {
      let row : MoonCodeTranscriptRow = {
        role: "assistant",
        content,
        status: if event.status == "" { "done" } else { event.status },
      }
      if mooncode_canonical_body_tail_is_running_assistant(turn) {
        mooncode_canonical_replace_body_tail_message(turn, row)
      } else {
        turn.body_items.push(mooncode_transcript_message_item(row))
      }
      turn.assistant = Some(row)
      turn.assistant_delta = ""
      turn.status = mooncode_canonical_merge_status(turn.status, event.status)
    } else if mooncode_event_assistant_content(event).trim().to_owned() != "" {
      turn.assistant = Some({
        role: "assistant",
        content: mooncode_canonical_last_assistant_content(turn),
        status: if event.status == "" { "done" } else { event.status },
      })
      turn.assistant_delta = ""
      turn.status = mooncode_canonical_merge_status(turn.status, event.status)
    }
  } else if mooncode_event_is_terminal_without_answer(event) {
    if mooncode_canonical_body_tail_is_running_assistant(turn) {
      mooncode_canonical_mark_body_tail_assistant_done(turn)
    } else if turn.assistant is None && turn.assistant_delta.trim().to_owned() != "" {
      let row : MoonCodeTranscriptRow = {
        role: "assistant",
        content: turn.assistant_delta.trim().to_owned(),
        status: if event.status == "" { "done" } else { event.status },
      }
      turn.body_items.push(mooncode_transcript_message_item(row))
      turn.assistant = Some(row)
      turn.assistant_delta = ""
    }
    turn.status = mooncode_canonical_merge_status(turn.status, event.status)
  } else {
    match mooncode_activity_row_from_event(event) {
      Some(row) => {
        let key = mooncode_activity_item_key(event, row)
        if !turn.activity_keys.contains(key) {
          if mooncode_canonical_body_tail_is_running_assistant(turn) &&
            mooncode_canonical_activity_is_thinking(row) {
            let tail = turn.body_items.length() - 1
            turn.activity_keys.push(key)
            turn.body_items.insert(tail, mooncode_transcript_activity_item(row))
          } else {
            if mooncode_canonical_body_tail_is_running_assistant(turn) {
              mooncode_canonical_mark_body_tail_assistant_done(turn)
            }
            turn.activity_keys.push(key)
            turn.body_items.push(mooncode_transcript_activity_item(row))
          }
          turn.status = mooncode_canonical_merge_status(turn.status, row.status)
        }
      }
      None => ()
    }
  }
  turns[index] = turn
}

///|
fn mooncode_canonical_activity_is_thinking(row : MoonCodeActivityRow) -> Bool {
  row.tone == "thinking" || row.label == "Thinking" || row.label == "Working"
}

///|
fn mooncode_canonical_push_assistant_delta(
  turn : MoonCodeCanonicalTurn,
  content : String,
) -> Unit {
  turn.assistant_delta = turn.assistant_delta + content
  if mooncode_canonical_body_tail_is_running_assistant(turn) {
    let index = turn.body_items.length() - 1
    match turn.body_items[index].message {
      Some(row) =>
        mooncode_canonical_replace_body_tail_message(turn, {
          ..row,
          content: row.content + content,
          status: "running",
        })
      None => ()
    }
  } else {
    turn.body_items.push(
      mooncode_transcript_message_item({
        role: "assistant",
        content,
        status: "running",
      }),
    )
  }
}

///|
fn mooncode_canonical_final_content(
  turn : MoonCodeCanonicalTurn,
  event : MoonCodeEvent,
) -> String {
  let raw = mooncode_event_assistant_content(event).trim().to_owned()
  if raw == "" {
    return ""
  }
  if mooncode_canonical_body_tail_is_running_assistant(turn) {
    return raw
  }
  let prior = mooncode_canonical_last_assistant_content(turn)
  if prior == "" {
    raw
  } else if raw == prior {
    ""
  } else if raw.has_prefix(prior) {
    raw[prior.length():].trim().to_owned()
  } else {
    raw
  }
}

///|
fn mooncode_canonical_last_assistant_content(
  turn : MoonCodeCanonicalTurn,
) -> String {
  let mut index = turn.body_items.length()
  while index > 0 {
    index = index - 1
    match turn.body_items[index].message {
      Some(row) if row.role == "assistant" => return row.content.trim().to_owned()
      _ => ()
    }
  }
  ""
}

///|
fn mooncode_canonical_body_tail_is_running_assistant(
  turn : MoonCodeCanonicalTurn,
) -> Bool {
  if turn.body_items.length() == 0 {
    return false
  }
  match turn.body_items[turn.body_items.length() - 1].message {
    Some(row) => row.role == "assistant" && row.status == "running"
    None => false
  }
}

///|
fn mooncode_canonical_replace_body_tail_message(
  turn : MoonCodeCanonicalTurn,
  row : MoonCodeTranscriptRow,
) -> Unit {
  if turn.body_items.length() == 0 {
    return
  }
  turn.body_items[turn.body_items.length() - 1] = mooncode_transcript_message_item(row)
}

///|
fn mooncode_canonical_mark_body_tail_assistant_done(
  turn : MoonCodeCanonicalTurn,
) -> Unit {
  if !mooncode_canonical_body_tail_is_running_assistant(turn) {
    return
  }
  match turn.body_items[turn.body_items.length() - 1].message {
    Some(row) => mooncode_canonical_replace_body_tail_message(
      turn,
      { ..row, status: "done" },
    )
    None => ()
  }
}

///|
fn mooncode_canonical_push_turn_items(
  items : Array[MoonCodeTranscriptItem],
  turn : MoonCodeCanonicalTurn,
) -> Unit {
  match turn.user {
    Some(row) => mooncode_push_event_tail_transcript_item(
      items,
      mooncode_transcript_message_item(row),
    )
    None => ()
  }
  for item in turn.body_items {
    mooncode_push_event_tail_transcript_item(items, item)
  }
}

///|
fn mooncode_canonical_turn_index_for_command(
  turns : Array[MoonCodeCanonicalTurn],
  command_id : String,
) -> Int {
  if command_id == "" {
    return -1
  }
  for index, turn in turns {
    if turn.command_id == command_id {
      return index
    }
  }
  -1
}

///|
fn mooncode_canonical_pending_turn_index_for_user(
  turns : Array[MoonCodeCanonicalTurn],
  content : String,
) -> Int {
  let normalized = content.trim().to_owned()
  if normalized == "" {
    return -1
  }
  for index, turn in turns {
    match turn.user {
      Some(row) if row.content.trim().to_owned() == normalized => return index
      _ => ()
    }
  }
  -1
}

///|
fn mooncode_canonical_open_pending_turn_index(
  turns : Array[MoonCodeCanonicalTurn],
) -> Int {
  let mut index = turns.length()
  while index > 0 {
    index = index - 1
    let turn = turns[index]
    if turn.user is Some(_) && turn.assistant is None {
      return index
    }
    match turn.user {
      Some(_) => return -1
      None => ()
    }
  }
  -1
}

///|
fn mooncode_canonical_turns_have_user_content(
  turns : Array[MoonCodeCanonicalTurn],
  content : String,
) -> Bool {
  mooncode_canonical_pending_turn_index_for_user(turns, content) >= 0
}

///|
fn mooncode_canonical_merge_status(current : String, incoming : String) -> String {
  if current == "failed" || incoming == "failed" {
    "failed"
  } else if incoming == "running" || current == "running" {
    "running"
  } else if incoming == "done" {
    "done"
  } else if incoming == "" {
    current
  } else {
    incoming
  }
}
