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
    | SendMoonCodeMessage =>
      update_mooncode_session_actions(dispatch, msg, model)
    ManageMoonClaw(action) =>
      (
        manage_moonclaw_cmd(dispatch, action),
        { ..model, mooncode_composer_status: "Starting MoonClaw…" },
      )
    PollMoonCodeSessions(_) =>
      update_mooncode_poll_actions(dispatch, msg, model)
    _ => (@rabbita.none, model)
  }
}
