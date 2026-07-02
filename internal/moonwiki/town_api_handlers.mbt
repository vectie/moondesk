///|
async fn handle_town_analytics(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let root = workspace_context(workspace_root).suite_root
  let repair = sync_all_book_pattern_standing_goals(root) catch {
    _ => Json::object({})
  }
  let daemon = read_json_file_or_object(town_daemon_path(root))
  let daemon_tick = json_int(daemon, "tick_sequence", default=0)
  let goals = read_json_array_file(town_standing_goals_path(root))
  let watcher_records = read_watcher_records(root, 400)
  let events = collect_town_event_records(root, 160)
  let request_count = count_matching_files(
    town_moondesk_requests_root(root),
    ".json",
  )
  let message_count = count_matching_files(
    @pathx.join(moontown_product_root(root), "book-results"),
    ".json",
  )
  let run_count = count_run_workspaces(root)
  let active_goal_count = json_string_array_len(daemon, "active_goal_ids")
  send_json(conn, method_, {
    "daemon_tick": daemon_tick,
    "standing_goal_count": goals.length(),
    "due_goal_count": count_due_goals(goals, daemon_tick),
    "active_goal_count": active_goal_count,
    "request_count": request_count,
    "message_count": message_count,
    "run_count": run_count,
    "watcher_run_count": watcher_records.length(),
    "updates": count_watcher_decision(watcher_records, "Update"),
    "no_changes": count_watcher_decision(watcher_records, "NoChange"),
    "needs_review": count_watcher_decision(watcher_records, "NeedsReview"),
    "failures": count_watcher_decision(watcher_records, "Failed"),
    "deferred": count_watcher_decision(watcher_records, "Deferred"),
    "event_count": events.length(),
    "failure_event_count": count_event_severity(events, "failure"),
    "review_event_count": count_event_severity(events, "review"),
    "last_failure": latest_event_title(events, "failure"),
    "review_item_count": count_review_items(root),
    "next_due_tick": next_due_tick(goals),
    "moondesk_standing_goal_repair": repair,
  })
}

///|
async fn handle_town_progress(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let root = workspace_context(workspace_root).suite_root
  let repair = sync_all_book_pattern_standing_goals(root) catch {
    _ => Json::object({})
  }
  let daemon = read_json_file_or_object(town_daemon_path(root))
  let lifecycle = daemon_status_record(root, "progress")
  let goals = read_json_array_file(town_standing_goals_path(root))
  let daemon_tick = json_int(daemon, "tick_sequence", default=0)
  let dispatch_root = town_moondesk_dispatches_root(root)
  let request_root = town_moondesk_requests_root(root)
  let message_root = @pathx.join(moontown_product_root(root), "book-results")
  let latest_run = latest_run_info(root)
  send_json(conn, method_, {
    "daemon_tick": daemon_tick,
    "daemon_running": json_bool(lifecycle, "running", default=false),
    "daemon_status": json_string(lifecycle, "status", default="unknown"),
    "supervision_enabled": json_bool(
      lifecycle,
      "supervision_enabled",
      default=false,
    ),
    "due_goal_count": count_due_goals(goals, daemon_tick),
    "next_due_tick": next_due_tick(goals),
    "request_count": count_matching_files(request_root, ".json"),
    "message_count": count_matching_files(message_root, ".json"),
    "dispatch_count": count_matching_files(dispatch_root, ".json"),
    "run_count": count_run_workspaces(root),
    "latest_request": latest_matching_name(request_root, ".json"),
    "latest_message": latest_matching_name(message_root, ".json"),
    "latest_dispatch": latest_matching_name(dispatch_root, ".json"),
    "latest_run": json_string(latest_run, "run_id", default=""),
    "latest_run_status": json_string(latest_run, "status", default=""),
    "latest_run_artifacts": json_int(latest_run, "artifact_count", default=0),
    "moondesk_standing_goal_repair": repair,
  })
}

///|
async fn handle_town_calendar(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let root = workspace_context(workspace_root).suite_root
  ignore(
    sync_all_book_pattern_standing_goals(root) catch {
      _ => Json::object({})
    },
  )
  let daemon = read_json_file_or_object(town_daemon_path(root))
  let daemon_tick = json_int(daemon, "tick_sequence", default=0)
  let goals = read_json_array_file(town_standing_goals_path(root))
  let mut body = "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Vectie//Moondesk//EN\r\n"
  for goal in goals {
    if !json_bool(goal, "enabled", default=true) {
      continue
    }
    let id = json_string(
      goal,
      "id",
      default=@desk.stable_id(
        "watch",
        json_string(goal, "title", default="watch"),
      ),
    )
    let title = json_string(goal, "title", default="Moondesk watch")
    let next_due = json_int(goal, "next_due_tick", default=0)
    let delta = next_due - daemon_tick
    body = body +
      "BEGIN:VTODO\r\n" +
      "UID:\{ics_escape(id)}@moondesk\r\n" +
      "SUMMARY:\{ics_escape(title)}\r\n" +
      "STATUS:NEEDS-ACTION\r\n" +
      "DESCRIPTION:\{ics_escape("Next due tick \{next_due}; current daemon tick \{daemon_tick}; delta \{delta}.")}\r\n" +
      "END:VTODO\r\n"
  }
  body = body + "END:VCALENDAR\r\n"
  send_text(conn, method_, "text/calendar; charset=utf-8", body)
}
