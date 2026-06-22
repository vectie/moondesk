///|
fn update_mooncode_results(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    LoadedMoonClawDaemon(_) | LoadedMoonClawModels(_) | LoadedMoonCodeSessions(_) =>
      update_mooncode_session_results(dispatch, msg, model)
    LoadedMoonCodeStream(_, _) | SavedMoonCodeStreamCheckpoint(_, _) | LoadedMoonCodeRuntimeEventSink(_, _) =>
      update_mooncode_stream_results(dispatch, msg, model)
    CreatedMoonCodeSession(_) | CompletedMoonCodeCommand(_) =>
      update_mooncode_session_results(dispatch, msg, model)
    _ => (@rabbita.none, model)
  }
}
