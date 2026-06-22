///|
fn update_mooncode_actions(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    SelectMoonCodeSession(_)
    | NewMoonCodeSession
    | SetMoonCodePrompt(_)
    | ToggleMoonCodeWebSearch
    | SendMoonCodeMessage => update_mooncode_session_actions(dispatch, msg, model)
    PollMoonCodeSessions => update_mooncode_poll_actions(dispatch, msg, model)
    _ => (@rabbita.none, model)
  }
}
