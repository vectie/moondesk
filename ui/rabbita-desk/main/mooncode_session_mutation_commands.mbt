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
  let submission : Json = {
    "action": "prompt",
    "workspace_id": model.selected_workspace_id,
    "title": mooncode_new_session_title(model),
    "message": prompt,
    "client_turn_id": client_turn_id,
    "model": mooncode_selected_runtime_model(model, None),
    "web_search": model.mooncode_web_search,
    "context_path": mooncode_context_path(model),
  }
  let encoded = match typed_mooncode_command_body(submission) {
    Ok(value) => value
    Err(error) => return dispatch(CreatedMoonCodeSession(Err(error)))
  }
  let body = mooncode_command_body_with_creation_fields(encoded, submission)
  @http.post(@desk.mooncode_sessions_url(""))
  .with_json(body)
  .expect_json(result => {
    let decoded = match result {
      Ok(payload) => decode_mooncode_selected_session(payload)
      Err(error) => Err(error.to_string())
    }
    dispatch(CreatedMoonCodeSession(decoded))
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
  approval_id? : String = "",
  context_path? : String = "",
  message? : String = "",
  force_preflight? : Bool = false,
  target_command_id? : String = "",
  tool_call_id? : String = "",
) -> @rabbita.Cmd {
  let target_path = if context_path == "" {
    mooncode_context_path(model)
  } else {
    context_path
  }
  let selected_model = mooncode_selected_runtime_model(model, Some(session))
  let client_turn_id = mooncode_client_turn_id(model, session.id, message)
  let submission : Json = {
    "action": action,
    "message": message,
    "client_turn_id": client_turn_id,
    "model": selected_model,
    "web_search": model.mooncode_web_search,
    "context_path": target_path,
    "force_preflight": force_preflight,
    "approval_id": approval_id,
    "target_command_id": target_command_id,
    "tool_call_id": tool_call_id,
  }
  let body = match typed_mooncode_command_body(submission) {
    Ok(value) => value
    Err(error) => return dispatch(CompletedMoonCodeCommand(Err(error)))
  }
  @http.post(@desk.mooncode_session_commands_url(session.id))
  .with_json(body)
  .expect_json(result => {
    let decoded = match result {
      Ok(payload) => decode_mooncode_selected_session(payload)
      Err(error) => Err(error.to_string())
    }
    dispatch(CompletedMoonCodeCommand(decoded))
  })
}

///|
fn mooncode_session_approval_cmd(
  dispatch : Dispatch[Msg],
  session : MoonCodeSession,
  approval : @mooncode_core.MoonCodeApproval,
  decision : @mooncode_core.MoonCodeApprovalDecision,
) -> @rabbita.Cmd {
  let body = match approval.decision_wire(decision, session.id) {
    Ok(wire) =>
      match typed_mooncode_command_body(wire) {
        Ok(value) => value
        Err(error) => return dispatch(CompletedMoonCodeCommand(Err(error)))
      }
    Err(_) =>
      return dispatch(
        CompletedMoonCodeCommand(Err("Approval target is unavailable")),
      )
  }
  @http.post(@desk.mooncode_session_commands_url(session.id))
  .with_json(body)
  .expect_json(result => {
    let decoded = match result {
      Ok(payload) => decode_mooncode_selected_session(payload)
      Err(error) => Err(error.to_string())
    }
    dispatch(CompletedMoonCodeCommand(decoded))
  })
}

///|
fn typed_mooncode_command_body(submission : Json) -> Result[Json, String] {
  match @mooncode_core.decode_mooncode_command(submission) {
    Ok(command) => @mooncode_core.encode_mooncode_command(command)
    Err(error) => Err(error)
  }
}

///|
fn mooncode_command_body_with_creation_fields(
  encoded : Json,
  source : Json,
) -> Json {
  guard encoded is Object(encoded_fields) && source is Object(source_fields) else {
    return encoded
  }
  let fields = encoded_fields.copy()
  for key in ["workspace_id", "title"] {
    match source_fields.get(key) {
      Some(value) => fields[key] = value
      None => ()
    }
  }
  Json::object(fields)
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
  trimmed_or(model.mooncode_model, session_model)
}

///|
fn mooncode_new_session_title(model : Model) -> String {
  let prompt = model.mooncode_prompt.trim().to_owned()
  if prompt != "" {
    return prompt
  }
  let draft_session_id = mooncode_draft_session_id(model)
  for row in model.mooncode_optimistic_rows {
    if row.session_id == draft_session_id && row.role == "user" {
      let content = row.content.trim().to_owned()
      if content != "" {
        return content
      }
    }
  }
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
    match find_entry(model, model.selected_path) {
      Some(entry) => if entry.kind is Directory { "" } else { entry.path }
      _ => ""
    }
  }
}

///|
fn schedule_mooncode_metadata_refresh(
  dispatch : Dispatch[Msg],
  generation : Int,
) -> @rabbita.Cmd {
  @rabbita.delay(dispatch(RefreshMoonCodeMetadata(generation)), 5000)
}
