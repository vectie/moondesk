///|
fn update_mooncode_transport_actions(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    RefreshMoonCodeMetadata(generation) =>
      if generation != model.mooncode_metadata_generation {
        (@rabbita.none, model)
      } else {
        (mooncode_metadata_refresh_cmd(dispatch, model, generation), model)
      }
    ResumeMoonCodeWatch(generation, session_id) =>
      if generation != model.mooncode_watch_generation ||
        session_id != model.selected_mooncode_session_id ||
        model.workspace_mode != MoonCode {
        (@rabbita.none, model)
      } else {
        (mooncode_watch_cmd(dispatch, model), model)
      }
    _ => (@rabbita.none, model)
  }
}
