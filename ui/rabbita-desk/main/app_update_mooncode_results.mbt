///|
fn update_mooncode_results(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    LoadedMoonClawDaemon(_)
    | LoadedMoonClawModels(_)
    | LoadedMoonCodeSessions(_)
    | LoadedMoonCodeSession(_, _) =>
      update_mooncode_session_results(dispatch, msg, model)
    CreatedMoonCodeSession(_) | CompletedMoonCodeCommand(_) =>
      update_mooncode_session_results(dispatch, msg, model)
    _ => (@rabbita.none, model)
  }
}
