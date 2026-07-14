///|
fn app_subscriptions(dispatch : Dispatch[Msg], model : Model) -> @sub.Sub {
  if model.bootstrapped {
    @sub.none
  } else {
    // Give the native WebView and its supervised localhost sidecar a moment to
    // finish attaching before the first request batch. A 1 ms interval could
    // race the initial mount in Lepusa and leave the visible shell waiting
    // until the user guessed to press Refresh.
    @sub.every(150, dispatch(Bootstrap))
  }
}

///|
fn bootstrap_action(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  if model.bootstrapped {
    (@rabbita.none, model)
  } else {
    (bootstrap_cmd(dispatch), { ..model, bootstrapped: true })
  }
}

///|
fn bootstrap_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @rabbita.batch([
    fetch_workspace_metadata_cmd(dispatch),
    fetch_workspaces_cmd(dispatch),
    fetch_moonclaw_daemon_cmd(dispatch),
    fetch_moonclaw_models_cmd(dispatch),
    fetch_mooncode_sessions_cmd(dispatch, ""),
    fetch_moonflow_runs_cmd(dispatch),
    fetch_book_base_types_cmd(dispatch),
    fetch_book_patterns_cmd(dispatch),
    schedule_import_drop_poll(dispatch),
    install_desk_location_enter_cmd(),
    install_mooncode_enter_send_cmd(),
    install_browser_preview_observer_cmd(),
  ])
}
