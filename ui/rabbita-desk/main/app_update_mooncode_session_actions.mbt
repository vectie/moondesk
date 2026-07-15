///|
fn update_mooncode_session_actions(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    SelectMoonCodeSession(session_id) => {
      let next = mooncode_select_session_model(model, session_id)
      (
        @rabbita.batch([
          mooncode_selected_session_cmd(dispatch, next),
          sync_mooncode_context_cmd(
            mooncode_workspace_id_for_selected_session(model, session_id),
            session_id,
          ),
        ]),
        next,
      )
    }
    NewMoonCodeSession =>
      (
        @rabbita.batch([
          sync_shell_cmd(MoonCode, model.activity),
          sync_mooncode_context_cmd(model.selected_workspace_id, ""),
          clear_mooncode_composer_cmd(),
          stop_mooncode_watch_cmd(),
        ]),
        {
          ..model,
          workspace_mode: MoonCode,
          command_open: false,
          selected_mooncode_session_id: "",
          mooncode_new_chat_active: true,
          mooncode_prompt: "",
          mooncode_watch_generation: model.mooncode_watch_generation + 1,
          mooncode_watch_revision: 0,
          mooncode_watch_sequence: 0,
          mooncode_watch_status: "idle",
          mooncode_watch_failure_count: 0,
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
    SendMoonCodeMessage(prompt) =>
      mooncode_send_composer(dispatch, { ..model, mooncode_prompt: prompt })
    RetryMoonCodeTurn(session_id, prompt) =>
      mooncode_retry_turn(dispatch, model, session_id, prompt)
    CancelMoonCodeWork(session_id, target_command_id) =>
      mooncode_cancel_work(dispatch, model, session_id, target_command_id)
    DecideMoonCodeTool(
      session_id,
      action,
      approval_id,
      target_command_id,
      tool_call_id,
    ) =>
      mooncode_decide_tool(
        dispatch,
        model,
        session_id,
        action,
        approval_id,
        target_command_id,
        tool_call_id,
      )
    _ => (@rabbita.none, model)
  }
}

///|
fn mooncode_retry_turn(
  dispatch : Dispatch[Msg],
  model : Model,
  session_id : String,
  prompt : String,
) -> (@rabbita.Cmd, Model) {
  let prompt = prompt.trim().to_owned()
  if prompt == "" {
    return (
      @rabbita.none,
      { ..model, mooncode_composer_status: "Nothing to retry" },
    )
  }
  match mooncode_find_session(model.mooncode_sessions, session_id) {
    Some(_) => {
      let selected = if model.selected_mooncode_session_id == session_id {
        model
      } else {
        mooncode_select_session_model(model, session_id)
      }
      mooncode_send_composer(dispatch, {
        ..selected,
        mooncode_prompt: prompt,
        mooncode_composer_status: "retrying",
      })
    }
    None =>
      (
        @rabbita.none,
        {
          ..model,
          mooncode_composer_status: "This MoonCode session is no longer available",
        },
      )
  }
}

///|
fn mooncode_cancel_work(
  dispatch : Dispatch[Msg],
  model : Model,
  session_id : String,
  target_command_id : String,
) -> (@rabbita.Cmd, Model) {
  let session_id = if session_id.trim().to_owned() == "" {
    model.selected_mooncode_session_id
  } else {
    session_id
  }
  match mooncode_find_session(model.mooncode_sessions, session_id) {
    Some(session) if target_command_id != "" ||
      mooncode_conversation_has_unfinished_turn(session) ||
      session.status == "running" ||
      session.status == "queued" ||
      session.queued_count > 0 =>
      (
        mooncode_session_command_cmd(
          dispatch,
          model,
          session,
          "cancel",
          target_command_id~,
        ),
        { ..model, mooncode_composer_status: "Cancellation requested" },
      )
    Some(_) =>
      (
        @rabbita.none,
        { ..model, mooncode_composer_status: "MoonCode is not running" },
      )
    None =>
      (
        @rabbita.none,
        {
          ..model,
          mooncode_composer_status: "This MoonCode session is no longer available",
        },
      )
  }
}

///|
fn mooncode_decide_tool(
  dispatch : Dispatch[Msg],
  model : Model,
  session_id : String,
  action : String,
  approval_id : String,
  target_command_id : String,
  tool_call_id : String,
) -> (@rabbita.Cmd, Model) {
  if action != "approve_tool" && action != "reject_tool" {
    return (
      @rabbita.none,
      { ..model, mooncode_composer_status: "Unsupported approval decision" },
    )
  }
  match mooncode_find_session(model.mooncode_sessions, session_id) {
    Some(session) if approval_id != "" && target_command_id != "" =>
      (
        mooncode_session_command_cmd(
          dispatch,
          model,
          session,
          action,
          approval_id~,
          target_command_id~,
          tool_call_id~,
        ),
        {
          ..model,
          mooncode_composer_status: if action == "approve_tool" {
            "Approval sent to MoonClaw"
          } else {
            "Rejection sent to MoonClaw"
          },
        },
      )
    Some(_) =>
      (
        @rabbita.none,
        { ..model, mooncode_composer_status: "Approval target is unavailable" },
      )
    None =>
      (
        @rabbita.none,
        {
          ..model,
          mooncode_composer_status: "This MoonCode session is no longer available",
        },
      )
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
    mooncode_watch_generation: model.mooncode_watch_generation + 1,
    mooncode_watch_revision: 0,
    mooncode_watch_sequence: 0,
    mooncode_watch_status: if session_id == "" {
      "idle"
    } else {
      "connecting"
    },
    mooncode_watch_failure_count: 0,
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
    let draft_session_id = mooncode_draft_session_id(model)
    if model.selected_mooncode_session_id == "" &&
      mooncode_optimistic_rows_have_session(
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
    match selected_mooncode_session(model) {
      Some(session) => {
        let model = {
          ..model,
          mooncode_optimistic_rows: mooncode_drop_acknowledged_optimistic_rows(
            model.mooncode_optimistic_rows,
            session,
          ),
        }
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
