///|
fn update_mooncode_runtime_results(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    LoadedMoonCodeRuntimeDispatch(session_id, Ok(state)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_dispatch_session_id: session_id,
            mooncode_runtime_dispatch: Some(state),
            mooncode_runtime_dispatch_status: "\{state.runtime_dispatch_count} receipt(s), \{state.runtime_dispatch_pending_count} pending",
          },
        )
      }
    LoadedMoonCodeRuntimeDispatch(session_id, Err(error)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_dispatch_session_id: session_id,
            mooncode_runtime_dispatch: None,
            mooncode_runtime_dispatch_status: error,
          },
        )
      }
    LoadedMoonCodeRuntimeClaimState(session_id, Ok(state)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_claim_session_id: session_id,
            mooncode_runtime_claim: Some(state),
            mooncode_runtime_claim_status: "\{state.claimable_command_count} claimable, \{state.claimed_command_count} claimed, \{state.tool_authorization_blocked_command_count} auth blocked",
          },
        )
      }
    LoadedMoonCodeRuntimeClaimState(session_id, Err(error)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_claim_session_id: session_id,
            mooncode_runtime_claim: None,
            mooncode_runtime_claim_status: error,
          },
        )
      }
    ClaimedMoonCodeRuntime(session_id, force, Ok(response)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        let claimed_count = json_field_int(response, "claimed_count", default=0)
        (
          sync_activity_batch(
            MoonCode,
            @rabbita.batch([
              fetch_mooncode_sessions_cmd(dispatch, model.selected_workspace_id),
              fetch_mooncode_runtime_claim_state_cmd(dispatch, session_id),
              fetch_mooncode_runtime_replay_cmd(dispatch, session_id),
              fetch_mooncode_runtime_dispatch_cmd(dispatch, session_id),
              fetch_mooncode_runtime_command_feed_cmd(dispatch, session_id),
              fetch_mooncode_action_plan_cmd(dispatch, session_id),
              fetch_mooncode_readiness_cmd(dispatch, session_id),
              fetch_mooncode_runtime_evidence_cmd(dispatch, session_id),
              fetch_mooncode_runtime_handoff_cmd(dispatch, session_id),
            ]),
          ),
          {
            ..model,
            mooncode_runtime_claim_session_id: session_id,
            mooncode_runtime_claim_status: if force {
              "force-claimed \{claimed_count} command(s)"
            } else {
              "claimed \{claimed_count} command(s)"
            },
            mooncode_composer_status: if claimed_count == 0 {
              "no claimable MoonCode runtime command"
            } else if force {
              "force-claimed MoonCode runtime command"
            } else {
              "claimed MoonCode runtime command"
            },
          },
        )
      }
    ClaimedMoonCodeRuntime(session_id, force, Err(error)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_claim_session_id: session_id,
            mooncode_runtime_claim_status: if force {
              "force claim failed: \{error}"
            } else {
              "claim failed: \{error}"
            },
            mooncode_composer_status: error,
          },
        )
      }
    AckedMoonCodeRuntimeCommand(session_id, _command_id, status, Ok(response)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        let accepted_count = json_field_int(
          response, "accepted_receipt_count", default=0,
        )
        (
          sync_activity_batch(
            MoonCode,
            @rabbita.batch([
              fetch_mooncode_sessions_cmd(dispatch, model.selected_workspace_id),
              fetch_mooncode_runtime_claim_state_cmd(dispatch, session_id),
              fetch_mooncode_runtime_replay_cmd(dispatch, session_id),
              fetch_mooncode_runtime_dispatch_cmd(dispatch, session_id),
              fetch_mooncode_runtime_command_feed_cmd(dispatch, session_id),
              fetch_mooncode_runtime_event_sink_cmd(dispatch, session_id),
              fetch_mooncode_action_plan_cmd(dispatch, session_id),
              fetch_mooncode_readiness_cmd(dispatch, session_id),
              fetch_mooncode_runtime_evidence_cmd(dispatch, session_id),
              fetch_mooncode_runtime_handoff_cmd(dispatch, session_id),
            ]),
          ),
          {
            ..model,
            mooncode_runtime_claim_session_id: session_id,
            mooncode_runtime_claim_status: "runtime \{status}: \{accepted_count} receipt(s)",
            mooncode_composer_status: if accepted_count == 0 {
              "MoonCode runtime acknowledgement recorded no receipts"
            } else {
              "MoonCode runtime \{status} recorded"
            },
          },
        )
      }
    AckedMoonCodeRuntimeCommand(session_id, _command_id, status, Err(error)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_claim_session_id: session_id,
            mooncode_runtime_claim_status: "runtime \{status} failed: \{error}",
            mooncode_composer_status: error,
          },
        )
      }
    CreatedMoonCodeSession(Ok(session)) =>
      (
        sync_activity_batch(
          MoonCode,
          @rabbita.batch([
            fetch_mooncode_sessions_cmd(dispatch, model.selected_workspace_id),
            fetch_moonclaw_daemon_cmd(dispatch),
            fetch_moonclaw_models_cmd(dispatch),
            fetch_mooncode_runtime_event_sink_cmd(dispatch, session.id),
            fetch_mooncode_eval_report_cmd(dispatch, session.id),
            fetch_mooncode_runtime_handoff_cmd(dispatch, session.id),
            fetch_mooncode_command_queue_cmd(dispatch, session.id),
            fetch_mooncode_runtime_command_feed_cmd(dispatch, session.id),
            fetch_mooncode_runtime_replay_cmd(dispatch, session.id),
            fetch_mooncode_runtime_dispatch_cmd(dispatch, session.id),
            fetch_mooncode_runtime_claim_state_cmd(dispatch, session.id),
            fetch_mooncode_package_candidates_cmd(dispatch, session.id),
            fetch_mooncode_action_plan_cmd(dispatch, session.id),
            fetch_mooncode_readiness_cmd(dispatch, session.id),
            fetch_mooncode_runtime_evidence_cmd(dispatch, session.id),
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
          command_open: false,
          selected_mooncode_session_id: session.id,
          mooncode_prompt: "",
          mooncode_composer_status: "created \{session.title}",
        },
      )
    CreatedMoonCodeSession(Err(error)) =>
      (
        sync_activity_cmd(MoonCode),
        {
          ..model,
          workspace_mode: MoonCode,
          activity: MoonCode,
          command_open: false,
          mooncode_composer_status: error,
        },
      )
    CompletedMoonCodeCommand(Ok(session)) =>
      (
        sync_activity_batch(
          MoonCode,
          @rabbita.batch([
            fetch_mooncode_sessions_cmd(dispatch, model.selected_workspace_id),
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
            fetch_mooncode_preflight_matrix_cmd(
              dispatch, session.id, model.selected_path,
            ),
            fetch_mooncode_runtime_dispatch_cmd(dispatch, session.id),
            fetch_mooncode_runtime_claim_state_cmd(dispatch, session.id),
            schedule_mooncode_poll(dispatch),
          ]),
        ),
        {
          ..model,
          workspace_mode: MoonCode,
          activity: MoonCode,
          command_open: false,
          selected_mooncode_session_id: session.id,
          mooncode_composer_status: "MoonCode command queued",
        },
      )
    CompletedMoonCodeCommand(Err(error)) =>
      match selected_mooncode_session(model) {
        Some(session) =>
          (
            sync_activity_batch(
              MoonCode,
              @rabbita.batch([
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
                fetch_mooncode_action_plan_cmd(dispatch, session.id),
                fetch_mooncode_readiness_cmd(dispatch, session.id),
                fetch_mooncode_runtime_evidence_cmd(dispatch, session.id),
                fetch_mooncode_runtime_dispatch_cmd(dispatch, session.id),
                fetch_mooncode_runtime_claim_state_cmd(dispatch, session.id),
                fetch_mooncode_command_queue_cmd(dispatch, session.id),
                fetch_mooncode_runtime_command_feed_cmd(dispatch, session.id),
                fetch_mooncode_runtime_replay_cmd(dispatch, session.id),
                fetch_mooncode_preflight_matrix_cmd(
                  dispatch, session.id, model.selected_path,
                ),
              ]),
            ),
            {
              ..model,
              workspace_mode: MoonCode,
              activity: MoonCode,
              command_open: false,
              mooncode_composer_status: error,
            },
          )
        None =>
          (
            sync_activity_cmd(MoonCode),
            {
              ..model,
              workspace_mode: MoonCode,
              activity: MoonCode,
              command_open: false,
              mooncode_composer_status: error,
            },
          )
      }
    _ => (@rabbita.none, model)
  }
}
