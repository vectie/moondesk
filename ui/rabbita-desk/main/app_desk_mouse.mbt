///|
#cfg(target="js")
fn desk_mouse_event_msg(path : String, event : @dom.MouseEvent) -> Msg {
  DeskMouseDown(
    path,
    event.get_shift_key(),
    event.get_ctrl_key() || event.get_meta_key(),
  )
}

///|
#cfg(not(target="js"))
fn desk_mouse_event_msg(path : String, _event : Unit) -> Msg {
  DeskMouseDown(path, false, false)
}

///|
fn desk_mouse_action(
  dispatch : Dispatch[Msg],
  path : String,
  shift : Bool,
  accel : Bool,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  if model.workspace_mode != Desk {
    return (@rabbita.none, model)
  }
  match find_entry(model, path) {
    Some(entry) =>
      if shift {
        desk_select_mouse_entry(dispatch, model, entry, extend=true)
      } else if accel {
        desk_toggle_mouse_entry(dispatch, model, entry)
      } else {
        desk_select_mouse_entry(dispatch, model, entry, extend=false)
      }
    None => (@rabbita.none, model)
  }
}

///|
fn desk_select_mouse_entry(
  dispatch : Dispatch[Msg],
  model : Model,
  entry : @desk.DeskFileEntry,
  extend~ : Bool,
) -> (@rabbita.Cmd, Model) {
  let selected_paths = desk_selection_paths_for_focus(model, entry.path, extend)
  let anchor = if extend {
    desk_selection_anchor_for_range(model, entry.path)
  } else {
    entry.path
  }
  desk_focus_selection(dispatch, model, entry.path, selected_paths, anchor)
}

///|
fn desk_toggle_mouse_entry(
  dispatch : Dispatch[Msg],
  model : Model,
  entry : @desk.DeskFileEntry,
) -> (@rabbita.Cmd, Model) {
  let current = if model.desk_selected_paths.length() == 0 &&
    model.selected_path != "" {
    [model.selected_path]
  } else {
    model.desk_selected_paths
  }
  let selected_paths = toggle_string(current, entry.path)
  let focus_path = if selected_paths.contains(entry.path) {
    entry.path
  } else if selected_paths.length() > 0 {
    selected_paths[0]
  } else {
    ""
  }
  let anchor = if focus_path == "" { "" } else { focus_path }
  desk_focus_selection(dispatch, model, focus_path, selected_paths, anchor)
}

///|
fn desk_focus_selection(
  dispatch : Dispatch[Msg],
  model : Model,
  focus_path : String,
  selected_paths : Array[String],
  anchor : String,
) -> (@rabbita.Cmd, Model) {
  if focus_path == "" {
    return clear_desk_selection_action(model)
  }
  (
    fetch_preview_cmd(dispatch, model.selected_workspace_id, focus_path),
    {
      ..clear_if_path_leaves_markdown_editor(model, focus_path),
      selected_path: focus_path,
      desk_selected_paths: selected_paths,
      desk_selection_anchor: anchor,
      desk_rename_editing_path: "",
      desk_rename_name: @desk.display_name(focus_path),
      desk_move_target_directory: parent_path(focus_path),
      primary_preview_path: remember_primary_preview_path(model, focus_path),
      preview: None,
      preview_status: "loading selection",
    },
  )
}

///|
fn clear_desk_selection_action(model : Model) -> (@rabbita.Cmd, Model) {
  (
    @rabbita.none,
    {
      ..model,
      selected_path: "",
      desk_selected_paths: [],
      desk_selection_anchor: "",
      desk_rename_editing_path: "",
      desk_rename_name: "",
      desk_move_target_directory: "",
      preview: None,
      preview_status: "selection cleared",
    },
  )
}
