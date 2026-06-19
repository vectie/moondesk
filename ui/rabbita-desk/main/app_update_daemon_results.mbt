///|
fn update_daemon_results(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    LoadedDaemonLifecycle(Ok(result)) =>
      (
        @rabbita.none,
        {
          ..model,
          daemon_lifecycle: Some(result),
          daemon_status: daemon_lifecycle_label(result),
        },
      )
    LoadedDaemonLifecycle(Err(error)) =>
      (@rabbita.none, { ..model, daemon_status: error })
    DispatchedDaemon(Ok(result)) =>
      (
        sync_activity_batch(
          Town,
          @rabbita.batch([
            fetch_requests_cmd(dispatch),
            fetch_messages_cmd(dispatch),
            fetch_standing_goals_cmd(dispatch),
            fetch_analytics_cmd(dispatch),
            fetch_town_progress_cmd(dispatch),
            fetch_town_events_cmd(dispatch),
            fetch_runs_cmd(dispatch, model.selected_workspace_id),
            fetch_moonclaw_progress_cmd(dispatch, model.selected_workspace_id),
            fetch_daemon_lifecycle_cmd(dispatch),
            fetch_launch_agent_cmd(dispatch),
          ]),
        ),
        {
          ..model,
          activity: Town,
          command_open: false,
          dispatch_status: if result.ok {
            "\{result.status} (\{result.id}) -> \{result.path}"
          } else {
            "\{result.status} (\{result.exit_code}) \{result.path}: \{if result.stderr == "" { result.stdout } else { result.stderr }}"
          },
        },
      )
    DispatchedDaemon(Err(error)) =>
      (@rabbita.none, { ..model, dispatch_status: error })
    ManagedDaemon(Ok(result)) =>
      (
        sync_activity_batch(
          Town,
          @rabbita.batch([
            fetch_analytics_cmd(dispatch),
            fetch_town_progress_cmd(dispatch),
            fetch_town_events_cmd(dispatch),
            fetch_daemon_lifecycle_cmd(dispatch),
            fetch_launch_agent_cmd(dispatch),
          ]),
        ),
        {
          ..model,
          activity: Town,
          command_open: false,
          daemon_lifecycle: Some(result),
          daemon_status: daemon_lifecycle_label(result),
          dispatch_status: result.message,
        },
      )
    ManagedDaemon(Err(error)) =>
      (@rabbita.none, { ..model, daemon_status: error, dispatch_status: error })
    LoadedLaunchAgent(Ok(result)) =>
      (
        @rabbita.none,
        {
          ..model,
          launch_agent: Some(result),
          daemon_status: launch_agent_label(result),
        },
      )
    LoadedLaunchAgent(Err(error)) =>
      (@rabbita.none, { ..model, daemon_status: error })
    ManagedLaunchAgent(Ok(result)) =>
      (
        fetch_launch_agent_cmd(dispatch),
        {
          ..model,
          launch_agent: Some(result),
          daemon_status: launch_agent_label(result),
          dispatch_status: result.message,
        },
      )
    ManagedLaunchAgent(Err(error)) =>
      (@rabbita.none, { ..model, daemon_status: error })
    RevealedSelection(Ok(result)) =>
      (
        @rabbita.none,
        {
          ..model,
          reveal_status: if result.ok {
            "\{result.status}: \{result.path}"
          } else {
            "\{result.status} (\{result.exit_code}) \{result.absolute_path} [\{result.workspace_id}]"
          },
        },
      )
    RevealedSelection(Err(error)) =>
      (@rabbita.none, { ..model, reveal_status: error })
    _ => (@rabbita.none, model)
  }
}

