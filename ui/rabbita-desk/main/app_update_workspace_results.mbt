///|
fn moonflow_import_status(result : MoonFlowImportResult) -> String {
  let detail = if result.run_id != "" {
    " · run " + result.run_id
  } else if result.next_action != "" {
    " · next: " + result.next_action.replace_all(old="_", new=" ")
  } else {
    " · " + result.status
  }
  result.message + detail
}

///|
fn upsert_moonflow_operator_actions(
  existing : Array[MoonFlowOperatorActions],
  next : MoonFlowOperatorActions,
) -> Array[MoonFlowOperatorActions] {
  let values = existing.filter(value => value.run_id != next.run_id)
  values.push(next)
  values
}

///|
fn update_workspace_results(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    LoadedPackApps(Ok(catalog)) =>
      (
        @rabbita.none,
        {
          ..model,
          pack_apps: catalog.apps,
          pack_apps_status: if catalog.apps.is_empty() {
            "No domain packs installed"
          } else {
            "\{catalog.configured_count} ready · \{catalog.app_count} installed"
          },
        },
      )
    LoadedPackApps(Err(error)) =>
      (@rabbita.none, { ..model, pack_apps_status: error })
    LoadedWorkspaceMetadata(Ok(metadata)) =>
      (
        @rabbita.none,
        {
          ..model,
          workspace_root_path: metadata.root_path,
          workspace_suite_root_path: if metadata.active_suite_root != "" {
            metadata.active_suite_root
          } else if metadata.suite_root != "" {
            metadata.suite_root
          } else {
            metadata.root_path
          },
          workspace_library_path: metadata.library_path,
          workspace_books_root_path: if metadata.books_root != "" {
            metadata.books_root
          } else {
            metadata.library_path
          },
          moonsuite_products: metadata.products,
        },
      )
    LoadedWorkspaceMetadata(Err(error)) =>
      (@rabbita.none, { ..model, host_status: error })
    LoadedWorkspaces(Ok(workspaces)) => {
      let selected_known = has_workspace(
        workspaces,
        model.selected_workspace_id,
      )
      let selected_workspace_id = if selected_known {
        model.selected_workspace_id
      } else {
        first_workspace_id(workspaces)
      }
      let selected_path = if model.workspace_mode == Desk {
        if selected_known {
          model.selected_path
        } else {
          ""
        }
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
      (
        @rabbita.none,
        {
          ..model,
          entries,
          host_status: "workspace indexed",
          desk_new_item_status: if model.desk_new_item_status ==
            "Refreshing folder..." ||
            model.desk_new_item_status ==
            "Couldn't refresh this folder. Check the connection and try Refresh again." {
            ""
          } else {
            model.desk_new_item_status
          },
        },
      )
    LoadedEntries(Err(error)) =>
      (
        @rabbita.none,
        {
          ..model,
          host_status: error,
          desk_new_item_status: "Couldn't refresh this folder. Check the connection and try Refresh again.",
        },
      )
    LoadedDeskTrash(Ok(entries)) =>
      (
        @rabbita.none,
        {
          ..model,
          desk_trash_entries: entries,
          desk_trash_status: if entries.length() == 0 {
            if model.desk_trash_status == "ready to trash selection" {
              "trash empty"
            } else {
              model.desk_trash_status
            }
          } else {
            "\{entries.length()} item(s) in trash"
          },
        },
      )
    LoadedDeskTrash(Err(error)) =>
      (@rabbita.none, { ..model, desk_trash_status: error, host_status: error })
    LoadedPreview(Ok(preview)) =>
      (
        @rabbita.none,
        {
          ..model,
          preview: Some(preview),
          preview_status: "preview ready",
          recent_paths: remember_path(model.recent_paths, model.selected_path),
          inbox_content: if should_load_preview_into_inbox(model, preview) {
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
    LoadedMoonFlowRuns(Ok(runs)) =>
      (
        @rabbita.batch([
          for run in runs =>
            fetch_moonflow_operator_actions_cmd(dispatch, run.run_id)
        ]),
        {
          ..model,
          moonflow_runs: runs,
          moonflow_operator_actions: model.moonflow_operator_actions.filter(
            actions => runs.any(run => run.run_id == actions.run_id),
          ),
          moonflow_status: if runs.is_empty() {
            "No MoonFlow runs yet"
          } else {
            "\{runs.length()} MoonFlow run(s)"
          },
        },
      )
    LoadedMoonFlowRuns(Err(error)) =>
      (@rabbita.none, { ..model, moonflow_status: error, host_status: error })
    LoadedMoonFlowComposition(Ok(composition)) =>
      (
        @rabbita.none,
        {
          ..model,
          moonflow_composition: Some(composition),
          moonflow_composition_status: "Composition loaded",
          moonflow_composition_saving: false,
        },
      )
    LoadedMoonFlowComposition(Err(error)) =>
      (
        @rabbita.none,
        {
          ..model,
          moonflow_composition: None,
          moonflow_composition_status: error,
          moonflow_composition_saving: false,
        },
      )
    SavedMoonFlowComposition(Ok(composition)) =>
      (
        @rabbita.none,
        {
          ..model,
          moonflow_composition: Some(composition),
          moonflow_composition_status: "Composition saved · next run uses this selection",
          moonflow_composition_saving: false,
        },
      )
    SavedMoonFlowComposition(Err(error)) =>
      (
        @rabbita.none,
        {
          ..model,
          moonflow_composition_status: error,
          moonflow_composition_saving: false,
        },
      )
    LoadedMoonFlowOperatorActions(_, Ok(actions)) =>
      (
        @rabbita.none,
        {
          ..model,
          moonflow_operator_actions: upsert_moonflow_operator_actions(
            model.moonflow_operator_actions,
            actions,
          ),
          moonflow_operator_action_status: if actions.status == "available" {
            "\{actions.actions.length()} operator action(s) available for \{actions.run_id}"
          } else {
            "Operator actions \{actions.status} for \{actions.run_id}"
          },
        },
      )
    LoadedMoonFlowOperatorActions(run_id, Err(error)) =>
      (
        @rabbita.none,
        {
          ..model,
          moonflow_operator_action_status: "\{run_id}: \{error}",
        },
      )
    ImportedMoonFlow(Ok(result)) =>
      (
        if result.ok {
          fetch_moonflow_runs_cmd(dispatch)
        } else {
          @rabbita.none
        },
        {
          ..model,
          moonflow_status: moonflow_import_status(result),
          selected_workspace_id: if result.book_id == "" {
            model.selected_workspace_id
          } else {
            result.book_id
          },
        },
      )
    ImportedMoonFlow(Err(error)) =>
      (@rabbita.none, { ..model, moonflow_status: error })
    ControlledMoonFlow(Ok(control)) =>
      (
        fetch_moonflow_runs_cmd(dispatch),
        {
          ..model,
          moonflow_status: "Run " + control.run_id + " is " + control.state,
        },
      )
    ControlledMoonFlow(Err(error)) =>
      (@rabbita.none, { ..model, moonflow_status: error, host_status: error })
    ExecutedMoonFlowOperatorAction(run_id, Ok(receipt)) =>
      (
        @rabbita.batch([
          fetch_moonflow_runs_cmd(dispatch),
          fetch_moonflow_operator_actions_cmd(dispatch, run_id),
        ]),
        {
          ..model,
          moonflow_operator_action_receipt: Some(receipt),
          moonflow_operator_action_status: "\{receipt.action_id}: \{receipt.status}",
          moonflow_operator_action_pending: "",
        },
      )
    ExecutedMoonFlowOperatorAction(run_id, Err(error)) =>
      (
        @rabbita.batch([
          fetch_moonflow_runs_cmd(dispatch),
          fetch_moonflow_operator_actions_cmd(dispatch, run_id),
        ]),
        {
          ..model,
          moonflow_operator_action_status: "\{run_id}: \{error}",
          moonflow_operator_action_pending: "",
        },
      )
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
    CreatedDeskEntry(Ok(result)) =>
      (
        @rabbita.batch([
          fetch_entries_cmd(dispatch, result.workspace_id, result.directory),
          fetch_preview_cmd(dispatch, result.workspace_id, result.path),
        ]),
        {
          ..model,
          selected_workspace_id: result.workspace_id,
          selected_path: result.path,
          desk_selected_paths: [result.path],
          desk_selection_anchor: result.path,
          desk_rename_editing_path: "",
          primary_preview_path: remember_primary_preview_path(
            model,
            result.path,
          ),
          current_directory: result.directory,
          desk_location_input: result.directory,
          preview: None,
          preview_status: "loading created item",
          desk_new_item_name: "Untitled",
          desk_new_item_status: "created \{result.path}",
          host_status: "created \{result.path}",
        },
      )
    CreatedDeskEntry(Err(error)) =>
      (
        @rabbita.none,
        { ..model, desk_new_item_status: error, host_status: error },
      )
    RenamedDeskEntry(Ok(result)) =>
      (
        @rabbita.batch([
          fetch_entries_cmd(dispatch, result.workspace_id, result.directory),
          fetch_preview_cmd(dispatch, result.workspace_id, result.path),
        ]),
        {
          ..model,
          selected_workspace_id: result.workspace_id,
          selected_path: result.path,
          desk_selected_paths: [result.path],
          desk_selection_anchor: result.path,
          desk_rename_editing_path: "",
          desk_rename_name: @desk.display_name(result.path),
          desk_rename_status: "renamed \{result.path}",
          primary_preview_path: remember_primary_preview_path(
            model,
            result.path,
          ),
          current_directory: result.directory,
          desk_location_input: result.directory,
          preview: None,
          preview_status: "loading renamed item",
          host_status: "renamed \{result.path}",
        },
      )
    RenamedDeskEntry(Err(error)) =>
      (
        @rabbita.none,
        { ..model, desk_rename_status: error, host_status: error },
      )
    MovedDeskEntry(Ok(result)) => {
      let is_cut_paste = model.desk_clipboard_status.has_prefix(
        "moving clipboard",
      )
      (
        @rabbita.batch([
          fetch_entries_cmd(dispatch, result.workspace_id, result.directory),
          fetch_preview_cmd(dispatch, result.workspace_id, result.path),
        ]),
        {
          ..model,
          selected_workspace_id: result.workspace_id,
          selected_path: result.path,
          desk_selected_paths: [result.path],
          desk_selection_anchor: result.path,
          desk_rename_editing_path: "",
          desk_rename_name: @desk.display_name(result.path),
          desk_move_target_directory: result.directory,
          desk_move_status: if result.moved_count > 1 {
            "moved \{result.moved_count} items"
          } else {
            "moved \{result.path}"
          },
          desk_clipboard_paths: if is_cut_paste {
            []
          } else {
            model.desk_clipboard_paths
          },
          desk_clipboard_workspace_id: if is_cut_paste {
            ""
          } else {
            model.desk_clipboard_workspace_id
          },
          desk_clipboard_operation: if is_cut_paste {
            ""
          } else {
            model.desk_clipboard_operation
          },
          desk_clipboard_status: if is_cut_paste {
            if result.moved_count > 1 {
              "moved clipboard \{result.moved_count} items"
            } else {
              "moved clipboard \{result.path}"
            }
          } else {
            model.desk_clipboard_status
          },
          primary_preview_path: remember_primary_preview_path(
            model,
            result.path,
          ),
          current_directory: result.directory,
          desk_location_input: result.directory,
          preview: None,
          preview_status: if is_cut_paste {
            "loading moved clipboard item"
          } else {
            "loading moved item"
          },
          host_status: if is_cut_paste {
            "moved clipboard \{result.path}"
          } else {
            "moved \{result.path}"
          },
        },
      )
    }
    MovedDeskEntry(Err(error)) =>
      (
        @rabbita.none,
        {
          ..model,
          desk_move_status: error,
          desk_clipboard_status: if model.desk_clipboard_status.has_prefix(
              "moving clipboard",
            ) {
            error
          } else {
            model.desk_clipboard_status
          },
          host_status: error,
        },
      )
    CopiedDeskEntry(Ok(result)) => {
      let is_paste = model.desk_clipboard_status.has_prefix("pasting")
      (
        @rabbita.batch([
          fetch_entries_cmd(dispatch, result.workspace_id, result.directory),
          fetch_preview_cmd(dispatch, result.workspace_id, result.path),
        ]),
        {
          ..model,
          selected_workspace_id: result.workspace_id,
          selected_path: result.path,
          desk_selected_paths: [result.path],
          desk_selection_anchor: result.path,
          desk_rename_name: @desk.display_name(result.path),
          desk_copy_status: if result.copied_count > 1 {
            "duplicated \{result.copied_count} items"
          } else {
            "duplicated \{result.path}"
          },
          desk_clipboard_status: if is_paste {
            if result.copied_count > 1 {
              "pasted \{result.copied_count} items"
            } else {
              "pasted \{result.path}"
            }
          } else {
            model.desk_clipboard_status
          },
          primary_preview_path: remember_primary_preview_path(
            model,
            result.path,
          ),
          current_directory: result.directory,
          desk_location_input: result.directory,
          preview: None,
          preview_status: if is_paste {
            "loading pasted item"
          } else {
            "loading duplicated item"
          },
          host_status: if is_paste {
            "pasted \{result.path}"
          } else {
            "duplicated \{result.path}"
          },
        },
      )
    }
    CopiedDeskEntry(Err(error)) =>
      (
        @rabbita.none,
        {
          ..model,
          desk_copy_status: error,
          desk_clipboard_status: if model.desk_clipboard_status.has_prefix(
              "pasting",
            ) {
            error
          } else {
            model.desk_clipboard_status
          },
          host_status: error,
        },
      )
    TrashedDeskEntry(Ok(result)) =>
      (
        @rabbita.batch([
          fetch_entries_cmd(dispatch, result.workspace_id, result.directory),
          fetch_desk_trash_cmd(dispatch, result.workspace_id),
        ]),
        {
          ..model,
          selected_workspace_id: result.workspace_id,
          selected_path: "",
          desk_selected_paths: [],
          desk_selection_anchor: "",
          desk_rename_name: "",
          desk_move_target_directory: "",
          desk_trash_status: if result.trashed_count > 1 {
            "moved \{result.trashed_count} items to trash"
          } else {
            "moved to trash \{result.path}"
          },
          desk_last_trash_path: result.trash_path,
          current_directory: result.directory,
          desk_location_input: result.directory,
          preview: None,
          preview_status: "selection moved to trash",
          host_status: "moved to trash \{result.path}",
        },
      )
    TrashedDeskEntry(Err(error)) =>
      (@rabbita.none, { ..model, desk_trash_status: error, host_status: error })
    RestoredDeskEntry(Ok(result)) =>
      (
        @rabbita.batch([
          fetch_entries_cmd(dispatch, result.workspace_id, result.directory),
          fetch_preview_cmd(dispatch, result.workspace_id, result.path),
          fetch_desk_trash_cmd(dispatch, result.workspace_id),
        ]),
        {
          ..model,
          selected_workspace_id: result.workspace_id,
          selected_path: result.path,
          desk_selected_paths: [result.path],
          desk_selection_anchor: result.path,
          desk_rename_name: @desk.display_name(result.path),
          desk_move_target_directory: result.directory,
          desk_trash_status: "restored \{result.path}",
          desk_last_trash_path: "",
          primary_preview_path: remember_primary_preview_path(
            model,
            result.path,
          ),
          current_directory: result.directory,
          desk_location_input: result.directory,
          preview: None,
          preview_status: "loading restored item",
          host_status: "restored \{result.path}",
        },
      )
    RestoredDeskEntry(Err(error)) =>
      (@rabbita.none, { ..model, desk_trash_status: error, host_status: error })
    ImportedDeskFiles(Ok(result)) =>
      (
        @rabbita.batch([
          fetch_entries_cmd(dispatch, result.workspace_id, result.directory),
          fetch_preview_cmd(dispatch, result.workspace_id, result.path),
        ]),
        {
          ..model,
          selected_workspace_id: result.workspace_id,
          selected_path: result.path,
          desk_selected_paths: if result.path == "" {
            []
          } else {
            [result.path]
          },
          desk_selection_anchor: result.path,
          desk_rename_name: if result.path == "" {
            ""
          } else {
            @desk.display_name(result.path)
          },
          primary_preview_path: remember_primary_preview_path(
            model,
            result.path,
          ),
          current_directory: result.directory,
          desk_location_input: result.directory,
          preview: None,
          preview_status: "loading imported file",
          desk_new_item_status: if result.imported_count > 1 {
            "imported \{result.imported_count} files"
          } else {
            "imported \{result.path}"
          },
          host_status: if result.imported_count > 1 {
            "imported \{result.imported_count} files"
          } else {
            "imported \{result.path}"
          },
        },
      )
    ImportedDeskFiles(Err(error)) =>
      (
        @rabbita.none,
        { ..model, desk_new_item_status: error, host_status: error },
      )
    LocalFilesPicked(Ok(files)) =>
      if files.length() == 0 {
        (@rabbita.none, model)
      } else if model.selected_workspace_id == "" {
        (
          @rabbita.none,
          { ..model, desk_new_item_status: "select a MoonBook first" },
        )
      } else {
        (
          import_desk_local_files_cmd(dispatch, model, files),
          {
            ..model,
            desk_new_item_status: "importing \{files.length()} local file(s)",
          },
        )
      }
    LocalFilesPicked(Err(error)) =>
      (
        @rabbita.none,
        { ..model, desk_new_item_status: "local import failed: \{error}" },
      )
    LocalMoonBookFolderPicked(Ok(files)) =>
      if files.length() == 0 {
        (
          @rabbita.none,
          { ..model, import_book_status: "no MoonBook folder selected" },
        )
      } else {
        (
          import_moonbook_folder_cmd(dispatch, files),
          {
            ..model,
            import_book_path: "",
            import_book_status: "importing MoonBook folder",
          },
        )
      }
    LocalMoonBookFolderPicked(Err(error)) =>
      (
        @rabbita.none,
        {
          ..model,
          import_book_status: "folder import failed: \{error}",
          host_status: "folder import failed: \{error}",
        },
      )
    LocalMoonBookArchivePicked(Ok(file)) =>
      (
        import_moonbook_archive_cmd(dispatch, file),
        {
          ..model,
          import_book_path: "",
          import_book_status: "importing MoonBook archive \{file.name}",
        },
      )
    LocalMoonBookArchivePicked(Err(error)) =>
      (
        @rabbita.none,
        {
          ..model,
          import_book_status: "archive import failed: \{error}",
          host_status: "archive import failed: \{error}",
        },
      )
    CreatedBlankMoonBook(Ok(result)) =>
      open_created_or_imported_workspace(
        dispatch,
        model,
        result,
        status="loading created MoonBook",
        new_book_name="",
        new_book_id="",
        new_book_status="created \{result.book_id}",
        import_book_status=model.import_book_status,
        host_status="created MoonBook \{result.name}",
      )
    CreatedBlankMoonBook(Err(error)) =>
      (@rabbita.none, { ..model, new_book_status: error, host_status: error })
    ImportedMoonBook(Ok(result)) =>
      open_created_or_imported_workspace(
        dispatch,
        model,
        result,
        status="loading imported MoonBook",
        new_book_name=model.new_book_name,
        new_book_id=model.new_book_id,
        new_book_status=model.new_book_status,
        import_book_status="imported \{result.book_id}",
        host_status="imported MoonBook \{result.name}",
      )
    ImportedMoonBook(Err(error)) =>
      (
        @rabbita.none,
        { ..model, import_book_status: error, host_status: error },
      )
    SavedMarkdownEdit(Ok(result)) =>
      (
        @rabbita.batch([
          fetch_preview_cmd(dispatch, result.workspace_id, result.path),
          fetch_entries_cmd(
            dispatch,
            result.workspace_id,
            parent_path(result.path),
          ),
        ]),
        {
          ..model,
          selected_workspace_id: result.workspace_id,
          selected_path: result.path,
          desk_selected_paths: if result.path == "" {
            []
          } else {
            [result.path]
          },
          desk_selection_anchor: result.path,
          current_directory: parent_path(result.path),
          desk_location_input: parent_path(result.path),
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

///|
fn should_load_preview_into_inbox(
  model : Model,
  preview : @desk.DeskPreview,
) -> Bool {
  model.editing_inbox_path != "" &&
  model.editing_inbox_path == model.selected_path &&
  is_textual_renderer(preview.renderer)
}

///|
fn open_created_or_imported_workspace(
  dispatch : Dispatch[Msg],
  model : Model,
  result : CreatedWorkspace,
  status~ : String,
  new_book_name~ : String,
  new_book_id~ : String,
  new_book_status~ : String,
  import_book_status~ : String,
  host_status~ : String,
) -> (@rabbita.Cmd, Model) {
  let selected_path = result.path
  (
    @rabbita.batch([
      fetch_workspaces_cmd(dispatch),
      fetch_entries_cmd(
        dispatch,
        result.workspace_id,
        parent_path(selected_path),
      ),
      if selected_path == "" {
        @rabbita.none
      } else {
        fetch_preview_cmd(dispatch, result.workspace_id, selected_path)
      },
      fetch_runs_cmd(dispatch, result.workspace_id),
    ]),
    {
      ..model,
      workspace_mode: Desk,
      selected_workspace_id: result.workspace_id,
      selected_path,
      desk_selected_paths: if selected_path == "" {
        []
      } else {
        [selected_path]
      },
      desk_selection_anchor: selected_path,
      primary_preview_path: if selected_path == "" {
        model.primary_preview_path
      } else {
        selected_path
      },
      current_directory: parent_path(selected_path),
      desk_location_input: parent_path(selected_path),
      preview: None,
      preview_status: status,
      new_book_name,
      new_book_id,
      new_book_status,
      import_book_path: "",
      import_book_status,
      host_status,
    },
  )
}
