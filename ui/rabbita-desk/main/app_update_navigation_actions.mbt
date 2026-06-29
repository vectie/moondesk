///|
fn update_navigation_actions(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    SelectWorkspaceMode(mode) => {
      let activity = if mode == MoonCode {
        Activity::MoonCode
      } else if model.activity == MoonCode {
        Explorer
      } else {
        model.activity
      }
      (
        sync_activity_cmd(activity),
        {
          ..model,
          workspace_mode: mode,
          activity,
          command_open: false,
          mooncode_prompt: if mode == MoonCode {
            ""
          } else {
            model.mooncode_prompt
          },
          mooncode_composer_status: if mode == MoonCode {
            "MoonCode workspace ready"
          } else {
            model.mooncode_composer_status
          },
        },
      )
    }
    SelectActivity(activity) =>
      (
        sync_activity_cmd(activity),
        {
          ..model,
          workspace_mode: workspace_mode_for_activity(activity),
          activity,
          command_open: false,
        },
      )
    SelectWorkspace(workspace_id) =>
      (
        @rabbita.batch([
          reload_workspace_cmds(dispatch, workspace_id, "wiki/index.md"),
          fetch_mooncode_sessions_cmd(dispatch, workspace_id),
        ]),
        {
          ..model,
          selected_workspace_id: workspace_id,
          selected_mooncode_session_id: "",
          selected_path: "wiki/index.md",
          primary_preview_path: "wiki/index.md",
          current_directory: "",
          preview: None,
          preview_status: "loading preview",
          entries: [],
        },
      )
    SelectPath(path) => select_path_action(dispatch, model, path)
    OpenDirectory(path) =>
      (
        @rabbita.batch([
          fetch_entries_cmd(dispatch, model.selected_workspace_id, path),
          fetch_preview_cmd(dispatch, model.selected_workspace_id, path),
        ]),
        {
          ..model,
          current_directory: path,
          selected_path: path,
          primary_preview_path: remember_primary_preview_path(model, path),
          preview: None,
          preview_status: "loading directory",
        },
      )
    OpenQuickPath(path) =>
      (
        fetch_preview_cmd(dispatch, model.selected_workspace_id, path),
        {
          ..model,
          selected_path: path,
          primary_preview_path: remember_primary_preview_path(model, path),
          preview: None,
          preview_status: "loading preview",
        },
      )
    SelectSearchHit(workspace_id, path) =>
      (
        sync_activity_batch(
          Explorer,
          @rabbita.batch([
            fetch_entries_cmd(dispatch, workspace_id, ""),
            fetch_preview_cmd(dispatch, workspace_id, path),
            fetch_runs_cmd(dispatch, workspace_id),
          ]),
        ),
        {
          ..model,
          activity: Explorer,
          command_open: false,
          selected_workspace_id: workspace_id,
          selected_path: path,
          primary_preview_path: if is_generated_site_path(path) {
            "wiki/index.md"
          } else {
            path
          },
          current_directory: "",
          preview: None,
          preview_status: "loading search result",
        },
      )
    ToggleCommand =>
      (@rabbita.none, { ..model, command_open: !model.command_open })
    _ => (@rabbita.none, model)
  }
}

///|
fn select_path_action(
  dispatch : Dispatch[Msg],
  model : Model,
  path : String,
) -> (@rabbita.Cmd, Model) {
  let is_directory = match find_entry(model, path) {
    Some(entry) => entry.kind is Directory
    None => false
  }
  let base_cmd = if is_directory {
    @rabbita.batch([
      fetch_entries_cmd(dispatch, model.selected_workspace_id, path),
      fetch_preview_cmd(dispatch, model.selected_workspace_id, path),
    ])
  } else {
    fetch_preview_cmd(dispatch, model.selected_workspace_id, path)
  }
  (
    base_cmd,
    {
      ..model,
      selected_path: path,
      primary_preview_path: remember_primary_preview_path(model, path),
      current_directory: if is_directory {
        path
      } else {
        model.current_directory
      },
      preview: None,
      preview_status: "loading preview",
      editing_inbox_path: if is_inbox_path(path) {
        path
      } else {
        model.editing_inbox_path
      },
    },
  )
}
