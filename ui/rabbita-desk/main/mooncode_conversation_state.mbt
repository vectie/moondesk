///|
fn mooncode_append_conversation_user_prompt(
  rows : Array[MoonCodeConversationRow],
  session_id : String,
  content : String,
  client_turn_id? : String = "",
) -> Array[MoonCodeConversationRow] {
  let next = mooncode_copy_conversation_rows(rows)
  let row_key = if client_turn_id == "" {
    "ui-user:\{session_id}:\{next.length()}"
  } else {
    client_turn_id
  }
  mooncode_push_conversation_row(
    next,
    session_id,
    "user",
    content,
    "queued",
    row_key,
  )
  next
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
  rows.push({ session_id, role, content: normalized, status, key })
}
