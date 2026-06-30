///|
fn update_workspace_results(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    LoadedWorkspaces(Ok(workspaces)) => {
      let selected_workspace_id = if has_workspace(
          workspaces,
          model.selected_workspace_id,
        ) {
        model.selected_workspace_id
      } else {
        first_workspace_id(workspaces)
      }
      let selected_path = if model.workspace_mode == Desk {
        ""
      } else if model.selected_path == "" {
        "wiki/index.md"
      } else {
        model.selected_path
      }
      (
        reload_workspace_cmds(dispatch, selected_workspace_id, selected_path),
        {
          ..model,
          loading: false,
          host_status: "local host ready",
          workspaces,
          selected_workspace_id,
          selected_path,
          preview_status: "loading preview",
        },
      )
    }
    LoadedWorkspaces(Err(error)) =>
      (
        @rabbita.none,
        { ..model, loading: false, host_status: error, preview_status: error },
      )
    LoadedEntries(Ok(entries)) =>
      (@rabbita.none, { ..model, entries, host_status: "workspace indexed" })
    LoadedEntries(Err(error)) =>
      (@rabbita.none, { ..model, host_status: error })
    LoadedPreview(Ok(preview)) =>
      (
        @rabbita.none,
        {
          ..model,
          preview: Some(preview),
          preview_status: "preview ready",
          recent_paths: remember_path(model.recent_paths, model.selected_path),
          inbox_content: if model.editing_inbox_path == model.selected_path &&
            is_textual_renderer(preview.renderer) {
            preview.body
          } else {
            model.inbox_content
          },
        },
      )
    LoadedPreview(Err(error)) =>
      (@rabbita.none, { ..model, preview: None, preview_status: error })
    LoadedRuns(Ok(runs)) => (@rabbita.none, { ..model, runs, })
    LoadedRuns(Err(error)) => (@rabbita.none, { ..model, host_status: error })
    LoadedSavedViews(Ok(saved_views)) =>
      (@rabbita.none, { ..model, saved_views, })
    LoadedSavedViews(Err(error)) =>
      (@rabbita.none, { ..model, host_status: error })
    LoadedSearch(Ok(search_hits)) =>
      (
        @rabbita.none,
        {
          ..model,
          search_hits,
          search_status: "\{search_hits.length()} results",
        },
      )
    LoadedSearch(Err(error)) =>
      (@rabbita.none, { ..model, search_status: error })
    SavedView(Ok(view)) =>
      (
        fetch_saved_views_cmd(dispatch),
        { ..model, host_status: "saved view \{view.title}" },
      )
    SavedView(Err(error)) => (@rabbita.none, { ..model, host_status: error })
    SavedMarkdownEdit(Ok(result)) =>
      (
        @rabbita.batch([
          fetch_preview_cmd(dispatch, result.workspace_id, result.path),
          fetch_entries_cmd(dispatch, result.workspace_id, parent_path(result.path)),
        ]),
        {
          ..model,
          selected_workspace_id: result.workspace_id,
          selected_path: result.path,
          current_directory: parent_path(result.path),
          markdown_editor_path: "",
          markdown_editor_content: "",
          markdown_editor_status: "saved \{result.path}",
          preview: None,
          preview_status: "loading saved markdown",
        },
      )
    SavedMarkdownEdit(Err(error)) =>
      (
        @rabbita.none,
        { ..model, markdown_editor_status: error, preview_status: error },
      )
    _ => (@rabbita.none, model)
  }
}
