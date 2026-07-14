///|
fn update_mooncode_session_results(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    ManagedMoonClaw(Ok(status)) =>
      (
        @rabbita.batch([
          fetch_moonclaw_daemon_cmd(dispatch),
          fetch_moonclaw_models_cmd(dispatch),
        ]),
        {
          ..model,
          moonclaw_daemon: Some(status),
          mooncode_composer_status: status.message,
        },
      )
    ManagedMoonClaw(Err(error)) =>
      (@rabbita.none, { ..model, mooncode_composer_status: error })
    LoadedMoonClawDaemon(Ok(status)) =>
      (
        @rabbita.none,
        {
          ..model,
          moonclaw_daemon: Some(status),
          mooncode_composer_status: if status.running {
            if mooncode_new_session_draft_active(model) {
              model.mooncode_composer_status
            } else {
              "MoonClaw daemon running on \{status.port}"
            }
          } else if mooncode_new_session_draft_active(model) {
            model.mooncode_composer_status
          } else {
            status.message
          },
        },
      )
    LoadedMoonClawDaemon(Err(error)) =>
      (
        @rabbita.none,
        {
          ..model,
          mooncode_composer_status: mooncode_background_status_unless_draft(
            model, error,
          ),
        },
      )
    LoadedMoonClawModels(Ok(result)) =>
      (
        @rabbita.none,
        {
          ..model,
          mooncode_model: if model.mooncode_model == "" {
            mooncode_default_runtime_model(result)
          } else {
            model.mooncode_model
          },
          mooncode_composer_status: if mooncode_new_session_draft_active(model) {
            model.mooncode_composer_status
          } else if result.ok {
            "\{result.models.length()} model(s) available"
          } else {
            result.daemon.message
          },
        },
      )
    LoadedMoonClawModels(Err(error)) =>
      (
        @rabbita.none,
        {
          ..model,
          mooncode_composer_status: mooncode_background_status_unless_draft(
            model, error,
          ),
        },
      )
    LoadedMoonCodeSessions(Ok(mooncode_sessions)) => {
      let mooncode_sessions = mooncode_preserve_selected_inflight_session(
        model, mooncode_sessions,
      )
      let optimistic_rows = mooncode_drop_acknowledged_optimistic_rows_for_sessions(
        model.mooncode_optimistic_rows,
        mooncode_sessions,
      )
      let session_model = {
        ..model,
        mooncode_sessions,
        mooncode_optimistic_rows: optimistic_rows,
      }
      let draft_active = mooncode_new_session_draft_active(session_model)
      match
        mooncode_find_acknowledged_draft_session(
          session_model, mooncode_sessions,
        ) {
        Some(session) =>
          return mooncode_session_mutation_succeeded(
            dispatch, session_model, session, "MoonCode session started",
          )
        None => ()
      }
      let selected = if model.selected_mooncode_session_id != "" &&
        mooncode_session_exists(
          mooncode_sessions,
          model.selected_mooncode_session_id,
        ) {
        model.selected_mooncode_session_id
      } else if draft_active || model.mooncode_sessions.length() > 0 {
        ""
      } else {
        first_mooncode_session_id(
          mooncode_sessions,
          model.selected_workspace_id,
        )
      }
      let selected_workspace_id = if selected == "" {
        model.selected_workspace_id
      } else {
        mooncode_workspace_id_for_selected_session(session_model, selected)
      }
      let selection_changed = selected != model.selected_mooncode_session_id
      let next = {
        ..model,
        mooncode_sessions,
        mooncode_optimistic_rows: optimistic_rows,
        selected_workspace_id,
        selected_mooncode_session_id: selected,
        mooncode_new_chat_active: selected == "" && draft_active,
        mooncode_watch_generation: if selection_changed {
          model.mooncode_watch_generation + 1
        } else {
          model.mooncode_watch_generation
        },
        mooncode_watch_revision: if selection_changed {
          0
        } else {
          model.mooncode_watch_revision
        },
        mooncode_watch_sequence: if selection_changed {
          0
        } else {
          model.mooncode_watch_sequence
        },
        mooncode_watch_status: if selection_changed {
          if selected == "" { "idle" } else { "connecting" }
        } else {
          model.mooncode_watch_status
        },
        mooncode_composer_status: if draft_active {
          model.mooncode_composer_status
        } else {
          "\{mooncode_sessions.length()} MoonCode session(s)"
        },
      }
      (
        mooncode_listing_watch_cmd(dispatch, model, next),
        next,
      )
    }
    LoadedMoonCodeSessions(Err(error)) =>
      (
        @rabbita.none,
        {
          ..model,
          mooncode_composer_status: mooncode_background_status_unless_draft(
            model, error,
          ),
        },
      )
    LoadedMoonCodeWatch(generation, session_id, Ok(response)) =>
      if generation != model.mooncode_watch_generation ||
        session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else if !mooncode_watch_response_is_valid(response, session_id) {
        mooncode_watch_failed(
          dispatch, model, generation, session_id, "Invalid MoonCode watch contract",
        )
      } else {
        mooncode_watch_succeeded(dispatch, model, response)
      }
    LoadedMoonCodeWatch(generation, session_id, Err(error)) =>
      if generation != model.mooncode_watch_generation ||
        session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        mooncode_watch_failed(dispatch, model, generation, session_id, error)
      }
    CreatedMoonCodeSession(Ok(session)) =>
      mooncode_created_session_succeeded(dispatch, model, session)
    CreatedMoonCodeSession(Err(error)) =>
      (@rabbita.none, { ..model, mooncode_composer_status: error })
    CompletedMoonCodeCommand(Ok(session)) =>
      mooncode_session_mutation_succeeded(
        dispatch, model, session, "MoonCode message sent",
      )
    CompletedMoonCodeCommand(Err(error)) =>
      (
        @rabbita.none,
        {
          ..model,
          mooncode_optimistic_rows: mooncode_fail_pending_optimistic_rows_for_session(
            model.mooncode_optimistic_rows,
            mooncode_current_composer_session_id(model),
            "MoonCode could not send this message: \{error}",
          ),
          mooncode_composer_status: error,
        },
      )
    _ => (@rabbita.none, model)
  }
}

///|
fn mooncode_current_composer_session_id(model : Model) -> String {
  if model.selected_mooncode_session_id != "" {
    model.selected_mooncode_session_id
  } else {
    mooncode_draft_session_id(model)
  }
}

///|
fn mooncode_watch_response_is_valid(
  response : MoonCodeWatchResponse,
  session_id : String,
) -> Bool {
  response.kind == "moonsuite-conversation-watch" &&
  response.contract_id == "moonsuite-conversation-watch.v1" &&
  response.session_id == session_id &&
  response.revision >= 0 &&
  response.next_sequence >= 0 &&
  response.changed != response.heartbeat &&
  (!response.changed || response.snapshot is Some(_))
}

///|
fn mooncode_watch_succeeded(
  dispatch : Dispatch[Msg],
  model : Model,
  response : MoonCodeWatchResponse,
) -> (@rabbita.Cmd, Model) {
  let sessions = match response.snapshot {
    Some(snapshot) if response.changed =>
      mooncode_upsert_session_if_revision_changed(
        model.mooncode_sessions, snapshot,
      )
    _ => model.mooncode_sessions
  }
  let optimistic_rows = match response.snapshot {
    Some(snapshot) if response.changed =>
      mooncode_drop_acknowledged_optimistic_rows(
        model.mooncode_optimistic_rows, snapshot,
      )
    _ => model.mooncode_optimistic_rows
  }
  let next_sequence = if response.next_sequence > model.mooncode_watch_sequence {
    response.next_sequence
  } else {
    model.mooncode_watch_sequence
  }
  let next_revision = if response.revision > model.mooncode_watch_revision {
    response.revision
  } else {
    model.mooncode_watch_revision
  }
  let next = {
    ..model,
    mooncode_sessions: sessions,
    mooncode_optimistic_rows: optimistic_rows,
    mooncode_watch_revision: next_revision,
    mooncode_watch_sequence: next_sequence,
    mooncode_watch_status: if response.terminal {
      "watching-terminal"
    } else if response.heartbeat {
      "watching"
    } else {
      "watching-active"
    },
  }
  let cmd = if response.retry_after_ms > 0 {
    schedule_mooncode_watch_resume(
      dispatch,
      next.mooncode_watch_generation,
      next.selected_mooncode_session_id,
      response.retry_after_ms,
    )
  } else {
    mooncode_watch_cmd(dispatch, next)
  }
  (cmd, next)
}

///|
fn mooncode_watch_failed(
  dispatch : Dispatch[Msg],
  model : Model,
  generation : Int,
  session_id : String,
  error : String,
) -> (@rabbita.Cmd, Model) {
  (
    schedule_mooncode_watch_resume(
      dispatch, generation, session_id, 1000,
    ),
    {
      ..model,
      mooncode_watch_status: "reconnecting",
      mooncode_composer_status: if error == "MoonCode watch replaced" {
        model.mooncode_composer_status
      } else {
        "Reconnecting to MoonCode"
      },
    },
  )
}

///|
fn mooncode_created_session_succeeded(
  dispatch : Dispatch[Msg],
  model : Model,
  session : MoonCodeSession,
) -> (@rabbita.Cmd, Model) {
  mooncode_session_mutation_succeeded(
    dispatch, model, session, "MoonCode session started",
  )
}

///|
fn mooncode_listing_watch_cmd(
  dispatch : Dispatch[Msg],
  previous : Model,
  next : Model,
) -> @rabbita.Cmd {
  if next.selected_mooncode_session_id == "" {
    if previous.selected_mooncode_session_id != "" {
      stop_mooncode_watch_cmd()
    } else {
      @rabbita.none
    }
  } else if next.selected_mooncode_session_id !=
    previous.selected_mooncode_session_id || previous.mooncode_watch_status == "idle" {
    mooncode_watch_cmd(dispatch, next)
  } else {
    @rabbita.none
  }
}

///|
fn mooncode_default_runtime_model(result : MoonClawModelsResult) -> String {
  if result.models.length() > 0 {
    result.models[0].name
  } else if result.ok {
    "codex/gpt-5.4"
  } else {
    ""
  }
}

///|
fn mooncode_session_mutation_succeeded(
  dispatch : Dispatch[Msg],
  model : Model,
  session : MoonCodeSession,
  status : String,
) -> (@rabbita.Cmd, Model) {
  let draft_session_id = mooncode_draft_session_id(model)
  let optimistic_rows = mooncode_reassign_optimistic_session(
    model.mooncode_optimistic_rows,
    draft_session_id,
    session.id,
  )
  let optimistic_rows = mooncode_drop_acknowledged_optimistic_rows(
    optimistic_rows, session,
  )
  let selection_changed = model.selected_mooncode_session_id != session.id
  let next = {
    ..model,
    workspace_mode: MoonCode,
    mooncode_sessions: mooncode_upsert_session_at_top(
      model.mooncode_sessions,
      session,
    ),
    selected_mooncode_session_id: session.id,
    mooncode_new_chat_active: false,
    mooncode_prompt: "",
    mooncode_optimistic_rows: optimistic_rows,
    mooncode_watch_generation: if selection_changed {
      model.mooncode_watch_generation + 1
    } else {
      model.mooncode_watch_generation
    },
    mooncode_watch_revision: if selection_changed {
      0
    } else {
      model.mooncode_watch_revision
    },
    mooncode_watch_sequence: if selection_changed {
      0
    } else {
      model.mooncode_watch_sequence
    },
    mooncode_watch_status: "connecting",
    mooncode_composer_status: status,
  }
  (
    mooncode_after_session_mutation_cmd(dispatch, next, session.id),
    next,
  )
}

///|
fn mooncode_upsert_session(
  sessions : Array[MoonCodeSession],
  session : MoonCodeSession,
) -> Array[MoonCodeSession] {
  let next : Array[MoonCodeSession] = []
  let mut inserted = false
  for existing in sessions {
    if existing.id == session.id {
      next.push(mooncode_session_with_stable_identity(existing, session))
      inserted = true
    } else {
      next.push(existing)
    }
  }
  if !inserted {
    let with_session : Array[MoonCodeSession] = [session]
    for existing in next {
      with_session.push(existing)
    }
    with_session
  } else {
    next
  }
}

///|
fn mooncode_session_with_stable_identity(
  existing : MoonCodeSession,
  incoming : MoonCodeSession,
) -> MoonCodeSession {
  {
    ..incoming,
    workspace_id: if existing.workspace_id == "" {
      incoming.workspace_id
    } else {
      existing.workspace_id
    },
    workspace_name: if existing.workspace_name == "" {
      incoming.workspace_name
    } else {
      existing.workspace_name
    },
    cwd: if existing.cwd == "" {
      incoming.cwd
    } else {
      existing.cwd
    },
  }
}

///|
fn mooncode_upsert_session_if_revision_changed(
  sessions : Array[MoonCodeSession],
  session : MoonCodeSession,
) -> Array[MoonCodeSession] {
  for existing in sessions {
    if existing.id == session.id &&
      mooncode_session_response_cannot_replace(existing, session) {
      return sessions
    }
  }
  mooncode_upsert_session(sessions, session)
}

///|
fn mooncode_session_response_cannot_replace(
  existing : MoonCodeSession,
  incoming : MoonCodeSession,
) -> Bool {
  if mooncode_session_canonical_unchanged(incoming) {
    return true
  }
  let existing_revision = mooncode_session_conversation_revision(existing)
  existing_revision > 0 &&
  mooncode_session_conversation_revision(incoming) <= existing_revision
}

///|
fn mooncode_session_canonical_unchanged(session : MoonCodeSession) -> Bool {
  match session.canonical_unchanged {
    Some(true) => true
    _ => false
  }
}

///|
fn mooncode_session_conversation_revision(session : MoonCodeSession) -> Int {
  match session.mooncode_conversation {
    Some(conversation) => conversation.revision
    None => 0
  }
}

///|
fn mooncode_upsert_session_at_top(
  sessions : Array[MoonCodeSession],
  session : MoonCodeSession,
) -> Array[MoonCodeSession] {
  let stable = match mooncode_find_session(sessions, session.id) {
    Some(existing) =>
      if mooncode_session_response_cannot_replace(existing, session) {
        existing
      } else {
        mooncode_session_with_stable_identity(existing, session)
      }
    None => session
  }
  let next : Array[MoonCodeSession] = [stable]
  for existing in sessions {
    if existing.id != session.id {
      next.push(existing)
    }
  }
  next
}
