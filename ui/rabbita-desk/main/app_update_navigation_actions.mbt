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
      let prompt = if mode == MoonCode &&
        model.mooncode_prompt.trim().to_owned() == "" {
        "Help me improve \{workspace_name(model)} by adding or changing executable code for the selected MoonBook."
      } else {
        model.mooncode_prompt
      }
      (
        sync_activity_cmd(activity),
        {
          ..model,
          workspace_mode: mode,
          activity,
          command_open: false,
          mooncode_prompt: prompt,
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
    SelectDrawerTab(tab) => (@rabbita.none, { ..model, drawer_tab: tab })
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
          match selected_mooncode_session(model) {
            Some(session) =>
              fetch_mooncode_preflight_matrix_cmd(dispatch, session.id, path)
            None => @rabbita.none
          },
        ]),
        {
          ..model,
          current_directory: path,
          selected_path: path,
          primary_preview_path: remember_primary_preview_path(model, path),
          preview: None,
          preview_status: "loading directory",
          mooncode_preflight_status: if model.selected_mooncode_session_id == "" {
            model.mooncode_preflight_status
          } else {
            "loading preflight gates"
          },
        },
      )
    OpenQuickPath(path) =>
      (
        @rabbita.batch([
          fetch_preview_cmd(dispatch, model.selected_workspace_id, path),
          fetch_review_diff_cmd(dispatch, model.selected_workspace_id, path),
          match selected_mooncode_session(model) {
            Some(session) =>
              fetch_mooncode_preflight_matrix_cmd(dispatch, session.id, path)
            None => @rabbita.none
          },
        ]),
        {
          ..model,
          selected_path: path,
          primary_preview_path: remember_primary_preview_path(model, path),
          preview: None,
          preview_status: "loading preview",
          mooncode_preflight_status: if model.selected_mooncode_session_id == "" {
            model.mooncode_preflight_status
          } else {
            "loading preflight gates"
          },
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
            fetch_review_diff_cmd(dispatch, workspace_id, path),
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
      fetch_review_diff_cmd(dispatch, model.selected_workspace_id, path),
    ])
  } else {
    @rabbita.batch([
      fetch_preview_cmd(dispatch, model.selected_workspace_id, path),
      fetch_review_diff_cmd(dispatch, model.selected_workspace_id, path),
    ])
  }
  let cmd = match selected_mooncode_session(model) {
    Some(session) =>
      @rabbita.batch([
        base_cmd,
        fetch_mooncode_preflight_matrix_cmd(dispatch, session.id, path),
      ])
    None => base_cmd
  }
  (
    cmd,
    {
      ..model,
      selected_path: path,
      primary_preview_path: remember_primary_preview_path(model, path),
      current_directory: if is_directory { path } else { model.current_directory },
      preview: None,
      preview_status: "loading preview",
      mooncode_preflight_status: if model.selected_mooncode_session_id == "" {
        model.mooncode_preflight_status
      } else {
        "loading preflight gates"
      },
      editing_inbox_path: if is_inbox_path(path) {
        path
      } else {
        model.editing_inbox_path
      },
    },
  )
}
