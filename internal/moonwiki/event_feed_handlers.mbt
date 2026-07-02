///|
async fn handle_town_events(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let root = @pathx.normalize(workspace_root)
  send_json(conn, method_, Json::array(collect_town_event_records(root, 120)))
}

///|
async fn handle_moonclaw_events(
  workspace_root : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let requested_workspace = query_value(request_path, "workspace")
  send_json(
    conn,
    method_,
    Json::array(
      collect_moonclaw_event_records(workspace_root, requested_workspace, 120),
    ),
  )
}

///|
async fn collect_town_event_records(root : String, limit : Int) -> Array[Json] {
  let events : Array[Json] = []
  for record in read_watcher_records(root, limit) {
    let decision = json_string(record, "decision", default="Watcher")
    let goal_id = json_string(record, "goal_id", default="")
    let title = json_string(
      record,
      "title",
      default=if goal_id == "" { decision } else { goal_id },
    )
    events.push(
      event_record(
        id=@desk.stable_id(
          "watcher",
          title + decision + events.length().to_string(),
        ),
        source="moontown",
        kind="watcher",
        severity=severity_for_decision(decision),
        title~,
        detail=json_string(record, "summary", default=record.stringify()),
        path=json_string(record, "path", default=""),
        run_id=json_string(record, "run_id", default=""),
        tick=json_int(record, "tick", default=0),
        created_at=json_string(record, "created_at", default=""),
      ),
    )
    if events.length() >= limit {
      return events
    }
  }
  collect_file_events(
    town_moondesk_dispatches_root(root),
    town_moondesk_dispatches_relative_root(),
    "dispatch",
    "moontown",
    events,
    limit,
  )
  collect_file_events(
    town_moondesk_requests_root(root),
    town_moondesk_requests_relative_root(),
    "request",
    "moontown",
    events,
    limit,
  )
  events
}

///|
async fn collect_moonclaw_event_records(
  workspace_root : String,
  requested_workspace : String?,
  limit : Int,
) -> Array[Json] {
  let events : Array[Json] = []
  for workspace in discover_workspaces(workspace_root) {
    match requested_workspace {
      Some(id) if id != workspace.id => continue
      _ => ()
    }
    let run_root = moonclaw_jobs_root(workspace.root_path)
    for run_name in read_directory_names(run_root, include_hidden=false) {
      if events.length() >= limit {
        return events
      }
      if !run_name.has_prefix("run-") {
        continue
      }
      let event_path = @pathx.join(
        @pathx.join(run_root, run_name),
        "events.jsonl",
      )
      for record in read_jsonl_file(event_path, limit - events.length()) {
        let kind = json_string(record, "type", default="event")
        events.push(
          event_record(
            id=@desk.stable_id(
              "moonclaw",
              run_name + kind + events.length().to_string(),
            ),
            source="moonclaw",
            kind~,
            severity=severity_for_text(kind + " " + record.stringify()),
            title=json_string(record, "title", default=kind),
            detail=json_string(record, "message", default=record.stringify()),
            path=moonclaw_run_relative_path(run_name, "events.jsonl"),
            run_id=run_name,
            tick=0,
            created_at=json_string(record, "created_at", default=""),
          ),
        )
      }
      let result_path = @pathx.join(
        @pathx.join(run_root, run_name),
        "result.json",
      )
      if @fsx.exists(result_path) && events.length() < limit {
        let result = read_json_file_or_object(result_path)
        events.push(
          event_record(
            id=@desk.stable_id("moonclaw-result", run_name),
            source="moonclaw",
            kind="result",
            severity=severity_for_text(result.stringify()),
            title=run_name,
            detail=trim_for_record(result.stringify()),
            path=moonclaw_run_relative_path(run_name, "result.json"),
            run_id=run_name,
            tick=0,
            created_at="",
          ),
        )
      }
    }
  }
  events
}

///|
async fn collect_file_events(
  dir : String,
  relative_root : String,
  kind : String,
  source : String,
  events : Array[Json],
  limit : Int,
) -> Unit {
  let names = read_directory_names(dir, include_hidden=false)
  let mut index = names.length()
  while index > 0 && events.length() < limit {
    index -= 1
    let name = names[index]
    if !name.has_suffix(".json") {
      continue
    }
    let path = @pathx.join(dir, name)
    let record = read_json_file_or_object(path)
    let ok = json_bool(record, "ok", default=true)
    events.push(
      event_record(
        id=@desk.stable_id(kind, name),
        source~,
        kind~,
        severity=if ok { "info" } else { "failure" },
        title=name,
        detail=trim_for_record(record.stringify()),
        path=relative_root + "/" + name,
        run_id="",
        tick=0,
        created_at="",
      ),
    )
  }
}

///|
fn event_record(
  id~ : String,
  source~ : String,
  kind~ : String,
  severity~ : String,
  title~ : String,
  detail~ : String,
  path~ : String,
  run_id~ : String,
  tick~ : Int,
  created_at~ : String,
) -> Json {
  {
    "id": id,
    "source": source,
    "kind": kind,
    "severity": severity,
    "title": title,
    "detail": trim_for_record(detail),
    "path": path,
    "run_id": run_id,
    "tick": tick,
    "created_at": created_at,
  }
}

///|
fn severity_for_decision(decision : String) -> String {
  match decision {
    "Failed" => "failure"
    "NeedsReview" => "review"
    "Deferred" => "deferred"
    "Update" => "success"
    _ => "info"
  }
}

///|
fn severity_for_text(text : String) -> String {
  let lower = text.to_lower()
  if lower.contains("failed") || lower.contains("error") {
    "failure"
  } else if lower.contains("review") {
    "review"
  } else if lower.contains("complete") || lower.contains("success") {
    "success"
  } else {
    "info"
  }
}

///|
fn count_event_severity(events : Array[Json], severity : String) -> Int {
  let mut count = 0
  for event in events {
    if json_string(event, "severity", default="") == severity {
      count += 1
    }
  }
  count
}

///|
fn latest_event_title(events : Array[Json], severity : String) -> String {
  for event in events {
    if json_string(event, "severity", default="") == severity {
      return json_string(event, "title", default="")
    }
  }
  ""
}

///|
async fn read_jsonl_file(path : String, limit : Int) -> Array[Json] {
  if limit <= 0 || !@fsx.exists(path) {
    return []
  }
  let records : Array[Json] = []
  let text = @fs.read_file(path).text() catch { _ => return records }
  for line in text.split("\n") {
    if records.length() >= limit {
      break
    }
    let line = line.to_owned().trim().to_owned()
    if line == "" {
      continue
    }
    let parsed = Some(@json.parse(line)) catch { _ => None }
    match parsed {
      Some(json) => records.push(json)
      None => ()
    }
  }
  records
}
