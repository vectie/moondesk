///|
fn update_mooncode_results(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    LoadedMoonClawDaemon(_)
    | ManagedMoonClaw(_)
    | LoadedMoonClawModels(_)
    | LoadedMoonCodeSessions(_)
    | LoadedMoonCodeArchivedSessions(_)
    | LoadedMoonCodeWatch(_, _, _) =>
      update_mooncode_session_results(dispatch, msg, model)
    CreatedMoonCodeSession(_)
    | CompletedMoonCodeCommand(_)
    | ManagedMoonCodeSession(_) =>
      update_mooncode_session_results(dispatch, msg, model)
    _ => (@rabbita.none, model)
  }
}
