///|
fn bootstrap_action(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  if model.bootstrapped {
    (@rabbita.none, model)
  } else {
    (
      bootstrap_cmd(dispatch),
      {
        ..model,
        bootstrapped: true,
        workspace_catalog_state: Some(Loading),
        workspace_catalog_error: "",
      },
    )
  }
}

///|
fn bootstrap_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @rabbita.batch([
    bootstrap_fetch_cmd(dispatch),
    schedule_import_drop_poll(dispatch),
    install_desk_location_enter_cmd(),
    install_mooncode_enter_send_cmd(),
    install_browser_preview_observer_cmd(),
  ])
}

///|
fn bootstrap_fetch_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @rabbita.batch([
    fetch_workspace_metadata_cmd(dispatch),
    fetch_pack_apps_cmd(dispatch),
    fetch_workspaces_cmd(dispatch),
    fetch_moonclaw_daemon_cmd(dispatch),
    fetch_moonflow_capability_cmd(dispatch),
    fetch_moonflow_runs_cmd(dispatch),
    fetch_book_base_types_cmd(dispatch),
    fetch_book_patterns_cmd(dispatch),
  ])
}

///|
fn bootstrap_retry_action(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  (
    bootstrap_fetch_cmd(dispatch),
    {
      ..model,
      loading: true,
      host_status: "Connecting to your library",
      workspace_catalog_state: Some(Loading),
      workspace_catalog_error: "",
    },
  )
}
