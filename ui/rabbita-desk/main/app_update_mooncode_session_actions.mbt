///|
fn update_mooncode_session_actions(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    SelectMoonCodeSession(session_id) =>
      (
        mooncode_selected_session_reload_cmd(dispatch, model, session_id),
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
          mooncode_prompt: "Help me improve \{workspace_name(model)} using the selected context \{model.selected_path}.",
          mooncode_composer_status: "new session draft",
        },
      )
    SetMoonCodePrompt(prompt) =>
      (
        @rabbita.none,
        { ..model, mooncode_prompt: prompt, mooncode_composer_status: "draft" },
      )
    SetMoonClawModel(value) =>
      (
        @rabbita.none,
        { ..model, mooncode_model: value, mooncode_composer_status: "model selected" },
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
  model : Model,
  session_id : String,
) -> @rabbita.Cmd {
  @rabbita.batch([
    fetch_mooncode_stream_cmd(dispatch, session_id, 0),
    fetch_mooncode_runtime_event_sink_cmd(dispatch, session_id),
    fetch_mooncode_change_set_cmd(dispatch, session_id),
    fetch_mooncode_eval_report_cmd(dispatch, session_id),
    fetch_mooncode_runtime_handoff_cmd(dispatch, session_id),
    fetch_mooncode_patch_set_cmd(dispatch, session_id),
    fetch_mooncode_tool_approvals_cmd(dispatch, session_id),
    fetch_mooncode_test_runs_cmd(dispatch, session_id),
    fetch_mooncode_package_candidates_cmd(dispatch, session_id),
    fetch_mooncode_action_plan_cmd(dispatch, session_id),
    fetch_mooncode_readiness_cmd(dispatch, session_id),
    fetch_mooncode_runtime_evidence_cmd(dispatch, session_id),
    fetch_mooncode_command_queue_cmd(dispatch, session_id),
    fetch_mooncode_runtime_command_feed_cmd(dispatch, session_id),
    fetch_mooncode_runtime_replay_cmd(dispatch, session_id),
    fetch_mooncode_preflight_matrix_cmd(
      dispatch, session_id, model.selected_path,
    ),
    fetch_mooncode_runtime_receipt_cmd(dispatch, session_id),
    fetch_mooncode_runtime_claim_state_cmd(dispatch, session_id),
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
    mooncode_change_set_session_id: "",
    mooncode_change_set_status: "loading change set",
    mooncode_change_set: None,
    mooncode_eval_report_session_id: "",
    mooncode_eval_report_status: "loading eval report",
    mooncode_eval_report: None,
    mooncode_runtime_handoff_session_id: "",
    mooncode_runtime_handoff_status: "loading runtime handoff",
    mooncode_runtime_handoff: None,
    mooncode_patch_set_session_id: "",
    mooncode_patch_set_status: "loading patch set",
    mooncode_patch_set: None,
    mooncode_tool_approvals_session_id: "",
    mooncode_tool_approvals_status: "loading tool approvals",
    mooncode_tool_approvals: None,
    mooncode_tool_authorization_session_id: "",
    mooncode_tool_authorization_status: "tool authorization idle",
    mooncode_tool_authorization: None,
    mooncode_test_runs_session_id: "",
    mooncode_test_runs_status: "loading test runs",
    mooncode_test_runs: None,
    mooncode_package_candidates_session_id: "",
    mooncode_package_candidates_status: "loading package candidates",
    mooncode_package_candidates: None,
    mooncode_action_plan_session_id: "",
    mooncode_action_plan_status: "loading action plan",
    mooncode_action_plan: None,
    mooncode_readiness_session_id: "",
    mooncode_readiness_status: "loading readiness",
    mooncode_readiness: None,
    mooncode_runtime_evidence_session_id: "",
    mooncode_runtime_evidence_status: "loading runtime evidence",
    mooncode_runtime_evidence: None,
    mooncode_command_queue_session_id: "",
    mooncode_command_queue_status: "loading command queue",
    mooncode_command_queue: None,
    mooncode_runtime_command_feed_session_id: "",
    mooncode_runtime_command_feed_status: "loading runtime feed",
    mooncode_runtime_command_feed: None,
    mooncode_runtime_replay_session_id: "",
    mooncode_runtime_replay_status: "loading runtime replay",
    mooncode_runtime_replay: None,
    mooncode_preflight_session_id: "",
    mooncode_preflight_status: "loading preflight gates",
    mooncode_preflights: [],
    mooncode_runtime_receipt_session_id: "",
    mooncode_runtime_receipt_status: "loading runtime receipt",
    mooncode_runtime_receipt: None,
    mooncode_runtime_claim_session_id: "",
    mooncode_runtime_claim_status: "loading runtime claim",
    mooncode_runtime_claim: None,
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

///|
fn mooncode_needs_selected_session(model : Model) -> (@rabbita.Cmd, Model) {
  (
    sync_activity_cmd(MoonCode),
    {
      ..model,
      workspace_mode: MoonCode,
      activity: MoonCode,
      command_open: false,
      mooncode_composer_status: "start or select a MoonCode session first",
    },
  )
}

