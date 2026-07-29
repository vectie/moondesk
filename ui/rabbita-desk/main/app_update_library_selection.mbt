///|
fn update_library_selection(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    PickLibraryFolder =>
      (
        pick_library_folder_cmd(dispatch),
        { ..model, host_status: "Choose a MoonBook library folder" },
      )
    LibraryFolderPicked(Ok(path)) =>
      if path == "" {
        (@rabbita.none, { ..model, host_status: "Library selection cancelled" })
      } else {
        (
          select_library_cmd(dispatch, path),
          { ..model, host_status: "Checking selected library" },
        )
      }
    LibraryFolderPicked(Err(error)) =>
      (@rabbita.none, { ..model, host_status: error })
    SelectedLibrary(Ok(metadata)) => {
      let (_, with_metadata) = update_workspace_results(
        dispatch,
        LoadedWorkspaceMetadata(Ok(metadata)),
        model,
      )
      (
        @rabbita.batch([
          fetch_pack_apps_cmd(dispatch),
          fetch_workspaces_cmd(dispatch),
          fetch_book_base_types_cmd(dispatch),
          fetch_book_patterns_cmd(dispatch),
          fetch_moonclaw_daemon_cmd(dispatch),
          fetch_moonflow_capability_cmd(dispatch),
          fetch_moonflow_runs_cmd(dispatch),
        ]),
        {
          ..with_metadata,
          loading: true,
          host_status: "MoonBook library ready",
          workspace_catalog_state: Some(Loading),
          workspace_catalog_error: "",
          workspaces: [],
          selected_workspace_id: "",
          current_directory: "",
          desk_location_input: "",
          desk_back_stack: [],
          desk_forward_stack: [],
          entries: [],
          desk_selected_paths: [],
          selected_path: "",
          primary_preview_path: "",
          preview: None,
          preview_state: Some(FirstUseEmpty),
          preview_error: "",
          preview_request_workspace_id: "",
          preview_request_path: "",
          preview_status: "",
          desk_trash_entries: [],
          runs: [],
          moonflow_runs: [],
          moonflow_runs_state: Some(FirstUseEmpty),
          moonflow_runs_error: None,
          moonflow_ingest_preparing: false,
          requests: [],
          requests_state: Some(FirstUseEmpty),
          requests_error: "",
          runs_state: Some(FirstUseEmpty),
          runs_error: "",
          review_items: [],
          review_state: Some(FirstUseEmpty),
          publish_state: Some(FirstUseEmpty),
          publish_error: "",
          pages_search: with_metadata.pages_search.clear_hits(),
        },
      )
    }
    SelectedLibrary(Err(error)) =>
      (@rabbita.none, { ..model, host_status: error })
    _ => (@rabbita.none, model)
  }
}
