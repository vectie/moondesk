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
        mooncode_sessions,
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
      } else if draft_active {
        ""
      } else {
        first_mooncode_session_id(
          mooncode_sessions,
          model.selected_workspace_id,
        )
      }
      let keep_stream = selected == model.mooncode_stream_session_id
      (
        mooncode_session_hydration_cmd(dispatch, selected, keep_stream),
        {
          ..model,
          mooncode_sessions,
          mooncode_optimistic_rows: optimistic_rows,
          selected_mooncode_session_id: selected,
          mooncode_new_chat_active: selected == "" && draft_active,
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
          mooncode_composer_status: if draft_active {
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
    StartedMoonCodeRuntime(session_id, Ok(_)) =>
      (
        @rabbita.batch([
          fetch_mooncode_sessions_cmd(dispatch, model.selected_workspace_id),
          fetch_mooncode_stream_cmd(dispatch, session_id, 0),
          schedule_mooncode_fast_poll(dispatch),
          schedule_mooncode_poll(dispatch),
        ]),
        {
          ..model,
          mooncode_composer_status: if model.selected_mooncode_session_id ==
            session_id {
            "MoonCode runtime started"
          } else {
            model.mooncode_composer_status
          },
        },
      )
    StartedMoonCodeRuntime(session_id, Err(error)) =>
      (
        @rabbita.batch([
          fetch_mooncode_sessions_cmd(dispatch, model.selected_workspace_id),
          fetch_mooncode_stream_cmd(dispatch, session_id, 0),
          schedule_mooncode_poll(dispatch),
        ]),
        {
          ..model,
          mooncode_composer_status: if model.selected_mooncode_session_id ==
            session_id {
            error
          } else {
            model.mooncode_composer_status
          },
        },
      )
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
    let optimistic_rows = mooncode_drop_acknowledged_optimistic_rows(
      model.mooncode_optimistic_rows,
      session,
    )
    (
      @rabbita.none,
      {
        ..model,
        mooncode_sessions: mooncode_upsert_session(
          model.mooncode_sessions,
          session,
        ),
        mooncode_new_chat_active: false,
        mooncode_optimistic_rows: optimistic_rows,
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
) -> @rabbita.Cmd {
  if selected == "" || keep_stream {
    @rabbita.none
  } else {
    fetch_mooncode_stream_cmd(dispatch, selected, 0)
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
  (
    @rabbita.batch([
      start_mooncode_runtime_service_cmd(dispatch, session.id),
      fetch_mooncode_sessions_cmd(dispatch, model.selected_workspace_id),
      fetch_mooncode_stream_cmd(dispatch, session.id, 0),
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
      mooncode_new_chat_active: false,
      mooncode_prompt: "",
      mooncode_optimistic_rows: optimistic_rows,
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
