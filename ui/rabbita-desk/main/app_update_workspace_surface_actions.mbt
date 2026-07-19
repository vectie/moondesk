///|
fn update_workspace_surface_actions(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    ReloadBrowserPreview => (reload_browser_preview_cmd(), model)
    SetBrowserPreviewViewport(viewport) =>
      (set_browser_preview_viewport_cmd(viewport), model)
    CaptureBrowserPreviewEvidence =>
      (capture_browser_preview_evidence_cmd(), model)
    RequestBrowserHostControl(control) =>
      (request_browser_host_control_cmd(control), model)
    FixBrowserPreviewInMoonCode => {
      let (cmd, next) = select_workspace_mode_action(dispatch, MoonCode, model)
      (
        cmd,
        {
          ..next,
          mooncode_new_chat_active: true,
          mooncode_prompt: "Fix the executable preview for " +
          model.selected_path +
          ". Use the attached browser diagnostics and preserve its current behavior unless the evidence shows a defect.",
          mooncode_composer_status: "Preview diagnostics attached",
        },
      )
    }
    SetNewBookName(name) =>
      (
        @rabbita.none,
        {
          ..model,
          new_book_name: name,
          new_book_id: suggested_new_book_id(name, model.new_book_id),
          new_book_status: "draft",
        },
      )
    SetNewBookId(book_id) =>
      (
        @rabbita.none,
        { ..model, new_book_id: book_id, new_book_status: "draft" },
      )
    CreateBlankMoonBook => create_blank_moonbook_action(dispatch, model)
    SetImportBookPath(path) =>
      (
        @rabbita.none,
        {
          ..model,
          import_book_path: path,
          import_book_status: "draft import path",
        },
      )
    ImportMoonBook => import_moonbook_action(dispatch, model)
    PickImportMoonBookFolder =>
      (
        pick_moonbook_folder_cmd(dispatch),
        { ..model, import_book_status: "choose a MoonBook folder" },
      )
    PickImportMoonBookArchive =>
      (
        pick_moonbook_archive_cmd(dispatch),
        { ..model, import_book_status: "choose a MoonBook .zip archive" },
      )
    SetSearchQuery(query) =>
      (@rabbita.none, { ..model, search_query: query, search_status: "draft" })
    SearchNow => search_now_action(dispatch, model)
    SetDeskSort(key) =>
      (
        @rabbita.none,
        {
          ..model,
          desk_sort_key: key,
          desk_sort_desc: if model.desk_sort_key == key {
            !model.desk_sort_desc
          } else {
            false
          },
        },
      )
    SetDeskFilterQuery(query) =>
      desk_filter_query_action(dispatch, model, query)
    SetDeskDensity(density) =>
      (@rabbita.none, { ..model, desk_density: density })
    DeskKeyDown(key, shift, accel) =>
      desk_keydown_action(dispatch, key, shift, accel, model)
    DeskMouseDown(path, shift, accel) =>
      desk_mouse_action(dispatch, path, shift, accel, model)
    ClearDeskSelection => clear_desk_selection_action(model)
    SetDeskNewItemName(name) =>
      (
        @rabbita.none,
        {
          ..model,
          desk_new_item_name: name,
          desk_new_item_status: "draft item name",
        },
      )
    CreateDeskFolder => create_desk_entry_action(dispatch, model, "folder")
    CreateDeskMarkdown => create_desk_entry_action(dispatch, model, "markdown")
    ImportLocalFilesToDesk => import_local_files_to_desk_action(dispatch, model)
    ImportLocalFolderToDesk =>
      import_local_folder_to_desk_action(dispatch, model)
    StartDeskRename => start_desk_rename_action(model)
    CancelDeskRename =>
      (
        @rabbita.none,
        {
          ..model,
          desk_rename_editing_path: "",
          desk_rename_status: "rename canceled",
        },
      )
    SetDeskRenameName(name) =>
      (
        @rabbita.none,
        { ..model, desk_rename_name: name, desk_rename_status: "draft rename" },
      )
    RenameDeskSelection => rename_desk_entry_action(dispatch, model)
    SetDeskMoveTargetDirectory(directory) =>
      (
        @rabbita.none,
        {
          ..model,
          desk_move_target_directory: directory,
          desk_move_status: "draft move target",
        },
      )
    MoveDeskSelection => move_desk_entry_action(dispatch, model)
    CopyDeskSelection => copy_desk_selection_action(model)
    CutDeskSelection => cut_desk_selection_action(model)
    PasteDeskClipboard => paste_desk_clipboard_action(dispatch, model)
    CopyDeskPath => copy_desk_path_action(model)
    DuplicateDeskSelection => duplicate_desk_entry_action(dispatch, model)
    TrashDeskSelection => trash_desk_entry_action(dispatch, model)
    RestoreLastTrashedDeskEntry => restore_desk_entry_action(dispatch, model)
    RestoreDeskTrashEntry(trash_path) =>
      restore_desk_trash_entry_action(dispatch, model, trash_path)
    ToggleFavorite(path) =>
      (
        @rabbita.none,
        { ..model, favorites: toggle_string(model.favorites, path) },
      )
    SetViewTitle(title) => (@rabbita.none, { ..model, view_title: title })
    SaveCurrentView =>
      (save_view_cmd(dispatch, model), { ..model, host_status: "saving view" })
    ControlMoonFlow(run_id, action, detail) =>
      (
        control_moonflow_cmd(dispatch, run_id, action, detail),
        { ..model, moonflow_status: "Applying " + action + "…" },
      )
    ExecuteMoonFlowOperatorAction(run_id, action_id) =>
      (
        execute_moonflow_operator_action_cmd(dispatch, run_id, action_id),
        {
          ..model,
          moonflow_operator_action_receipt: None,
          moonflow_operator_action_status: "Applying \{action_id}…",
          moonflow_operator_action_pending: action_id,
        },
      )
    PrepareMoonFlow =>
      if model.selected_workspace_id == "" {
        (@rabbita.none, { ..model, moonflow_status: "Select a MoonBook first" })
      } else {
        (
          import_selected_moonflow_cmd(dispatch, model.selected_workspace_id),
          {
            ..model,
            moonflow_status: "Preparing executable work… this may take up to 30 seconds",
          },
        )
      }
    SetReviewDecisionNote(note) =>
      (@rabbita.none, { ..model, review_decision_note: note })
    DecideReviewItem(item, decision) =>
      decide_review_item_action(dispatch, model, item, decision)
    StartMarkdownEdit => start_markdown_edit_action(model)
    SetMarkdownEditorContent(content) =>
      (
        @rabbita.none,
        {
          ..model,
          markdown_editor_content: content,
          markdown_editor_status: "editing \{model.markdown_editor_path}",
        },
      )
    CancelMarkdownEdit =>
      (
        @rabbita.none,
        {
          ..model,
          markdown_editor_path: "",
          markdown_editor_content: "",
          markdown_editor_status: "editor idle",
        },
      )
    SaveMarkdownEdit =>
      if model.markdown_editor_path == "" {
        (
          @rabbita.none,
          { ..model, markdown_editor_status: "no markdown document selected" },
        )
      } else {
        (
          save_markdown_cmd(dispatch, model),
          { ..model, markdown_editor_status: "saving markdown" },
        )
      }
    NotifyDaily =>
      (
        notify_cmd(
          "MoonDesk daily surface",
          "\{model.requests.length()} requests, \{model.runs.length()} runs, \{model.standing_goals.length()} standing goals",
        ),
        { ..model, notification_status: "notification requested" },
      )
    RefreshAll =>
      (
        refresh_all_cmd(dispatch, model),
        {
          ..model,
          host_status: "refreshing",
          desk_new_item_status: "Refreshing folder...",
        },
      )
    _ => (@rabbita.none, model)
  }
}

///|
fn start_desk_rename_action(model : Model) -> (@rabbita.Cmd, Model) {
  if model.selected_workspace_id == "" {
    (@rabbita.none, { ..model, desk_rename_status: "select a MoonBook first" })
  } else if model.selected_path == "" {
    (@rabbita.none, { ..model, desk_rename_status: "select an item to rename" })
  } else if model.desk_selected_paths.length() > 1 {
    (
      @rabbita.none,
      { ..model, desk_rename_status: "rename one item at a time" },
    )
  } else {
    (
      @rabbita.none,
      {
        ..model,
        desk_rename_editing_path: model.selected_path,
        desk_rename_name: @desk.display_name(model.selected_path),
        desk_rename_status: "editing rename",
      },
    )
  }
}

///|
fn desk_filter_query_action(
  dispatch : Dispatch[Msg],
  model : Model,
  query : String,
) -> (@rabbita.Cmd, Model) {
  let trimmed = query.trim().to_owned()
  let visible_paths = desk_visible_paths_for_filter(model.entries, trimmed)
  let selected_paths = desk_current_selection_paths(model)
  let retained_paths = desk_retain_visible_paths(selected_paths, visible_paths)
  let focus_path = desk_filter_focus_path(
    model.selected_path,
    retained_paths,
    visible_paths,
  )
  let focus_changed = focus_path != model.selected_path
  let next_model = {
    ..clear_if_path_leaves_markdown_editor(model, focus_path),
    desk_filter_query: query,
    selected_path: focus_path,
    desk_selected_paths: if trimmed == "" {
      model.desk_selected_paths
    } else {
      retained_paths
    },
    desk_selection_anchor: if trimmed == "" {
      model.desk_selection_anchor
    } else if focus_path == "" {
      ""
    } else {
      focus_path
    },
    desk_rename_editing_path: if focus_path == model.selected_path {
      model.desk_rename_editing_path
    } else {
      ""
    },
    desk_rename_name: if focus_path == "" {
      ""
    } else if focus_path == model.selected_path {
      model.desk_rename_name
    } else {
      @desk.display_name(focus_path)
    },
    desk_move_target_directory: if focus_path == "" {
      ""
    } else if focus_path == model.selected_path {
      model.desk_move_target_directory
    } else {
      parent_path(focus_path)
    },
    preview: if focus_changed {
      None
    } else {
      model.preview
    },
    preview_status: if focus_changed && focus_path == "" {
      "selection hidden by filter"
    } else if focus_changed {
      "loading filtered selection"
    } else {
      model.preview_status
    },
    desk_path_status: if focus_changed {
      "ready to copy path"
    } else {
      model.desk_path_status
    },
  }
  if focus_changed && focus_path != "" {
    (
      fetch_preview_cmd(dispatch, model.selected_workspace_id, focus_path),
      next_model,
    )
  } else {
    (@rabbita.none, next_model)
  }
}

///|
fn desk_visible_paths_for_filter(
  entries : Array[@desk.DeskFileEntry],
  query : String,
) -> Array[String] {
  let normalized = query.trim().to_owned().to_lower()
  let paths : Array[String] = []
  for entry in entries {
    if normalized == "" || desk_entry_matches_filter(entry, normalized) {
      paths.push(entry.path)
    }
  }
  paths
}

///|
fn desk_current_selection_paths(model : Model) -> Array[String] {
  if model.desk_selected_paths.length() == 0 {
    if model.selected_path == "" {
      []
    } else {
      [model.selected_path]
    }
  } else {
    model.desk_selected_paths
  }
}

///|
fn desk_retain_visible_paths(
  selected_paths : Array[String],
  visible_paths : Array[String],
) -> Array[String] {
  let retained : Array[String] = []
  for path in selected_paths {
    if visible_paths.contains(path) {
      retained.push(path)
    }
  }
  retained
}

///|
fn desk_filter_focus_path(
  current_focus : String,
  retained_paths : Array[String],
  visible_paths : Array[String],
) -> String {
  if current_focus != "" && visible_paths.contains(current_focus) {
    current_focus
  } else if retained_paths.length() > 0 {
    retained_paths[0]
  } else {
    ""
  }
}

///|
fn import_local_files_to_desk_action(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  if model.selected_workspace_id == "" {
    (
      @rabbita.none,
      { ..model, desk_new_item_status: "select a MoonBook first" },
    )
  } else {
    (
      pick_import_files_cmd(dispatch),
      {
        ..model,
        workspace_mode: Desk,
        activity: Files,
        command_open: false,
        desk_new_item_status: "opening file picker",
      },
    )
  }
}

///|
fn import_local_folder_to_desk_action(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  if model.selected_workspace_id == "" {
    (
      @rabbita.none,
      { ..model, desk_new_item_status: "select a MoonBook first" },
    )
  } else {
    (
      pick_import_folder_cmd(dispatch),
      {
        ..model,
        workspace_mode: Desk,
        activity: Files,
        command_open: false,
        desk_new_item_status: "opening folder picker",
      },
    )
  }
}

///|
fn copy_desk_selection_action(model : Model) -> (@rabbita.Cmd, Model) {
  let paths = if model.desk_selected_paths.length() == 0 {
    if model.selected_path == "" {
      []
    } else {
      [model.selected_path]
    }
  } else {
    model.desk_selected_paths
  }
  if model.selected_workspace_id == "" {
    (
      @rabbita.none,
      { ..model, desk_clipboard_status: "select a MoonBook first" },
    )
  } else if paths.length() == 0 {
    (@rabbita.none, { ..model, desk_clipboard_status: "select items to copy" })
  } else {
    (
      @rabbita.none,
      {
        ..model,
        desk_clipboard_paths: paths,
        desk_clipboard_workspace_id: model.selected_workspace_id,
        desk_clipboard_operation: "copy",
        desk_clipboard_status: if paths.length() > 1 {
          "copied \{paths.length()} items"
        } else {
          "copied \{paths[0]}"
        },
      },
    )
  }
}

///|
fn cut_desk_selection_action(model : Model) -> (@rabbita.Cmd, Model) {
  let paths = if model.desk_selected_paths.length() == 0 {
    if model.selected_path == "" {
      []
    } else {
      [model.selected_path]
    }
  } else {
    model.desk_selected_paths
  }
  if model.selected_workspace_id == "" {
    (
      @rabbita.none,
      { ..model, desk_clipboard_status: "select a MoonBook first" },
    )
  } else if paths.length() == 0 {
    (@rabbita.none, { ..model, desk_clipboard_status: "select items to cut" })
  } else {
    (
      @rabbita.none,
      {
        ..model,
        desk_clipboard_paths: paths,
        desk_clipboard_workspace_id: model.selected_workspace_id,
        desk_clipboard_operation: "cut",
        desk_clipboard_status: if paths.length() > 1 {
          "cut \{paths.length()} items"
        } else {
          "cut \{paths[0]}"
        },
      },
    )
  }
}

///|
fn copy_desk_path_action(model : Model) -> (@rabbita.Cmd, Model) {
  if model.selected_workspace_id == "" {
    (@rabbita.none, { ..model, desk_path_status: "select a MoonBook first" })
  } else {
    let text = desk_path_clipboard_text(model)
    if text == "" {
      (@rabbita.none, { ..model, desk_path_status: "nothing to copy" })
    } else {
      (
        copy_text_to_clipboard_cmd(text),
        { ..model, desk_path_status: desk_path_copied_status(model) },
      )
    }
  }
}

///|
fn desk_path_clipboard_text(model : Model) -> String {
  desk_path_clipboard_paths(model).join("\n")
}

///|
fn desk_path_clipboard_paths(model : Model) -> Array[String] {
  let paths = if model.desk_selected_paths.length() > 0 {
    model.desk_selected_paths
  } else if model.selected_path != "" {
    [model.selected_path]
  } else if model.current_directory != "" {
    [model.current_directory]
  } else {
    ["/"]
  }
  paths.map(path => if path == "" { "/" } else { path })
}

///|
fn desk_path_copied_status(model : Model) -> String {
  let paths = desk_path_clipboard_paths(model)
  if paths.length() > 1 {
    "copied \{paths.length()} paths"
  } else {
    "copied path \{paths[0]}"
  }
}

///|
fn paste_desk_clipboard_action(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  if model.selected_workspace_id == "" {
    (
      @rabbita.none,
      { ..model, desk_clipboard_status: "select a MoonBook first" },
    )
  } else if model.desk_clipboard_paths.length() == 0 {
    (@rabbita.none, { ..model, desk_clipboard_status: "clipboard empty" })
  } else if model.desk_clipboard_workspace_id != model.selected_workspace_id {
    (
      @rabbita.none,
      {
        ..model,
        desk_clipboard_status: "clipboard belongs to another MoonBook",
      },
    )
  } else {
    (
      if model.desk_clipboard_operation == "cut" {
        paste_desk_cut_cmd(dispatch, model)
      } else {
        paste_desk_clipboard_cmd(dispatch, model)
      },
      {
        ..model,
        desk_clipboard_status: if model.desk_clipboard_operation == "cut" {
          if model.desk_clipboard_paths.length() > 1 {
            "moving clipboard \{model.desk_clipboard_paths.length()} items"
          } else {
            "moving clipboard selection"
          }
        } else if model.desk_clipboard_paths.length() > 1 {
          "pasting \{model.desk_clipboard_paths.length()} items"
        } else {
          "pasting selection"
        },
      },
    )
  }
}

///|
fn duplicate_desk_entry_action(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  if model.selected_workspace_id == "" {
    (@rabbita.none, { ..model, desk_copy_status: "select a MoonBook first" })
  } else if model.selected_path == "" {
    (
      @rabbita.none,
      { ..model, desk_copy_status: "select an item to duplicate" },
    )
  } else {
    (
      copy_desk_entry_cmd(dispatch, model),
      {
        ..model,
        desk_copy_status: if model.desk_selected_paths.length() > 1 {
          "duplicating \{model.desk_selected_paths.length()} items"
        } else {
          "duplicating selection"
        },
      },
    )
  }
}

///|
fn restore_desk_entry_action(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  if model.selected_workspace_id == "" {
    (@rabbita.none, { ..model, desk_trash_status: "select a MoonBook first" })
  } else if model.desk_last_trash_path == "" {
    (@rabbita.none, { ..model, desk_trash_status: "nothing to restore" })
  } else {
    (
      restore_desk_entry_cmd(dispatch, model),
      { ..model, desk_trash_status: "restoring last trashed item" },
    )
  }
}

///|
fn restore_desk_trash_entry_action(
  dispatch : Dispatch[Msg],
  model : Model,
  trash_path : String,
) -> (@rabbita.Cmd, Model) {
  if model.selected_workspace_id == "" {
    (@rabbita.none, { ..model, desk_trash_status: "select a MoonBook first" })
  } else if trash_path == "" {
    (
      @rabbita.none,
      { ..model, desk_trash_status: "select a trash item to restore" },
    )
  } else {
    (
      restore_desk_trash_path_cmd(dispatch, model, trash_path),
      { ..model, desk_trash_status: "restoring trash item" },
    )
  }
}

///|
fn trash_desk_entry_action(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  if model.selected_workspace_id == "" {
    (@rabbita.none, { ..model, desk_trash_status: "select a MoonBook first" })
  } else if model.selected_path == "" {
    (@rabbita.none, { ..model, desk_trash_status: "select an item to trash" })
  } else {
    (
      trash_desk_entry_cmd(dispatch, model),
      {
        ..model,
        desk_trash_status: if model.desk_selected_paths.length() > 1 {
          "moving \{model.desk_selected_paths.length()} items to trash"
        } else {
          "moving selection to trash"
        },
      },
    )
  }
}

///|
fn move_desk_entry_action(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  if model.selected_workspace_id == "" {
    (@rabbita.none, { ..model, desk_move_status: "select a MoonBook first" })
  } else if model.selected_path == "" {
    (@rabbita.none, { ..model, desk_move_status: "select an item to move" })
  } else if model.desk_move_target_directory.trim().to_owned() == "" {
    (@rabbita.none, { ..model, desk_move_status: "enter a target directory" })
  } else {
    (
      move_desk_entry_cmd(dispatch, model),
      {
        ..model,
        desk_move_status: if model.desk_selected_paths.length() > 1 {
          "moving \{model.desk_selected_paths.length()} items"
        } else {
          "moving selection"
        },
      },
    )
  }
}

///|
fn rename_desk_entry_action(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  if model.selected_workspace_id == "" {
    (@rabbita.none, { ..model, desk_rename_status: "select a MoonBook first" })
  } else if model.selected_path == "" {
    (@rabbita.none, { ..model, desk_rename_status: "select an item to rename" })
  } else if model.desk_selected_paths.length() > 1 {
    (
      @rabbita.none,
      { ..model, desk_rename_status: "rename one item at a time" },
    )
  } else if model.desk_rename_name.trim().to_owned() == "" {
    (@rabbita.none, { ..model, desk_rename_status: "enter a new name" })
  } else {
    (
      rename_desk_entry_cmd(dispatch, model),
      { ..model, desk_rename_status: "renaming selection" },
    )
  }
}

///|
fn create_desk_entry_action(
  dispatch : Dispatch[Msg],
  model : Model,
  kind : String,
) -> (@rabbita.Cmd, Model) {
  if model.selected_workspace_id == "" {
    (
      @rabbita.none,
      { ..model, desk_new_item_status: "select a MoonBook first" },
    )
  } else if model.desk_new_item_name.trim().to_owned() == "" {
    (@rabbita.none, { ..model, desk_new_item_status: "enter a name" })
  } else {
    (
      create_desk_entry_cmd(dispatch, model, kind),
      {
        ..model,
        desk_new_item_status: if kind == "folder" {
          "creating folder"
        } else {
          "creating markdown"
        },
      },
    )
  }
}

///|
fn import_moonbook_action(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  if model.import_book_path.trim().to_owned() == "" {
    (
      @rabbita.none,
      { ..model, import_book_status: "enter a MoonBook folder path" },
    )
  } else {
    (
      import_moonbook_cmd(dispatch, model),
      { ..model, import_book_status: "importing MoonBook" },
    )
  }
}

///|
fn create_blank_moonbook_action(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  if model.new_book_name.trim().to_owned() == "" &&
    model.new_book_id.trim().to_owned() == "" {
    (@rabbita.none, { ..model, new_book_status: "enter a MoonBook name or id" })
  } else {
    (
      create_blank_moonbook_cmd(dispatch, model),
      { ..model, new_book_status: "creating MoonBook" },
    )
  }
}

///|
fn suggested_new_book_id(name : String, current_id : String) -> String {
  if current_id != "" && current_id != "research-untitled-moonbook" {
    current_id
  } else {
    let clean = sanitize_ui_id(name)
    if clean == "" {
      "research-untitled-moonbook"
    } else {
      "research-" + clean
    }
  }
}

///|
fn decide_review_item_action(
  dispatch : Dispatch[Msg],
  model : Model,
  item : ReviewItem,
  decision : String,
) -> (@rabbita.Cmd, Model) {
  if item.workspace_id == "" {
    (
      @rabbita.none,
      { ..model, review_decision_status: "review item is not book-scoped" },
    )
  } else if decision != "accepted" && decision != "rejected" {
    (
      @rabbita.none,
      { ..model, review_decision_status: "unknown review decision" },
    )
  } else {
    (
      decide_review_item_cmd(dispatch, model, item, decision),
      { ..model, review_decision_status: "recording \{decision}" },
    )
  }
}

///|
fn start_markdown_edit_action(model : Model) -> (@rabbita.Cmd, Model) {
  if !can_edit_markdown_selection(model) {
    (
      @rabbita.none,
      {
        ..model,
        markdown_editor_status: "select a wiki or inbox markdown document",
      },
    )
  } else {
    let content = match model.preview {
      Some(preview) if preview.renderer is Markdown => preview.body
      _ => ""
    }
    (
      @rabbita.none,
      {
        ..model,
        markdown_editor_path: model.selected_path,
        markdown_editor_content: content,
        markdown_editor_status: "editing \{model.selected_path}",
      },
    )
  }
}

///|
fn search_now_action(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  let query = model.search_query.trim().to_owned()
  if query == "" {
    (@rabbita.none, { ..model, search_status: "enter a query" })
  } else {
    (
      sync_activity_batch(Search, fetch_search_cmd(dispatch, query)),
      {
        ..model,
        activity: Search,
        command_open: false,
        search_status: "searching",
      },
    )
  }
}

///|
fn refresh_all_cmd(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Cmd {
  @rabbita.batch([
    fetch_workspace_metadata_cmd(dispatch),
    fetch_workspaces_cmd(dispatch),
    if model.selected_workspace_id == "" {
      @rabbita.none
    } else {
      fetch_entries_cmd(
        dispatch,
        model.selected_workspace_id,
        model.current_directory,
      )
    },
    if model.selected_workspace_id == "" {
      @rabbita.none
    } else {
      fetch_preview_cmd(
        dispatch,
        model.selected_workspace_id,
        model.selected_path,
      )
    },
    if model.selected_workspace_id == "" {
      @rabbita.none
    } else {
      fetch_desk_trash_cmd(dispatch, model.selected_workspace_id)
    },
    fetch_messages_cmd(dispatch),
    fetch_requests_cmd(dispatch),
    fetch_standing_goals_cmd(dispatch),
    fetch_analytics_cmd(dispatch),
    fetch_town_progress_cmd(dispatch),
    fetch_town_events_cmd(dispatch),
    fetch_moonclaw_progress_cmd(dispatch, model.selected_workspace_id),
    fetch_daemon_lifecycle_cmd(dispatch),
    fetch_launch_agent_cmd(dispatch),
    fetch_moonclaw_daemon_cmd(dispatch),
    fetch_moonclaw_models_cmd(dispatch),
    fetch_mooncode_sessions_cmd(dispatch, ""),
    fetch_review_items_cmd(dispatch, model.selected_workspace_id),
    fetch_saved_views_cmd(dispatch),
    fetch_book_patterns_cmd(dispatch),
    fetch_book_base_types_cmd(dispatch),
    fetch_moonflow_runs_cmd(dispatch),
  ])
}
