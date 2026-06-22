///|
fn update_mooncode_session_actions(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    SelectMoonCodeSession(session_id) =>
      (
        mooncode_selected_session_reload_cmd(dispatch, session_id),
        mooncode_select_session_model(model, session_id),
      )
    NewMoonCodeSession =>
      (
        sync_activity_cmd(MoonCode),
        {
          ..model,
          workspace_mode: MoonCode,
          activity: MoonCode,
          command_open: false,
          selected_mooncode_session_id: "",
          mooncode_prompt: "",
          mooncode_composer_status: "new session draft",
        },
      )
    SetMoonCodePrompt(prompt) =>
      (
        @rabbita.none,
        { ..model, mooncode_prompt: prompt, mooncode_composer_status: "draft" },
      )
    ToggleMoonCodeWebSearch =>
      (
        @rabbita.none,
        {
          ..model,
          mooncode_web_search: !model.mooncode_web_search,
          mooncode_composer_status: if !model.mooncode_web_search {
            "web search on"
          } else {
            "web search off"
          },
        },
      )
    SendMoonCodeMessage => mooncode_send_composer(dispatch, model)
    _ => (@rabbita.none, model)
  }
}

///|
fn mooncode_selected_session_reload_cmd(
  dispatch : Dispatch[Msg],
  session_id : String,
) -> @rabbita.Cmd {
  @rabbita.batch([
    fetch_mooncode_stream_cmd(dispatch, session_id, 0),
    fetch_mooncode_runtime_event_sink_cmd(dispatch, session_id),
  ])
}

///|
fn mooncode_select_session_model(model : Model, session_id : String) -> Model {
  {
    ..model,
    selected_mooncode_session_id: session_id,
    mooncode_stream_session_id: "",
    mooncode_stream_cursor: 0,
    mooncode_stream_events: [],
    mooncode_stream_status: "stream cursor reset",
    mooncode_stream_checkpoint_session_id: "",
    mooncode_stream_checkpoint_status: "checkpoint idle",
    mooncode_runtime_event_sink_session_id: "",
    mooncode_runtime_event_sink_status: "loading runtime events",
    mooncode_runtime_event_sink: None,
  }
}

///|
fn mooncode_send_composer(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  if model.selected_workspace_id == "" {
    (
      sync_activity_cmd(MoonCode),
      {
        ..model,
        workspace_mode: MoonCode,
        activity: MoonCode,
        command_open: false,
        mooncode_composer_status: "select a book first",
      },
    )
  } else if model.mooncode_prompt.trim().to_owned() == "" {
    (
      sync_activity_cmd(MoonCode),
      {
        ..model,
        workspace_mode: MoonCode,
        activity: MoonCode,
        command_open: false,
        mooncode_composer_status: "enter a message",
      },
    )
  } else {
    match selected_mooncode_session(model) {
      Some(session) => {
        let action = mooncode_composer_action(model, session)
        (
          sync_activity_batch(
            MoonCode,
            send_mooncode_composer_cmd(dispatch, model, session),
          ),
          {
            ..model,
            workspace_mode: MoonCode,
            activity: MoonCode,
            command_open: false,
            mooncode_composer_status: if action == "steer" {
              "steering MoonCode turn"
            } else {
              "prompting MoonCode runtime"
            },
          },
        )
      }
      None =>
        (
          sync_activity_batch(
            MoonCode,
            create_mooncode_session_cmd(dispatch, model),
          ),
          {
            ..model,
            workspace_mode: MoonCode,
            activity: MoonCode,
            command_open: false,
            mooncode_composer_status: "starting MoonCode session",
          },
        )
    }
  }
}
