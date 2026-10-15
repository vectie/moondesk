///|
struct WorkLocation {
  workspace_id : String
  mode : WorkspaceMode
  path : String
  directory : String
  filter : String
  title : String
}

///|
struct BookWorkPosition {
  location : WorkLocation
  title : String
  request_prompt : String
  request_status : String
  task_id : String
  stream_task_id : String
  stream_cursor : String
  chat : Array[WikiChatEntry]
  files : Array[String]
  context : Array[WikiChatContextItem]
  materials : Array[String]
  code_session : String
  code_prompt : String
  back : Array[String]
  forward : Array[String]
}

///|
fn current_work_title(model : Model) -> String {
  if model.workspace_mode == MoonCode {
    return mooncode_context_title(model, selected_mooncode_session(model))
  }
  if model.work_title != "" {
    model.work_title
  } else {
    for entry in model.wiki_chat_entries {
      if entry.role == "user" && entry.content.trim() != "" {
        return entry.content
      }
    }
    if model.selected_path != "" {
      @desk.display_name(model.selected_path)
    } else {
      "New task"
    }
  }
}

///|
fn work_location(model : Model) -> WorkLocation {
  {
    workspace_id: model.selected_workspace_id,
    mode: model.workspace_mode,
    path: model.selected_path,
    directory: model.current_directory,
    filter: model.desk_filter_query,
    title: if model.workspace_mode == Desk {
      "Files"
    } else {
      current_work_title(model)
    },
  }
}

///|
fn remember_book_work(model : Model) -> Array[BookWorkPosition] {
  let positions = model.book_positions.filter(p => {
    p.location.workspace_id != model.selected_workspace_id
  })
  if model.selected_workspace_id != "" {
    positions.push({
      location: work_location(model),
      title: model.work_title,
      request_prompt: model.request_prompt,
      request_status: model.request_status,
      task_id: model.wiki_agent_task_id,
      stream_task_id: model.wiki_chat_stream_task_id,
      stream_cursor: model.wiki_chat_stream_cursor,
      chat: model.wiki_chat_entries,
      files: model.wiki_chat_file_paths,
      context: model.wiki_chat_context_items,
      materials: model.request_material_paths,
      code_session: model.selected_mooncode_session_id,
      code_prompt: model.mooncode_prompt,
      back: model.desk_back_stack,
      forward: model.desk_forward_stack,
    })
  }
  positions
}

///|
fn restore_book_work(model : Model) -> Model {
  for position in model.book_positions {
    if position.location.workspace_id == model.selected_workspace_id {
      return {
        ..model,
        selected_path: position.location.path,
        current_directory: position.location.directory,
        desk_location_input: position.location.directory,
        desk_filter_query: position.location.filter,
        desk_selected_paths: if position.location.path == "" {
          []
        } else {
          [position.location.path]
        },
        primary_preview_path: position.location.path,
        work_title: position.title,
        request_prompt: position.request_prompt,
        request_status: position.request_status,
        wiki_agent_task_id: position.task_id,
        wiki_chat_stream_task_id: position.stream_task_id,
        wiki_chat_stream_cursor: position.stream_cursor,
        wiki_chat_entries: position.chat,
        wiki_chat_file_paths: position.files,
        wiki_chat_context_items: position.context,
        request_material_paths: position.materials,
        selected_mooncode_session_id: position.code_session,
        mooncode_prompt: position.code_prompt,
        desk_back_stack: position.back,
        desk_forward_stack: position.forward,
      }
    }
  }
  model
}

///|
fn remembered_work_location(
  model : Model,
  workspace_id : String,
) -> WorkLocation {
  for position in model.book_positions {
    if position.location.workspace_id == workspace_id {
      return position.location
    }
  }
  {
    workspace_id,
    mode: model.workspace_mode,
    path: "",
    directory: "",
    filter: "",
    title: "",
  }
}

///|
fn work_file_mode(path : String) -> WorkspaceMode {
  let lower = path.to_lower()
  if is_generated_site_path(path) || lower.has_prefix("outputs/") {
    return MoonWiki
  }
  if [
      ".mbt", ".mbtx", ".js", ".mjs", ".ts", ".tsx", ".jsx", ".py", ".rs", ".go",
      ".c", ".h", ".cpp", ".css", ".json", ".toml", ".yaml", ".yml", ".html",
    ].any(suffix => lower.has_suffix(suffix)) &&
    !wiki_living_artifact_path_supported(path) {
    MoonCode
  } else {
    MoonWiki
  }
}

///|
fn open_work_file_action(
  dispatch : Dispatch[Msg],
  model : Model,
  path : String,
) -> (@rabbita.Cmd, Model) {
  if path == "" {
    return (@rabbita.none, model)
  }
  let origin = work_location(model)
  let (path_cmd, selected) = open_quick_path_action(dispatch, path, model)
  let (mode_cmd, opened) = select_workspace_mode_action(
    dispatch,
    work_file_mode(path),
    selected,
  )
  let (source_cmd, ready) = if opened.workspace_mode == MoonCode {
    source_pane_action(dispatch, RequestSource(path), opened)
  } else {
    (@rabbita.none, opened)
  }
  (
    @rabbita.batch([path_cmd, mode_cmd, source_cmd]),
    {
      ..ready,
      work_return: Some(origin),
      wiki_chat_file_paths: if ready.workspace_mode == MoonWiki &&
        !wiki_document_path_supported(path) {
        add_request_material(ready.wiki_chat_file_paths, path)
      } else {
        ready.wiki_chat_file_paths
      },
    },
  )
}

///|
fn return_to_work_action(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  guard model.work_return is Some(origin) else { return (@rabbita.none, model) }
  let (book_cmd, selected) = if origin.workspace_id !=
    model.selected_workspace_id {
    select_workspace_action(dispatch, origin.workspace_id, model)
  } else {
    (@rabbita.none, model)
  }
  guard selected.selected_workspace_id == origin.workspace_id else {
    return (book_cmd, selected)
  }
  let (mode_cmd, opened) = select_workspace_mode_action(dispatch, origin.mode, {
    ..selected,
    selected_path: origin.path,
    current_directory: origin.directory,
  })
  (
    @rabbita.batch([
      book_cmd,
      mode_cmd,
      fetch_entries_cmd(dispatch, origin.workspace_id, origin.directory),
      fetch_preview_cmd(dispatch, origin.workspace_id, origin.path),
      sync_workspace_context_cmd(origin.workspace_id, origin.path),
    ]),
    {
      ..opened,
      current_directory: origin.directory,
      desk_location_input: origin.directory,
      desk_filter_query: origin.filter,
      desk_selected_paths: if origin.path == "" {
        []
      } else {
        [origin.path]
      },
      primary_preview_path: origin.path,
      work_return: None,
    },
  )
}
