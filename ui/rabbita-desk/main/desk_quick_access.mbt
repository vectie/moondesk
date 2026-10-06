///|
struct DeskQuickAccessBook {
  scope : String
  favorites : Array[String]
  recent_paths : Array[String]
  directories : Array[String]
}

///|
/// These lists are session-local. A relative path without ownership is never
/// assigned to the Book that happens to be active when it is encountered.
fn desk_quick_access_scope(model : Model) -> String {
  if model.selected_workspace_id == "" {
    return ""
  }
  let mut root = ""
  for book in model.workspaces {
    if book.id == model.selected_workspace_id {
      root = book.root_path
      break
    }
  }
  [
    model.workspace_suite_root_path,
    model.workspace_books_root_path,
    model.workspace_library_path,
    model.selected_workspace_id,
    root,
  ]
  .to_json()
  .stringify()
}

///|
fn valid_desk_quick_path(path : String) -> Bool {
  path != "" &&
  !path.contains("\\") &&
  !path.contains("\u0000") &&
  path.split("/").all(part => part != "" && part != "." && part != "..")
}

///|
fn clean_desk_quick_paths(paths : Array[String]) -> Array[String] {
  let result : Array[String] = []
  for path in paths {
    if valid_desk_quick_path(path) && !result.contains(path) {
      result.push(path)
    }
  }
  result
}

///|
fn desk_quick_directory_paths(model : Model) -> Array[String] {
  let paths = clean_desk_quick_paths(model.favorites + model.recent_paths)
  paths.filter(path => {
    match find_entry(model, path) {
      Some(entry) => entry.kind is Directory
      None =>
        if path == model.selected_path && model.preview is Some(preview) {
          preview.renderer is DirectoryListing
        } else {
          model.desk_quick_access_directories.contains(path)
        }
    }
  })
}

///|
/// Central rebinding covers catalog changes and every Book-selection route.
fn rebind_desk_quick_access(
  model : Model,
  refresh_paths? : Bool = true,
) -> Model {
  let scope = desk_quick_access_scope(model)
  if scope == model.desk_quick_access_owner {
    if !refresh_paths {
      return model
    }
    return {
      ..model,
      favorites: clean_desk_quick_paths(model.favorites),
      recent_paths: clean_desk_quick_paths(model.recent_paths),
      desk_quick_access_directories: desk_quick_directory_paths(model),
    }
  }
  let books = model.desk_quick_access_books.filter(book => {
    book.scope != model.desk_quick_access_owner
  })
  if model.desk_quick_access_owner != "" {
    books.push({
      scope: model.desk_quick_access_owner,
      favorites: clean_desk_quick_paths(model.favorites),
      recent_paths: clean_desk_quick_paths(model.recent_paths),
      directories: model.desk_quick_access_directories,
    })
  }
  let mut favorites : Array[String] = []
  let mut recent_paths : Array[String] = []
  let mut directories : Array[String] = []
  for book in books {
    if scope != "" && book.scope == scope {
      favorites = clean_desk_quick_paths(book.favorites)
      recent_paths = clean_desk_quick_paths(book.recent_paths)
      directories = clean_desk_quick_paths(book.directories)
      break
    }
  }
  {
    ..model,
    desk_quick_access_owner: scope,
    desk_quick_access_books: books,
    desk_quick_access_directories: directories,
    favorites,
    recent_paths,
  }
}

///|
/// Stream and unrelated UI updates should not scan bookmark or file lists.
fn desk_quick_access_paths_changed(msg : Msg) -> Bool {
  match msg {
    ToggleFavorite(_)
    | LoadedPreview(_, _, _, _)
    | LoadedEntries(_, _, _, _)
    | RenamedDeskEntry(_)
    | MovedDeskEntry(_) => true
    _ => false
  }
}

///|
fn sync_desk_quick_access_transition(
  previous : Model,
  next : Model,
  msg : Msg,
) -> Model {
  let next = if desk_quick_access_scope(next) !=
    previous.desk_quick_access_owner {
    // A context-changing result must not relabel the outgoing Book's paths.
    {
      ..next,
      favorites: previous.favorites,
      recent_paths: previous.recent_paths,
      desk_quick_access_directories: previous.desk_quick_access_directories,
    }
  } else {
    match msg {
      RenamedDeskEntry(Ok(result)) if result.workspace_id ==
        previous.selected_workspace_id =>
        {
          ..next,
          desk_quick_access_directories: replace_remembered_path(
            previous.desk_quick_access_directories,
            previous.selected_path,
            result.path,
          ),
        }
      MovedDeskEntry(Ok(result)) if result.workspace_id ==
        previous.selected_workspace_id =>
        {
          ..next,
          desk_quick_access_directories: replace_moved_remembered_paths(
            previous.desk_quick_access_directories,
            previous.desk_selected_paths,
            result.directory,
          ),
        }
      _ => next
    }
  }
  rebind_desk_quick_access(
    next,
    refresh_paths=desk_quick_access_paths_changed(msg),
  )
}

///|
fn open_desk_quick_path_action(
  dispatch : Dispatch[Msg],
  model : Model,
  scope : String,
  path : String,
) -> (@rabbita.Cmd, Model) {
  if scope == "" ||
    scope != desk_quick_access_scope(model) ||
    scope != model.desk_quick_access_owner ||
    !valid_desk_quick_path(path) ||
    (!model.favorites.contains(path) && !model.recent_paths.contains(path)) {
    return (@rabbita.none, model)
  }
  if desk_quick_directory_paths(model).contains(path) {
    if path == model.current_directory {
      return (@rabbita.none, model)
    }
    if markdown_navigation_needs_confirmation(model, true) {
      queue_markdown_navigation(model, PendingDeskQuickPath(scope, path))
    } else {
      update_navigation_actions(dispatch, OpenDirectory(path), model)
    }
  } else if path == model.selected_path &&
    parent_path(path) == model.current_directory {
    (@rabbita.none, model)
  } else if markdown_navigation_needs_confirmation(
      model,
      path != model.markdown_editor_path,
    ) {
    queue_markdown_navigation(model, PendingDeskQuickPath(scope, path))
  } else {
    update_navigation_actions(dispatch, OpenQuickPath(path), model)
  }
}
