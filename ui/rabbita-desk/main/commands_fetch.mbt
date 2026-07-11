///|
fn fetch_workspaces_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @http.get(@desk.workspaces_url()).expect_json(result => {
    dispatch(
      LoadedWorkspaces(http_result(result, "Invalid workspace registry")),
    )
  })
}

///|
fn fetch_workspace_metadata_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @http.get(@desk.workspace_metadata_url()).expect_json(result => {
    dispatch(
      LoadedWorkspaceMetadata(http_result(result, "Invalid workspace metadata")),
    )
  })
}

///|
fn fetch_entries_cmd(
  dispatch : Dispatch[Msg],
  workspace_id : String,
  path : String,
) -> @rabbita.Cmd {
  @http.get(workspace_entries_url(workspace_id, path)).expect_json(result => {
    dispatch(LoadedEntries(http_result(result, "Invalid entry listing")))
  })
}

///|
fn fetch_preview_cmd(
  dispatch : Dispatch[Msg],
  workspace_id : String,
  path : String,
) -> @rabbita.Cmd {
  @http.get(workspace_preview_url(workspace_id, path)).expect_json(result => {
    dispatch(LoadedPreview(http_result(result, "Preview is not available")))
  })
}

///|
fn fetch_desk_trash_cmd(
  dispatch : Dispatch[Msg],
  workspace_id : String,
) -> @rabbita.Cmd {
  @http.get(@desk.workspace_endpoint_url(workspace_id, "trash")).expect_json(result => {
    dispatch(LoadedDeskTrash(http_result(result, "Invalid Desk trash listing")))
  })
}

///|
fn fetch_runs_cmd(
  dispatch : Dispatch[Msg],
  workspace_id : String,
) -> @rabbita.Cmd {
  @http.get(@desk.moonclaw_workspace_url("runs", workspace_id)).expect_json(result => {
    dispatch(LoadedRuns(http_result(result, "Invalid MoonClaw run listing")))
  })
}

///|
fn fetch_moonflow_runs_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @http.get("/api/moonflow/runs").expect_json(result => {
    dispatch(
      LoadedMoonFlowRuns(http_result(result, "Invalid MoonFlow run listing")),
    )
  })
}

///|
fn fetch_messages_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @http.get(@desk.town_endpoint_url("messages")).expect_json(result => {
    dispatch(
      LoadedTownMessages(http_result(result, "Invalid town message stream")),
    )
  })
}

///|
fn fetch_requests_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @http.get(@desk.town_endpoint_url("requests")).expect_json(result => {
    dispatch(LoadedRequests(http_result(result, "Invalid request ledger")))
  })
}

///|
fn fetch_standing_goals_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @http.get(@desk.town_endpoint_url("standing-goals")).expect_json(result => {
    dispatch(
      LoadedStandingGoals(http_result(result, "Invalid standing goal registry")),
    )
  })
}

///|
fn fetch_analytics_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @http.get(@desk.town_endpoint_url("analytics")).expect_json(result => {
    dispatch(LoadedAnalytics(http_result(result, "Invalid town analytics")))
  })
}

///|
fn fetch_town_progress_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @http.get(@desk.town_endpoint_url("progress")).expect_json(result => {
    dispatch(LoadedTownProgress(http_result(result, "Invalid town progress")))
  })
}

///|
fn fetch_moonclaw_progress_cmd(
  dispatch : Dispatch[Msg],
  workspace_id : String,
) -> @rabbita.Cmd {
  @http.get(@desk.moonclaw_workspace_url("progress", workspace_id)).expect_json(result => {
      dispatch(
        LoadedMoonclawProgress(http_result(result, "Invalid MoonClaw progress")),
      )
    },
  )
}

///|
fn fetch_events_cmd(
  dispatch : Dispatch[Msg],
  workspace_id : String,
) -> @rabbita.Cmd {
  @http.get(@desk.moonclaw_workspace_url("events", workspace_id)).expect_json(result => {
    dispatch(LoadedEvents(http_result(result, "Invalid event stream")))
  })
}

///|
fn fetch_town_events_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @http.get(@desk.town_endpoint_url("events")).expect_json(result => {
    dispatch(LoadedEvents(http_result(result, "Invalid town event stream")))
  })
}

///|
fn fetch_review_items_cmd(
  dispatch : Dispatch[Msg],
  workspace_id : String,
) -> @rabbita.Cmd {
  @http.get(@desk.review_items_url(workspace_id)).expect_json(result => {
    dispatch(LoadedReviewItems(http_result(result, "Invalid review queue")))
  })
}

///|
fn fetch_saved_views_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @http.get(@desk.preferences_views_url()).expect_json(result => {
    dispatch(LoadedSavedViews(http_result(result, "Invalid saved views")))
  })
}

///|
fn fetch_daemon_lifecycle_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @http.get(@desk.town_endpoint_url("daemon/status")).expect_json(result => {
    dispatch(
      LoadedDaemonLifecycle(
        http_result(result, "Invalid daemon lifecycle status"),
      ),
    )
  })
}

///|
fn fetch_launch_agent_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @http.get(@desk.town_endpoint_url("daemon/launch-agent")).expect_json(result => {
    dispatch(
      LoadedLaunchAgent(http_result(result, "Invalid LaunchAgent status")),
    )
  })
}

///|
fn fetch_search_cmd(dispatch : Dispatch[Msg], query : String) -> @rabbita.Cmd {
  @http.get(@desk.search_url(query)).expect_json(result => {
    dispatch(LoadedSearch(http_result(result, "Invalid search results")))
  })
}

///|
fn fetch_book_patterns_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @http.get(@desk.books_endpoint_url("patterns")).expect_json(result => {
    dispatch(
      LoadedBookPatterns(http_result(result, "Invalid book pattern catalog")),
    )
  })
}

///|
fn fetch_book_base_types_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @http.get(@desk.books_endpoint_url("base-types")).expect_json(result => {
    dispatch(
      LoadedBookBaseTypes(http_result(result, "Invalid book base-type catalog")),
    )
  })
}
