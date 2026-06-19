///|
fn update_mooncode_session_results(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    LoadedMoonClawDaemon(Ok(status)) =>
      (
        @rabbita.none,
        {
          ..model,
          moonclaw_daemon: Some(status),
          mooncode_composer_status: if status.running {
            "MoonClaw daemon running on \{status.port}"
          } else {
            status.message
          },
        },
      )
    LoadedMoonClawDaemon(Err(error)) =>
      (@rabbita.none, { ..model, mooncode_composer_status: error })
    LoadedMoonClawModels(Ok(result)) =>
      (
        @rabbita.none,
        {
          ..model,
          moonclaw_daemon: Some(result.daemon),
          moonclaw_models: result.models,
          mooncode_model: if model.mooncode_model == "" && result.models.length() > 0 {
            result.models[0].name
          } else {
            model.mooncode_model
          },
          mooncode_composer_status: if result.ok {
            "\{result.models.length()} model(s) available"
          } else {
            result.daemon.message
          },
        },
      )
    LoadedMoonClawModels(Err(error)) =>
      (@rabbita.none, { ..model, mooncode_composer_status: error })
    LoadedMoonCodeSessions(Ok(mooncode_sessions)) => {
      let selected = if model.selected_mooncode_session_id != "" &&
        mooncode_session_exists(mooncode_sessions, model.selected_mooncode_session_id) {
        model.selected_mooncode_session_id
      } else {
        first_mooncode_session_id(mooncode_sessions, model.selected_workspace_id)
      }
      let stream_session_id = if selected == model.mooncode_stream_session_id {
        model.mooncode_stream_session_id
      } else {
        ""
      }
      let stream_cursor = if selected == model.mooncode_stream_session_id {
        model.mooncode_stream_cursor
      } else {
        0
      }
      let stream_events = if selected == model.mooncode_stream_session_id {
        model.mooncode_stream_events
      } else {
        []
      }
      let runtime_event_sink = if selected ==
        model.mooncode_runtime_event_sink_session_id {
        model.mooncode_runtime_event_sink
      } else {
        None
      }
      let stream_checkpoint_session_id = if selected ==
        model.mooncode_stream_checkpoint_session_id {
        model.mooncode_stream_checkpoint_session_id
      } else {
        ""
      }
      let change_set = if selected == model.mooncode_change_set_session_id {
        model.mooncode_change_set
      } else {
        None
      }
      let eval_report = if selected == model.mooncode_eval_report_session_id {
        model.mooncode_eval_report
      } else {
        None
      }
      let runtime_handoff = if selected ==
        model.mooncode_runtime_handoff_session_id {
        model.mooncode_runtime_handoff
      } else {
        None
      }
      let patch_set = if selected == model.mooncode_patch_set_session_id {
        model.mooncode_patch_set
      } else {
        None
      }
      let tool_approvals = if selected == model.mooncode_tool_approvals_session_id {
        model.mooncode_tool_approvals
      } else {
        None
      }
      let tool_authorization = if selected ==
        model.mooncode_tool_authorization_session_id {
        model.mooncode_tool_authorization
      } else {
        None
      }
      let test_runs = if selected == model.mooncode_test_runs_session_id {
        model.mooncode_test_runs
      } else {
        None
      }
      let package_candidates = if selected ==
        model.mooncode_package_candidates_session_id {
        model.mooncode_package_candidates
      } else {
        None
      }
      let action_plan = if selected == model.mooncode_action_plan_session_id {
        model.mooncode_action_plan
      } else {
        None
      }
      let readiness = if selected ==
        model.mooncode_readiness_session_id {
        model.mooncode_readiness
      } else {
        None
      }
      let runtime_evidence = if selected ==
        model.mooncode_runtime_evidence_session_id {
        model.mooncode_runtime_evidence
      } else {
        None
      }
      let command_queue = if selected == model.mooncode_command_queue_session_id {
        model.mooncode_command_queue
      } else {
        None
      }
      let runtime_command_feed = if selected ==
        model.mooncode_runtime_command_feed_session_id {
        model.mooncode_runtime_command_feed
      } else {
        None
      }
      let runtime_replay = if selected ==
        model.mooncode_runtime_replay_session_id {
        model.mooncode_runtime_replay
      } else {
        None
      }
      let runtime_dispatch = if selected ==
        model.mooncode_runtime_dispatch_session_id {
        model.mooncode_runtime_dispatch
      } else {
        None
      }
      let runtime_claim = if selected ==
        model.mooncode_runtime_claim_session_id {
        model.mooncode_runtime_claim
      } else {
        None
      }
      (
        if selected == "" {
          @rabbita.none
        } else {
          @rabbita.batch([
            fetch_mooncode_runtime_event_sink_cmd(dispatch, selected),
            fetch_mooncode_change_set_cmd(dispatch, selected),
            fetch_mooncode_eval_report_cmd(dispatch, selected),
            fetch_mooncode_runtime_handoff_cmd(dispatch, selected),
            fetch_mooncode_patch_set_cmd(dispatch, selected),
            fetch_mooncode_tool_approvals_cmd(dispatch, selected),
            fetch_mooncode_test_runs_cmd(dispatch, selected),
            fetch_mooncode_package_candidates_cmd(dispatch, selected),
            fetch_mooncode_action_plan_cmd(dispatch, selected),
            fetch_mooncode_readiness_cmd(dispatch, selected),
            fetch_mooncode_runtime_evidence_cmd(dispatch, selected),
            fetch_mooncode_command_queue_cmd(dispatch, selected),
            fetch_mooncode_runtime_command_feed_cmd(dispatch, selected),
            fetch_mooncode_runtime_replay_cmd(dispatch, selected),
            fetch_mooncode_preflight_matrix_cmd(
              dispatch, selected, model.selected_path,
            ),
            fetch_mooncode_runtime_dispatch_cmd(dispatch, selected),
            fetch_mooncode_runtime_claim_state_cmd(dispatch, selected),
          ])
        },
        {
          ..model,
          mooncode_sessions,
          selected_mooncode_session_id: selected,
          mooncode_stream_session_id: stream_session_id,
          mooncode_stream_cursor: stream_cursor,
          mooncode_stream_events: stream_events,
          mooncode_stream_status: if selected == "" {
            "stream idle"
          } else if selected == model.mooncode_stream_session_id {
            model.mooncode_stream_status
          } else {
            "stream cursor reset"
          },
          mooncode_stream_checkpoint_session_id: stream_checkpoint_session_id,
          mooncode_stream_checkpoint_status: if selected == "" {
            "checkpoint idle"
          } else if selected == model.mooncode_stream_checkpoint_session_id {
            model.mooncode_stream_checkpoint_status
          } else {
            "checkpoint idle"
          },
          mooncode_runtime_event_sink_session_id: if selected ==
            model.mooncode_runtime_event_sink_session_id {
            model.mooncode_runtime_event_sink_session_id
          } else {
            ""
          },
          mooncode_runtime_event_sink: runtime_event_sink,
          mooncode_runtime_event_sink_status: if selected == "" {
            "runtime events idle"
          } else if selected == model.mooncode_runtime_event_sink_session_id {
            model.mooncode_runtime_event_sink_status
          } else {
            "loading runtime events"
          },
          mooncode_change_set_session_id: if selected == model.mooncode_change_set_session_id {
            model.mooncode_change_set_session_id
          } else {
            ""
          },
          mooncode_change_set: change_set,
          mooncode_change_set_status: if selected == "" {
            "change set idle"
          } else if selected == model.mooncode_change_set_session_id {
            model.mooncode_change_set_status
          } else {
            "loading change set"
          },
          mooncode_eval_report_session_id: if selected ==
            model.mooncode_eval_report_session_id {
            model.mooncode_eval_report_session_id
          } else {
            ""
          },
          mooncode_eval_report: eval_report,
          mooncode_eval_report_status: if selected == "" {
            "eval report idle"
          } else if selected == model.mooncode_eval_report_session_id {
            model.mooncode_eval_report_status
          } else {
            "loading eval report"
          },
          mooncode_runtime_handoff_session_id: if selected ==
            model.mooncode_runtime_handoff_session_id {
            model.mooncode_runtime_handoff_session_id
          } else {
            ""
          },
          mooncode_runtime_handoff: runtime_handoff,
          mooncode_runtime_handoff_status: if selected == "" {
            "runtime handoff idle"
          } else if selected == model.mooncode_runtime_handoff_session_id {
            model.mooncode_runtime_handoff_status
          } else {
            "loading runtime handoff"
          },
          mooncode_patch_set_session_id: if selected == model.mooncode_patch_set_session_id {
            model.mooncode_patch_set_session_id
          } else {
            ""
          },
          mooncode_patch_set: patch_set,
          mooncode_patch_set_status: if selected == "" {
            "patch set idle"
          } else if selected == model.mooncode_patch_set_session_id {
            model.mooncode_patch_set_status
          } else {
            "loading patch set"
          },
          mooncode_tool_approvals_session_id: if selected ==
            model.mooncode_tool_approvals_session_id {
            model.mooncode_tool_approvals_session_id
          } else {
            ""
          },
          mooncode_tool_approvals: tool_approvals,
          mooncode_tool_approvals_status: if selected == "" {
            "tool approvals idle"
          } else if selected == model.mooncode_tool_approvals_session_id {
            model.mooncode_tool_approvals_status
          } else {
            "loading tool approvals"
          },
          mooncode_tool_authorization_session_id: if selected ==
            model.mooncode_tool_authorization_session_id {
            model.mooncode_tool_authorization_session_id
          } else {
            ""
          },
          mooncode_tool_authorization: tool_authorization,
          mooncode_tool_authorization_status: if selected == "" {
            "tool authorization idle"
          } else if selected == model.mooncode_tool_authorization_session_id {
            model.mooncode_tool_authorization_status
          } else {
            "tool authorization idle"
          },
          mooncode_test_runs_session_id: if selected ==
            model.mooncode_test_runs_session_id {
            model.mooncode_test_runs_session_id
          } else {
            ""
          },
          mooncode_test_runs: test_runs,
          mooncode_test_runs_status: if selected == "" {
            "test runs idle"
          } else if selected == model.mooncode_test_runs_session_id {
            model.mooncode_test_runs_status
          } else {
            "loading test runs"
          },
          mooncode_package_candidates_session_id: if selected ==
            model.mooncode_package_candidates_session_id {
            model.mooncode_package_candidates_session_id
          } else {
            ""
          },
          mooncode_package_candidates: package_candidates,
          mooncode_package_candidates_status: if selected == "" {
            "package candidates idle"
          } else if selected == model.mooncode_package_candidates_session_id {
            model.mooncode_package_candidates_status
          } else {
            "loading package candidates"
          },
          mooncode_action_plan_session_id: if selected ==
            model.mooncode_action_plan_session_id {
            model.mooncode_action_plan_session_id
          } else {
            ""
          },
          mooncode_action_plan: action_plan,
          mooncode_action_plan_status: if selected == "" {
            "action plan idle"
          } else if selected == model.mooncode_action_plan_session_id {
            model.mooncode_action_plan_status
          } else {
            "loading action plan"
          },
          mooncode_readiness_session_id: if selected ==
            model.mooncode_readiness_session_id {
            model.mooncode_readiness_session_id
          } else {
            ""
          },
          mooncode_readiness: readiness,
          mooncode_readiness_status: if selected == "" {
            "readiness idle"
          } else if selected == model.mooncode_readiness_session_id {
            model.mooncode_readiness_status
          } else {
            "loading readiness"
          },
          mooncode_runtime_evidence_session_id: if selected ==
            model.mooncode_runtime_evidence_session_id {
            model.mooncode_runtime_evidence_session_id
          } else {
            ""
          },
          mooncode_runtime_evidence: runtime_evidence,
          mooncode_runtime_evidence_status: if selected == "" {
            "runtime evidence idle"
          } else if selected == model.mooncode_runtime_evidence_session_id {
            model.mooncode_runtime_evidence_status
          } else {
            "loading runtime evidence"
          },
          mooncode_command_queue_session_id: if selected ==
            model.mooncode_command_queue_session_id {
            model.mooncode_command_queue_session_id
          } else {
            ""
          },
          mooncode_command_queue: command_queue,
          mooncode_command_queue_status: if selected == "" {
            "command queue idle"
          } else if selected == model.mooncode_command_queue_session_id {
            model.mooncode_command_queue_status
          } else {
            "loading command queue"
          },
          mooncode_runtime_command_feed_session_id: if selected ==
            model.mooncode_runtime_command_feed_session_id {
            model.mooncode_runtime_command_feed_session_id
          } else {
            ""
          },
          mooncode_runtime_command_feed: runtime_command_feed,
          mooncode_runtime_command_feed_status: if selected == "" {
            "runtime feed idle"
          } else if selected == model.mooncode_runtime_command_feed_session_id {
            model.mooncode_runtime_command_feed_status
          } else {
            "loading runtime feed"
          },
          mooncode_runtime_replay_session_id: if selected ==
            model.mooncode_runtime_replay_session_id {
            model.mooncode_runtime_replay_session_id
          } else {
            ""
          },
          mooncode_runtime_replay: runtime_replay,
          mooncode_runtime_replay_status: if selected == "" {
            "runtime replay idle"
          } else if selected == model.mooncode_runtime_replay_session_id {
            model.mooncode_runtime_replay_status
          } else {
            "loading runtime replay"
          },
          mooncode_preflight_session_id: if selected ==
            model.mooncode_preflight_session_id {
            model.mooncode_preflight_session_id
          } else {
            ""
          },
          mooncode_preflights: if selected == model.mooncode_preflight_session_id {
            model.mooncode_preflights
          } else {
            []
          },
          mooncode_preflight_status: if selected == "" {
            "preflight idle"
          } else if selected == model.mooncode_preflight_session_id {
            model.mooncode_preflight_status
          } else {
            "loading preflight gates"
          },
          mooncode_runtime_dispatch_session_id: if selected ==
            model.mooncode_runtime_dispatch_session_id {
            model.mooncode_runtime_dispatch_session_id
          } else {
            ""
          },
          mooncode_runtime_dispatch: runtime_dispatch,
          mooncode_runtime_dispatch_status: if selected == "" {
            "runtime dispatch idle"
          } else if selected == model.mooncode_runtime_dispatch_session_id {
            model.mooncode_runtime_dispatch_status
          } else {
            "loading runtime dispatch"
          },
          mooncode_runtime_claim_session_id: if selected ==
            model.mooncode_runtime_claim_session_id {
            model.mooncode_runtime_claim_session_id
          } else {
            ""
          },
          mooncode_runtime_claim: runtime_claim,
          mooncode_runtime_claim_status: if selected == "" {
            "runtime claim idle"
          } else if selected == model.mooncode_runtime_claim_session_id {
            model.mooncode_runtime_claim_status
          } else {
            "loading runtime claim"
          },
          mooncode_composer_status: "\{mooncode_sessions.length()} MoonCode session(s)",
        },
      )
    }
    LoadedMoonCodeSessions(Err(error)) =>
      (@rabbita.none, { ..model, mooncode_composer_status: error })
    LoadedMoonCodeCapabilities(Ok(capabilities)) =>
      (
        @rabbita.none,
        {
          ..model,
          mooncode_capabilities: Some(capabilities),
          mooncode_status: "MoonCode \{capabilities.component}.v\{capabilities.version} contract loaded",
        },
      )
    LoadedMoonCodeCapabilities(Err(error)) =>
      (@rabbita.none, { ..model, mooncode_status: error })
    _ => (@rabbita.none, model)
  }
}
