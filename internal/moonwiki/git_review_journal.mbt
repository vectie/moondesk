///|
let git_review_write_mutex : @async.Mutex = Mutex()

///|
fn git_review_journal_path(root : String) -> String {
  let book_key = @desk.stable_id("git-review-book", root)
  moonsuite_product_artifact_for_workspace_root(
    root,
    "moondesk",
    "coding/git-review-\{book_key}.v1.json",
  )
}

///|
fn git_review_has_hunk(body : String, hunk : String) -> Bool {
  if hunk == "" {
    return true
  }
  body.split("\n").any(line => line == hunk && line.has_prefix("@@"))
}

///|
fn git_review_hunk_start(header : String, side : String) -> Int? {
  let parts = header.split(" ").to_array()
  if parts.length() < 3 || parts[0] != "@@" {
    return None
  }
  let marker = if side == "left" { "-" } else { "+" }
  let span = if side == "left" { parts[1] } else { parts[2] }
  if !span.has_prefix(marker) {
    return None
  }
  let start = span.strip_prefix(marker).unwrap_or("").split(",").to_array()[0]
  let number = @string.parse_int(start.to_owned()) catch { _ => return None }
  if number < 0 {
    None
  } else {
    Some(number)
  }
}

///|
fn git_review_line_anchor_valid(
  body : String,
  hunk : String,
  side : String,
  line : Int,
) -> Bool {
  if line == 0 && side == "" {
    return git_review_has_hunk(body, hunk)
  }
  if line <= 0 || (side != "left" && side != "right") || hunk == "" {
    return false
  }
  let mut active = false
  let mut old_line = 0
  let mut new_line = 0
  for row in body.split("\n") {
    if row.has_prefix("@@ ") {
      active = row == hunk
      if active {
        old_line = git_review_hunk_start(row.to_owned(), "left").unwrap_or(0)
        new_line = git_review_hunk_start(row.to_owned(), "right").unwrap_or(0)
      }
      continue
    }
    if !active || row == "" || row.has_prefix("\\") {
      continue
    }
    if row.has_prefix("+") {
      if side == "right" && new_line == line {
        return true
      }
      new_line += 1
    } else if row.has_prefix("-") {
      if side == "left" && old_line == line {
        return true
      }
      old_line += 1
    } else if row.has_prefix(" ") {
      if (side == "left" && old_line == line) ||
        (side == "right" && new_line == line) {
        return true
      }
      old_line += 1
      new_line += 1
    }
  }
  false
}

///|
async fn git_review_state(root : String, path : String) -> Json {
  let diff = read_git_diff_projection(root, path)
  let records = read_json_array_file(git_review_journal_path(root))
  let current : Array[Json] = []
  let stale : Array[Json] = []
  let mut stale_count = 0
  for record in records {
    let record_path = json_string(record, "path", default="")
    if record_path != path &&
      (diff.previous_path == "" || record_path != diff.previous_path) {
      continue
    }
    if record_path == path &&
      diff.digest != "" &&
      json_string(record, "digest", default="") == diff.digest {
      current.push(record)
    } else {
      stale_count += 1
      if stale.length() < 30 {
        stale.push(record)
      }
    }
  }
  {
    "contract": "moondesk.git_review.v1",
    "path": path,
    "head": diff.head,
    "digest": diff.digest,
    "diff_state": diff.state,
    "records": Json::array(current),
    "stale_records": Json::array(stale),
    "stale_count": stale_count,
  }
}

///|
async fn git_review_progress(root : String) -> Json {
  let repository = read_git_repository_projection(root)
  if repository.state != "ready" {
    return {
      "contract": "moondesk.git_review_progress.v1",
      "state": repository.state,
      "head": repository.head,
      "total": 0,
      "reviewed": 0,
      "needs_changes": 0,
      "pending": 0,
      "truncated": false,
      "files": [],
    }
  }
  let records = read_json_array_file(git_review_journal_path(root))
  let files : Array[Json] = []
  let mut reviewed = 0
  let mut needs_changes = 0
  for change in repository.changes {
    let mut status = "pending"
    let has_decision = records.any(record => {
      json_string(record, "path", default="") == change.path &&
      json_string(record, "kind", default="") == "decision"
    })
    if has_decision {
      let diff = read_git_diff_for_repository(root, change.path, repository)
      if (diff.state == "ready" || diff.state == "binary") && diff.digest != "" {
        for record in records {
          if json_string(record, "path", default="") == change.path &&
            json_string(record, "kind", default="") == "decision" &&
            json_string(record, "digest", default="") == diff.digest {
            status = json_string(record, "action", default="pending")
          }
        }
      }
    }
    if status == "reviewed" {
      reviewed += 1
    } else if status == "needs_changes" {
      needs_changes += 1
    } else {
      status = "pending"
    }
    files.push({ "path": change.path, "status": status })
  }
  {
    "contract": "moondesk.git_review_progress.v1",
    "state": "ready",
    "head": repository.head,
    "total": repository.changes.length(),
    "reviewed": reviewed,
    "needs_changes": needs_changes,
    "pending": repository.changes.length() - reviewed - needs_changes,
    "truncated": repository.truncated,
    "files": Json::array(files),
  }
}

///|
async fn handle_workspace_git_review_progress(
  workspace_root : String,
  workspace_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match find_workspace(workspace_root, workspace_id) {
    Some(workspace) =>
      send_json(conn, method_, git_review_progress(workspace.root_path))
    None => send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
  }
}

///|
async fn save_git_review_record(
  root : String,
  payload : Json,
) -> Result[Json, String] {
  let path = json_string(payload, "path", default="")
  let head = json_string(payload, "head", default="")
  let digest = json_string(payload, "digest", default="")
  let action = json_string(payload, "action", default="")
  let note = json_string(payload, "note", default="").trim().to_owned()
  let hunk = json_string(payload, "hunk", default="")
  let side = json_string(payload, "side", default="")
  let line = json_int(payload, "line", default=0)
  if path == "" ||
    !["reviewed", "needs_changes", "comment"].contains(action) ||
    digest == "" ||
    !digest.has_prefix("sha256:") ||
    note.length() > 4000 ||
    hunk.length() > 240 ||
    line < 0 ||
    line > 10_000_000 ||
    ((action == "needs_changes" || action == "comment") && note == "") {
    return Err("Invalid review record")
  }
  let diff = read_git_diff_projection(root, path)
  if (diff.state != "ready" && diff.state != "binary") ||
    diff.head != head ||
    diff.digest != digest ||
    !git_review_line_anchor_valid(diff.body, hunk, side, line) {
    return Err("The file changed. Refresh its diff before saving the review.")
  }
  git_review_write_mutex.acquire()
  defer git_review_write_mutex.release()
  // Re-read after acquiring the writer lock. Other edits can arrive while a
  // review is being prepared; only the exact patch the person saw may land.
  let current = read_git_diff_projection(root, path)
  if (current.state != "ready" && current.state != "binary") ||
    current.head != head ||
    current.digest != digest ||
    !git_review_line_anchor_valid(current.body, hunk, side, line) {
    return Err("The file changed. Refresh its diff before saving the review.")
  }
  let now = @async.now().to_string()
  let id = if action == "comment" {
    @desk.stable_id("git-review-comment", path + digest + hunk + note + now)
  } else {
    @desk.stable_id("git-review-decision", path + digest)
  }
  let record : Json = {
    "id": id,
    "kind": if action == "comment" {
      "comment"
    } else {
      "decision"
    },
    "path": path,
    "previous_path": current.previous_path,
    "head": head,
    "digest": digest,
    "action": action,
    "hunk": hunk,
    "side": side,
    "line": line,
    "note": note,
    "created_at": now,
    "authority": "local",
  }
  let storage = git_review_journal_path(root)
  let records = read_json_array_file(storage)
  if records.length() >= 1000 &&
    !records.any(item => json_string(item, "id", default="") == id) {
    return Err("Review journal is full")
  }
  write_preference_records(storage, upsert_record_by_id(records, record)) catch {
    _ => return Err("Could not save the local review")
  }
  Ok(record)
}

///|
async fn handle_workspace_git_review(
  workspace_root : String,
  workspace_id : String,
  request_path : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(value) => value
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
      return
    }
  }
  if method_ == Get || method_ == Head {
    let path = decode_query_value(
      query_value(request_path, "path").unwrap_or(""),
    )
    match resolve_workspace_path(workspace.root_path, path) {
      Some((_, clean)) if clean != "" && clean == path =>
        send_json(conn, method_, git_review_state(workspace.root_path, path))
      _ =>
        send_api_error(conn, method_, 400, "Bad Request", "Invalid file path")
    }
    return
  }
  let payload = match read_json_body(body) {
    Some(value) => value
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  let path = json_string(payload, "path", default="")
  match resolve_workspace_path(workspace.root_path, path) {
    Some((_, clean)) if clean != "" && clean == path => ()
    _ => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid file path")
      return
    }
  }
  match save_git_review_record(workspace.root_path, payload) {
    Ok(record) => send_json(conn, method_, record)
    Err(message) =>
      send_api_error(
        conn,
        method_,
        if message.contains("changed") {
          409
        } else {
          400
        },
        if message.contains("changed") {
          "Conflict"
        } else {
          "Bad Request"
        },
        message,
      )
  }
}
