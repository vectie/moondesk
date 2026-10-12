///| Apply the source-pane reducer before deriving the command identity. Only a

///|
/// valid RequestSource starts I/O; all other messages are reducer-only.
fn source_pane_action(
  dispatch : Dispatch[Msg],
  msg : SourcePaneMsg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  let resolved_msg = if msg is OpenPathInput {
    RequestSource(model.source_pane.path_input)
  } else {
    msg
  }
  let previous = match resolved_msg {
    FindNext
    | FindPrevious
    | ReplaceNext
    | ReplaceAll
    | SetLineIndent(_)
    | IndentLines(_)
    | DuplicateLines
    | EditChecklist(_)
    | WrapMarkdown(_)
    | CleanupLines(_)
    | LayoutJson(_)
    | ConvertDelimitedTable(_)
    | MoveMarkdownSection(_, _) =>
      source_literal_capture_selection(model.source_pane)
    _ => model.source_pane
  }
  let source_pane = update_source_pane(previous, resolved_msg)
  let next = { ..model, source_pane, }
  match resolved_msg {
    FindNext
    | FindPrevious
    | ReplaceNext
    | ReplaceAll
    | UndoEdit
    | RedoEdit
    | SetLineIndent(_)
    | IndentLines(_)
    | DuplicateLines
    | EditChecklist(_)
    | WrapMarkdown(_)
    | CleanupLines(_)
    | LayoutJson(_)
    | ConvertDelimitedTable(_)
    | SelectMarkdownSection(_)
    | MoveMarkdownSection(_, _) =>
      (source_literal_selection_cmd(source_pane), next)
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
    Save | ReplaceServer =>
      if source_pane.saving &&
        source_pane.pending_save != model.source_pane.pending_save {
        (save_source_pane_cmd(dispatch, source_pane), next)
      } else {
        (@rabbita.none, next)
      }
    SaveResult(_, _) => (@rabbita.none, next)
    _ => (@rabbita.none, next)
  }
}
