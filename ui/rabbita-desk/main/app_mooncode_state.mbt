///|
fn selected_mooncode_session(model : Model) -> MoonCodeSession? {
  if model.selected_mooncode_session_id != "" {
    for session in model.mooncode_sessions {
      if session.id == model.selected_mooncode_session_id {
        return Some(session)
      }
    }
  }
  if model.selected_mooncode_session_id == "" {
    match mooncode_draft_session(model) {
      Some(session) => return Some(session)
      None => ()
    }
    if mooncode_new_session_draft_active(model) {
      return None
    }
  }
  for session in model.mooncode_sessions {
    if session.workspace_id == model.selected_workspace_id {
      return Some(session)
    }
  }
  None
}

///|
fn mooncode_draft_session_id(model : Model) -> String {
  if model.selected_workspace_id == "" {
    "mooncode-draft-general"
  } else {
    "mooncode-draft-" + model.selected_workspace_id
  }
}

///|
fn mooncode_draft_session(model : Model) -> MoonCodeSession? {
  let session_id = mooncode_draft_session_id(model)
  if !mooncode_optimistic_rows_have_session(
      model.mooncode_optimistic_rows,
      session_id,
    ) {
    return None
  }
  Some({
    id: session_id,
    workspace_id: model.selected_workspace_id,
    workspace_name: if model.selected_workspace_id == "" {
      "General"
    } else {
      workspace_name(model)
    },
    cwd: if model.selected_workspace_id == "" {
      ""
    } else {
      model.workspace_root_path
    },
    mooncode_runtime_session_id: None,
    title: mooncode_new_session_title(model),
    model: mooncode_selected_runtime_model(model, None),
    status: "queued",
    queued_count: 1,
    mooncode_conversation: None,
    mooncode_summary: {
      event_count: 0,
      verified_test_count: 0,
      pending_diff_count: 0,
    },
  })
}

///|
fn mooncode_find_acknowledged_draft_session(
  model : Model,
  sessions : Array[MoonCodeSession],
) -> MoonCodeSession? {
  if model.selected_mooncode_session_id != "" {
    return None
  }
  let draft_session_id = mooncode_draft_session_id(model)
  let draft_rows = mooncode_optimistic_rows_for_session(
    model.mooncode_optimistic_rows,
    draft_session_id,
  )
  if draft_rows.length() == 0 {
    return None
  }
  for session in sessions {
    if !mooncode_session_matches_draft_workspace(model, session) {
      continue
    }
    for row in draft_rows {
      if mooncode_session_acknowledges_optimistic_row(session, row) {
        return Some(session)
      }
    }
  }
  None
}

///|
fn mooncode_session_matches_draft_workspace(
  model : Model,
  session : MoonCodeSession,
) -> Bool {
  if model.selected_workspace_id == "" {
    session.workspace_id.contains("general-mooncode") ||
    session.workspace_name == "General MoonCode" ||
    session.workspace_name == "General"
  } else {
    session.workspace_id == model.selected_workspace_id
  }
}

///|
fn mooncode_new_session_draft_active(model : Model) -> Bool {
  if model.selected_mooncode_session_id != "" {
    return false
  }
  if model.mooncode_prompt.trim().to_owned() != "" {
    return true
  }
  model.mooncode_new_chat_active ||
  mooncode_optimistic_rows_have_session(
    model.mooncode_optimistic_rows,
    mooncode_draft_session_id(model),
  )
}

///|
fn mooncode_background_status_unless_draft(
  model : Model,
  status : String,
) -> String {
  if mooncode_new_session_draft_active(model) {
    model.mooncode_composer_status
  } else {
    status
  }
}

///|
fn first_mooncode_session_id(
  sessions : Array[MoonCodeSession],
  workspace_id : String,
) -> String {
  for session in sessions {
    if workspace_id == "" || session.workspace_id == workspace_id {
      return session.id
    }
  }
  ""
}

///|
fn mooncode_session_exists(
  sessions : Array[MoonCodeSession],
  session_id : String,
) -> Bool {
  for session in sessions {
    if session.id == session_id {
      return true
    }
  }
  false
}

///|
fn mooncode_preserve_selected_inflight_session(
  model : Model,
  incoming : Array[MoonCodeSession],
) -> Array[MoonCodeSession] {
  let selected = model.selected_mooncode_session_id
  if selected == "" {
    return incoming
  }
  match mooncode_find_session(model.mooncode_sessions, selected) {
    Some(session) =>
      if mooncode_session_matches_selected_workspace(model, session) &&
        mooncode_selected_session_has_fresher_conversation(
          incoming, session,
        ) {
        return mooncode_replace_session(incoming, session)
      }
    None => ()
  }
  if mooncode_session_exists(incoming, selected) {
    return incoming
  }
  if !mooncode_selected_session_has_inflight_state(model, selected) {
    return incoming
  }
  match mooncode_find_session(model.mooncode_sessions, selected) {
    Some(session) =>
      if mooncode_session_matches_selected_workspace(model, session) {
        let next : Array[MoonCodeSession] = [session]
        for listed in incoming {
          next.push(listed)
        }
        next
      } else {
        incoming
      }
    None => incoming
  }
}

///|
fn mooncode_selected_session_has_fresher_conversation(
  incoming : Array[MoonCodeSession],
  selected : MoonCodeSession,
) -> Bool {
  match mooncode_find_session(incoming, selected.id) {
    Some(listed) => mooncode_session_conversation_regressed(selected, listed)
    None => false
  }
}

///|
fn mooncode_session_conversation_regressed(
  current : MoonCodeSession,
  incoming : MoonCodeSession,
) -> Bool {
  match (current.mooncode_conversation, incoming.mooncode_conversation) {
    (Some(current_conversation), Some(incoming_conversation)) =>
      incoming_conversation.turns.length() <
      current_conversation.turns.length() ||
      incoming_conversation.source_event_count <
      current_conversation.source_event_count
    _ => false
  }
}

///|
fn mooncode_replace_session(
  sessions : Array[MoonCodeSession],
  replacement : MoonCodeSession,
) -> Array[MoonCodeSession] {
  let next : Array[MoonCodeSession] = []
  for session in sessions {
    if session.id == replacement.id {
      next.push(replacement)
    } else {
      next.push(session)
    }
  }
  next
}

///|
fn mooncode_selected_session_has_inflight_state(
  model : Model,
  session_id : String,
) -> Bool {
  mooncode_optimistic_rows_have_session(
    model.mooncode_optimistic_rows,
    session_id,
  ) ||
  mooncode_session_is_active(model, session_id)
}

///|
fn mooncode_session_is_active(model : Model, session_id : String) -> Bool {
  for session in model.mooncode_sessions {
    if session.id == session_id {
      return session.status == "queued" ||
        session.status == "running" ||
        session.queued_count > 0
    }
  }
  false
}

///|
fn mooncode_session_matches_selected_workspace(
  model : Model,
  session : MoonCodeSession,
) -> Bool {
  model.selected_workspace_id == "" ||
  session.workspace_id == model.selected_workspace_id
}

///|
fn mooncode_find_session(
  sessions : Array[MoonCodeSession],
  session_id : String,
) -> MoonCodeSession? {
  for session in sessions {
    if session.id == session_id {
      return Some(session)
    }
  }
  None
}
