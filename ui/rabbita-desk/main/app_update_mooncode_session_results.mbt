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
        model,
        mooncode_merge_session_listing(
          model.mooncode_sessions,
          mooncode_sessions,
        ),
      )
      match mooncode_find_acknowledged_draft_session(model, mooncode_sessions) {
        Some(session) =>
          return mooncode_session_mutation_succeeded(
            dispatch,
            { ..model, mooncode_sessions, },
            session,
            "MoonCode session started",
          )
        None => ()
      }
      let selected = if model.selected_mooncode_session_id != "" &&
        mooncode_session_exists(
          mooncode_sessions,
          model.selected_mooncode_session_id,
        ) {
        model.selected_mooncode_session_id
      } else if mooncode_new_session_draft_active(model) ||
        mooncode_draft_session(model) is Some(_) {
        ""
      } else {
        first_mooncode_session_id(
          mooncode_sessions,
          model.selected_workspace_id,
        )
      }
      let keep_stream = selected == model.mooncode_stream_session_id
      let keep_sink = selected == model.mooncode_runtime_event_sink_session_id
      (
        mooncode_session_hydration_cmd(
          dispatch, selected, keep_stream, keep_sink,
        ),
        {
          ..model,
          mooncode_sessions,
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
      (
        @rabbita.none,
        {
          ..model,
          mooncode_composer_status: mooncode_background_status_unless_draft(
            model, error,
          ),
        },
      )
    CreatedMoonCodeSession(Ok(session)) =>
      mooncode_created_session_succeeded(dispatch, model, session)
    CreatedMoonCodeSession(Err(error)) =>
      (@rabbita.none, { ..model, mooncode_composer_status: error })
    CompletedMoonCodeCommand(Ok(session)) =>
      mooncode_session_mutation_succeeded(
        dispatch, model, session, "MoonCode message sent",
      )
    CompletedMoonCodeCommand(Err(error)) =>
      (@rabbita.none, { ..model, mooncode_composer_status: error })
    StartedMoonCodeRuntimeService(session_id, Ok(session)) =>
      mooncode_runtime_service_succeeded(dispatch, model, session_id, session)
    StartedMoonCodeRuntimeService(session_id, Err(error)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          schedule_mooncode_fast_poll(dispatch),
          {
            ..model,
            mooncode_conversation_rows: mooncode_append_conversation_assistant_status(
              model.mooncode_conversation_rows,
              session_id,
              error,
              "failed",
              "runtime-service-error:\{session_id}",
            ),
            mooncode_composer_status: error,
          },
        )
      }
    _ => (@rabbita.none, model)
  }
}

///|
fn mooncode_created_session_succeeded(
  dispatch : Dispatch[Msg],
  model : Model,
  session : MoonCodeSession,
) -> (@rabbita.Cmd, Model) {
  if model.selected_mooncode_session_id == session.id {
    (
      @rabbita.none,
      {
        ..model,
        mooncode_sessions: mooncode_upsert_session(
          model.mooncode_sessions,
          session,
        ),
        mooncode_composer_status: "MoonCode session started",
      },
    )
  } else {
    mooncode_session_mutation_succeeded(
      dispatch, model, session, "MoonCode session started",
    )
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
  let conversation_rows = mooncode_reassign_conversation_session(
    model.mooncode_conversation_rows,
    draft_session_id,
    session.id,
  )
  let pending_prompts = mooncode_reassign_pending_prompts(
    model.mooncode_pending_prompts,
    draft_session_id,
    session.id,
  )
  (
    @rabbita.batch([
      fetch_mooncode_sessions_cmd(dispatch, model.selected_workspace_id),
      fetch_mooncode_stream_cmd(dispatch, session.id, 0),
      fetch_mooncode_runtime_event_sink_cmd(dispatch, session.id),
      start_mooncode_runtime_service_cmd(dispatch, session.id),
      schedule_mooncode_fast_poll(dispatch),
      schedule_mooncode_poll(dispatch),
      sync_shell_cmd(MoonCode, model.activity),
    ]),
    {
      ..model,
      workspace_mode: MoonCode,
      mooncode_sessions: mooncode_upsert_session(
        model.mooncode_sessions,
        session,
      ),
      selected_mooncode_session_id: session.id,
      mooncode_runtime_event_sink_session_id: session.id,
      mooncode_runtime_event_sink: None,
      mooncode_runtime_event_sink_status: "starting runtime service",
      mooncode_prompt: "",
      mooncode_pending_prompts: mooncode_clear_acknowledged_pending_prompts(
        pending_prompts,
        session.id,
        session.mooncode_events,
      ),
      mooncode_conversation_rows: conversation_rows,
      mooncode_composer_status: status,
    },
  )
}

///|
fn mooncode_runtime_service_succeeded(
  dispatch : Dispatch[Msg],
  model : Model,
  session_id : String,
  session : MoonCodeSession,
) -> (@rabbita.Cmd, Model) {
  if session_id != model.selected_mooncode_session_id {
    (
      @rabbita.none,
      {
        ..model,
        mooncode_sessions: mooncode_upsert_session(
          model.mooncode_sessions,
          session,
        ),
      },
    )
  } else {
    (
      @rabbita.batch([
        fetch_mooncode_sessions_cmd(dispatch, model.selected_workspace_id),
        fetch_mooncode_stream_cmd(
          dispatch,
          session_id,
          model.mooncode_stream_cursor,
        ),
        fetch_mooncode_runtime_event_sink_cmd(dispatch, session_id),
        schedule_mooncode_fast_poll(dispatch),
      ]),
      {
        ..model,
        mooncode_sessions: mooncode_upsert_session(
          model.mooncode_sessions,
          session,
        ),
        mooncode_composer_status: "MoonCode runtime updated",
      },
    )
  }
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
