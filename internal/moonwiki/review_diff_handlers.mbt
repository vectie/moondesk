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
    let candidate = "wiki/" + path["reviews/".length():].to_owned()
    if @fsx.exists(@pathx.join(workspace.root_path, candidate)) {
      return Some(candidate)
    }
  }
  if path.has_prefix("review/") {
    let candidate = "wiki/" + path["review/".length():].to_owned()
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
