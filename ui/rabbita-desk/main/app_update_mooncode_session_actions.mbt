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
        sync_shell_cmd(MoonCode, Files),
        {
          ..model,
          workspace_mode: MoonCode,
          activity: Files,
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
  if model.mooncode_prompt.trim().to_owned() == "" {
    (
      sync_shell_cmd(MoonCode, Files),
      {
        ..model,
        workspace_mode: MoonCode,
        activity: Files,
        command_open: false,
        mooncode_composer_status: "enter a message",
      },
    )
  } else {
    match selected_mooncode_session(model) {
      Some(session) => {
        let action = mooncode_composer_action(model, session)
        let prompt = model.mooncode_prompt.trim().to_owned()
        (
          sync_shell_batch(
            MoonCode,
            Files,
            send_mooncode_composer_cmd(dispatch, model, session),
          ),
          {
            ..model,
            workspace_mode: MoonCode,
            activity: Files,
            command_open: false,
            mooncode_prompt: "",
            mooncode_conversation_rows: mooncode_append_conversation_user_prompt(
              model.mooncode_conversation_rows,
              session.id,
              prompt,
            ),
            mooncode_pending_prompts: mooncode_append_pending_prompt(
              model.mooncode_pending_prompts,
              session.id,
              prompt,
              mooncode_transcript_rows(model, session).length(),
            ),
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
          sync_shell_batch(
            MoonCode,
            Files,
            create_mooncode_session_cmd(dispatch, model),
          ),
          {
            ..model,
            workspace_mode: MoonCode,
            activity: Files,
            command_open: false,
            mooncode_composer_status: if model.selected_workspace_id == "" {
              "starting General MoonCode"
            } else {
              "starting MoonCode session"
            },
          },
        )
    }
  }
}

///|
fn mooncode_append_pending_prompt(
  prompts : Array[MoonCodePendingPrompt],
  session_id : String,
  content : String,
  after_row_count : Int,
) -> Array[MoonCodePendingPrompt] {
  let next : Array[MoonCodePendingPrompt] = []
  for prompt in prompts {
    next.push(prompt)
  }
  next.push({ session_id, content, status: "queued", after_row_count })
  next
}
