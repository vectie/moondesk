///|
#cfg(target="js")
fn desk_keyboard_msg(keyboard : @html.Keyboard) -> Msg {
  DeskKeyDown(
    keyboard.key(),
    keyboard.shift_key(),
    keyboard.ctrl_key() || keyboard.meta_key(),
  )
}

///|
#cfg(not(target="js"))
fn desk_keyboard_msg(_keyboard : @html.Keyboard) -> Msg {
  DeskKeyDown("", false, false)
}

///|
fn desk_keydown_action(
  dispatch : Dispatch[Msg],
  key : String,
  shift : Bool,
  accel : Bool,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  if model.workspace_mode != Desk {
    return (@rabbita.none, model)
  }
  if model.desk_rename_editing_path != "" {
    return match key {
      "Enter" =>
        update_workspace_surface_actions(dispatch, RenameDeskSelection, model)
      "Escape" =>
        update_workspace_surface_actions(dispatch, CancelDeskRename, model)
      _ => (@rabbita.none, model)
    }
  }
  let lower_key = key.to_lower()
  if accel && shift && lower_key == "n" {
    return update_workspace_surface_actions(dispatch, CreateDeskFolder, model)
  }
  if accel && lower_key == "c" {
    return update_workspace_surface_actions(dispatch, CopyDeskSelection, model)
  }
  if accel && lower_key == "a" {
    return desk_select_all_visible_entries(model)
  }
  if accel && lower_key == "x" {
    return update_workspace_surface_actions(dispatch, CutDeskSelection, model)
  }
  if accel && lower_key == "v" {
    return update_workspace_surface_actions(dispatch, PasteDeskClipboard, model)
  }
  match key {
    "ArrowDown" => desk_move_selection(dispatch, model, 1, shift)
    "ArrowUp" => desk_move_selection(dispatch, model, -1, shift)
    "Home" => desk_move_to_edge(dispatch, model, first=true, extend=shift)
    "End" => desk_move_to_edge(dispatch, model, first=false, extend=shift)
    "F2" => update_workspace_surface_actions(dispatch, StartDeskRename, model)
    "F5" => update_workspace_surface_actions(dispatch, RefreshAll, model)
    "Enter" => desk_open_keyboard_selection(dispatch, model)
    "Backspace" =>
      update_navigation_actions(
        dispatch,
        OpenDirectory(parent_path(model.current_directory)),
        model,
      )
    "Delete" =>
      update_workspace_surface_actions(dispatch, TrashDeskSelection, model)
    "Escape" => clear_desk_selection_action(model)
    " " if accel => desk_toggle_focused_selection(model)
    _ =>
      if key.length() == 1 && !accel {
        desk_typeahead_selection(dispatch, model, key)
      } else {
        (@rabbita.none, model)
      }
  }
}

///|
fn desk_select_all_visible_entries(model : Model) -> (@rabbita.Cmd, Model) {
  let entries = sorted_desk_entries(model)
  if entries.length() == 0 {
    return (@rabbita.none, model)
  }
  let paths : Array[String] = []
  for entry in entries {
    paths.push(entry.path)
  }
  let focused = if model.selected_path != "" &&
    paths.contains(model.selected_path) {
    model.selected_path
  } else {
    paths[0]
  }
  (
    @rabbita.none,
    {
      ..model,
      selected_path: focused,
      desk_selected_paths: paths,
      desk_selection_anchor: focused,
      desk_rename_editing_path: "",
      desk_rename_name: @desk.display_name(focused),
      desk_move_target_directory: parent_path(focused),
      preview_status: "\{paths.length()} items selected",
    },
  )
}

///|
fn desk_move_selection(
  dispatch : Dispatch[Msg],
  model : Model,
  delta : Int,
  extend : Bool,
) -> (@rabbita.Cmd, Model) {
  let entries = sorted_desk_entries(model)
  if entries.length() == 0 {
    return (@rabbita.none, model)
  }
  let current = desk_entry_index(entries, model.selected_path)
  let index = if current < 0 {
    if delta < 0 {
      entries.length() - 1
    } else {
      0
    }
  } else {
    clamp_int(current + delta, 0, entries.length() - 1)
  }
  desk_select_keyboard_entry(dispatch, model, entries[index], extend)
}

///|
fn desk_move_to_edge(
  dispatch : Dispatch[Msg],
  model : Model,
  first~ : Bool,
  extend~ : Bool,
) -> (@rabbita.Cmd, Model) {
  let entries = sorted_desk_entries(model)
  if entries.length() == 0 {
    return (@rabbita.none, model)
  }
  let index = if first { 0 } else { entries.length() - 1 }
  desk_select_keyboard_entry(dispatch, model, entries[index], extend)
}

///|
fn desk_typeahead_selection(
  dispatch : Dispatch[Msg],
  model : Model,
  key : String,
) -> (@rabbita.Cmd, Model) {
  let entries = sorted_desk_entries(model)
  let target = desk_typeahead_entry(entries, model.selected_path, key)
  match target {
    Some(entry) => desk_select_keyboard_entry(dispatch, model, entry, false)
    None => (@rabbita.none, model)
  }
}

///|
fn desk_open_keyboard_selection(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match find_entry(model, model.selected_path) {
    Some(entry) if entry.kind is Directory =>
      update_navigation_actions(dispatch, OpenDirectory(entry.path), model)
    Some(entry) => desk_select_keyboard_entry(dispatch, model, entry, false)
    None => (@rabbita.none, model)
  }
}

///|
fn desk_select_keyboard_entry(
  dispatch : Dispatch[Msg],
  model : Model,
  entry : @desk.DeskFileEntry,
  extend : Bool,
) -> (@rabbita.Cmd, Model) {
  let selected_paths = desk_selection_paths_for_focus(model, entry.path, extend)
  let anchor = if extend {
    desk_selection_anchor_for_range(model, entry.path)
  } else {
    entry.path
  }
  (
    fetch_preview_cmd(dispatch, model.selected_workspace_id, entry.path),
    {
      ..clear_if_path_leaves_markdown_editor(model, entry.path),
      selected_path: entry.path,
      desk_selected_paths: selected_paths,
      desk_selection_anchor: anchor,
      desk_rename_editing_path: "",
      desk_rename_name: entry.display_name,
      desk_move_target_directory: parent_path(entry.path),
      primary_preview_path: remember_primary_preview_path(model, entry.path),
      preview: None,
      preview_status: "loading selection",
    },
  )
}

///|
fn desk_toggle_focused_selection(model : Model) -> (@rabbita.Cmd, Model) {
  let path = model.selected_path
  if path == "" {
    return (@rabbita.none, model)
  }
  let next = toggle_string(model.desk_selected_paths, path)
  (
    @rabbita.none,
    {
      ..model,
      desk_selected_paths: next,
      desk_selection_anchor: if next.length() == 0 {
        ""
      } else {
        path
      },
    },
  )
}

///|
fn desk_selection_paths_for_focus(
  model : Model,
  path : String,
  extend : Bool,
) -> Array[String] {
  if path == "" {
    []
  } else if extend {
    desk_range_selection(
      model,
      desk_selection_anchor_for_range(model, path),
      path,
    )
  } else {
    [path]
  }
}

///|
fn desk_selection_anchor_for_range(model : Model, fallback : String) -> String {
  if model.desk_selection_anchor != "" {
    model.desk_selection_anchor
  } else if model.selected_path != "" {
    model.selected_path
  } else {
    fallback
  }
}

///|
fn desk_range_selection(
  model : Model,
  anchor : String,
  target : String,
) -> Array[String] {
  let entries = sorted_desk_entries(model)
  let anchor_index = desk_entry_index(entries, anchor)
  let target_index = desk_entry_index(entries, target)
  if anchor_index < 0 || target_index < 0 {
    return [target]
  }
  let start = if anchor_index < target_index {
    anchor_index
  } else {
    target_index
  }
  let end = if anchor_index > target_index {
    anchor_index
  } else {
    target_index
  }
  let paths : Array[String] = []
  for index in start..<=end {
    paths.push(entries[index].path)
  }
  paths
}

///|
fn desk_entry_index(entries : Array[@desk.DeskFileEntry], path : String) -> Int {
  for index in 0..<entries.length() {
    if entries[index].path == path {
      return index
    }
  }
  -1
}

///|
fn desk_typeahead_entry(
  entries : Array[@desk.DeskFileEntry],
  current_path : String,
  key : String,
) -> @desk.DeskFileEntry? {
  if entries.length() == 0 {
    return None
  }
  let needle = key.to_lower()
  let current = desk_entry_index(entries, current_path)
  let start = if current < 0 { 0 } else { current + 1 }
  for offset in 0..<entries.length() {
    let index = (start + offset) % entries.length()
    if entries[index].display_name.to_lower().has_prefix(needle) {
      return Some(entries[index])
    }
  }
  None
}
