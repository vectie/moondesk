///|
fn reload_workspace_cmds(
  dispatch : (Msg) -> @rabbita.Cmd,
  workspace_id : String,
  selected_path : String,
) -> @rabbita.Cmd {
  if workspace_id == "" {
    @rabbita.none
  } else {
    @rabbita.batch([
      fetch_entries_cmd(dispatch, workspace_id, ""),
      fetch_preview_cmd(dispatch, workspace_id, selected_path),
      fetch_runs_cmd(dispatch, workspace_id),
      fetch_moonclaw_progress_cmd(dispatch, workspace_id),
      fetch_messages_cmd(dispatch),
      fetch_requests_cmd(dispatch),
      fetch_standing_goals_cmd(dispatch),
      fetch_analytics_cmd(dispatch),
      fetch_town_progress_cmd(dispatch),
      fetch_town_events_cmd(dispatch),
      fetch_daemon_lifecycle_cmd(dispatch),
      fetch_launch_agent_cmd(dispatch),
      fetch_moonclaw_daemon_cmd(dispatch),
      fetch_moonclaw_models_cmd(dispatch),
      fetch_mooncode_sessions_cmd(dispatch, workspace_id),
      fetch_review_items_cmd(dispatch, workspace_id),
      fetch_saved_views_cmd(dispatch),
      fetch_book_base_types_cmd(dispatch),
      fetch_book_patterns_cmd(dispatch),
    ])
  }
}
