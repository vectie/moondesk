///|
fn selected_mooncode_session(model : Model) -> MoonCodeSession? {
  if model.selected_mooncode_session_id != "" {
    for session in model.mooncode_sessions {
      if session.id == model.selected_mooncode_session_id {
        return Some(session)
      }
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
fn selected_mooncode_runtime_label(model : Model) -> String {
  match selected_mooncode_session(model) {
    Some(session) => {
      let runtime_id = mooncode_session_runtime_id(session)
      if runtime_id == "" {
        "not attached"
      } else {
        "\{runtime_id} / \{session.status}"
      }
    }
    None => "new session"
  }
}

///|
fn mooncode_session_runtime_id(session : MoonCodeSession) -> String {
  match session.mooncode_runtime_session_id {
    Some(id) if id != "" => id
    _ => session.id
  }
}
