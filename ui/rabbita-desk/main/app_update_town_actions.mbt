///|
fn update_town_actions(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    SetRequestPrompt(prompt) =>
      (
        @rabbita.none,
        { ..model, request_prompt: prompt, request_status: "draft" },
      )
    SubmitRequest =>
      (
        sync_activity_batch(Town, submit_request_cmd(dispatch, model)),
        {
          ..model,
          activity: Town,
          command_open: false,
          request_status: "staging request",
        },
      )
    _ => (@rabbita.none, model)
  }
}
