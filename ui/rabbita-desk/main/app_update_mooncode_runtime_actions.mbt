///|
fn update_mooncode_runtime_actions(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    RunMoonCodeRuntimeLoop => mooncode_start_runtime_loop(dispatch, model)
    RanMoonCodeRuntimeLoop(session_id, Ok(session)) =>
      mooncode_runtime_loop_succeeded(dispatch, model, session_id, session)
    RanMoonCodeRuntimeLoop(session_id, Err(error)) =>
      mooncode_runtime_loop_failed(dispatch, model, session_id, error)
    StartMoonCodeRuntimeService => mooncode_start_runtime_service(dispatch, model)
    StartedMoonCodeRuntimeService(session_id, Ok(session)) =>
      mooncode_runtime_service_started(dispatch, model, session_id, session)
    StartedMoonCodeRuntimeService(session_id, Err(error)) =>
      mooncode_runtime_service_failed(dispatch, model, session_id, error)
    ClaimMoonCodeRuntime(force) => mooncode_claim_runtime(dispatch, model, force)
    AckMoonCodeRuntimeCommand(command_id, status) =>
      mooncode_ack_runtime_command(dispatch, model, command_id, status)
    _ => (@rabbita.none, model)
  }
}

///|
fn mooncode_start_runtime_loop(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match selected_mooncode_session(model) {
    Some(session) =>
      (
        sync_activity_batch(
          MoonCode,
          run_mooncode_runtime_loop_cmd(dispatch, session.id),
        ),
        {
          ..model,
          workspace_mode: MoonCode,
          activity: MoonCode,
          command_open: false,
          mooncode_runtime_claim_session_id: session.id,
          mooncode_runtime_claim_status: "running native runtime loop",
          mooncode_composer_status: "running MoonClaw native MoonCode loop",
        },
      )
    None => mooncode_needs_selected_session(model)
  }
}

///|
fn mooncode_start_runtime_service(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match selected_mooncode_session(model) {
    Some(session) =>
      (
        sync_activity_batch(
          MoonCode,
          start_mooncode_runtime_service_cmd(dispatch, session.id),
        ),
        {
          ..model,
          workspace_mode: MoonCode,
          activity: MoonCode,
          command_open: false,
          mooncode_runtime_claim_session_id: session.id,
          mooncode_runtime_claim_status: "starting native runtime service",
          mooncode_composer_status: "starting MoonClaw native MoonCode service",
        },
      )
    None => mooncode_needs_selected_session(model)
  }
}

///|
fn mooncode_runtime_loop_succeeded(
  dispatch : Dispatch[Msg],
  model : Model,
  session_id : String,
  session : MoonCodeSession,
) -> (@rabbita.Cmd, Model) {
  if session_id != model.selected_mooncode_session_id {
    (@rabbita.none, model)
  } else {
    mooncode_runtime_refresh_after_success(
      dispatch,
      model,
      session,
      claim_status="native runtime loop completed",
      composer_status="MoonClaw native MoonCode loop completed",
    )
  }
}

///|
fn mooncode_runtime_service_started(
  dispatch : Dispatch[Msg],
  model : Model,
  session_id : String,
  session : MoonCodeSession,
) -> (@rabbita.Cmd, Model) {
  if session_id != model.selected_mooncode_session_id {
    (@rabbita.none, model)
  } else {
    mooncode_runtime_refresh_after_success(
      dispatch,
      model,
      session,
      claim_status="native runtime service started",
      composer_status="MoonClaw native MoonCode service started",
    )
  }
}

///|
fn mooncode_runtime_loop_failed(
  dispatch : Dispatch[Msg],
  model : Model,
  session_id : String,
  error : String,
) -> (@rabbita.Cmd, Model) {
  mooncode_runtime_refresh_after_error(
    dispatch,
    model,
    session_id,
    claim_status="native runtime loop failed: \{error}",
    composer_status=error,
  )
}

///|
fn mooncode_runtime_service_failed(
  dispatch : Dispatch[Msg],
  model : Model,
  session_id : String,
  error : String,
) -> (@rabbita.Cmd, Model) {
  mooncode_runtime_refresh_after_error(
    dispatch,
    model,
    session_id,
    claim_status="native runtime service failed: \{error}",
    composer_status=error,
  )
}

///|
fn mooncode_runtime_refresh_after_success(
  dispatch : Dispatch[Msg],
  model : Model,
  session : MoonCodeSession,
  claim_status~ : String,
  composer_status~ : String,
) -> (@rabbita.Cmd, Model) {
  (
    sync_activity_batch(
      MoonCode,
      @rabbita.batch([
        fetch_mooncode_sessions_cmd(dispatch, model.selected_workspace_id),
        fetch_mooncode_stream_cmd(
          dispatch,
          session.id,
          if model.mooncode_stream_session_id == session.id {
            model.mooncode_stream_cursor
          } else {
            0
          },
        ),
        fetch_mooncode_runtime_event_sink_cmd(dispatch, session.id),
        fetch_mooncode_change_set_cmd(dispatch, session.id),
        fetch_mooncode_eval_report_cmd(dispatch, session.id),
        fetch_mooncode_runtime_handoff_cmd(dispatch, session.id),
        fetch_mooncode_patch_set_cmd(dispatch, session.id),
        fetch_mooncode_tool_approvals_cmd(dispatch, session.id),
        fetch_mooncode_test_runs_cmd(dispatch, session.id),
        fetch_mooncode_package_candidates_cmd(dispatch, session.id),
        fetch_mooncode_action_plan_cmd(dispatch, session.id),
        fetch_mooncode_readiness_cmd(dispatch, session.id),
        fetch_mooncode_runtime_evidence_cmd(dispatch, session.id),
        fetch_mooncode_command_queue_cmd(dispatch, session.id),
        fetch_mooncode_runtime_command_feed_cmd(dispatch, session.id),
        fetch_mooncode_runtime_replay_cmd(dispatch, session.id),
        fetch_mooncode_runtime_receipt_cmd(dispatch, session.id),
        fetch_mooncode_runtime_claim_state_cmd(dispatch, session.id),
        fetch_mooncode_preflight_matrix_cmd(
          dispatch, session.id, model.selected_path,
        ),
        schedule_mooncode_poll(dispatch),
      ]),
    ),
    {
      ..model,
      workspace_mode: MoonCode,
      activity: MoonCode,
      selected_mooncode_session_id: session.id,
      mooncode_runtime_claim_session_id: session.id,
      mooncode_runtime_claim_status: claim_status,
      mooncode_composer_status: composer_status,
    },
  )
}

///|
fn mooncode_runtime_refresh_after_error(
  dispatch : Dispatch[Msg],
  model : Model,
  session_id : String,
  claim_status~ : String,
  composer_status~ : String,
) -> (@rabbita.Cmd, Model) {
  if session_id != model.selected_mooncode_session_id {
    (@rabbita.none, model)
  } else {
    (
      sync_activity_batch(
        MoonCode,
        @rabbita.batch([
          fetch_mooncode_stream_cmd(
            dispatch,
            session_id,
            if model.mooncode_stream_session_id == session_id {
              model.mooncode_stream_cursor
            } else {
              0
            },
          ),
          fetch_mooncode_runtime_event_sink_cmd(dispatch, session_id),
          fetch_mooncode_action_plan_cmd(dispatch, session_id),
          fetch_mooncode_readiness_cmd(dispatch, session_id),
          fetch_mooncode_runtime_evidence_cmd(dispatch, session_id),
          fetch_mooncode_runtime_receipt_cmd(dispatch, session_id),
          fetch_mooncode_runtime_claim_state_cmd(dispatch, session_id),
          fetch_mooncode_command_queue_cmd(dispatch, session_id),
          fetch_mooncode_runtime_command_feed_cmd(dispatch, session_id),
          fetch_mooncode_runtime_replay_cmd(dispatch, session_id),
        ]),
      ),
      {
        ..model,
        workspace_mode: MoonCode,
        activity: MoonCode,
        mooncode_runtime_claim_session_id: session_id,
        mooncode_runtime_claim_status: claim_status,
        mooncode_composer_status: composer_status,
      },
    )
  }
}

///|
fn mooncode_claim_runtime(
  dispatch : Dispatch[Msg],
  model : Model,
  force : Bool,
) -> (@rabbita.Cmd, Model) {
  match selected_mooncode_session(model) {
    Some(session) =>
      (
        sync_activity_batch(
          MoonCode,
          claim_mooncode_runtime_cmd(dispatch, session.id, force),
        ),
        {
          ..model,
          workspace_mode: MoonCode,
          activity: MoonCode,
          command_open: false,
          mooncode_runtime_claim_session_id: session.id,
          mooncode_runtime_claim_status: if force {
            "force-claiming runtime command"
          } else {
            "claiming runtime command"
          },
          mooncode_composer_status: if force {
            "force-claiming MoonCode runtime command"
          } else {
            "claiming MoonCode runtime command"
          },
        },
      )
    None => mooncode_needs_selected_session(model)
  }
}

///|
fn mooncode_ack_runtime_command(
  dispatch : Dispatch[Msg],
  model : Model,
  command_id : String,
  status : String,
) -> (@rabbita.Cmd, Model) {
  match selected_mooncode_session(model) {
    Some(session) =>
      (
        sync_activity_batch(
          MoonCode,
          ack_mooncode_runtime_command_cmd(
            dispatch, session.id, command_id, status,
          ),
        ),
        {
          ..model,
          workspace_mode: MoonCode,
          activity: MoonCode,
          command_open: false,
          mooncode_runtime_claim_session_id: session.id,
          mooncode_runtime_claim_status: "recording runtime \{status}",
          mooncode_composer_status: "recording MoonCode runtime acknowledgement",
        },
      )
    None => mooncode_needs_selected_session(model)
  }
}

