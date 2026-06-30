///|
fn app_subscriptions(dispatch : Dispatch[Msg], model : Model) -> @sub.Sub {
  if model.bootstrapped {
    @sub.none
  } else {
    @sub.every(1, dispatch(Bootstrap))
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
    fetch_workspaces_cmd(dispatch),
    fetch_moonclaw_daemon_cmd(dispatch),
    fetch_moonclaw_models_cmd(dispatch),
    fetch_mooncode_sessions_cmd(dispatch, ""),
    fetch_book_base_types_cmd(dispatch),
    fetch_book_patterns_cmd(dispatch),
    schedule_mooncode_poll(dispatch),
    schedule_import_drop_poll(dispatch),
  ])
}
