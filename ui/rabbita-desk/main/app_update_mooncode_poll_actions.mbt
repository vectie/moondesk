///|
fn update_mooncode_poll_actions(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    PollMoonCodeSessions(generation) =>
      if generation != model.mooncode_poll_generation {
        (@rabbita.none, model)
      } else {
        (mooncode_poll_cmd(dispatch, model, generation), model)
      }
    _ => (@rabbita.none, model)
  }
}
