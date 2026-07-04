///|
fn mooncode_conversation_transcript_rows(
  model : Model,
  session : MoonCodeSession,
) -> Array[MoonCodeTranscriptRow] {
  let rows : Array[MoonCodeTranscriptRow] = []
  for row in model.mooncode_conversation_rows {
    if row.session_id == session.id {
      rows.push({
        role: mooncode_transcript_message_role(row.role),
        content: row.content,
        status: row.status,
      })
    }
  }
  rows
}

///|
fn mooncode_conversation_rows_to_transcript(
  rows : Array[MoonCodeConversationRow],
  session_id : String,
) -> Array[MoonCodeTranscriptRow] {
  let transcript_rows : Array[MoonCodeTranscriptRow] = []
  for row in rows {
    if row.session_id == session_id {
      transcript_rows.push({
        role: mooncode_transcript_message_role(row.role),
        content: row.content,
        status: row.status,
      })
    }
  }
  transcript_rows
}

///|
fn mooncode_hydrate_conversation_from_events(
  rows : Array[MoonCodeConversationRow],
  session_id : String,
  events : Array[MoonCodeEvent],
) -> Array[MoonCodeConversationRow] {
  if events.length() == 0 {
    return mooncode_copy_conversation_rows(rows)
  }
  let rebuild_acknowledged_session = mooncode_events_have_user(events)
  let next : Array[MoonCodeConversationRow] = []
  if rebuild_acknowledged_session {
    for row in rows {
      if row.session_id != session_id {
        next.push(row)
      }
    }
  } else {
    for row in rows {
      next.push(row)
    }
  }
  let ordered = mooncode_order_transcript_events(
    mooncode_merge_stream_events(events, []),
  )
  let assistant_delta_parts : Array[String] = []
  let pending_assistant_finals : Array[MoonCodeConversationRow] = []
  for event in ordered {
    if mooncode_event_is_user_prompt(event) {
      if assistant_delta_parts.length() > 0 &&
        mooncode_conversation_has_user(next, session_id) {
        mooncode_push_conversation_row(
          next,
          session_id,
          "assistant",
          assistant_delta_parts.join(""),
          "done",
          mooncode_event_conversation_key(event, "assistant-delta-before-user"),
          dedupe_content=true,
        )
        assistant_delta_parts.clear()
      }
      mooncode_push_conversation_row(
        next,
        session_id,
        "user",
        event.detail,
        event.status,
        mooncode_event_conversation_key(event, "user"),
        dedupe_content=true,
      )
      for row in pending_assistant_finals {
        mooncode_push_conversation_row(
          next,
          row.session_id,
          row.role,
          row.content,
          row.status,
          row.key,
          dedupe_content=true,
        )
      }
      pending_assistant_finals.clear()
    } else if mooncode_event_is_assistant_final(event) {
      let content = mooncode_event_assistant_content(event)
      if content != "" {
        let status = if event.status == "" { "done" } else { event.status }
        let key = mooncode_event_conversation_key(event, "assistant")
        if mooncode_conversation_has_user(next, session_id) {
          if !mooncode_replace_running_assistant_row(
              next, session_id, content, status, key,
            ) {
            mooncode_push_conversation_row(
              next,
              session_id,
              "assistant",
              content,
              status,
              key,
              dedupe_content=true,
            )
          }
        } else {
          pending_assistant_finals.push({
            session_id,
            role: "assistant",
            content,
            status,
            key,
          })
        }
        assistant_delta_parts.clear()
      }
    } else if mooncode_event_is_assistant_delta(event) {
      let content = event.detail.trim().to_owned()
      if content != "" {
        assistant_delta_parts.push(content)
      }
    } else if mooncode_event_is_terminal_without_answer(event) {
      if assistant_delta_parts.length() > 0 &&
        mooncode_conversation_has_user(next, session_id) {
        mooncode_push_conversation_row(
          next,
          session_id,
          "assistant",
          assistant_delta_parts.join(""),
          "done",
          mooncode_event_conversation_key(event, "assistant-delta"),
          dedupe_content=true,
        )
        assistant_delta_parts.clear()
      }
    }
  }
  if assistant_delta_parts.length() > 0 &&
    mooncode_conversation_has_user(next, session_id) {
    mooncode_push_conversation_row(
      next,
      session_id,
      "assistant",
      assistant_delta_parts.join(""),
      "running",
      "assistant-delta:\{session_id}:\{next.length()}",
      dedupe_content=true,
    )
  }
  if rebuild_acknowledged_session {
    for row in rows {
      if row.session_id != session_id {
        continue
      }
      let role = mooncode_transcript_message_role(row.role)
      let content = row.content.trim().to_owned()
      if content == "" ||
        mooncode_conversation_rows_have_message(next, session_id, role, content) ||
        (
          role == "user" &&
          mooncode_transcript_events_have_acknowledged_message(
            events, role, content,
          )
        ) {
        continue
      }
      mooncode_push_conversation_row(
        next,
        session_id,
        role,
        content,
        row.status,
        row.key,
        dedupe_content=true,
      )
    }
  }
  next
}

///|
fn mooncode_conversation_rows_have_message(
  rows : Array[MoonCodeConversationRow],
  session_id : String,
  role : String,
  content : String,
) -> Bool {
  let normalized_role = mooncode_transcript_message_role(role)
  let normalized_content = content.trim().to_owned()
  for row in rows {
    if row.session_id == session_id &&
      mooncode_transcript_message_role(row.role) == normalized_role &&
      row.content.trim().to_owned() == normalized_content {
      return true
    }
  }
  false
}

///|
fn mooncode_conversation_has_user(
  rows : Array[MoonCodeConversationRow],
  session_id : String,
) -> Bool {
  for row in rows {
    if row.session_id == session_id && row.role == "user" {
      return true
    }
  }
  false
}

///|
fn mooncode_conversation_has_session(
  rows : Array[MoonCodeConversationRow],
  session_id : String,
) -> Bool {
  if session_id == "" {
    return false
  }
  for row in rows {
    if row.session_id == session_id {
      return true
    }
  }
  false
}

///|
fn mooncode_conversation_has_open_user_turn(
  rows : Array[MoonCodeConversationRow],
  session_id : String,
) -> Bool {
  let mut open = false
  for row in rows {
    if row.session_id != session_id {
      continue
    }
    let role = mooncode_transcript_message_role(row.role)
    if role == "user" {
      open = true
    } else if role == "assistant" {
      open = false
    }
  }
  open
}

///|
fn mooncode_replace_running_assistant_row(
  rows : Array[MoonCodeConversationRow],
  session_id : String,
  content : String,
  status : String,
  key : String,
) -> Bool {
  let normalized = content.trim().to_owned()
  if session_id == "" || normalized == "" {
    return false
  }
  let mut index = rows.length()
  while index > 0 {
    index = index - 1
    let row = rows[index]
    if row.session_id != session_id {
      continue
    }
    if row.role == "user" {
      return false
    }
    if row.role == "assistant" && row.status == "running" {
      rows[index] = { ..row, content: normalized, status, key }
      return true
    }
  }
  false
}

///|
fn mooncode_append_conversation_user_prompt(
  rows : Array[MoonCodeConversationRow],
  session_id : String,
  content : String,
) -> Array[MoonCodeConversationRow] {
  let next = mooncode_copy_conversation_rows(rows)
  mooncode_push_conversation_row(
    next,
    session_id,
    "user",
    content,
    "queued",
    "ui-user:\{session_id}:\{next.length()}",
    dedupe_content=false,
  )
  next
}

///|
fn mooncode_append_conversation_assistant_status(
  rows : Array[MoonCodeConversationRow],
  session_id : String,
  content : String,
  status : String,
  key : String,
) -> Array[MoonCodeConversationRow] {
  let next = mooncode_copy_conversation_rows(rows)
  mooncode_push_conversation_row(
    next,
    session_id,
    "assistant",
    content,
    status,
    key,
    dedupe_content=true,
  )
  next
}

///|
fn mooncode_reassign_conversation_session(
  rows : Array[MoonCodeConversationRow],
  from_session_id : String,
  to_session_id : String,
) -> Array[MoonCodeConversationRow] {
  let next : Array[MoonCodeConversationRow] = []
  for row in rows {
    if row.session_id == from_session_id {
      next.push({
        ..row,
        session_id: to_session_id,
        key: mooncode_rewrite_local_row_key(
          row.key,
          from_session_id,
          to_session_id,
        ),
      })
    } else {
      next.push(row)
    }
  }
  next
}

///|
fn mooncode_rewrite_local_row_key(
  key : String,
  from_session_id : String,
  to_session_id : String,
) -> String {
  let from_prefix = "ui-user:\{from_session_id}:"
  if key.has_prefix(from_prefix) {
    "ui-user:\{to_session_id}:" + key[from_prefix.length():].to_owned()
  } else {
    key
  }
}

///|
fn mooncode_reassign_pending_prompts(
  prompts : Array[MoonCodePendingPrompt],
  from_session_id : String,
  to_session_id : String,
) -> Array[MoonCodePendingPrompt] {
  let next : Array[MoonCodePendingPrompt] = []
  for prompt in prompts {
    if prompt.session_id == from_session_id {
      next.push({ ..prompt, session_id: to_session_id })
    } else {
      next.push(prompt)
    }
  }
  next
}

///|
fn mooncode_copy_conversation_rows(
  rows : Array[MoonCodeConversationRow],
) -> Array[MoonCodeConversationRow] {
  let next : Array[MoonCodeConversationRow] = []
  for row in rows {
    next.push(row)
  }
  next
}

///|
fn mooncode_push_conversation_row(
  rows : Array[MoonCodeConversationRow],
  session_id : String,
  role : String,
  content : String,
  status : String,
  key : String,
  dedupe_content~ : Bool,
) -> Unit {
  let normalized = content.trim().to_owned()
  if session_id == "" || normalized == "" {
    return
  }
  for row in rows {
    if row.session_id == session_id && row.key == key {
      return
    }
  }
  if dedupe_content &&
    mooncode_replace_optimistic_conversation_row(
      rows, session_id, role, normalized, status, key,
    ) {
    return
  }
  if dedupe_content && rows.length() > 0 {
    let last = rows[rows.length() - 1]
    if last.session_id == session_id &&
      last.role == role &&
      last.content == normalized {
      return
    }
  }
  rows.push({ session_id, role, content: normalized, status, key })
}

///|
fn mooncode_replace_optimistic_conversation_row(
  rows : Array[MoonCodeConversationRow],
  session_id : String,
  role : String,
  content : String,
  status : String,
  key : String,
) -> Bool {
  let local_prefix = "ui-user:\{session_id}:"
  for index in 0..<rows.length() {
    let row = rows[index]
    if row.session_id == session_id &&
      row.role == role &&
      row.content == content &&
      row.key.has_prefix(local_prefix) {
      rows[index] = { ..row, status, key }
      return true
    }
  }
  false
}

///|
fn mooncode_event_conversation_key(
  event : MoonCodeEvent,
  prefix : String,
) -> String {
  if event.id != "" {
    "\{prefix}:event:\{event.id}"
  } else {
    "\{prefix}:event:\{event.created_at}:\{event.kind}"
  }
}
