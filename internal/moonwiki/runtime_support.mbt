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
  let text = text.trim().to_owned()
  if text.length() > 4000 {
    text[:4000].to_owned()
  } else {
    text
  }
}

///|
fn trimmed_text(value : String, fallback~ : String) -> String {
  let trimmed = value.trim().to_owned()
  if trimmed == "" {
    fallback
  } else {
    trimmed
  }
}

///|
async fn read_watcher_records(root : String, limit : Int) -> Array[Json] {
  let records : Array[Json] = []
  let watcher_root = @pathx.join(
    moonsuite_product_dir(root, "moontown"),
    "watchers",
  )
  for name in read_directory_names(watcher_root, include_hidden=false) {
    if !name.has_suffix(".jsonl") {
      continue
    }
    let text = @fs.read_file(@pathx.join(watcher_root, name)).text() catch {
      _ => continue
    }
    for line in text.split("\n") {
      let line = line.to_owned().trim().to_owned()
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
