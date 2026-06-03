///|
async fn handle_town_analytics(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let root = @pathx.normalize(workspace_root)
  let repair = sync_all_pdf_watch_standing_goals(root) catch {
    _ => Json::object({})
  }
  let daemon = read_json_file_or_object(town_daemon_path(root))
  let daemon_tick = json_int(daemon, "tick_sequence", default=0)
  let goals = read_json_array_file(town_standing_goals_path(root))
  let watcher_records = read_watcher_records(root, 400)
  let events = collect_town_event_records(root, 160)
  let request_count = count_matching_files(
    @pathx.join(root, ".moontown/moondesk-requests"),
    ".json",
  )
  let message_count = count_matching_files(
    @pathx.join(root, ".moontown/book-results"),
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
  let root = @pathx.normalize(workspace_root)
  let repair = sync_all_pdf_watch_standing_goals(root) catch {
    _ => Json::object({})
  }
  let daemon = read_json_file_or_object(town_daemon_path(root))
  let lifecycle = daemon_status_record(root, "progress")
  let goals = read_json_array_file(town_standing_goals_path(root))
  let daemon_tick = json_int(daemon, "tick_sequence", default=0)
  let dispatch_root = @pathx.join(root, ".moontown/moondesk-dispatches")
  let request_root = @pathx.join(root, ".moontown/moondesk-requests")
  let message_root = @pathx.join(root, ".moontown/book-results")
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
async fn handle_moonclaw_progress(
  workspace_root : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let requested_workspace = query_value(request_path, "workspace")
  let summary = moonclaw_progress_summary(workspace_root, requested_workspace)
  send_json(conn, method_, summary)
}

///|
async fn handle_town_calendar(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let root = @pathx.normalize(workspace_root)
  ignore(
    sync_all_pdf_watch_standing_goals(root) catch {
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

///|
async fn handle_saved_views(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  send_json(
    conn,
    method_,
    Json::array(read_json_array_file(saved_views_path(workspace_root))),
  )
}

///|
async fn handle_save_view(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = match read_json_body(body) {
    Some(json) => json
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  let title = json_string(payload, "title", default="Saved view")
  let id = json_string(payload, "id", default=@desk.stable_id("view", title))
  let record : Json = {
    "id": id,
    "title": title,
    "query": json_string(payload, "query", default=""),
    "workspace_id": json_string(payload, "workspace_id", default=""),
    "path": json_string(payload, "path", default=""),
    "created_at": json_string(
      payload,
      "created_at",
      default=@async.now().to_string(),
    ),
    "updated_at": @async.now().to_string(),
  }
  let path = saved_views_path(workspace_root)
  write_preference_records(
    path,
    upsert_record_by_id(read_json_array_file(path), record),
  ) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not save view",
      )
      return
    }
  }
  send_json(conn, method_, record)
}

///|
async fn handle_tags(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  send_json(
    conn,
    method_,
    Json::array(read_json_array_file(tags_path(workspace_root))),
  )
}

///|
async fn handle_save_tag(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = match read_json_body(body) {
    Some(json) => json
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  let workspace_id = json_string(payload, "workspace_id", default="")
  let path_value = json_string(payload, "path", default="")
  let tag = json_string(payload, "tag", default="")
  if workspace_id == "" || path_value == "" || tag == "" {
    send_api_error(
      conn, method_, 400, "Bad Request", "workspace_id, path, and tag are required",
    )
    return
  }
  let record : Json = {
    "id": @desk.stable_id("tag", workspace_id + ":" + path_value + ":" + tag),
    "workspace_id": workspace_id,
    "path": path_value,
    "tag": tag,
    "created_at": @async.now().to_string(),
  }
  let path = tags_path(workspace_root)
  write_preference_records(
    path,
    upsert_record_by_id(read_json_array_file(path), record),
  ) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not save tag",
      )
      return
    }
  }
  send_json(conn, method_, record)
}

///|
async fn handle_town_messages(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let results_root = @pathx.join(
    @pathx.normalize(workspace_root),
    ".moontown/book-results",
  )
  let messages : Array[Json] = []
  let names = read_directory_names(results_root, include_hidden=false)
  let start = if names.length() > 40 { names.length() - 40 } else { 0 }
  for index = start; index < names.length(); index = index + 1 {
    let name = names[index]
    if !name.has_suffix(".json") {
      continue
    }
    messages.push({
      "id": @desk.stable_id("message", name),
      "path": "book-results/" + name,
      "title": name,
      "kind": "book-result",
    })
  }
  send_json(conn, method_, Json::array(messages))
}

///|
async fn handle_town_requests(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let requests_root = @pathx.join(
    @pathx.normalize(workspace_root),
    ".moontown/moondesk-requests",
  )
  let requests : Array[Json] = []
  let names = read_directory_names(requests_root, include_hidden=false)
  let start = if names.length() > 80 { names.length() - 80 } else { 0 }
  for index = start; index < names.length(); index = index + 1 {
    let name = names[index]
    if !name.has_suffix(".json") {
      continue
    }
    let absolute = @pathx.join(requests_root, name)
    let record = @json.parse(@fs.read_file(absolute).text()) catch {
      _ => {
        let fallback : Json = {
          "id": @desk.stable_id("request", name),
          "status": "unreadable",
          "path": ".moontown/moondesk-requests/" + name,
          "request": { "title": name },
        }
        fallback
      }
    }
    requests.push(town_request_listing_record(record, name))
  }
  send_json(conn, method_, Json::array(requests))
}

///|
fn town_request_listing_record(record : Json, name : String) -> Json {
  let path = json_string(
    record,
    "path",
    default=".moontown/moondesk-requests/" + name,
  )
  let request = match record {
    Json::Object(object) =>
      match object.get("request") {
        Some(value) =>
          town_request_payload_from_existing_request(value, record, name)
        None => town_request_payload_from_record(record, name)
      }
    _ => town_request_payload_from_record(record, name)
  }
  {
    "id": json_string(record, "id", default=@desk.stable_id("request", name)),
    "status": json_string(record, "status", default="staged"),
    "path": path,
    "request": request,
    "kind": json_string(record, "kind", default="moondesk-request"),
    "book_id": json_string(record, "book_id", default=""),
  }
}

///|
fn town_request_payload_from_existing_request(
  request : Json,
  record : Json,
  name : String,
) -> Json {
  {
    "title": json_first_string(
      request,
      ["title", "summary", "book_id", "id"],
      default=json_first_string(
        record,
        ["title", "summary", "book_id", "id"],
        default=name,
      ),
    ),
    "prompt": json_first_string(
      request,
      ["prompt", "purpose", "summary", "body"],
      default=json_first_string(
        record,
        ["prompt", "purpose", "summary"],
        default="",
      ),
    ),
    "kind": json_string(
      request,
      "kind",
      default=json_string(record, "kind", default="moondesk-request"),
    ),
    "book_id": json_string(
      request,
      "book_id",
      default=json_string(record, "book_id", default=""),
    ),
    "pattern_id": json_string(
      request,
      "pattern_id",
      default=json_string(record, "pattern_id", default=""),
    ),
  }
}

///|
fn town_request_payload_from_record(record : Json, name : String) -> Json {
  let title = json_first_string(
    record,
    ["title", "summary", "book_id", "id"],
    default=name,
  )
  {
    "title": title,
    "prompt": json_first_string(
      record,
      ["prompt", "purpose", "summary"],
      default="",
    ),
    "kind": json_string(record, "kind", default="moondesk-request"),
    "book_id": json_string(record, "book_id", default=""),
    "pattern_id": json_string(record, "pattern_id", default=""),
  }
}

///|
async fn handle_town_request(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = match read_json_body(body) {
    Some(json) => json
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  let root = @pathx.normalize(workspace_root)
  let requests_root = @pathx.join(root, ".moontown/moondesk-requests")
  @fsx.make_directory(requests_root, recursive=true, exists_ok=true) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not create request ledger",
      )
      return
    }
  }
  let title = json_string(payload, "title", default="Moondesk request")
  let id = @desk.stable_id("request", title + "-" + @async.now().to_string())
  let relative = ".moontown/moondesk-requests/" + id + ".json"
  let absolute = @pathx.join(root, relative)
  let record : Json = {
    "id": id,
    "status": "staged",
    "path": relative,
    "request": payload,
  }
  @fsx.write_to_file(absolute, record.stringify(indent=2) + "\n", create=0o644) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not write request",
      )
      return
    }
  }
  send_json(conn, method_, record)
}

///|
async fn handle_moonclaw_runs(
  workspace_root : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let requested_workspace = query_value(request_path, "workspace")
  let runs : Array[@desk.DeskRunProjection] = []
  for workspace in discover_workspaces(workspace_root) {
    match requested_workspace {
      Some(id) if id != workspace.id => continue
      _ => ()
    }
    let run_root = @pathx.join(workspace.root_path, "moonclaw-jobs")
    let names = read_directory_names(run_root, include_hidden=false)
    let start = if names.length() > 80 { names.length() - 80 } else { 0 }
    for index = start; index < names.length(); index = index + 1 {
      let name = names[index]
      if !name.has_prefix("run-") {
        continue
      }
      let absolute = @pathx.join(run_root, name)
      if !is_directory(absolute) {
        continue
      }
      let artifacts = run_artifacts(workspace, name, absolute)
      let status = if @fs.exists(@pathx.join(absolute, "result.json")) {
        "ready"
      } else {
        "available"
      }
      runs.push(
        @desk.run_projection(
          run_id=name,
          book_id=workspace.id,
          status~,
          phase="workspace",
          summary="MoonClaw run workspace with \{artifacts.length()} visible artifacts.",
          artifacts~,
        ),
      )
    }
  }
  send_json(conn, method_, runs.to_json())
}
