///|
fn update_navigation_actions(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    SelectWorkspaceMode(mode) =>
      if markdown_navigation_needs_confirmation(
          model,
          mode != model.workspace_mode,
        ) {
        queue_markdown_navigation(model, PendingWorkspaceMode(mode))
      } else {
        select_workspace_mode_action(dispatch, mode, model)
      }
    SelectActivity(activity) =>
      if markdown_editor_active(model) && activity == model.activity {
        (@rabbita.none, model)
      } else if markdown_navigation_needs_confirmation(
          model,
          activity != model.activity,
        ) {
        queue_markdown_navigation(model, PendingActivity(activity))
      } else {
        select_activity_action(dispatch, activity, model)
      }
    SelectWorkspace(workspace_id) =>
      if markdown_editor_active(model) &&
        workspace_id == model.selected_workspace_id {
        (@rabbita.none, model)
      } else if markdown_navigation_needs_confirmation(
          model,
          workspace_id != model.selected_workspace_id,
        ) {
        queue_markdown_navigation(model, PendingWorkspace(workspace_id))
      } else {
        select_workspace_action(dispatch, workspace_id, model)
      }
    SelectPath(path) =>
      if markdown_navigation_needs_confirmation(
          model,
          path != model.markdown_editor_path,
        ) {
        queue_markdown_navigation(model, PendingPath(path))
      } else {
        select_path_action(dispatch, model, path)
      }
    OpenDirectory(path) =>
      if markdown_navigation_needs_confirmation(model, true) {
        queue_markdown_navigation(model, PendingDirectory(path))
      } else {
        open_directory_action(dispatch, model, path)
      }
    NavigateDeskBack => navigate_desk_back_action(dispatch, model)
    NavigateDeskForward => navigate_desk_forward_action(dispatch, model)
    SetDeskLocationInput(path) =>
      (@rabbita.none, { ..model, desk_location_input: path })
    OpenDeskLocation =>
      open_directory_action(
        dispatch,
        model,
        desk_location_path_from_input(model.desk_location_input),
      )
    OpenQuickPath(path) =>
      if markdown_navigation_needs_confirmation(
          model,
          path != model.markdown_editor_path,
        ) {
        queue_markdown_navigation(model, PendingQuickPath(path))
      } else {
        open_quick_path_action(dispatch, path, model)
      }
    SelectSearchHit(workspace_id, path) =>
      if markdown_editor_active(model) &&
        workspace_id == model.selected_workspace_id &&
        path == model.markdown_editor_path {
        (@rabbita.none, model)
      } else if markdown_navigation_needs_confirmation(
          model,
          workspace_id != model.selected_workspace_id ||
          path != model.markdown_editor_path,
        ) {
        queue_markdown_navigation(model, PendingSearchHit(workspace_id, path))
      } else {
        select_search_hit_action(dispatch, workspace_id, path, model)
      }
    ConfirmDiscardMarkdownNavigation =>
      confirm_markdown_navigation_action(dispatch, model)
    CancelDiscardMarkdownNavigation =>
      (
        @rabbita.none,
        { ..model, pending_markdown_navigation: NoPendingMarkdownNavigation },
      )
    ToggleCommand =>
      (
        @rabbita.none,
        { ..model, command_open: !model.command_open, command_query: "" },
      )
    SetCommandQuery(query) => (@rabbita.none, { ..model, command_query: query })
    _ => (@rabbita.none, model)
  }
}

///|
fn markdown_navigation_needs_confirmation(
  model : Model,
  leaves_editor : Bool,
) -> Bool {
  markdown_editor_active(model) && leaves_editor
}

///|
fn queue_markdown_navigation(
  model : Model,
  navigation : PendingMarkdownNavigation,
) -> (@rabbita.Cmd, Model) {
  (@rabbita.none, { ..model, pending_markdown_navigation: navigation })
}

///|
fn confirm_markdown_navigation_action(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  let navigation = model.pending_markdown_navigation
  let cleared = clear_markdown_editor({
    ..model,
    pending_markdown_navigation: NoPendingMarkdownNavigation,
  })
  match navigation {
    NoPendingMarkdownNavigation => (@rabbita.none, model)
    PendingWorkspaceMode(mode) =>
      select_workspace_mode_action(dispatch, mode, cleared)
    PendingActivity(activity) =>
      select_activity_action(dispatch, activity, cleared)
    PendingWorkspace(workspace_id) =>
      select_workspace_action(dispatch, workspace_id, cleared)
    PendingPath(path) => select_path_action(dispatch, cleared, path)
    PendingDirectory(path) => open_directory_action(dispatch, cleared, path)
    PendingQuickPath(path) => open_quick_path_action(dispatch, path, cleared)
    PendingSearchHit(workspace_id, path) =>
      select_search_hit_action(dispatch, workspace_id, path, cleared)
  }
}

///|
fn select_activity_action(
  dispatch : Dispatch[Msg],
  activity : Activity,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  (
    sync_activity_batch(
      activity,
      activity_refresh_cmds(dispatch, activity, model),
    ),
    clear_markdown_editor({
      ..model,
      workspace_mode: workspace_mode_for_activity(activity),
      activity,
      command_open: false,
      command_query: "",
    }),
  )
}

///|
fn select_workspace_action(
  dispatch : Dispatch[Msg],
  workspace_id : String,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  (
    @rabbita.batch([
      reload_workspace_cmds(dispatch, workspace_id, ""),
      fetch_mooncode_sessions_cmd(dispatch, ""),
      sync_workspace_context_cmd(workspace_id, ""),
      sync_mooncode_context_cmd(workspace_id, ""),
      stop_mooncode_watch_cmd(),
    ]),
    clear_markdown_editor({
      ..model,
      selected_workspace_id: workspace_id,
      selected_mooncode_session_id: "",
      mooncode_watch_generation: model.mooncode_watch_generation + 1,
      mooncode_watch_revision: 0,
      mooncode_watch_sequence: 0,
      mooncode_watch_status: "idle",
      mooncode_watch_failure_count: 0,
      mooncode_new_chat_active: false,
      mooncode_prompt: "",
      request_material_paths: [],
      request_material_status: "",
      selected_path: "",
      desk_selected_paths: [],
      desk_selection_anchor: "",
      desk_new_item_name: "Untitled",
      desk_new_item_status: "ready to create item",
      desk_rename_editing_path: "",
      desk_rename_name: "",
      desk_rename_status: "ready to rename selection",
      desk_move_target_directory: "",
      desk_move_status: "ready to move selection",
      desk_clipboard_paths: [],
      desk_clipboard_workspace_id: "",
      desk_clipboard_operation: "",
      desk_clipboard_status: "clipboard empty",
      desk_path_status: "ready to copy path",
      desk_copy_status: "ready to duplicate selection",
      desk_trash_status: "ready to trash selection",
      desk_back_stack: [],
      desk_forward_stack: [],
      desk_trash_entries: [],
      desk_last_trash_path: "",
      primary_preview_path: "wiki/index.md",
      current_directory: "",
      desk_location_input: "",
      desk_filter_query: "",
      preview: None,
      preview_status: "loading workspace",
      entries: [],
    }),
  )
}

///|
fn open_quick_path_action(
  dispatch : Dispatch[Msg],
  path : String,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  (
    @rabbita.batch([
      fetch_entries_cmd(
        dispatch,
        model.selected_workspace_id,
        parent_path(path),
      ),
      fetch_preview_cmd(dispatch, model.selected_workspace_id, path),
      sync_workspace_context_cmd(model.selected_workspace_id, path),
    ]),
    {
      ..clear_if_path_leaves_markdown_editor(model, path),
      selected_path: path,
      current_directory: parent_path(path),
      desk_location_input: parent_path(path),
      desk_filter_query: "",
      desk_selected_paths: if path == "" {
        []
      } else {
        [path]
      },
      desk_selection_anchor: path,
      desk_rename_editing_path: "",
      desk_rename_name: if path == "" {
        ""
      } else {
        @desk.display_name(path)
      },
      desk_move_target_directory: if path == "" {
        ""
      } else {
        parent_path(path)
      },
      primary_preview_path: remember_primary_preview_path(model, path),
      preview: None,
      preview_status: "loading preview",
    },
  )
}

///|
fn select_search_hit_action(
  dispatch : Dispatch[Msg],
  workspace_id : String,
  path : String,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  let directory = parent_path(path)
  let target_mode = if model.workspace_mode == MoonWiki {
    MoonWiki
  } else {
    Desk
  }
  (
    sync_shell_batch(
      target_mode,
      Files,
      @rabbita.batch([
        fetch_entries_cmd(dispatch, workspace_id, directory),
        fetch_preview_cmd(dispatch, workspace_id, path),
        fetch_runs_cmd(dispatch, workspace_id),
        sync_workspace_context_cmd(workspace_id, path),
      ]),
    ),
    clear_markdown_editor({
      ..model,
      workspace_mode: target_mode,
      activity: Files,
      command_open: false,
      command_query: "",
      selected_workspace_id: workspace_id,
      selected_path: path,
      desk_selected_paths: if path == "" {
        []
      } else {
        [path]
      },
      desk_selection_anchor: path,
      desk_rename_editing_path: "",
      desk_rename_name: if path == "" {
        ""
      } else {
        @desk.display_name(path)
      },
      desk_move_target_directory: if path == "" {
        ""
      } else {
        parent_path(path)
      },
      primary_preview_path: if is_generated_site_path(path) {
        "wiki/index.md"
      } else {
        path
      },
      current_directory: directory,
      desk_location_input: directory,
      desk_filter_query: "",
      preview: None,
      preview_status: "loading search result",
    }),
  )
}

///|
fn open_directory_action(
  dispatch : Dispatch[Msg],
  model : Model,
  path : String,
) -> (@rabbita.Cmd, Model) {
  let back_stack = if path == model.current_directory {
    model.desk_back_stack
  } else {
    desk_history_push(model.desk_back_stack, model.current_directory)
  }
  open_directory_with_history(
    dispatch,
    model,
    path,
    back_stack,
    [],
    "loading directory",
  )
}

///|
fn navigate_desk_back_action(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match desk_history_pop(model.desk_back_stack) {
    Some((target, remaining_back)) =>
      open_directory_with_history(
        dispatch,
        model,
        target,
        remaining_back,
        desk_history_push(model.desk_forward_stack, model.current_directory),
        "loading previous directory",
      )
    None =>
      (@rabbita.none, { ..model, preview_status: "no previous directory" })
  }
}

///|
fn navigate_desk_forward_action(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match desk_history_pop(model.desk_forward_stack) {
    Some((target, remaining_forward)) =>
      open_directory_with_history(
        dispatch,
        model,
        target,
        desk_history_push(model.desk_back_stack, model.current_directory),
        remaining_forward,
        "loading next directory",
      )
    None => (@rabbita.none, { ..model, preview_status: "no next directory" })
  }
}

///|
fn open_directory_with_history(
  dispatch : Dispatch[Msg],
  model : Model,
  path : String,
  back_stack : Array[String],
  forward_stack : Array[String],
  status : String,
) -> (@rabbita.Cmd, Model) {
  (
    @rabbita.batch([
      fetch_entries_cmd(dispatch, model.selected_workspace_id, path),
      fetch_preview_cmd(dispatch, model.selected_workspace_id, path),
      sync_workspace_context_cmd(model.selected_workspace_id, path),
    ]),
    clear_markdown_editor({
      ..model,
      current_directory: path,
      desk_location_input: path,
      desk_filter_query: "",
      selected_path: path,
      desk_selected_paths: if path == "" {
        []
      } else {
        [path]
      },
      desk_selection_anchor: path,
      desk_rename_editing_path: "",
      desk_rename_name: if path == "" {
        ""
      } else {
        @desk.display_name(path)
      },
      desk_move_target_directory: if path == "" {
        ""
      } else {
        parent_path(path)
      },
      desk_back_stack: back_stack,
      desk_forward_stack: forward_stack,
      primary_preview_path: remember_primary_preview_path(model, path),
      preview: None,
      preview_status: status,
    }),
  )
}

///|
fn desk_location_path_from_input(input : String) -> String {
  let raw = input.trim().to_owned()
  let lower = raw.to_lower()
  if raw == "" ||
    raw == "/" ||
    raw == "\\" ||
    lower == "root" ||
    lower == "(root)" {
    ""
  } else {
    normalize_desk_location_path(raw)
  }
}

///|
fn normalize_desk_location_path(raw : String) -> String {
  let normalized = normalize_desk_location_separators(raw)
    .trim(chars=['/', '\\'])
    .to_owned()
  let mut segments : Array[String] = []
  for part in normalized.split("/") {
    let segment = part.trim().to_owned()
    if segment == "" || segment == "." {
      continue
    } else if segment == ".." {
      if segments.length() == 0 {
        return ""
      }
      segments = desk_location_without_last_segment(segments)
    } else {
      segments.push(segment)
    }
  }
  segments.join("/")
}

///|
fn normalize_desk_location_separators(raw : String) -> String {
  let pieces : Array[String] = []
  for ch in raw {
    if ch == '\\' {
      pieces.push("/")
    } else {
      pieces.push(String::from_array([ch]))
    }
  }
  pieces.join("")
}

///|
fn desk_location_without_last_segment(
  segments : Array[String],
) -> Array[String] {
  let next : Array[String] = []
  if segments.length() == 0 {
    return next
  }
  for index in 0..<(segments.length() - 1) {
    next.push(segments[index])
  }
  next
}

///|
fn desk_history_push(stack : Array[String], path : String) -> Array[String] {
  if stack.length() > 0 && stack[stack.length() - 1] == path {
    stack
  } else {
    let next : Array[String] = []
    for item in stack {
      next.push(item)
    }
    next.push(path)
    if next.length() > 50 {
      let trimmed : Array[String] = []
      for index in 1..<next.length() {
        trimmed.push(next[index])
      }
      trimmed
    } else {
      next
    }
  }
}

///|
fn desk_history_pop(stack : Array[String]) -> (String, Array[String])? {
  if stack.length() == 0 {
    None
  } else {
    let next : Array[String] = []
    for index in 0..<(stack.length() - 1) {
      next.push(stack[index])
    }
    Some((stack[stack.length() - 1], next))
  }
}

///|
fn activity_refresh_cmds(
  dispatch : Dispatch[Msg],
  activity : Activity,
  model : Model,
) -> @rabbita.Cmd {
  match activity {
    Files =>
      if model.selected_workspace_id == "" {
        @rabbita.none
      } else {
        @rabbita.batch([
          fetch_entries_cmd(
            dispatch,
            model.selected_workspace_id,
            model.current_directory,
          ),
          fetch_preview_cmd(
            dispatch,
            model.selected_workspace_id,
            model.selected_path,
          ),
          fetch_desk_trash_cmd(dispatch, model.selected_workspace_id),
        ])
      }
    Town =>
      @rabbita.batch([
        fetch_requests_cmd(dispatch),
        fetch_messages_cmd(dispatch),
        fetch_standing_goals_cmd(dispatch),
        fetch_analytics_cmd(dispatch),
        fetch_town_progress_cmd(dispatch),
        fetch_town_events_cmd(dispatch),
        fetch_daemon_lifecycle_cmd(dispatch),
        fetch_launch_agent_cmd(dispatch),
      ])
    Runs =>
      if model.selected_workspace_id == "" {
        @rabbita.none
      } else {
        @rabbita.batch([
          fetch_runs_cmd(dispatch, model.selected_workspace_id),
          fetch_moonclaw_progress_cmd(dispatch, model.selected_workspace_id),
          fetch_events_cmd(dispatch, model.selected_workspace_id),
        ])
      }
    Settings =>
      @rabbita.batch([
        fetch_standing_goals_cmd(dispatch),
        fetch_analytics_cmd(dispatch),
        fetch_town_progress_cmd(dispatch),
        fetch_saved_views_cmd(dispatch),
        fetch_daemon_lifecycle_cmd(dispatch),
        fetch_launch_agent_cmd(dispatch),
        if model.selected_workspace_id == "" {
          @rabbita.none
        } else {
          fetch_review_items_cmd(dispatch, model.selected_workspace_id)
        },
      ])
    Search | Inbox => @rabbita.none
  }
}

///|
fn select_workspace_mode_action(
  dispatch : Dispatch[Msg],
  mode : WorkspaceMode,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  let activity = match mode {
    PackHome => Files
    Desk => Files
    MoonCode => Files
    MoonFlow => Files
    MoonWiki => model.activity
  }
  let desk_directory = desk_context_directory(model)
  let base_cmd = if mode == PackHome {
    sync_shell_batch(mode, activity, fetch_pack_apps_cmd(dispatch))
  } else if mode == Desk && model.selected_workspace_id != "" {
    sync_shell_batch(
      mode,
      activity,
      @rabbita.batch([
        fetch_entries_cmd(dispatch, model.selected_workspace_id, desk_directory),
        fetch_preview_cmd(
          dispatch,
          model.selected_workspace_id,
          model.selected_path,
        ),
        fetch_desk_trash_cmd(dispatch, model.selected_workspace_id),
      ]),
    )
  } else if mode == MoonCode {
    sync_shell_batch(mode, activity, fetch_mooncode_sessions_cmd(dispatch, ""))
  } else if mode == MoonFlow {
    sync_shell_batch(
      mode,
      activity,
      @rabbita.batch([
        fetch_moonflow_runs_cmd(dispatch),
        if model.selected_workspace_id == "" {
          @rabbita.none
        } else {
          fetch_moonflow_composition_cmd(dispatch, model.selected_workspace_id)
        },
      ]),
    )
  } else {
    sync_shell_cmd(mode, activity)
  }
  let mode_changed = mode != model.workspace_mode
  let next = {
    ..clear_if_switching_out_of_markdown_editor(model, mode),
    workspace_mode: mode,
    activity,
    command_open: false,
    command_query: "",
    current_directory: if mode == Desk {
      desk_directory
    } else {
      model.current_directory
    },
    desk_location_input: if mode == Desk {
      desk_directory
    } else {
      model.desk_location_input
    },
    desk_filter_query: if mode == Desk {
      ""
    } else {
      model.desk_filter_query
    },
    preview: if mode == Desk {
      None
    } else {
      model.preview
    },
    preview_status: if mode == Desk && model.selected_workspace_id != "" {
      "loading desk context"
    } else {
      model.preview_status
    },
    mooncode_prompt: if mode == MoonCode {
      ""
    } else {
      model.mooncode_prompt
    },
    mooncode_new_chat_active: if mode == MoonCode {
      false
    } else {
      model.mooncode_new_chat_active
    },
    mooncode_watch_generation: if mode_changed {
      model.mooncode_watch_generation + 1
    } else {
      model.mooncode_watch_generation
    },
    mooncode_watch_revision: if mode_changed {
      0
    } else {
      model.mooncode_watch_revision
    },
    mooncode_watch_sequence: if mode_changed {
      0
    } else {
      model.mooncode_watch_sequence
    },
    mooncode_watch_status: if mode == MoonCode &&
      model.selected_mooncode_session_id != "" {
      "connecting"
    } else if mode == MoonCode {
      "idle"
    } else {
      "paused"
    },
    mooncode_watch_failure_count: if mode_changed {
      0
    } else {
      model.mooncode_watch_failure_count
    },
    mooncode_composer_status: if mode == MoonCode {
      "MoonCode workspace ready"
    } else {
      model.mooncode_composer_status
    },
  }
  let transport_cmd = if !mode_changed {
    @rabbita.none
  } else if mode == MoonCode && next.selected_mooncode_session_id != "" {
    mooncode_watch_cmd(dispatch, next)
  } else if model.workspace_mode == MoonCode {
    stop_mooncode_watch_cmd()
  } else {
    @rabbita.none
  }
  (@rabbita.batch([base_cmd, transport_cmd]), next)
}

///|
fn desk_context_directory(model : Model) -> String {
  if model.selected_path == "" {
    ""
  } else {
    match find_entry(model, model.selected_path) {
      Some(entry) if entry.kind is Directory => model.selected_path
      _ => parent_path(model.selected_path)
    }
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
    sync_workspace_context_batch(model.selected_workspace_id, path, base_cmd),
    {
      ..clear_if_path_leaves_markdown_editor(model, path),
      selected_path: path,
      desk_selected_paths: if path == "" {
        []
      } else {
        [path]
      },
      desk_selection_anchor: path,
      desk_rename_editing_path: "",
      desk_rename_name: if path == "" {
        ""
      } else {
        @desk.display_name(path)
      },
      desk_move_target_directory: if path == "" {
        ""
      } else {
        parent_path(path)
      },
      primary_preview_path: remember_primary_preview_path(model, path),
      current_directory: if is_directory {
        path
      } else {
        model.current_directory
      },
      desk_location_input: if is_directory {
        path
      } else {
        model.desk_location_input
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

///|
fn clear_if_path_leaves_markdown_editor(model : Model, path : String) -> Model {
  if model.markdown_editor_path == "" || model.markdown_editor_path == path {
    model
  } else {
    clear_markdown_editor(model)
  }
}

///|
fn clear_if_switching_out_of_markdown_editor(
  model : Model,
  mode : WorkspaceMode,
) -> Model {
  if mode is MoonWiki {
    model
  } else {
    clear_markdown_editor(model)
  }
}
