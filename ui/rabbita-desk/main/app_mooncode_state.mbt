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
    if mooncode_session_matches_workspace_id(
        session,
        model.selected_workspace_id,
      ) {
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
    source: Some("mooncode-draft"),
    mooncode_runtime_session_id: None,
    title: mooncode_new_session_title(model),
    model: mooncode_selected_runtime_model(model, None),
    status: "queued",
    queued_count: 1,
    last_message: None,
    mooncode_runtime_detail: None,
    mooncode_conversation: None,
    mooncode_summary: {
      event_count: 0,
      verified_test_count: 0,
      pending_diff_count: 0,
    },
    canonical_unchanged: None,
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
  mooncode_session_matches_workspace_id(session, model.selected_workspace_id)
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
    if mooncode_session_matches_workspace_id(session, workspace_id) {
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
  let incoming = mooncode_preserve_selected_listing_conversation(
    model, incoming,
  )
  let selected_inflight = mooncode_selected_session_has_inflight_state(
    model, selected,
  )
  if selected_inflight && mooncode_session_exists(incoming, selected) {
    return mooncode_promote_session(incoming, selected)
  }
  if mooncode_session_exists(incoming, selected) {
    return incoming
  }
  if !selected_inflight {
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
fn mooncode_preserve_selected_listing_conversation(
  model : Model,
  incoming : Array[MoonCodeSession],
) -> Array[MoonCodeSession] {
  let selected = model.selected_mooncode_session_id
  match mooncode_find_session(model.mooncode_sessions, selected) {
    Some(existing) => {
      let next : Array[MoonCodeSession] = []
      let mut preserved = false
      for listed in incoming {
        if listed.id == selected &&
          mooncode_should_preserve_selected_conversation(existing, listed) {
          next.push(mooncode_merge_selected_listing_session(existing, listed))
          preserved = true
        } else {
          next.push(listed)
        }
      }
      if preserved {
        return next
      }
      incoming
    }
    None => incoming
  }
}

///|
fn mooncode_promote_session(
  sessions : Array[MoonCodeSession],
  session_id : String,
) -> Array[MoonCodeSession] {
  match mooncode_find_session(sessions, session_id) {
    Some(session) => {
      let next : Array[MoonCodeSession] = [session]
      for existing in sessions {
        if existing.id != session_id {
          next.push(existing)
        }
      }
      next
    }
    None => sessions
  }
}

///|
fn mooncode_should_preserve_selected_conversation(
  existing : MoonCodeSession,
  listed : MoonCodeSession,
) -> Bool {
  mooncode_session_has_conversation(existing) &&
  (
    !mooncode_session_has_conversation(listed) ||
    mooncode_session_conversation_revision(listed) <=
    mooncode_session_conversation_revision(existing)
  )
}

///|
fn mooncode_session_has_conversation(session : MoonCodeSession) -> Bool {
  match session.mooncode_conversation {
    Some(conversation) => conversation.turns.length() > 0
    None => false
  }
}

///|
fn mooncode_merge_selected_listing_session(
  existing : MoonCodeSession,
  listed : MoonCodeSession,
) -> MoonCodeSession {
  {
    ..existing,
    workspace_id: existing.workspace_id,
    workspace_name: existing.workspace_name,
    cwd: existing.cwd,
    source: listed.source,
    mooncode_runtime_session_id: if listed.mooncode_runtime_session_id
      is Some(_) {
      listed.mooncode_runtime_session_id
    } else {
      existing.mooncode_runtime_session_id
    },
    title: if listed.title == "" {
      existing.title
    } else {
      listed.title
    },
    model: if listed.model == "" {
      existing.model
    } else {
      listed.model
    },
    status: if listed.status == "" {
      existing.status
    } else {
      listed.status
    },
    queued_count: listed.queued_count,
    last_message: if listed.last_message is Some(_) {
      listed.last_message
    } else {
      existing.last_message
    },
    mooncode_runtime_detail: if listed.mooncode_runtime_detail is Some(_) {
      listed.mooncode_runtime_detail
    } else {
      existing.mooncode_runtime_detail
    },
    mooncode_summary: listed.mooncode_summary,
  }
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
  mooncode_session_has_unfinished_turn(model, session_id)
}

///|
fn mooncode_session_has_unfinished_turn(
  model : Model,
  session_id : String,
) -> Bool {
  for session in model.mooncode_sessions {
    if session.id == session_id {
      return mooncode_conversation_has_unfinished_turn(session)
    }
  }
  false
}

///|
fn mooncode_conversation_has_unfinished_turn(session : MoonCodeSession) -> Bool {
  match session.mooncode_conversation {
    Some(conversation) => {
      for turn in conversation.turns {
        if mooncode_turn_is_unfinished(turn) {
          return true
        }
      }
      false
    }
    None => false
  }
}

///|
fn mooncode_turn_is_unfinished(turn : MoonCodeConversationTurn) -> Bool {
  let status = turn.status
  if status != "queued" && status != "running" {
    return false
  }
  let assistant_status = json_field_string(turn.assistant, "status", default="")
  if assistant_status == "queued" || assistant_status == "running" {
    return true
  }
  json_field_string(turn.assistant, "content", default="").trim().to_owned() ==
  ""
}

///|
fn mooncode_session_matches_selected_workspace(
  model : Model,
  session : MoonCodeSession,
) -> Bool {
  mooncode_session_matches_workspace_id(session, model.selected_workspace_id)
}

///|
fn mooncode_session_matches_workspace_id(
  session : MoonCodeSession,
  workspace_id : String,
) -> Bool {
  if workspace_id == "" {
    mooncode_session_is_general(session)
  } else {
    session.workspace_id == workspace_id
  }
}

///|
fn mooncode_session_is_general(session : MoonCodeSession) -> Bool {
  session.workspace_id == "" ||
  session.workspace_id.contains("general-mooncode") ||
  session.workspace_name == "General MoonCode" ||
  session.workspace_name == "General"
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
