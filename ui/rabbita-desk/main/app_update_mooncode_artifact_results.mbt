///|
fn update_mooncode_artifact_results(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    LoadedMoonCodeChangeSet(session_id, Ok(change_set)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_change_set_session_id: session_id,
            mooncode_change_set: Some(change_set),
            mooncode_change_set_status: "\{change_set.status} / \{change_set.diff_count} diff(s), \{change_set.test_count} test(s)",
          },
        )
      }
    LoadedMoonCodeChangeSet(session_id, Err(error)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_change_set_session_id: session_id,
            mooncode_change_set: None,
            mooncode_change_set_status: error,
          },
        )
      }
    LoadedMoonCodeEvalReport(session_id, Ok(report)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_eval_report_session_id: session_id,
            mooncode_eval_report: Some(report),
            mooncode_eval_report_status: "\{report.status} / \{report.passed_check_count} passed, \{report.missing_check_count} missing",
          },
        )
      }
    LoadedMoonCodeEvalReport(session_id, Err(error)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_eval_report_session_id: session_id,
            mooncode_eval_report: None,
            mooncode_eval_report_status: error,
          },
        )
      }
    LoadedMoonCodeRuntimeHandoff(session_id, Ok(handoff)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_handoff_session_id: session_id,
            mooncode_runtime_handoff: Some(handoff),
            mooncode_runtime_handoff_status: "\{handoff.status} / \{handoff.command_count} command(s)",
          },
        )
      }
    LoadedMoonCodeRuntimeHandoff(session_id, Err(error)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_handoff_session_id: session_id,
            mooncode_runtime_handoff: None,
            mooncode_runtime_handoff_status: error,
          },
        )
      }
    LoadedMoonCodePatchSet(session_id, Ok(patch_set)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_patch_set_session_id: session_id,
            mooncode_patch_set: Some(patch_set),
            mooncode_patch_set_status: "\{patch_set.status} / \{patch_set.patch_count} patch(es)",
          },
        )
      }
    LoadedMoonCodePatchSet(session_id, Err(error)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_patch_set_session_id: session_id,
            mooncode_patch_set: None,
            mooncode_patch_set_status: error,
          },
        )
      }
    LoadedMoonCodeToolApprovals(session_id, Ok(approvals)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_tool_approvals_session_id: session_id,
            mooncode_tool_approvals: Some(approvals),
            mooncode_tool_approvals_status: "\{approvals.status} / \{approvals.pending_approval_count} pending",
          },
        )
      }
    LoadedMoonCodeToolApprovals(session_id, Err(error)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_tool_approvals_session_id: session_id,
            mooncode_tool_approvals: None,
            mooncode_tool_approvals_status: error,
          },
        )
      }
    LoadedMoonCodeToolAuthorization(session_id, tool_id, Ok(authorization)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          sync_activity_batch(
            MoonCode,
            @rabbita.batch([
              fetch_mooncode_sessions_cmd(dispatch, model.selected_workspace_id),
              fetch_mooncode_tool_approvals_cmd(dispatch, session_id),
              fetch_mooncode_action_plan_cmd(dispatch, session_id),
              fetch_mooncode_readiness_cmd(dispatch, session_id),
              fetch_mooncode_runtime_evidence_cmd(dispatch, session_id),
              fetch_mooncode_preflight_matrix_cmd(
                dispatch, session_id, model.selected_path,
              ),
            ]),
          ),
          {
            ..model,
            mooncode_tool_authorization_session_id: session_id,
            mooncode_tool_authorization: Some(authorization),
            mooncode_tool_authorization_status: "\{tool_id}: \{authorization.decision}",
          },
        )
      }
    LoadedMoonCodeToolAuthorization(session_id, tool_id, Err(error)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_tool_authorization_session_id: session_id,
            mooncode_tool_authorization: None,
            mooncode_tool_authorization_status: "\{tool_id}: \{error}",
          },
        )
      }
    LoadedMoonCodeTestRuns(session_id, Ok(test_runs)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_test_runs_session_id: session_id,
            mooncode_test_runs: Some(test_runs),
            mooncode_test_runs_status: "\{test_runs.status} / \{test_runs.passed_run_count} passed, \{test_runs.failed_run_count} failed",
          },
        )
      }
    LoadedMoonCodeTestRuns(session_id, Err(error)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_test_runs_session_id: session_id,
            mooncode_test_runs: None,
            mooncode_test_runs_status: error,
          },
        )
      }
    LoadedMoonCodePackageCandidates(session_id, Ok(candidates)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_package_candidates_session_id: session_id,
            mooncode_package_candidates: Some(candidates),
            mooncode_package_candidates_status: "\{candidates.status} / \{candidates.source_bound_package_count} source-bound, \{candidates.missing_source_package_count} missing-source",
          },
        )
      }
    LoadedMoonCodePackageCandidates(session_id, Err(error)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_package_candidates_session_id: session_id,
            mooncode_package_candidates: None,
            mooncode_package_candidates_status: error,
          },
        )
      }
    LoadedMoonCodeActionPlan(session_id, Ok(plan)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_action_plan_session_id: session_id,
            mooncode_action_plan: Some(plan),
            mooncode_action_plan_status: "\{plan.status} / \{plan.next_required_action}",
          },
        )
      }
    LoadedMoonCodeActionPlan(session_id, Err(error)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_action_plan_session_id: session_id,
            mooncode_action_plan: None,
            mooncode_action_plan_status: error,
          },
        )
      }
    LoadedMoonCodeReadiness(session_id, Ok(readiness)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_readiness_session_id: session_id,
            mooncode_readiness: Some(readiness),
            mooncode_readiness_status: "\{if readiness.blocked_count == 0 { "ready" } else { "blocked" }} / \{readiness.passed_count}/\{readiness.check_count} / \{readiness.blocked_count} blocker(s)",
          },
        )
      }
    LoadedMoonCodeReadiness(session_id, Err(error)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_readiness_session_id: session_id,
            mooncode_readiness: None,
            mooncode_readiness_status: error,
          },
        )
      }
    LoadedMoonCodeRuntimeEvidence(session_id, Ok(evidence)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_evidence_session_id: session_id,
            mooncode_runtime_evidence: Some(evidence),
            mooncode_runtime_evidence_status: "\{evidence.status} / \{evidence.proven_command_count}/\{evidence.command_count} command(s) proven",
          },
        )
      }
    LoadedMoonCodeRuntimeEvidence(session_id, Err(error)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_evidence_session_id: session_id,
            mooncode_runtime_evidence: None,
            mooncode_runtime_evidence_status: error,
          },
        )
      }
    LoadedMoonCodeCommandQueue(session_id, Ok(queue)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_command_queue_session_id: session_id,
            mooncode_command_queue: Some(queue),
            mooncode_command_queue_status: "\{queue.command_count} command(s)",
          },
        )
      }
    LoadedMoonCodeCommandQueue(session_id, Err(error)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_command_queue_session_id: session_id,
            mooncode_command_queue: None,
            mooncode_command_queue_status: error,
          },
        )
      }
    LoadedMoonCodeRuntimeCommandFeed(session_id, Ok(feed)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_command_feed_session_id: session_id,
            mooncode_runtime_command_feed: Some(feed),
            mooncode_runtime_command_feed_status: "\{feed.runtime_command_count} runtime command(s), \{feed.runtime_receipt_pending_count} pending receipt",
          },
        )
      }
    LoadedMoonCodeRuntimeCommandFeed(session_id, Err(error)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_command_feed_session_id: session_id,
            mooncode_runtime_command_feed: None,
            mooncode_runtime_command_feed_status: error,
          },
        )
      }
    LoadedMoonCodeRuntimeReplay(session_id, Ok(replay)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_replay_session_id: session_id,
            mooncode_runtime_replay: Some(replay),
            mooncode_runtime_replay_status: "\{replay.pending_command_count} pending, \{replay.delivered_command_count} delivered",
          },
        )
      }
    LoadedMoonCodeRuntimeReplay(session_id, Err(error)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_replay_session_id: session_id,
            mooncode_runtime_replay: None,
            mooncode_runtime_replay_status: error,
          },
        )
      }
    LoadedMoonCodeCommandPreflight(session_id, _action, Ok(preflight)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        let preflights = mooncode_replace_command_preflight(
          model.mooncode_preflights, preflight,
        )
        (
          @rabbita.none,
          {
            ..model,
            mooncode_preflight_session_id: session_id,
            mooncode_preflights: preflights,
            mooncode_preflight_status: mooncode_preflight_status(preflights),
          },
        )
      }
    LoadedMoonCodeCommandPreflight(session_id, action, Err(error)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_preflight_session_id: session_id,
            mooncode_preflight_status: "\{action}: \{error}",
          },
        )
      }
    _ => (@rabbita.none, model)
  }
}
