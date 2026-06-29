///|
fn update_mooncode_poll_actions(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    PollMoonCodeSessions =>
      (
        @rabbita.batch([
          fetch_moonclaw_daemon_cmd(dispatch),
          fetch_mooncode_sessions_cmd(dispatch, model.selected_workspace_id),
          fetch_selected_mooncode_stream_cmd(dispatch, model),
          fetch_mooncode_runtime_event_sink_cmd(
            dispatch,
            model.selected_mooncode_session_id,
          ),
          schedule_mooncode_poll(dispatch),
        ]),
        model,
      )
    _ => (@rabbita.none, model)
  }
}
