///|
// A Book file link opens that file, not an empty conversation/editor. Wait for
// the catalog before reading, and never replace a handoff or an edited buffer.
fn open_initial_code_file(
  dispatch : Dispatch[Msg],
  previous : Model,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  if !previous.loading ||
    model.loading ||
    model.workspace_mode != MoonCode ||
    work_handoff_active(model) ||
    previous.selected_path.is_empty() ||
    !has_workspace(model.workspaces, model.selected_workspace_id) ||
    !(model.source_pane.content is Empty) ||
    model.source_pane.saving {
    return (@rabbita.none, model)
  }
  source_pane_action(
    dispatch,
    RequestSource(previous.selected_path),
    sync_workspace_editor_context(model),
  )
}
