///| Apply the source-pane reducer before deriving the command identity. Only a

///|
/// valid RequestSource starts I/O; all other messages are reducer-only.
fn source_pane_action(
  dispatch : Dispatch[Msg],
  msg : SourcePaneMsg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  let source_pane = update_source_pane(model.source_pane, msg)
  let next = { ..model, source_pane, }
  match msg {
    RequestSource(_) => {
      let identity = source_pane_identity(source_pane)
      if identity.workspace_id.trim() != "" &&
        identity.path != "" &&
        source_pane.content is Loading {
        (fetch_source_pane_preview_cmd(dispatch, identity), next)
      } else {
        (@rabbita.none, next)
      }
    }
    _ => (@rabbita.none, next)
  }
}
