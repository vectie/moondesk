///|
fn update_mooncode_session_actions(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    SelectMoonCodeSession(session_id) =>
      (
        mooncode_selected_session_cmd(dispatch, model, session_id),
        mooncode_select_session_model(model, session_id),
      )
    NewMoonCodeSession =>
      (
        sync_shell_cmd(MoonCode, model.activity),
        {
          ..model,
          workspace_mode: MoonCode,
          command_open: false,
          selected_mooncode_session_id: "",
          mooncode_new_chat_active: true,
          mooncode_prompt: "",
          mooncode_composer_status: "new session draft",
        },
      )
    SetMoonCodePrompt(prompt) =>
      (
        @rabbita.none,
        {
          ..model,
          mooncode_prompt: prompt,
          mooncode_new_chat_active: if model.selected_mooncode_session_id == "" {
            true
          } else {
            model.mooncode_new_chat_active
          },
          mooncode_composer_status: "draft",
        },
      )
    SendMoonCodeMessage => mooncode_send_composer(dispatch, model)
    _ => (@rabbita.none, model)
  }
}

///|
fn mooncode_select_session_model(model : Model, session_id : String) -> Model {
  let keep_stream = session_id != "" &&
    session_id == model.mooncode_stream_session_id
  {
    ..model,
    selected_mooncode_session_id: session_id,
    mooncode_new_chat_active: session_id == "",
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
    mooncode_stream_status: if keep_stream {
      model.mooncode_stream_status
    } else {
      "stream cursor reset"
    },
    mooncode_stream_checkpoint_session_id: "",
    mooncode_stream_checkpoint_status: "checkpoint idle",
  }
}

///|
fn mooncode_send_composer(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  if model.mooncode_prompt.trim().to_owned() == "" {
    (
      sync_shell_cmd(MoonCode, model.activity),
      {
        ..model,
        workspace_mode: MoonCode,
        command_open: false,
        mooncode_new_chat_active: model.selected_mooncode_session_id == "",
        mooncode_composer_status: "enter a message",
      },
    )
  } else {
    match selected_mooncode_session(model) {
      Some(session) => {
        let prompt = model.mooncode_prompt.trim().to_owned()
        let client_turn_id = mooncode_client_turn_id(model, session.id, prompt)
        (
          mooncode_after_user_submit_cmd(
            dispatch,
            model,
            send_mooncode_composer_cmd(dispatch, model, session),
          ),
          {
            ..model,
            workspace_mode: MoonCode,
            command_open: false,
            mooncode_new_chat_active: false,
            mooncode_prompt: "",
            mooncode_optimistic_rows: mooncode_append_optimistic_user_prompt(
              model.mooncode_optimistic_rows,
              session.id,
              prompt,
              client_turn_id~,
            ),
            mooncode_next_client_turn_index: model.mooncode_next_client_turn_index +
            1,
            mooncode_composer_status: "message queued for MoonCode",
          },
        )
      }
      None => {
        let prompt = model.mooncode_prompt.trim().to_owned()
        let draft_session_id = mooncode_draft_session_id(model)
        let client_turn_id = mooncode_client_turn_id(
          model, draft_session_id, prompt,
        )
        (
          mooncode_after_user_submit_cmd(
            dispatch,
            model,
            create_mooncode_session_cmd(dispatch, model),
          ),
          {
            ..model,
            workspace_mode: MoonCode,
            command_open: false,
            mooncode_new_chat_active: true,
            mooncode_prompt: "",
            mooncode_optimistic_rows: mooncode_append_optimistic_user_prompt(
              model.mooncode_optimistic_rows,
              draft_session_id,
              prompt,
              client_turn_id~,
            ),
            mooncode_next_client_turn_index: model.mooncode_next_client_turn_index +
            1,
            mooncode_composer_status: "message queued for MoonCode",
          },
        )
      }
    }
  }
}
