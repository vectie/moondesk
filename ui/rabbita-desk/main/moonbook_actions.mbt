///|
fn open_moonbook_action(
  dispatch : Dispatch[Msg],
  workspace_id : String,
  action : MoonBookAction,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  let (select_cmd, selected) = if workspace_id == model.selected_workspace_id {
    (@rabbita.none, model)
  } else {
    select_workspace_action(dispatch, workspace_id, model)
  }
  // A deferred workspace change must not open an action in the previous book.
  guard selected.selected_workspace_id == workspace_id else {
    return (select_cmd, selected)
  }
  match action {
    Chat => {
      let (chat_cmd, in_chat) = select_workspace_mode_action(
        dispatch,
        MoonWiki,
        selected,
      )
      (@rabbita.batch([select_cmd, chat_cmd]), in_chat)
    }
    StartTask =>
      (
        @rabbita.batch([
          select_cmd,
          workspace_feature_signal_cmd("open-recipe", ""),
        ]),
        { ..selected, command_open: false, },
      )
  }
}

///|
fn matching_moonbooks(model : Model) -> Array[@desk.DeskWorkspace] {
  let query = model.moonbook_query.trim().to_owned().to_lower()
  model.workspaces.filter(workspace => {
    query == "" ||
    (workspace.name +
    " " +
    workspace.id +
    " " +
    workspace_display_book_location(model, workspace))
    .to_lower()
    .contains(query)
  })
}
