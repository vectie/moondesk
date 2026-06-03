///|
fn upsert_record_by_id(records : Array[Json], record : Json) -> Array[Json] {
  let id = json_string(record, "id", default="")
  let next : Array[Json] = []
  let mut replaced = false
  for item in records {
    if json_string(item, "id", default="") == id {
      next.push(record)
      replaced = true
    } else {
      next.push(item)
    }
  }
  if !replaced {
    next.push(record)
  }
  next
}

///|
fn trim_for_record(text : String) -> String {
  let text = text.trim().to_string()
  if text.length() > 4000 {
    text[:4000].to_string()
  } else {
    text
  }
}

///|
async fn read_watcher_records(root : String, limit : Int) -> Array[Json] {
  let records : Array[Json] = []
  let watcher_root = @pathx.join(root, ".moontown/watchers")
  for name in read_directory_names(watcher_root, include_hidden=false) {
    if !name.has_suffix(".jsonl") {
      continue
    }
    let text = @fs.read_file(@pathx.join(watcher_root, name)).text() catch {
      _ => continue
    }
    for line in text.split("\n") {
      let line = line.to_string().trim().to_string()
      if line == "" {
        continue
      }
      let record = Some(@json.parse(line)) catch { _ => None }
      match record {
        Some(record) => if records.length() < limit { records.push(record) }
        None => ()
      }
    }
  }
  records
}

///|
fn count_watcher_decision(records : Array[Json], decision : String) -> Int {
  let mut count = 0
  for record in records {
    if json_string(record, "decision", default="") == decision {
      count += 1
    }
  }
  count
}

///|
fn count_due_goals(goals : Array[Json], daemon_tick : Int) -> Int {
  let mut count = 0
  for goal in goals {
    if json_bool(goal, "enabled", default=true) &&
      daemon_tick >= json_int(goal, "next_due_tick", default=0) {
      count += 1
    }
  }
  count
}

///|
fn next_due_tick(goals : Array[Json]) -> Int {
  let mut found = false
  let mut next = 0
  for goal in goals {
    if !json_bool(goal, "enabled", default=true) {
      continue
    }
    let due = json_int(goal, "next_due_tick", default=0)
    if !found || due < next {
      found = true
      next = due
    }
  }
  if found {
    next
  } else {
    0
  }
}

///|
async fn count_matching_files(root : String, suffix : String) -> Int {
  let mut count = 0
  for name in read_directory_names(root, include_hidden=false) {
    if name.has_suffix(suffix) {
      count += 1
    }
  }
  count
}

///|
async fn latest_matching_name(root : String, suffix : String) -> String {
  let names = read_directory_names(root, include_hidden=false)
  let mut index = names.length()
  while index > 0 {
    index -= 1
    let name = names[index]
    if name.has_suffix(suffix) {
      return name
    }
  }
  ""
}

///|
async fn count_run_workspaces(workspace_root : String) -> Int {
  let mut count = 0
  for workspace in discover_workspaces(workspace_root) {
    let run_root = @pathx.join(workspace.root_path, "moonclaw-jobs")
    for name in read_directory_names(run_root, include_hidden=false) {
      if name.has_prefix("run-") && is_directory(@pathx.join(run_root, name)) {
        count += 1
      }
    }
  }
  count
}

///|
async fn latest_run_info(workspace_root : String) -> Json {
  let root = @pathx.normalize(workspace_root)
  let mut latest : Json = {
    "workspace_id": "",
    "run_id": "",
    "status": "",
    "artifact_count": 0,
  }
  for workspace in discover_workspaces(root) {
    let run_root = @pathx.join(workspace.root_path, "moonclaw-jobs")
    let names = read_directory_names(run_root, include_hidden=false)
    let mut index = names.length()
    while index > 0 {
      index -= 1
      let name = names[index]
      let absolute = @pathx.join(run_root, name)
      if name.has_prefix("run-") && is_directory(absolute) {
        let artifacts = run_artifacts(workspace, name, absolute)
        latest = {
          "workspace_id": workspace.id,
          "run_id": name,
          "status": if @fs.exists(@pathx.join(absolute, "result.json")) {
            "ready"
          } else {
            "available"
          },
          "artifact_count": artifacts.length(),
        }
        break
      }
    }
  }
  latest
}

///|
async fn moonclaw_progress_summary(
  workspace_root : String,
  requested_workspace : String?,
) -> Json {
  let mut run_count = 0
  let mut ready_count = 0
  let mut artifact_count = 0
  let mut latest_run = ""
  let mut latest_status = ""
  for workspace in discover_workspaces(workspace_root) {
    match requested_workspace {
      Some(id) if id != workspace.id => continue
      _ => ()
    }
    let run_root = @pathx.join(workspace.root_path, "moonclaw-jobs")
    let names = read_directory_names(run_root, include_hidden=false)
    for name in names {
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
      run_count += 1
      if status == "ready" {
        ready_count += 1
      }
      artifact_count += artifacts.length()
      latest_run = name
      latest_status = status
    }
  }
  {
    "run_count": run_count,
    "ready_count": ready_count,
    "artifact_count": artifact_count,
    "latest_run": latest_run,
    "latest_status": latest_status,
  }
}

///|
fn preference_dir(workspace_root : String) -> String {
  @pathx.join(
    @pathx.normalize(workspace_root),
    ".moontown/moondesk-preferences",
  )
}

///|
fn saved_views_path(workspace_root : String) -> String {
  @pathx.join(preference_dir(workspace_root), "views.json")
}

///|
fn tags_path(workspace_root : String) -> String {
  @pathx.join(preference_dir(workspace_root), "tags.json")
}

///|
async fn write_preference_records(path : String, records : Array[Json]) -> Unit {
  @fsx.make_directory(
    @pathx.dirname(path).to_string(),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    path,
    Json::array(records).stringify(indent=2) + "\n",
    create=0o644,
  )
}

///|
fn ics_escape(text : String) -> String {
  text
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\r", new=" ")
  .replace_all(old="\n", new=" ")
  .replace_all(old=",", new="\\,")
  .replace_all(old=";", new="\\;")
  .to_string()
}

///|
async fn send_file(
  conn : @http.ServerConnection,
  method_ : @http.RequestMethod,
  path : String,
  code : Int,
  reason : String,
) -> Unit {
  conn.send_response(code, reason, extra_headers={
    "content-type": content_type(path),
  })
  if method_ is @http.RequestMethod::Head {
    conn.end_response()
    return
  }
  conn.write(@fs.read_file(path).binary())
  conn.end_response()
}

///|
async fn send_status(
  conn : @http.ServerConnection,
  code : Int,
  reason : String,
  body : String,
) -> Unit {
  conn.send_response(code, reason, extra_headers={
    "content-type": "text/plain; charset=utf-8",
  })
  conn.write(body)
  conn.end_response()
}

///|
async fn send_json(
  conn : @http.ServerConnection,
  method_ : @http.RequestMethod,
  body : Json,
) -> Unit {
  send_json_text(conn, method_, body.stringify(indent=2) + "\n")
}

///|
async fn send_json_text(
  conn : @http.ServerConnection,
  method_ : @http.RequestMethod,
  body : String,
) -> Unit {
  conn.send_response(200, "OK", extra_headers={
    "content-type": "application/json; charset=utf-8",
  })
  if method_ is @http.RequestMethod::Head {
    conn.end_response()
    return
  }
  conn.write(body)
  conn.end_response()
}

///|
async fn send_text(
  conn : @http.ServerConnection,
  method_ : @http.RequestMethod,
  content_type : String,
  body : String,
) -> Unit {
  conn.send_response(200, "OK", extra_headers={ "content-type": content_type })
  if method_ is @http.RequestMethod::Head {
    conn.end_response()
    return
  }
  conn.write(body)
  conn.end_response()
}

///|
async fn send_api_error(
  conn : @http.ServerConnection,
  method_ : @http.RequestMethod,
  code : Int,
  reason : String,
  message : String,
) -> Unit {
  conn.send_response(code, reason, extra_headers={
    "content-type": "application/json; charset=utf-8",
  })
  if method_ is @http.RequestMethod::Head {
    conn.end_response()
    return
  }
  let body : Json = { "error": message }
  conn.write(body.stringify(indent=2) + "\n")
  conn.end_response()
}

///|
async fn send_api_json_error(
  conn : @http.ServerConnection,
  method_ : @http.RequestMethod,
  code : Int,
  reason : String,
  payload : Json,
) -> Unit {
  conn.send_response(code, reason, extra_headers={
    "content-type": "application/json; charset=utf-8",
  })
  if method_ is @http.RequestMethod::Head {
    conn.end_response()
    return
  }
  conn.write(payload.stringify(indent=2) + "\n")
  conn.end_response()
}

///|
fn content_type(path : String) -> String {
  match @pathx.ext(path) {
    ".html" => "text/html; charset=utf-8"
    ".css" => "text/css; charset=utf-8"
    ".js" => "application/javascript"
    ".json" => "application/json"
    ".svg" => "image/svg+xml"
    ".png" => "image/png"
    ".jpg" | ".jpeg" => "image/jpeg"
    ".gif" => "image/gif"
    ".webp" => "image/webp"
    ".ico" => "image/x-icon"
    ".txt" | ".md" => "text/plain; charset=utf-8"
    _ => "application/octet-stream"
  }
}
