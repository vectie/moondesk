///|
fn update_book_runtime_results(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    LoadedBookBaseTypes(Ok(book_base_types)) =>
      (@rabbita.none, { ..model, book_base_types })
    LoadedBookBaseTypes(Err(error)) =>
      (@rabbita.none, { ..model, book_pattern_status: error })
    LoadedBookPatterns(Ok(book_patterns)) => {
      let with_patterns = { ..model, book_patterns }
      let pattern_id = if pattern_matches_base_type(
        with_patterns.selected_book_pattern_id,
        with_patterns.selected_book_base_type,
        book_patterns,
      ) {
        with_patterns.selected_book_pattern_id
      } else {
        first_pattern_for_base_type(
          book_patterns, with_patterns.selected_book_base_type,
        )
      }
      (@rabbita.none, apply_selected_book_pattern(with_patterns, pattern_id))
    }
    LoadedBookPatterns(Err(error)) =>
      (@rabbita.none, { ..model, book_pattern_status: error })
    CreatedBookFromPattern(Ok(result)) =>
      update_created_book_from_pattern(dispatch, model, result)
    CreatedBookFromPattern(Err(error)) =>
      (@rabbita.none, { ..model, book_pattern_status: error })
    ExportedAppToolPortable(Ok(result)) =>
      update_exported_app_tool_portable(dispatch, model, result)
    ExportedAppToolPortable(Err(error)) =>
      (@rabbita.none, { ..model, book_pattern_status: error })
    ExportedAllAppToolPortable(Ok(result)) =>
      update_exported_all_app_tool_portable(dispatch, model, result)
    ExportedAllAppToolPortable(Err(error)) =>
      (@rabbita.none, { ..model, book_pattern_status: error })
    _ => (@rabbita.none, model)
  }
}

///|
fn update_created_book_from_pattern(
  dispatch : Dispatch[Msg],
  model : Model,
  result : BookPatternCreationResult,
) -> (@rabbita.Cmd, Model) {
  let goal_id = json_field_string(result.standing_goal, "id", default="watch")
  let readiness_status = json_field_string(
    result.readiness,
    "status",
    default="ready",
  )
  let output_summary = "; reusable research-book pattern; readiness \{readiness_status}"
  let publish_status = json_field_string(
    result.moontown_publish,
    "status",
    default="published",
  )
  let publish_config = json_field_string(
    result.moontown_publish,
    "config_relative_path",
    default="book-template-config",
  )
  let operator_config = json_field_string(
    result.moontown_publish,
    "operator_config_path",
    default="raw/inbox/pdf-evidence-watch-config.json",
  )
  (
    sync_activity_batch(
      Town,
      @rabbita.batch([
        fetch_workspaces_cmd(dispatch),
        reload_workspace_cmds(dispatch, result.workspace_id, "wiki/index.md"),
        fetch_standing_goals_cmd(dispatch),
        fetch_analytics_cmd(dispatch),
        fetch_town_progress_cmd(dispatch),
        fetch_town_events_cmd(dispatch),
      ]),
    ),
    {
      ..model,
      activity: Town,
      command_open: false,
      selected_workspace_id: result.workspace_id,
      selected_path: "wiki/index.md",
      primary_preview_path: "wiki/index.md",
      current_directory: "",
      preview: None,
      preview_status: "loading published book",
      book_pattern_last_book_id: result.book_id,
      book_pattern_status: "published \{result.book_id}; Moontown \{publish_status} via \{publish_config}; editable config \{operator_config}\{output_summary}; registered standing watch",
      dispatch_status: "created \{goal_id}",
    },
  )
}

///|
fn update_exported_app_tool_portable(
  dispatch : Dispatch[Msg],
  model : Model,
  result : Json,
) -> (@rabbita.Cmd, Model) {
  let book_id = json_field_string(
    result,
    "book_id",
    default=selected_book_id_for_portable_export(model),
  )
  let standalone_ready = json_field_bool(
    result,
    "auto_open_allowed",
    default=json_field_bool(
      result,
      "operatable_without_moondesk_api",
      default=false,
    ),
  )
  let workspace_id = if model.selected_workspace_id.has_prefix("book-") {
    model.selected_workspace_id
  } else {
    @desk.stable_id("book", book_id)
  }
  let command = if standalone_ready {
    @rabbita.batch([
      fetch_workspaces_cmd(dispatch),
      reload_workspace_cmds(
        dispatch,
        workspace_id,
        "portable/app-tool/index.html",
      ),
    ])
  } else {
    fetch_workspaces_cmd(dispatch)
  }
  (
    sync_activity_batch(Town, command),
    {
      ..model,
      activity: Town,
      selected_workspace_id: if standalone_ready {
        workspace_id
      } else {
        model.selected_workspace_id
      },
      selected_path: if standalone_ready {
        "portable/app-tool/index.html"
      } else {
        model.selected_path
      },
      primary_preview_path: if standalone_ready {
        "portable/app-tool/index.html"
      } else {
        model.primary_preview_path
      },
      preview: if standalone_ready { None } else { model.preview },
      preview_status: if standalone_ready {
        "loading portable app-tool bundle"
      } else {
        model.preview_status
      },
      book_pattern_status: app_tool_portable_status_summary(result),
    },
  )
}

///|
fn update_exported_all_app_tool_portable(
  dispatch : Dispatch[Msg],
  model : Model,
  result : Json,
) -> (@rabbita.Cmd, Model) {
  let open_book_id = first_standalone_app_tool_book_id(result)
  let has_open_book = open_book_id != ""
  let workspace_id = if has_open_book {
    @desk.stable_id("book", open_book_id)
  } else {
    model.selected_workspace_id
  }
  let command = if has_open_book {
    @rabbita.batch([
      fetch_workspaces_cmd(dispatch),
      reload_workspace_cmds(
        dispatch,
        workspace_id,
        "portable/app-tool/index.html",
      ),
    ])
  } else {
    fetch_workspaces_cmd(dispatch)
  }
  (
    sync_activity_batch(Town, command),
    {
      ..model,
      activity: Town,
      selected_workspace_id: workspace_id,
      selected_path: if has_open_book {
        "portable/app-tool/index.html"
      } else {
        model.selected_path
      },
      primary_preview_path: if has_open_book {
        "portable/app-tool/index.html"
      } else {
        model.primary_preview_path
      },
      preview: if has_open_book { None } else { model.preview },
      preview_status: if has_open_book {
        "loading portable app-tool bundle"
      } else {
        model.preview_status
      },
      book_pattern_status: app_tool_portable_all_status_summary(result),
    },
  )
}

///|
fn first_standalone_app_tool_book_id(result : Json) -> String {
  for book in json_field_json_array_items(result, "books") {
    if json_field_bool(
      book,
      "auto_open_allowed",
      default=json_field_bool(
        book,
        "operatable_without_moondesk_api",
        default=false,
      ),
    ) {
      let book_id = json_field_string(book, "book_id", default="")
      if book_id != "" {
        return book_id
      }
    }
  }
  ""
}
