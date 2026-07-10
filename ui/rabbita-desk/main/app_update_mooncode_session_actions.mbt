///|
fn update_mooncode_session_actions(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    SelectMoonCodeSession(session_id) =>
      (
        @rabbita.batch([
          mooncode_selected_session_cmd(dispatch, model, session_id),
          sync_mooncode_context_cmd(
            mooncode_workspace_id_for_selected_session(model, session_id),
            session_id,
          ),
        ]),
        mooncode_select_session_model(model, session_id),
      )
    NewMoonCodeSession =>
      (
        @rabbita.batch([
          sync_shell_cmd(MoonCode, model.activity),
          sync_mooncode_context_cmd(model.selected_workspace_id, ""),
          clear_mooncode_composer_cmd(),
        ]),
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
  let workspace_id = mooncode_workspace_id_for_selected_session(
    model, session_id,
  )
  {
    ..model,
    selected_workspace_id: workspace_id,
    selected_mooncode_session_id: session_id,
    mooncode_new_chat_active: session_id == "",
  }
}

///|
fn mooncode_workspace_id_for_selected_session(
  model : Model,
  session_id : String,
) -> String {
  if session_id == "" {
    return model.selected_workspace_id
  }
  match mooncode_find_session(model.mooncode_sessions, session_id) {
    Some(session) =>
      if mooncode_session_is_general(session) {
        ""
      } else {
        session.workspace_id
      }
    None => model.selected_workspace_id
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
        if mooncode_selected_session_has_inflight_state(model, session.id) {
          return (
            fetch_mooncode_session_cmd(dispatch, session.id),
            {
              ..model,
              workspace_mode: MoonCode,
              command_open: false,
              mooncode_new_chat_active: if model.selected_mooncode_session_id ==
                "" {
                true
              } else {
                model.mooncode_new_chat_active
              },
              mooncode_composer_status: "waiting for previous MoonCode reply",
            },
          )
        }
        let client_turn_id = mooncode_client_turn_id(model, session.id, prompt)
        let poll_generation = model.mooncode_poll_generation + 1
        (
          mooncode_after_user_submit_cmd(
            dispatch,
            model,
            send_mooncode_composer_cmd(dispatch, model, session),
            poll_generation,
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
            mooncode_poll_generation: poll_generation,
            mooncode_composer_status: "message queued for MoonCode",
          },
        )
      }
      None => {
        let prompt = model.mooncode_prompt.trim().to_owned()
        let draft_session_id = mooncode_draft_session_id(model)
        if mooncode_optimistic_rows_have_session(
            model.mooncode_optimistic_rows,
            draft_session_id,
          ) {
          return (
            fetch_mooncode_sessions_cmd(dispatch, ""),
            {
              ..model,
              workspace_mode: MoonCode,
              command_open: false,
              mooncode_new_chat_active: true,
              mooncode_composer_status: "waiting for previous MoonCode reply",
            },
          )
        }
        let client_turn_id = mooncode_client_turn_id(
          model, draft_session_id, prompt,
        )
        let poll_generation = model.mooncode_poll_generation + 1
        (
          mooncode_after_user_submit_cmd(
            dispatch,
            model,
            create_mooncode_session_cmd(dispatch, model),
            poll_generation,
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
            mooncode_poll_generation: poll_generation,
            mooncode_composer_status: "message queued for MoonCode",
          },
        )
      }
    }
  }
}
