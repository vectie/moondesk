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
            "MoonClaw daemon running on \{status.port}"
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
          mooncode_model: if model.mooncode_model == "" &&
            result.models.length() > 0 {
            result.models[0].name
          } else {
            model.mooncode_model
          },
          mooncode_composer_status: if result.ok {
            "\{result.models.length()} model(s) available"
          } else {
            result.daemon.message
          },
        },
      )
    LoadedMoonClawModels(Err(error)) =>
      (@rabbita.none, { ..model, mooncode_composer_status: error })
    LoadedMoonCodeSessions(Ok(mooncode_sessions)) => {
      let selected = if model.selected_mooncode_session_id != "" &&
        mooncode_session_exists(
          mooncode_sessions,
          model.selected_mooncode_session_id,
        ) {
        model.selected_mooncode_session_id
      } else {
        first_mooncode_session_id(
          mooncode_sessions,
          model.selected_workspace_id,
        )
      }
      let keep_stream = selected == model.mooncode_stream_session_id
      let keep_sink = selected == model.mooncode_runtime_event_sink_session_id
      (
        if selected == "" {
          @rabbita.none
        } else {
          @rabbita.batch([
            fetch_mooncode_runtime_event_sink_cmd(dispatch, selected),
          ])
        },
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
          mooncode_composer_status: "\{mooncode_sessions.length()} MoonCode session(s)",
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
      selected_mooncode_session_id: session.id,
      mooncode_prompt: "",
      mooncode_composer_status: status,
    },
  )
}
