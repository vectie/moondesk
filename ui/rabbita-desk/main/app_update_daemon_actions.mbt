///|
fn update_daemon_actions(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    ControlDaemonTick =>
      (
        sync_activity_batch(Town, dispatch_daemon_cmd(dispatch)),
        {
          ..model,
          activity: Town,
          command_open: false,
          dispatch_status: "running daemon tick",
        },
      )
    FetchDaemonLifecycle =>
      (
        sync_activity_batch(Town, fetch_daemon_lifecycle_cmd(dispatch)),
        {
          ..model,
          activity: Town,
          command_open: false,
          daemon_status: "checking daemon",
        },
      )
    StartDaemon =>
      (
        sync_activity_batch(Town, manage_daemon_cmd(dispatch, "start")),
        {
          ..model,
          activity: Town,
          command_open: false,
          daemon_status: "starting daemon",
        },
      )
    StopDaemon =>
      (
        sync_activity_batch(Town, manage_daemon_cmd(dispatch, "stop")),
        {
          ..model,
          activity: Town,
          command_open: false,
          daemon_status: "stopping daemon",
        },
      )
    RestartDaemon =>
      (
        sync_activity_batch(Town, manage_daemon_cmd(dispatch, "restart")),
        {
          ..model,
          activity: Town,
          command_open: false,
          daemon_status: "restarting daemon",
        },
      )
    EnableDaemonSupervision =>
      (
        sync_activity_batch(Town, set_daemon_supervision_cmd(dispatch, true)),
        {
          ..model,
          activity: Town,
          command_open: false,
          daemon_status: "enabling supervision",
        },
      )
    DisableDaemonSupervision =>
      (
        sync_activity_batch(Town, set_daemon_supervision_cmd(dispatch, false)),
        {
          ..model,
          activity: Town,
          command_open: false,
          daemon_status: "disabling supervision",
        },
      )
    InstallLaunchAgent =>
      (
        sync_activity_batch(Town, manage_launch_agent_cmd(dispatch, "install")),
        {
          ..model,
          activity: Town,
          command_open: false,
          daemon_status: "installing LaunchAgent",
        },
      )
    UninstallLaunchAgent =>
      (
        sync_activity_batch(
          Town,
          manage_launch_agent_cmd(dispatch, "uninstall"),
        ),
        {
          ..model,
          activity: Town,
          command_open: false,
          daemon_status: "removing LaunchAgent",
        },
      )
    RevealSelection =>
      (
        reveal_selection_cmd(dispatch, model),
        { ..model, host_status: "revealing selection" },
      )
    _ => (@rabbita.none, model)
  }
}
