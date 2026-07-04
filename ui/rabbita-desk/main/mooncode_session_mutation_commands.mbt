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
  let prompt = trimmed_or(model.mooncode_prompt, mooncode_default_prompt(model))
  let client_turn_id = mooncode_client_turn_id(
    model,
    mooncode_draft_session_id(model),
    prompt,
  )
  let body : Json = {
    "workspace_id": model.selected_workspace_id,
    "title": mooncode_new_session_title(model),
    "message": prompt,
    "client_turn_id": client_turn_id,
    "model": mooncode_selected_runtime_model(model, None),
    "web_search": model.mooncode_web_search,
    "context_path": mooncode_context_path(model),
  }
  @http.post(mooncode_sessions_url(""))
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
  mooncode_session_command_cmd(
    dispatch,
    model,
    session,
    "prompt",
    message=model.mooncode_prompt.trim().to_owned(),
  )
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
  let selected_model = mooncode_selected_runtime_model(model, Some(session))
  let client_turn_id = mooncode_client_turn_id(model, session.id, message)
  let body : Json = {
    "action": action,
    "message": message,
    "client_turn_id": client_turn_id,
    "model": selected_model,
    "web_search": model.mooncode_web_search,
    "context_path": target_path,
    "force_preflight": force_preflight,
  }
  @http.post(mooncode_session_commands_url(session.id))
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
fn start_mooncode_runtime_service_cmd(
  dispatch : Dispatch[Msg],
  session_id : String,
) -> @rabbita.Cmd {
  let body : Json = {
    "consumer_id": "moondesk-ui-runtime-service",
    "max_turns": 8,
    "live_wait_ms": 5000,
    "poll_ms": 250,
  }
  @http.post(mooncode_session_runtime_service_url(session_id))
  .with_json(body)
  .expect_json(result => {
    dispatch(
      StartedMoonCodeRuntime(
        session_id,
        http_result(result, "Could not start MoonCode runtime service"),
      ),
    )
  })
}

///|
fn mooncode_client_turn_id(
  model : Model,
  session_id : String,
  content : String,
) -> String {
  let seed = session_id +
    ":" +
    content.trim().to_owned() +
    ":" +
    model.mooncode_next_client_turn_index.to_string()
  @desk.stable_id("mooncode-client-turn", seed)
}

///|
fn mooncode_selected_runtime_model(
  model : Model,
  session : MoonCodeSession?,
) -> String {
  let session_model = match session {
    Some(session) => session.model
    None => ""
  }
  trimmed_or(trimmed_or(model.mooncode_model, session_model), "codex/gpt-5.4")
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

///|
fn schedule_mooncode_fast_poll(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @rabbita.delay(dispatch(PollMoonCodeSessions), 750)
}
