///|
fn fetch_selected_mooncode_stream_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Cmd {
  match selected_mooncode_session(model) {
    Some(session) => {
      let since = if model.mooncode_stream_session_id == session.id {
        model.mooncode_stream_cursor
      } else {
        0
      }
      fetch_mooncode_stream_cmd(dispatch, session.id, since)
    }
    None => @rabbita.none
  }
}

///|
fn create_mooncode_session_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Cmd {
  let body : Json = {
    "workspace_id": model.selected_workspace_id,
    "title": mooncode_new_session_title(model),
    "message": trimmed_or(model.mooncode_prompt, mooncode_default_prompt(model)),
    "model": model.mooncode_model,
    "web_search": model.mooncode_web_search,
    "context_path": mooncode_context_path(model),
  }
  @http.post("/api/mooncode/sessions")
  .with_json(body)
  .expect_json(result => {
    dispatch(
      CreatedMoonCodeSession(
        http_result(result, "Could not create MoonCode session"),
      ),
    )
  })
}

///|
fn send_mooncode_composer_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
  session : MoonCodeSession,
) -> @rabbita.Cmd {
  let action = mooncode_composer_action(model, session)
  mooncode_session_command_cmd(
    dispatch,
    model,
    session,
    action,
    message=model.mooncode_prompt.trim().to_owned(),
  )
}

///|
fn mooncode_composer_action(model : Model, session : MoonCodeSession) -> String {
  if mooncode_session_accepts_steer(model, session) {
    "steer"
  } else {
    "prompt"
  }
}

///|
fn mooncode_session_accepts_steer(
  model : Model,
  session : MoonCodeSession,
) -> Bool {
  ignore(model)
  if session.status == "running" ||
    session.status == "queued" ||
    session.queued_count > 0 {
    return true
  }
  false
}

///|
fn mooncode_session_command_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
  session : MoonCodeSession,
  action : String,
  context_path? : String = "",
  message? : String = "",
  force_preflight? : Bool = false,
) -> @rabbita.Cmd {
  let target_path = if context_path == "" {
    mooncode_context_path(model)
  } else {
    context_path
  }
  let selected_model = trimmed_or(model.mooncode_model, session.model)
  let body : Json = {
    "action": action,
    "message": message,
    "model": selected_model,
    "web_search": model.mooncode_web_search,
    "context_path": target_path,
    "force_preflight": force_preflight,
  }
  @http.post("/api/mooncode/sessions/\{session.id}/commands")
  .with_json(body)
  .expect_json(result => {
    dispatch(
      CompletedMoonCodeCommand(
        http_result(result, "Could not run MoonCode command"),
      ),
    )
  })
}

///|
fn mooncode_new_session_title(model : Model) -> String {
  if model.selected_workspace_id == "" {
    "MoonCode - General"
  } else {
    "MoonCode - \{workspace_name(model)}"
  }
}

///|
fn mooncode_default_prompt(model : Model) -> String {
  if model.selected_workspace_id == "" {
    "Help me plan, write, test, or explain code."
  } else {
    "Create, inspect, test, or package executable code inside this MoonBook."
  }
}

///|
fn mooncode_context_path(model : Model) -> String {
  if model.selected_workspace_id == "" {
    ""
  } else {
    model.selected_path
  }
}

///|
fn schedule_mooncode_poll(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @rabbita.delay(dispatch(PollMoonCodeSessions), 5000)
}
