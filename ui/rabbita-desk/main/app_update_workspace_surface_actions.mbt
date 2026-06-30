///|
fn update_workspace_surface_actions(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    SetSearchQuery(query) =>
      (@rabbita.none, { ..model, search_query: query, search_status: "draft" })
    SearchNow => search_now_action(dispatch, model)
    ToggleFavorite(path) =>
      (
        @rabbita.none,
        { ..model, favorites: toggle_string(model.favorites, path) },
      )
    SetViewTitle(title) => (@rabbita.none, { ..model, view_title: title })
    SaveCurrentView =>
      (save_view_cmd(dispatch, model), { ..model, host_status: "saving view" })
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
          "Moondesk daily surface",
          "\{model.requests.length()} requests, \{model.runs.length()} runs, \{model.standing_goals.length()} standing goals",
        ),
        { ..model, notification_status: "notification requested" },
      )
    RefreshAll =>
      (refresh_all_cmd(dispatch, model), { ..model, host_status: "refreshing" })
    _ => (@rabbita.none, model)
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
    fetch_workspaces_cmd(dispatch),
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
    fetch_mooncode_sessions_cmd(dispatch, model.selected_workspace_id),
    fetch_review_items_cmd(dispatch, model.selected_workspace_id),
    fetch_saved_views_cmd(dispatch),
    fetch_book_patterns_cmd(dispatch),
  ])
}
