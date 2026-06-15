///|
async fn handle_daemon_agent(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let root = @pathx.normalize(workspace_root)
  let result = if method_ is @http.RequestMethod::Get ||
    method_ is @http.RequestMethod::Head {
    daemon_agent_record(root, action="status", exit_code=0, message="")
  } else {
    let payload = read_json_body(body).unwrap_or(Json::object({}))
    let action = json_string(payload, "action", default="status")
    match action {
      "install" => install_daemon_agent(root)
      "uninstall" => uninstall_daemon_agent(root)
      "status" =>
        daemon_agent_record(root, action="status", exit_code=0, message="")
      _ =>
        daemon_agent_record(
          root,
          action~,
          exit_code=-1,
          message="Unsupported daemon agent action",
        )
    }
  }
  send_json(conn, method_, result)
}

///|
async fn install_daemon_agent(root : String) -> Json {
  if !is_runnable_moontown(root) {
    return daemon_agent_record(
      root,
      action="install",
      exit_code=-1,
      message="Configured root is not a runnable Moontown checkout",
    )
  }
  @fsx.make_directory(moondesk_daemon_dir(root), recursive=true, exists_ok=true) catch {
    _ => ()
  }
  let plist_path = daemon_agent_plist_path(root)
  @fsx.make_directory(
    @pathx.dirname(plist_path).to_string(),
    recursive=true,
    exists_ok=true,
  ) catch {
    _ =>
      return daemon_agent_record(
        root,
        action="install",
        exit_code=-1,
        message="Could not create LaunchAgents directory",
      )
  }
  @fsx.write_to_file(plist_path, daemon_agent_plist(root), create=0o644) catch {
    _ =>
      return daemon_agent_record(
        root,
        action="install",
        exit_code=-1,
        message="Could not write LaunchAgent plist",
      )
  }
  ignore(launchctl_bootout(daemon_agent_label(), plist_path))
  let code = launchctl_bootstrap(daemon_agent_label(), plist_path)
  daemon_agent_record(
    root,
    action="install",
    exit_code=code,
    message=if code == 0 {
      "Moontown daemon LaunchAgent installed and loaded"
    } else {
      "LaunchAgent plist written; launchctl bootstrap failed"
    },
  )
}

///|
async fn uninstall_daemon_agent(root : String) -> Json {
  let plist_path = daemon_agent_plist_path(root)
  let code = launchctl_bootout(daemon_agent_label(), plist_path)
  @fs.remove(plist_path) catch {
    _ => ()
  }
  daemon_agent_record(
    root,
    action="uninstall",
    exit_code=code,
    message="Moontown daemon LaunchAgent removed",
  )
}

///|
async fn daemon_agent_record(
  root : String,
  action~ : String,
  exit_code~ : Int,
  message~ : String,
) -> Json {
  let label = daemon_agent_label()
  let plist_path = daemon_agent_plist_path(root)
  let installed = @fsx.exists(plist_path)
  let loaded = daemon_agent_loaded_status(installed, label)
  {
    "ok": if action == "status" {
      true
    } else {
      exit_code == 0
    },
    "action": action,
    "installed": installed,
    "loaded": loaded,
    "label": label,
    "plist_path": plist_path,
    "command": "moon run cmd/main -- daemon run",
    "cwd": root,
    "exit_code": exit_code,
    "message": if message == "" {
      if installed {
        if loaded {
          "LaunchAgent is installed and loaded"
        } else {
          "LaunchAgent is installed but not loaded"
        }
      } else {
        "LaunchAgent is not installed"
      }
    } else {
      message
    },
  }
}

///|
async fn daemon_agent_loaded_status(installed : Bool, label : String) -> Bool {
  if installed {
    launchctl_print(label) == 0
  } else {
    false
  }
}

///|
fn daemon_agent_label() -> String {
  "app.vectie.moondesk.moontown"
}

///|
fn user_launch_agents_dir() -> String {
  let home = @sys.get_env_var("HOME").unwrap_or(".")
  @pathx.join(home, "Library/LaunchAgents")
}

///|
fn daemon_agent_plist_path(root : String) -> String {
  ignore(root)
  @pathx.join(user_launch_agents_dir(), daemon_agent_label() + ".plist")
}

///|
fn daemon_agent_plist(root : String) -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
  "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n" +
  "<plist version=\"1.0\">\n" +
  "<dict>\n" +
  "  <key>Label</key>\n" +
  "  <string>\{daemon_agent_label()}</string>\n" +
  "  <key>WorkingDirectory</key>\n" +
  "  <string>\{xml_escape(root)}</string>\n" +
  "  <key>ProgramArguments</key>\n" +
  "  <array>\n" +
  "    <string>moon</string>\n" +
  "    <string>run</string>\n" +
  "    <string>cmd/main</string>\n" +
  "    <string>--</string>\n" +
  "    <string>daemon</string>\n" +
  "    <string>run</string>\n" +
  "  </array>\n" +
  "  <key>RunAtLoad</key>\n" +
  "  <true/>\n" +
  "  <key>KeepAlive</key>\n" +
  "  <true/>\n" +
  "  <key>StandardOutPath</key>\n" +
  "  <string>\{xml_escape(@pathx.join(root, ".moontown/moondesk-daemon/launch-agent.out.log"))}</string>\n" +
  "  <key>StandardErrorPath</key>\n" +
  "  <string>\{xml_escape(@pathx.join(root, ".moontown/moondesk-daemon/launch-agent.err.log"))}</string>\n" +
  "</dict>\n" +
  "</plist>\n"
}

///|
fn xml_escape(text : String) -> String {
  text
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
  .to_string()
}

///|
async fn launchctl_target(label : String) -> String {
  let uid = current_user_id()
  if uid == "" {
    "gui/0/" + label
  } else {
    "gui/\{uid}/\{label}"
  }
}

///|
async fn launchctl_domain_name() -> String {
  let uid = current_user_id()
  if uid == "" {
    "gui/0"
  } else {
    "gui/\{uid}"
  }
}

///|
async fn current_user_id() -> String {
  let output = @process.collect_output("id", ["-u"]) catch { _ => return "" }
  if output.0 == 0 {
    (output.1.text() catch { _ => "" }).trim().to_string()
  } else {
    ""
  }
}

///|
async fn launchctl_bootstrap(label : String, plist_path : String) -> Int {
  ignore(label)
  @process.run("launchctl", ["bootstrap", launchctl_domain_name(), plist_path]) catch {
    _ => -1
  }
}

///|
async fn launchctl_bootout(label : String, plist_path : String) -> Int {
  ignore(plist_path)
  @process.run("launchctl", ["bootout", launchctl_target(label)]) catch {
    _ => -1
  }
}

///|
async fn launchctl_print(label : String) -> Int {
  @process.run("launchctl", ["print", launchctl_target(label)]) catch {
    _ => -1
  }
}

///|
async test "daemon agent status is quiet when launchagent is not installed" {
  let root = "/tmp/moondesk-daemon-agent-status-wbtest-" +
    @desk.stable_id("daemon-agent-status", @async.now().to_string())
  let record = daemon_agent_record(
    root,
    action="status",
    exit_code=0,
    message="",
  )
  assert_true(json_bool(record, "ok", default=false))
  assert_false(json_bool(record, "installed", default=true))
  assert_false(json_bool(record, "loaded", default=true))
  assert_eq(
    json_string(record, "message", default=""),
    "LaunchAgent is not installed",
  )
}

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
    root, ".moontown/moondesk-dispatches", "dispatch", "moontown", events, limit,
  )
  collect_file_events(
    root, ".moontown/moondesk-requests", "request", "moontown", events, limit,
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
    let run_root = @pathx.join(workspace.root_path, "moonclaw-jobs")
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
            path="moonclaw-jobs/" + run_name + "/events.jsonl",
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
            path="moonclaw-jobs/" + run_name + "/result.json",
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
  root : String,
  relative_root : String,
  kind : String,
  source : String,
  events : Array[Json],
  limit : Int,
) -> Unit {
  let dir = @pathx.join(root, relative_root)
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
    let line = line.to_string().trim().to_string()
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

///|
async fn handle_review_items(
  workspace_root : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let requested_workspace = query_value(request_path, "workspace")
  send_json(
    conn,
    method_,
    Json::array(collect_review_items(workspace_root, requested_workspace, 120)),
  )
}

///|
async fn count_review_items(root : String) -> Int {
  collect_review_items(root, None, 10000).length()
}

///|
async fn collect_review_items(
  workspace_root : String,
  requested_workspace : String?,
  limit : Int,
) -> Array[Json] {
  let items : Array[Json] = []
  for workspace in discover_workspaces(workspace_root) {
    match requested_workspace {
      Some(id) if id != workspace.id => continue
      _ => ()
    }
    for review_root in ["reviews", "review", "book/reviews", "book/review"] {
      collect_review_directory(workspace, review_root, items, limit)
      if items.length() >= limit {
        return items
      }
    }
  }
  for
    event in collect_town_event_records(@pathx.normalize(workspace_root), limit) {
    if items.length() >= limit {
      break
    }
    let severity = json_string(event, "severity", default="")
    if severity == "review" || severity == "failure" {
      items.push({
        "id": json_string(
          event,
          "id",
          default=@desk.stable_id("review", event.stringify()),
        ),
        "workspace_id": "",
        "path": json_string(event, "path", default=""),
        "title": json_string(event, "title", default="Town event"),
        "kind": json_string(event, "kind", default="event"),
        "status": severity,
        "detail": json_string(event, "detail", default=""),
      })
    }
  }
  items
}

///|
async fn collect_review_directory(
  workspace : @desk.DeskWorkspace,
  relative : String,
  items : Array[Json],
  limit : Int,
) -> Unit {
  if items.length() >= limit {
    return
  }
  let root = @pathx.join(workspace.root_path, relative)
  if !is_directory(root) {
    return
  }
  for name in read_directory_names(root, include_hidden=false) {
    if items.length() >= limit {
      break
    }
    let path = relative + "/" + name
    let absolute = @pathx.join(workspace.root_path, path)
    if is_directory(absolute) {
      collect_review_directory(workspace, path, items, limit)
    } else {
      items.push({
        "id": @desk.stable_id("review", workspace.id + ":" + path),
        "workspace_id": workspace.id,
        "path": path,
        "title": @desk.display_name(path),
        "kind": if path.has_suffix(".json") {
          "json"
        } else {
          "file"
        },
        "status": if path.to_lower().contains("fail") {
          "failure"
        } else {
          "review"
        },
        "detail": path,
      })
    }
  }
}

///|
async fn handle_workspace_review_diff(
  workspace_root : String,
  workspace_id : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(workspace) => workspace
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
      return
    }
  }
  let path = decode_query_value(query_value(request_path, "path").unwrap_or(""))
  match resolve_workspace_path(workspace.root_path, path) {
    Some((absolute, clean)) =>
      if @fs.exists(absolute) && !is_directory(absolute) {
        let current = @fs.read_file(absolute).text() catch { _ => "" }
        let base_path = review_base_path(workspace, clean)
        let base_text = match base_path {
          Some(path) =>
            @fs.read_file(@pathx.join(workspace.root_path, path)).text() catch {
              _ => ""
            }
          None => ""
        }
        let diff = line_diff_summary(base_text, current)
        send_json(conn, method_, {
          "ok": true,
          "workspace_id": workspace.id,
          "path": clean,
          "base_path": base_path.unwrap_or(""),
          "comparison_path": clean,
          "added": json_int(diff, "added", default=0),
          "removed": json_int(diff, "removed", default=0),
          "changed": json_bool(diff, "changed", default=false),
          "body": json_string(diff, "body", default=""),
        })
      } else {
        send_json(conn, method_, empty_review_diff(workspace.id, clean))
      }
    None => send_json(conn, method_, empty_review_diff(workspace.id, path))
  }
}

///|
fn empty_review_diff(workspace_id : String, path : String) -> Json {
  {
    "ok": false,
    "workspace_id": workspace_id,
    "path": path,
    "base_path": "",
    "comparison_path": path,
    "added": 0,
    "removed": 0,
    "changed": false,
    "body": "No textual file is selected for review.",
  }
}

///|
async fn review_base_path(
  workspace : @desk.DeskWorkspace,
  path : String,
) -> String? {
  if path.has_prefix("reviews/") {
    let candidate = "wiki/" + path["reviews/".length():].to_string()
    if @fsx.exists(@pathx.join(workspace.root_path, candidate)) {
      return Some(candidate)
    }
  }
  if path.has_prefix("review/") {
    let candidate = "wiki/" + path["review/".length():].to_string()
    if @fsx.exists(@pathx.join(workspace.root_path, candidate)) {
      return Some(candidate)
    }
  }
  for suffix in [".base", ".orig", ".previous"] {
    let candidate = path + suffix
    if @fsx.exists(@pathx.join(workspace.root_path, candidate)) {
      return Some(candidate)
    }
  }
  None
}

///|
fn line_diff_summary(base_text : String, current_text : String) -> Json {
  let base_lines = review_diff_lines(base_text)
  let current_lines = review_diff_lines(current_text)
  let mut added = 0
  let mut removed = 0
  let body_lines : Array[String] = []
  for line in current_lines {
    if !has_line(base_lines, line) {
      added += 1
      if body_lines.length() < 80 {
        body_lines.push(diff_body_line("+ ", line))
      }
    }
  }
  for line in base_lines {
    if !has_line(current_lines, line) {
      removed += 1
      if body_lines.length() < 80 {
        body_lines.push(diff_body_line("- ", line))
      }
    }
  }
  {
    "added": added,
    "removed": removed,
    "changed": added > 0 || removed > 0,
    "body": if body_lines.length() == 0 {
      "No line-level difference against the nearest review base."
    } else {
      body_lines.join("\n")
    },
  }
}

///|
fn review_diff_lines(text : String) -> Array[String] {
  let lines : Array[String] = []
  for line in text.split("\n") {
    let line = line.to_owned()
    if line.trim().to_owned() != "" {
      lines.push(line)
    }
  }
  lines
}

///|
fn diff_body_line(prefix : String, line : String) -> String {
  let compact = line.trim().to_owned()
  if compact.length() > 240 {
    prefix + compact[:240].to_owned() + "..."
  } else {
    prefix + compact
  }
}

///|
fn has_line(lines : Array[String], line : String) -> Bool {
  for item in lines {
    if item == line {
      return true
    }
  }
  false
}

///|
test "event severity maps watcher decisions" {
  assert_eq(severity_for_decision("Failed"), "failure")
  assert_eq(severity_for_decision("NeedsReview"), "review")
  assert_eq(severity_for_decision("Update"), "success")
}

///|
test "line diff summary detects additions and removals" {
  let diff = line_diff_summary("a\nb\n", "a\nc\n")
  assert_eq(json_int(diff, "added", default=0), 1)
  assert_eq(json_int(diff, "removed", default=0), 1)
  assert_true(json_bool(diff, "changed", default=false))
}

///|
test "line diff summary keeps rendered body bounded" {
  let long = "x".repeat(500)
  let diff = line_diff_summary("", long)
  let body = json_string(diff, "body", default="")
  assert_true(body.length() < 260)
  assert_true(body.contains("..."))
}
