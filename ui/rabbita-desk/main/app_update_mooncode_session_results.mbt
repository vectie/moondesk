///|
fn update_mooncode_session_results(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    LoadedMoonClawDaemon(Ok(status)) =>
      (
        @rabbita.none,
        {
          ..model,
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
      (@rabbita.none, { ..model, mooncode_composer_status: error })
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
      (@rabbita.none, { ..model, mooncode_composer_status: error })
    LoadedMoonCodeSessions(Ok(mooncode_sessions)) => {
      let mooncode_sessions = mooncode_merge_session_listing(
        model.mooncode_sessions,
        mooncode_sessions,
      )
      let selected = if model.selected_mooncode_session_id != "" &&
        mooncode_session_exists(
          mooncode_sessions,
          model.selected_mooncode_session_id,
        ) {
        model.selected_mooncode_session_id
      } else if mooncode_new_session_draft_active(model) {
        ""
      } else {
        first_mooncode_session_id(
          mooncode_sessions,
          model.selected_workspace_id,
        )
      }
      let keep_stream = selected == model.mooncode_stream_session_id
      let keep_sink = selected == model.mooncode_runtime_event_sink_session_id
      let mooncode_conversation_rows = mooncode_hydrate_selected_conversation(
        model.mooncode_conversation_rows,
        mooncode_sessions,
        selected,
      )
      (
        mooncode_session_hydration_cmd(dispatch, selected, keep_stream, keep_sink),
        {
          ..model,
          mooncode_sessions,
          mooncode_conversation_rows,
          selected_mooncode_session_id: selected,
          mooncode_stream_session_id: if keep_stream {
            model.mooncode_stream_session_id
          } else {
            ""
          },
          mooncode_stream_cursor: if keep_stream {
            model.mooncode_stream_cursor
          } else {
            0
          },
          mooncode_stream_events: if keep_stream {
            model.mooncode_stream_events
          } else {
            []
          },
          mooncode_stream_status: if selected == "" {
            "stream idle"
          } else if keep_stream {
            model.mooncode_stream_status
          } else {
            "stream cursor reset"
          },
          mooncode_stream_checkpoint_session_id: if selected ==
            model.mooncode_stream_checkpoint_session_id {
            model.mooncode_stream_checkpoint_session_id
          } else {
            ""
          },
          mooncode_stream_checkpoint_status: if selected == "" {
            "checkpoint idle"
          } else if selected == model.mooncode_stream_checkpoint_session_id {
            model.mooncode_stream_checkpoint_status
          } else {
            "checkpoint idle"
          },
          mooncode_runtime_event_sink_session_id: if keep_sink {
            model.mooncode_runtime_event_sink_session_id
          } else {
            ""
          },
          mooncode_runtime_event_sink: if keep_sink {
            model.mooncode_runtime_event_sink
          } else {
            None
          },
          mooncode_runtime_event_sink_status: if selected == "" {
            "runtime events idle"
          } else if keep_sink {
            model.mooncode_runtime_event_sink_status
          } else {
            "loading runtime events"
          },
          mooncode_composer_status: if mooncode_new_session_draft_active(model) {
            model.mooncode_composer_status
          } else {
            "\{mooncode_sessions.length()} MoonCode session(s)"
          },
        },
      )
    }
    LoadedMoonCodeSessions(Err(error)) =>
      (@rabbita.none, { ..model, mooncode_composer_status: error })
    CreatedMoonCodeSession(Ok(session)) =>
      mooncode_session_mutation_succeeded(
        dispatch, model, session, "MoonCode session started",
      )
    CreatedMoonCodeSession(Err(error)) =>
      (@rabbita.none, { ..model, mooncode_composer_status: error })
    CompletedMoonCodeCommand(Ok(session)) =>
      mooncode_session_mutation_succeeded(
        dispatch, model, session, "MoonCode message sent",
      )
    CompletedMoonCodeCommand(Err(error)) =>
      (@rabbita.none, { ..model, mooncode_composer_status: error })
    _ => (@rabbita.none, model)
  }
}

///|
fn mooncode_session_hydration_cmd(
  dispatch : Dispatch[Msg],
  selected : String,
  keep_stream : Bool,
  keep_sink : Bool,
) -> @rabbita.Cmd {
  if selected == "" || (keep_stream && keep_sink) {
    @rabbita.none
  } else {
    @rabbita.batch([
      if keep_stream {
        @rabbita.none
      } else {
        fetch_mooncode_stream_cmd(dispatch, selected, 0)
      },
      if keep_sink {
        @rabbita.none
      } else {
        fetch_mooncode_runtime_event_sink_cmd(dispatch, selected)
      },
    ])
  }
}

///|
fn mooncode_hydrate_selected_conversation(
  rows : Array[MoonCodeConversationRow],
  sessions : Array[MoonCodeSession],
  selected : String,
) -> Array[MoonCodeConversationRow] {
  if selected == "" {
    return rows
  }
  for session in sessions {
    if session.id == selected {
      return mooncode_hydrate_conversation_from_session(rows, session)
    }
  }
  rows
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
  (
    sync_shell_batch(
      MoonCode,
      Files,
      @rabbita.batch([
        fetch_mooncode_sessions_cmd(dispatch, model.selected_workspace_id),
        fetch_mooncode_stream_cmd(dispatch, session.id, 0),
        fetch_mooncode_runtime_event_sink_cmd(dispatch, session.id),
        schedule_mooncode_poll(dispatch),
      ]),
    ),
    {
      ..model,
      workspace_mode: MoonCode,
      activity: Files,
      mooncode_sessions: mooncode_upsert_session(
        model.mooncode_sessions,
        session,
      ),
      mooncode_conversation_rows: mooncode_hydrate_conversation_from_session(
        model.mooncode_conversation_rows,
        session,
      ),
      selected_mooncode_session_id: session.id,
      mooncode_prompt: "",
      mooncode_pending_prompts: mooncode_clear_acknowledged_pending_prompts(
        model.mooncode_pending_prompts,
        session.id,
        session.mooncode_events,
      ),
      mooncode_composer_status: status,
    },
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
      next.push(session)
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
