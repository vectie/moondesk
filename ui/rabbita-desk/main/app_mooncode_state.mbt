///|
fn selected_mooncode_session(model : Model) -> MoonCodeSession? {
  if model.selected_mooncode_session_id != "" {
    for session in model.mooncode_sessions {
      if session.id == model.selected_mooncode_session_id {
        return Some(session)
      }
    }
  }
  if mooncode_new_session_draft_active(model) {
    return None
  }
  for session in model.mooncode_sessions {
    if session.workspace_id == model.selected_workspace_id {
      return Some(session)
    }
  }
  None
}

///|
fn mooncode_new_session_draft_active(model : Model) -> Bool {
  if model.selected_mooncode_session_id != "" {
    return false
  }
  if model.mooncode_prompt.trim().to_owned() != "" {
    return true
  }
  model.mooncode_composer_status == "new session draft" ||
  model.mooncode_composer_status == "draft" ||
  model.mooncode_composer_status == "enter a message" ||
  model.mooncode_composer_status == "starting MoonCode session" ||
  model.mooncode_composer_status == "starting General MoonCode"
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
fn mooncode_merge_session_listing(
  existing : Array[MoonCodeSession],
  incoming : Array[MoonCodeSession],
) -> Array[MoonCodeSession] {
  let merged : Array[MoonCodeSession] = []
  for session in incoming {
    match mooncode_find_session(existing, session.id) {
      Some(previous) => merged.push(
        mooncode_preserve_hydrated_session(previous, session),
      )
      None => merged.push(session)
    }
  }
  merged
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

///|
fn mooncode_preserve_hydrated_session(
  previous : MoonCodeSession,
  incoming : MoonCodeSession,
) -> MoonCodeSession {
  if incoming.transcript.length() == 0 &&
    incoming.mooncode_events.length() == 0 &&
    (
      previous.transcript.length() > 0 ||
      previous.mooncode_events.length() > 0
    ) {
    {
      ..incoming,
      transcript: previous.transcript,
      mooncode_events: previous.mooncode_events,
      mooncode_summary: previous.mooncode_summary,
    }
  } else {
    incoming
  }
}

///|
fn mooncode_clear_acknowledged_pending_prompts(
  prompts : Array[MoonCodePendingPrompt],
  session_id : String,
  events : Array[MoonCodeEvent],
) -> Array[MoonCodePendingPrompt] {
  let next : Array[MoonCodePendingPrompt] = []
  for prompt in prompts {
    if prompt.session_id == session_id &&
      mooncode_events_acknowledge_pending_prompt(events, prompt) {
      continue
    }
    next.push(prompt)
  }
  next
}

///|
fn mooncode_events_acknowledge_pending_prompt(
  events : Array[MoonCodeEvent],
  prompt : MoonCodePendingPrompt,
) -> Bool {
  for event in events {
    if mooncode_event_is_user_prompt(event) &&
      event.detail.trim().to_owned() == prompt.content {
      return true
    }
  }
  false
}
