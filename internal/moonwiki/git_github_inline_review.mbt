///|
fn github_inline_patch_digest(
  base_oid : String,
  head_oid : String,
  path : String,
  patch : String,
) -> String {
  "sha256:" +
  @crypto.bytes_to_hex_string(
    @crypto.sha256(
      @encoding/utf8.encode(
        base_oid + "\n" + head_oid + "\n" + path + "\n" + patch,
      ).to_fixedarray(),
    ),
  )
}

///|
fn github_inline_file_projection(
  file : Json,
  base_oid : String,
  head_oid : String,
) -> Json? {
  let path = json_string(file, "filename", default="")
  if path == "" || path.length() > 4096 || path.contains("\u{0000}") {
    return None
  }
  let raw_patch = json_string(file, "patch", default="")
  let patch = if raw_patch.length() > 128 * 1024 { "" } else { raw_patch }
  Some({
    "path": path,
    "previous_path": json_string(file, "previous_filename", default=""),
    "status": json_string(file, "status", default=""),
    "additions": json_int(file, "additions", default=0),
    "deletions": json_int(file, "deletions", default=0),
    "patch": patch,
    "digest": github_inline_patch_digest(base_oid, head_oid, path, patch),
    "commentable": patch != "" && patch.contains("@@ "),
  })
}

///|
let github_inline_draft_mutex : @async.Mutex = Mutex()

///|
fn github_inline_draft_path(root : String) -> String {
  let book_key = @desk.stable_id("github-inline-book", root)
  moonsuite_product_artifact_for_workspace_root(
    root,
    "moondesk",
    "coding/github-inline-drafts-\{book_key}.v1.json",
  )
}

///|
async fn github_inline_drafts(
  root : String,
  repository : String,
) -> Array[Json] {
  let output : Array[Json] = []
  for draft in read_json_array_file(github_inline_draft_path(root)) {
    if output.length() >= 20 {
      break
    }
    if github_inline_draft_valid(draft, repository) &&
      json_string(draft, "body", default="").trim() != "" {
      output.push(draft)
    }
  }
  output
}

///|
fn github_inline_draft_valid(payload : Json, repository : String) -> Bool {
  let head = json_string(payload, "head_oid", default="")
  let base = json_string(payload, "base_oid", default="")
  let digest = json_string(payload, "digest", default="")
  let body = json_string(payload, "body", default="")
  json_string(payload, "repository", default="") == repository &&
  json_int(payload, "number", default=0) > 0 &&
  json_int(payload, "number", default=0) <= 1_000_000_000 &&
  json_string(payload, "path", default="") != "" &&
  json_string(payload, "path", default="").length() <= 4096 &&
  !json_string(payload, "path", default="").contains("\u{0000}") &&
  head.length() == 40 &&
  base.length() == 40 &&
  digest.length() == 71 &&
  digest.has_prefix("sha256:") &&
  [head, base, digest.strip_prefix("sha256:").unwrap_or("").to_owned()].all(value => {
    value
    .to_array()
    .all(char => (char >= '0' && char <= '9') || (char >= 'a' && char <= 'f'))
  }) &&
  json_string(payload, "hunk", default="").has_prefix("@@ ") &&
  json_string(payload, "hunk", default="").length() <= 240 &&
  ["left", "right"].contains(json_string(payload, "side", default="")) &&
  json_int(payload, "line", default=0) > 0 &&
  json_int(payload, "line", default=0) <= 10_000_000 &&
  json_object_field(payload, "body") is Some(String(_)) &&
  body.length() <= 4000 &&
  !body.contains("\u{0000}")
}

///|
fn github_inline_draft_id(repository : String, payload : Json) -> String {
  @desk.stable_id(
    "github-inline-draft",
    Json::array([
      repository.to_json(),
      json_int(payload, "number", default=0).to_json(),
      json_string(payload, "head_oid", default="").to_json(),
      json_string(payload, "base_oid", default="").to_json(),
      json_string(payload, "path", default="").to_json(),
      json_string(payload, "digest", default="").to_json(),
      json_string(payload, "hunk", default="").to_json(),
      json_string(payload, "side", default="").to_json(),
      json_int(payload, "line", default=0).to_json(),
    ]).stringify(),
  )
}

///|
async fn save_github_inline_draft(
  root : String,
  payload : Json,
) -> Result[Json, String] {
  let repository = match github_repository_for_workspace(root) {
    Some(value) => value
    None => return Err("This MoonBook has no GitHub remote")
  }
  if !github_inline_draft_valid(payload, repository) {
    return Err("Invalid PR line draft")
  }
  let number = json_int(payload, "number", default=0)
  let body = json_string(payload, "body", default="")
  let id = github_inline_draft_id(repository, payload)
  github_inline_draft_mutex.acquire()
  defer github_inline_draft_mutex.release()
  let path = github_inline_draft_path(root)
  let records = read_json_array_file(path)
  let next = if body.trim() == "" {
    records.filter(record => json_string(record, "id", default="") != id)
  } else {
    if records.length() >= 20 &&
      !records.any(record => json_string(record, "id", default="") == id) {
      return Err("PR line draft storage is full")
    }
    upsert_record_by_id(records, {
      "id": id,
      "repository": repository,
      "number": number,
      "head_oid": json_string(payload, "head_oid", default=""),
      "base_oid": json_string(payload, "base_oid", default=""),
      "path": json_string(payload, "path", default=""),
      "digest": json_string(payload, "digest", default=""),
      "hunk": json_string(payload, "hunk", default=""),
      "side": json_string(payload, "side", default=""),
      "line": json_int(payload, "line", default=0),
      "body": body,
      "updated_at": @async.now().to_string(),
      "authority": "local",
    })
  }
  write_preference_records(path, next) catch {
    _ => return Err("Could not save the local PR line draft")
  }
  Ok({
    "contract": "moondesk.github_inline_draft.v1",
    "state": if body.trim() == "" {
      "discarded"
    } else {
      "saved"
    },
    "repository": repository,
    "number": number,
    "head_oid": json_string(payload, "head_oid", default=""),
  })
}

///|
async fn handle_workspace_github_inline_draft(
  workspace_root : String,
  workspace_id : String,
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
  let payload = match read_json_body(body) {
    Some(value) => value
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  match save_github_inline_draft(workspace.root_path, payload) {
    Ok(value) => send_json(conn, method_, value)
    Err(error) => send_api_error(conn, method_, 400, "Bad Request", error)
  }
}

///|
async fn github_inline_review_snapshot(
  root : String,
  number : Int,
) -> Result[Json, String] {
  if number <= 0 || number > 1_000_000_000 {
    return Err("Invalid pull request number")
  }
  let repository = match github_repository_for_workspace(root) {
    Some(value) => value
    None => return Err("This MoonBook has no GitHub remote")
  }
  let git = read_git_repository_projection(root)
  if git.state != "ready" || git.head == "" {
    return Err("The Git branch is unavailable. Refresh repository changes.")
  }
  let pull = match
    github_api_json(root, @trusted_host.github_get_pull(repository, number)) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if !github_pull_head_matches(pull, git.branch, git.head) {
    return Err("The PR changed or closed. Refresh GitHub context.")
  }
  let base = json_object_field_or_empty(pull, "base")
  let base_oid = json_string(base, "sha", default="")
  if base_oid.length() != 40 {
    return Err("The PR base is unavailable")
  }
  let files : Array[Json] = []
  let mut truncated = false
  for page in 1..<=15 {
    let response = match
      github_api_json(
        root,
        @trusted_host.github_get_pull_files(repository, number, page),
      ) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    guard response is Array(items) else {
      return Err("GitHub returned invalid PR files")
    }
    for file in items {
      if files.length() >= 300 {
        truncated = true
        break
      }
      match github_inline_file_projection(file, base_oid, git.head) {
        Some(value) => files.push(value)
        None => ()
      }
    }
    if items.length() < 20 || truncated {
      break
    }
    if page == 15 {
      truncated = true
    }
  }
  let confirmed = match
    github_api_json(root, @trusted_host.github_get_pull(repository, number)) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let confirmed_base = json_object_field_or_empty(confirmed, "base")
  let current = read_git_repository_projection(root)
  if !github_pull_head_matches(confirmed, git.branch, git.head) ||
    json_string(confirmed_base, "sha", default="") != base_oid ||
    current.state != "ready" ||
    current.branch != git.branch ||
    current.head != git.head {
    return Err(
      "The PR changed while its files were loading. Refresh the remote diff.",
    )
  }
  Ok({
    "contract": "moondesk.github_inline_review.v1",
    "state": "ready",
    "repository": repository,
    "number": number,
    "branch": git.branch,
    "head_oid": git.head,
    "base_oid": base_oid,
    "files": Json::array(files),
    "drafts": Json::array(github_inline_drafts(root, repository)),
    "truncated": truncated,
    "error": "",
  })
}

///|
fn github_inline_comment_target_valid(payload : Json, snapshot : Json) -> Bool {
  let body = json_string(payload, "body", default="").trim()
  let side = json_string(payload, "side", default="")
  let line = json_int(payload, "line", default=0)
  let path = json_string(payload, "path", default="")
  let digest = json_string(payload, "digest", default="")
  let hunk = json_string(payload, "hunk", default="")
  if body == "" ||
    body.length() > 4000 ||
    body.contains("\u{0000}") ||
    line <= 0 ||
    line > 10_000_000 ||
    hunk.length() > 240 ||
    !["left", "right"].contains(side) ||
    json_string(payload, "repository", default="") !=
    json_string(snapshot, "repository", default="") ||
    json_int(payload, "number", default=0) !=
    json_int(snapshot, "number", default=0) ||
    json_string(payload, "branch", default="") !=
    json_string(snapshot, "branch", default="") ||
    json_string(payload, "head_oid", default="") !=
    json_string(snapshot, "head_oid", default="") ||
    json_string(payload, "base_oid", default="") !=
    json_string(snapshot, "base_oid", default="") {
    return false
  }
  for file in json_array_items(snapshot, "files") {
    if json_string(file, "path", default="") == path &&
      json_string(file, "digest", default="") == digest &&
      json_bool(file, "commentable", default=false) {
      return git_review_line_anchor_valid(
        json_string(file, "patch", default=""),
        hunk,
        side,
        line,
      )
    }
  }
  false
}

///|
fn github_inline_comment_url_valid(
  url : String,
  repository : String,
  number : Int,
) -> Bool {
  let prefix = "https://github.com/" +
    repository +
    "/pull/" +
    number.to_string() +
    "#"
  let fragment = url.strip_prefix(prefix).unwrap_or("")
  let id = if fragment.has_prefix("discussion_r") {
    fragment.strip_prefix("discussion_r").unwrap_or("")
  } else {
    fragment.strip_prefix("discussion-diff-").unwrap_or("")
  }
  id != "" && id.to_array().all(char => char >= '0' && char <= '9')
}

///|
async fn publish_github_inline_comment(
  root : String,
  payload : Json,
) -> Result[Json, String] {
  let number = json_int(payload, "number", default=0)
  let snapshot = match github_inline_review_snapshot(root, number) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if !github_inline_comment_target_valid(payload, snapshot) {
    return Err("The PR line changed. Refresh its remote diff before posting.")
  }
  let repository = json_string(snapshot, "repository", default="")
  let body = json_string(payload, "body", default="").trim().to_owned()
  let side = if json_string(payload, "side", default="") == "left" {
    "LEFT"
  } else {
    "RIGHT"
  }
  let posted = match
    github_api_json(
      root,
      @trusted_host.github_post_pr_line(
        repository,
        number,
        json_string(snapshot, "head_oid", default=""),
        json_string(payload, "path", default=""),
        side,
        json_int(payload, "line", default=0),
        body,
      ),
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let url = json_string(posted, "html_url", default="")
  if !github_inline_comment_url_valid(url, repository, number) {
    return Err(
      "GitHub may have posted the line comment. Check the PR before retrying.",
    )
  }
  Ok({
    "contract": "moondesk.github_inline_comment.v1",
    "state": "published",
    "repository": repository,
    "number": number,
    "head_oid": json_string(snapshot, "head_oid", default=""),
    "path": json_string(payload, "path", default=""),
    "side": json_string(payload, "side", default=""),
    "line": json_int(payload, "line", default=0),
    "url": url,
  })
}

///|
async fn handle_workspace_github_inline_review(
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
  match method_ {
    Get | Head => {
      let number = @string.parse_int(
        query_value(request_path, "number").unwrap_or(""),
      ) catch {
        _ => 0
      }
      match github_inline_review_snapshot(workspace.root_path, number) {
        Ok(value) => send_json(conn, method_, value)
        Err(error) => send_api_error(conn, method_, 409, "Conflict", error)
      }
    }
    Post => {
      let payload = match read_json_body(body) {
        Some(value) => value
        None => {
          send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
          return
        }
      }
      match publish_github_inline_comment(workspace.root_path, payload) {
        Ok(value) => send_json(conn, method_, value)
        Err(error) => send_api_error(conn, method_, 409, "Conflict", error)
      }
    }
    _ =>
      send_api_error(
        conn, method_, 405, "Method Not Allowed", "Unsupported method",
      )
  }
}
