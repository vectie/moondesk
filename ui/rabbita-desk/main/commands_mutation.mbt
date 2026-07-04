///|
fn save_inbox_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
  title : String,
  content : String,
) -> @rabbita.Cmd {
  let body : Json = if model.editing_inbox_path == "" {
    { "title": title, "content": content }
  } else {
    { "title": title, "content": content, "path": model.editing_inbox_path }
  }
  @http.post(@desk.workspace_endpoint_url(model.selected_workspace_id, "inbox"))
  .with_json(body)
  .expect_json(result => {
    dispatch(SavedInbox(http_result(result, "Could not save inbox note")))
  })
}

///|
fn save_markdown_cmd(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Cmd {
  let body : Json = {
    "path": model.markdown_editor_path,
    "content": model.markdown_editor_content,
  }
  @http.post(@desk.workspace_endpoint_url(model.selected_workspace_id, "markdown"))
  .with_json(body)
  .expect_json(result => {
    dispatch(
      SavedMarkdownEdit(http_result(result, "Could not save markdown document")),
    )
  })
}

///|
fn create_desk_entry_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
  kind : String,
) -> @rabbita.Cmd {
  let body : Json = {
    "kind": kind,
    "directory": model.current_directory,
    "name": model.desk_new_item_name,
  }
  @http.post(@desk.workspace_endpoint_url(model.selected_workspace_id, "entries"))
  .with_json(body)
  .expect_json(result => {
    dispatch(
      CreatedDeskEntry(http_result(result, "Could not create Desk item")),
    )
  })
}

///|
fn rename_desk_entry_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Cmd {
  let body : Json = {
    "path": model.selected_path,
    "name": model.desk_rename_name,
  }
  @http.post(@desk.workspace_endpoint_url(model.selected_workspace_id, "rename"))
  .with_json(body)
  .expect_json(result => {
    dispatch(
      RenamedDeskEntry(http_result(result, "Could not rename Desk item")),
    )
  })
}

///|
fn move_desk_entry_cmd(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Cmd {
  let paths = if model.desk_selected_paths.length() == 0 {
    if model.selected_path == "" {
      []
    } else {
      [model.selected_path]
    }
  } else {
    model.desk_selected_paths
  }
  let body : Json = {
    "paths": string_array_json(paths),
    "directory": model.desk_move_target_directory,
  }
  @http.post(@desk.workspace_endpoint_url(model.selected_workspace_id, "move"))
  .with_json(body)
  .expect_json(result => {
    dispatch(MovedDeskEntry(http_result(result, "Could not move Desk item")))
  })
}

///|
fn copy_desk_entry_cmd(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Cmd {
  let paths = if model.desk_selected_paths.length() == 0 {
    if model.selected_path == "" {
      []
    } else {
      [model.selected_path]
    }
  } else {
    model.desk_selected_paths
  }
  let body : Json = { "paths": string_array_json(paths) }
  @http.post(@desk.workspace_endpoint_url(model.selected_workspace_id, "copy"))
  .with_json(body)
  .expect_json(result => {
    dispatch(
      CopiedDeskEntry(http_result(result, "Could not duplicate Desk item")),
    )
  })
}

///|
fn paste_desk_clipboard_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Cmd {
  let body : Json = {
    "paths": string_array_json(model.desk_clipboard_paths),
    "directory": model.current_directory,
  }
  @http.post(@desk.workspace_endpoint_url(model.selected_workspace_id, "copy"))
  .with_json(body)
  .expect_json(result => {
    dispatch(CopiedDeskEntry(http_result(result, "Could not paste Desk item")))
  })
}

///|
fn paste_desk_cut_cmd(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Cmd {
  let body : Json = {
    "paths": string_array_json(model.desk_clipboard_paths),
    "directory": model.current_directory,
  }
  @http.post(@desk.workspace_endpoint_url(model.selected_workspace_id, "move"))
  .with_json(body)
  .expect_json(result => {
    dispatch(
      MovedDeskEntry(http_result(result, "Could not move pasted Desk item")),
    )
  })
}

///|
fn trash_desk_entry_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Cmd {
  let paths = if model.desk_selected_paths.length() == 0 {
    if model.selected_path == "" {
      []
    } else {
      [model.selected_path]
    }
  } else {
    model.desk_selected_paths
  }
  let body : Json = { "paths": string_array_json(paths) }
  @http.post(@desk.workspace_endpoint_url(model.selected_workspace_id, "trash"))
  .with_json(body)
  .expect_json(result => {
    dispatch(
      TrashedDeskEntry(http_result(result, "Could not move Desk item to trash")),
    )
  })
}

///|
fn import_desk_local_files_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
  files : Array[LocalImportFile],
) -> @rabbita.Cmd {
  let file_items : Array[Json] = []
  for file in files {
    let is_data_url = file.content.has_prefix("data:")
    file_items.push({
      "filename": file.name,
      "relative_path": match file.relative_path {
        Some(path) => path
        None => ""
      },
      "browser_import_id": file.id,
      "content_type": file.media_type,
      "source": file.source,
      "content": if is_data_url {
        ""
      } else {
        file.content
      },
      "data_url": if is_data_url {
        file.content
      } else {
        ""
      },
    })
  }
  let body : Json = {
    "directory": model.current_directory,
    "files": Json::array(file_items),
  }
  @http.post(
    @desk.workspace_endpoint_url(model.selected_workspace_id, "entries/import"),
  )
  .with_json(body)
  .expect_json(result => {
    dispatch(
      ImportedDeskFiles(http_result(result, "Could not import files into Desk")),
    )
  })
}

///|
fn string_array_json(items : Array[String]) -> Json {
  let values : Array[Json] = []
  for item in items {
    values.push(item.to_json())
  }
  Json::array(values)
}

///|
fn restore_desk_entry_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Cmd {
  restore_desk_trash_path_cmd(dispatch, model, model.desk_last_trash_path)
}

///|
fn restore_desk_trash_path_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
  trash_path : String,
) -> @rabbita.Cmd {
  let body : Json = { "trash_path": trash_path }
  @http.post(@desk.workspace_endpoint_url(model.selected_workspace_id, "restore"))
  .with_json(body)
  .expect_json(result => {
    dispatch(
      RestoredDeskEntry(http_result(result, "Could not restore Desk item")),
    )
  })
}

///|
fn import_url_cmd(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Cmd {
  let url = model.import_url.trim().to_owned()
  let title = if url == "" { "Imported URL" } else { url }
  let body : Json = {
    "kind": "url",
    "title": title,
    "url": url,
    "note": model.import_note,
  }
  @http.post(@desk.workspace_endpoint_url(model.selected_workspace_id, "import"))
  .with_json(body)
  .expect_json(result => {
    dispatch(ImportedInbox(http_result(result, "Could not import URL")))
  })
}

///|
fn import_local_file_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
  file : LocalImportFile,
) -> @rabbita.Cmd {
  let is_data_url = file.content.has_prefix("data:")
  let body : Json = {
    "kind": if file.source == "paste" {
      "paste"
    } else {
      "file"
    },
    "title": file.name,
    "filename": file.name,
    "browser_import_id": file.id,
    "content_type": file.media_type,
    "note": model.import_note,
    "content": if is_data_url {
      ""
    } else {
      file.content
    },
    "data_url": if is_data_url {
      file.content
    } else {
      ""
    },
  }
  @http.post(@desk.workspace_endpoint_url(model.selected_workspace_id, "import"))
  .with_json(body)
  .expect_json(result => {
    dispatch(ImportedInbox(http_result(result, "Could not import local file")))
  })
}

///|
fn save_view_cmd(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Cmd {
  let body : Json = {
    "title": trimmed_or(model.view_title, "Current view"),
    "query": model.search_query,
    "workspace_id": model.selected_workspace_id,
    "path": model.selected_path,
  }
  @http.post(@desk.preferences_views_url())
  .with_json(body)
  .expect_json(result => {
    dispatch(SavedView(http_result(result, "Could not save view")))
  })
}

///|
fn create_blank_moonbook_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Cmd {
  let body : Json = {
    "name": model.new_book_name,
    "book_id": model.new_book_id,
  }
  @http.post(@desk.workspaces_url())
  .with_json(body)
  .expect_json(result => {
    dispatch(
      CreatedBlankMoonBook(http_result(result, "Could not create MoonBook")),
    )
  })
}

///|
fn import_moonbook_cmd(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Cmd {
  let body : Json = { "source_path": model.import_book_path }
  @http.post(@desk.workspace_import_url())
  .with_json(body)
  .expect_json(result => {
    dispatch(ImportedMoonBook(http_result(result, "Could not import MoonBook")))
  })
}

///|
fn import_moonbook_archive_cmd(
  dispatch : Dispatch[Msg],
  file : LocalImportFile,
) -> @rabbita.Cmd {
  let body : Json = {
    "filename": file.name,
    "browser_import_id": file.id,
    "content_type": file.media_type,
    "data_url": file.content,
  }
  @http.post(@desk.workspace_import_url())
  .with_json(body)
  .expect_json(result => {
    dispatch(
      ImportedMoonBook(http_result(result, "Could not import MoonBook archive")),
    )
  })
}

///|
fn import_moonbook_folder_cmd(
  dispatch : Dispatch[Msg],
  files : Array[LocalImportFile],
) -> @rabbita.Cmd {
  let file_items : Array[Json] = []
  for file in files {
    let is_data_url = file.content.has_prefix("data:")
    file_items.push({
      "filename": file.name,
      "relative_path": match file.relative_path {
        Some(path) => path
        None => ""
      },
      "browser_import_id": file.id,
      "content_type": file.media_type,
      "source": file.source,
      "content": if is_data_url {
        ""
      } else {
        file.content
      },
      "data_url": if is_data_url {
        file.content
      } else {
        ""
      },
    })
  }
  let body : Json = { "files": Json::array(file_items) }
  @http.post(@desk.workspace_import_url())
  .with_json(body)
  .expect_json(result => {
    dispatch(
      ImportedMoonBook(http_result(result, "Could not import MoonBook folder")),
    )
  })
}

///|
fn decide_review_item_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
  item : ReviewItem,
  decision : String,
) -> @rabbita.Cmd {
  let body : Json = {
    "workspace_id": item.workspace_id,
    "path": item.path,
    "decision": decision,
    "note": model.review_decision_note,
  }
  @http.post(@desk.review_decision_url())
  .with_json(body)
  .expect_json(result => {
    dispatch(
      DecidedReviewItem(http_result(result, "Could not record review decision")),
    )
  })
}

///|
fn submit_request_cmd(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Cmd {
  let title = "Moondesk request for \{workspace_name(model)}"
  let context_entries = if model.selected_path == "" {
    []
  } else {
    [model.selected_path]
  }
  let body : Json = {
    "title": title,
    "prompt": trimmed_or(model.request_prompt, "Review the selected context."),
    "target_book_id": model.selected_workspace_id,
    "context_entries": json_string_array(context_entries),
    "cadence": "one-shot",
    "review_policy": "bookkeeper_review",
    "source_policy": "mixed",
  }
  @http.post(@desk.town_endpoint_url("requests"))
  .with_json(body)
  .expect_json(result => {
    dispatch(SubmittedRequest(http_result(result, "Could not stage request")))
  })
}

///|
fn create_standing_goal_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Cmd {
  let title = trimmed_or(model.goal_title, "Standing watch")
  let cadence = clamp_int(int_text(model.goal_cadence_ticks, 60), 1, 525600)
  let body : Json = {
    "title": title,
    "prompt": trimmed_or(
      model.request_prompt,
      "Watch the selected MoonBook context for useful updates.",
    ),
    "target_book_id": model.selected_workspace_id,
    "cadence_ticks": cadence,
    "source_policy": trimmed_or(model.goal_source_policy, "web-first"),
    "review_policy": trimmed_or(model.goal_review_policy, "bookkeeper_review"),
    "enabled": true,
  }
  @http.post(@desk.town_endpoint_url("standing-goals"))
  .with_json(body)
  .expect_json(result => {
    dispatch(
      CreatedStandingGoal(
        http_result(result, "Could not create standing watch"),
      ),
    )
  })
}
