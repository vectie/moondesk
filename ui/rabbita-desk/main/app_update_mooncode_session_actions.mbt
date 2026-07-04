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
        sync_shell_cmd(MoonCode, model.activity),
        {
          ..model,
          workspace_mode: MoonCode,
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
  let keep_stream = session_id != "" &&
    session_id == model.mooncode_stream_session_id
  let keep_sink = session_id != "" &&
    session_id == model.mooncode_runtime_event_sink_session_id &&
    model.mooncode_runtime_event_sink is Some(_)
  {
    ..model,
    selected_mooncode_session_id: session_id,
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
    mooncode_runtime_event_sink_session_id: if keep_sink {
      model.mooncode_runtime_event_sink_session_id
    } else {
      ""
    },
    mooncode_runtime_event_sink_status: if keep_sink {
      model.mooncode_runtime_event_sink_status
    } else {
      "loading runtime events"
    },
    mooncode_runtime_event_sink: if keep_sink {
      model.mooncode_runtime_event_sink
    } else {
      None
    },
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
        mooncode_composer_status: "enter a message",
      },
    )
  } else {
    match selected_mooncode_session(model) {
      Some(session) => {
        let action = mooncode_composer_action(model, session)
        let prompt = model.mooncode_prompt.trim().to_owned()
        let client_turn_id = mooncode_client_turn_id(model, session.id, prompt)
        (
          @rabbita.batch([
            send_mooncode_composer_cmd(dispatch, model, session),
            schedule_mooncode_fast_poll(dispatch),
            schedule_mooncode_poll(dispatch),
            sync_shell_cmd(MoonCode, model.activity),
          ]),
          {
            ..model,
            workspace_mode: MoonCode,
            command_open: false,
            mooncode_prompt: "",
            mooncode_conversation_rows: mooncode_append_conversation_user_prompt(
              model.mooncode_conversation_rows,
              session.id,
              prompt,
              client_turn_id~,
            ),
            mooncode_pending_prompts: mooncode_append_pending_prompt(
              model.mooncode_pending_prompts,
              session.id,
              client_turn_id,
              prompt,
              mooncode_transcript_items(model, session).length(),
              mooncode_transcript_events(model, session).length(),
            ),
            mooncode_composer_status: if action == "steer" {
              "message queued for current turn"
            } else {
              "message queued for MoonCode"
            },
          },
        )
      }
      None => {
        let prompt = model.mooncode_prompt.trim().to_owned()
        let draft_session_id = mooncode_draft_session_id(model)
        let client_turn_id = mooncode_client_turn_id(
          model, draft_session_id, prompt,
        )
        let draft_session = mooncode_draft_session(model).unwrap_or(
          mooncode_local_draft_session_for_prompt(model, draft_session_id),
        )
        (
          @rabbita.batch([
            create_mooncode_session_cmd(dispatch, model),
            schedule_mooncode_fast_poll(dispatch),
            schedule_mooncode_poll(dispatch),
            sync_shell_cmd(MoonCode, model.activity),
          ]),
          {
            ..model,
            workspace_mode: MoonCode,
            command_open: false,
            mooncode_prompt: "",
            mooncode_conversation_rows: mooncode_append_conversation_user_prompt(
              model.mooncode_conversation_rows,
              draft_session_id,
              prompt,
              client_turn_id~,
            ),
            mooncode_pending_prompts: mooncode_append_pending_prompt(
              model.mooncode_pending_prompts,
              draft_session_id,
              client_turn_id,
              prompt,
              mooncode_transcript_items(model, draft_session).length(),
              mooncode_transcript_events(model, draft_session).length(),
            ),
            mooncode_composer_status: "message queued for MoonCode",
          },
        )
      }
    }
  }
}

///|
fn mooncode_local_draft_session_for_prompt(
  model : Model,
  draft_session_id : String,
) -> MoonCodeSession {
  {
    id: draft_session_id,
    workspace_id: model.selected_workspace_id,
    workspace_name: if model.selected_workspace_id == "" {
      "General"
    } else {
      workspace_name(model)
    },
    cwd: if model.selected_workspace_id == "" {
      ""
    } else {
      model.workspace_root_path
    },
    mooncode_runtime_session_id: None,
    title: mooncode_new_session_title(model),
    model: mooncode_selected_runtime_model(model, None),
    status: "queued",
    queued_count: 1,
    transcript: [],
    mooncode_events: [],
    mooncode_conversation: None,
    mooncode_summary: {
      event_count: 0,
      verified_test_count: 0,
      pending_diff_count: 0,
    },
  }
}

///|
fn mooncode_append_pending_prompt(
  prompts : Array[MoonCodePendingPrompt],
  session_id : String,
  client_turn_id : String,
  content : String,
  after_row_count : Int,
  after_event_count : Int,
) -> Array[MoonCodePendingPrompt] {
  let next : Array[MoonCodePendingPrompt] = []
  for prompt in prompts {
    next.push(prompt)
  }
  next.push({
    session_id,
    client_turn_id,
    content,
    status: "queued",
    after_row_count,
    after_event_count,
  })
  next
}
