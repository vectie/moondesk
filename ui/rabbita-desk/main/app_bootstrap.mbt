///|
const BootstrapRetryDelayMillis : Int32 = 5000

///|
fn bootstrap_action(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  if work_handoff_active(model) {
    if model.bootstrapped {
      return (@rabbita.none, model)
    }
    let (cmd, next) = update_work_handoff(dispatch, Resolve, model)
    return (cmd, { ..next, bootstrapped: true, loading: false, })
  }
  if model.bootstrapped {
    (@rabbita.none, model)
  } else {
    (
      @rabbita.batch([
        bootstrap_cmd(dispatch),
        fetch_requested_selection_cmd(dispatch, model),
      ]),
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
    install_import_capture_cmd(),
    schedule_import_drop_poll(dispatch),
    install_desk_location_enter_cmd(dispatch),
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
  if work_handoff_active(model) {
    return update_work_handoff(dispatch, Resolve, model)
  }
  (
    @rabbita.batch([
      bootstrap_fetch_cmd(dispatch),
      fetch_requested_selection_cmd(dispatch, model),
    ]),
    {
      ..model,
      loading: true,
      host_status: "Connecting to your library",
      workspace_catalog_state: Some(Loading),
      workspace_catalog_error: "",
      mooncode_selected_session_loading: model.selected_mooncode_session_id !=
      "",
      mooncode_sessions_error: "",
    },
  )
}
