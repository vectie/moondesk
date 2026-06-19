///|
fn fetch_workspaces_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/workspaces",
    expect=Json(fn(result) { dispatch(LoadedWorkspaces(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid workspace registry")
      }
    }),
  )
}

///|
fn fetch_entries_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  workspace_id : String,
  path : String,
) -> @rabbita.Cmd {
  @http.get(
    workspace_entries_url(workspace_id, path),
    expect=Json(fn(result) { dispatch(LoadedEntries(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid entry listing")
      }
    }),
  )
}

///|
fn fetch_preview_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  workspace_id : String,
  path : String,
) -> @rabbita.Cmd {
  @http.get(
    workspace_preview_url(workspace_id, path),
    expect=Json(fn(result) { dispatch(LoadedPreview(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Preview is not available")
      }
    }),
  )
}

///|
fn fetch_runs_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  workspace_id : String,
) -> @rabbita.Cmd {
  @http.get(
    "/api/moonclaw/runs?workspace=\{encode_component(workspace_id)}",
    expect=Json(fn(result) { dispatch(LoadedRuns(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonClaw run listing")
      }
    }),
  )
}

///|
fn fetch_messages_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/town/messages",
    expect=Json(fn(result) { dispatch(LoadedTownMessages(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid town message stream")
      }
    }),
  )
}

///|
fn fetch_requests_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/town/requests",
    expect=Json(fn(result) { dispatch(LoadedRequests(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid request ledger")
      }
    }),
  )
}

///|
fn fetch_standing_goals_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/town/standing-goals",
    expect=Json(fn(result) { dispatch(LoadedStandingGoals(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid standing goal registry")
      }
    }),
  )
}

///|
fn fetch_analytics_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/town/analytics",
    expect=Json(fn(result) { dispatch(LoadedAnalytics(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid town analytics")
      }
    }),
  )
}

///|
fn fetch_town_progress_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/town/progress",
    expect=Json(fn(result) { dispatch(LoadedTownProgress(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid town progress")
      }
    }),
  )
}

///|
fn fetch_moonclaw_progress_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  workspace_id : String,
) -> @rabbita.Cmd {
  @http.get(
    "/api/moonclaw/progress?workspace=\{encode_component(workspace_id)}",
    expect=Json(fn(result) { dispatch(LoadedMoonclawProgress(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonClaw progress")
      }
    }),
  )
}

///|
fn fetch_events_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  workspace_id : String,
) -> @rabbita.Cmd {
  @http.get(
    "/api/moonclaw/events?workspace=\{encode_component(workspace_id)}",
    expect=Json(fn(result) { dispatch(LoadedEvents(result)) }, json => {
      let events : Array[DeskEvent] = @json.from_json(json) catch {
        _ => return Err("Invalid event stream")
      }
      Ok(events)
    }),
  )
}

///|
fn fetch_town_events_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/town/events",
    expect=Json(fn(result) { dispatch(LoadedEvents(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid town event stream")
      }
    }),
  )
}

///|
fn fetch_review_items_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  workspace_id : String,
) -> @rabbita.Cmd {
  @http.get(
    "/api/review/items?workspace=\{encode_component(workspace_id)}",
    expect=Json(fn(result) { dispatch(LoadedReviewItems(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid review queue")
      }
    }),
  )
}

///|
fn fetch_review_diff_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  workspace_id : String,
  path : String,
) -> @rabbita.Cmd {
  @http.get(
    "/api/workspaces/\{workspace_id}/review-diff?path=\{encode_component(path)}",
    expect=Json(fn(result) { dispatch(LoadedReviewDiff(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid review diff")
      }
    }),
  )
}

///|
fn fetch_saved_views_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/preferences/views",
    expect=Json(fn(result) { dispatch(LoadedSavedViews(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid saved views")
      }
    }),
  )
}

///|
fn fetch_tags_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/preferences/tags",
    expect=Json(fn(result) { dispatch(LoadedTags(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid tags")
      }
    }),
  )
}

///|
fn fetch_daemon_lifecycle_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/town/daemon/status",
    expect=Json(fn(result) { dispatch(LoadedDaemonLifecycle(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid daemon lifecycle status")
      }
    }),
  )
}

///|
fn fetch_launch_agent_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/town/daemon/launch-agent",
    expect=Json(fn(result) { dispatch(LoadedLaunchAgent(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid LaunchAgent status")
      }
    }),
  )
}

///|
fn fetch_search_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  query : String,
) -> @rabbita.Cmd {
  @http.get(
    "/api/search?query=\{encode_component(query)}",
    expect=Json(fn(result) { dispatch(LoadedSearch(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid search results")
      }
    }),
  )
}

///|
fn fetch_book_patterns_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/books/patterns",
    expect=Json(fn(result) { dispatch(LoadedBookPatterns(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid book pattern catalog")
      }
    }),
  )
}

///|
fn fetch_book_base_types_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/books/base-types",
    expect=Json(fn(result) { dispatch(LoadedBookBaseTypes(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid book base-type catalog")
      }
    }),
  )
}
