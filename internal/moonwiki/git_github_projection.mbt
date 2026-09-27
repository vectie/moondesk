///|
fn github_repository_component_valid(value : String) -> Bool {
  value != "" &&
  value != "." &&
  value != ".." &&
  value.length() <= 100 &&
  value
  .to_array()
  .all(char => {
    (char >= 'a' && char <= 'z') ||
    (char >= 'A' && char <= 'Z') ||
    (char >= '0' && char <= '9') ||
    char == '-' ||
    char == '_' ||
    char == '.'
  })
}

///|
fn github_repository_from_remote(url : String) -> String? {
  let trimmed = url.trim().to_owned()
  let path = if trimmed.has_prefix("git@github.com:") {
    trimmed.strip_prefix("git@github.com:").unwrap_or("").to_owned()
  } else if trimmed.has_prefix("https://github.com/") {
    trimmed.strip_prefix("https://github.com/").unwrap_or("").to_owned()
  } else if trimmed.has_prefix("ssh://git@github.com/") {
    trimmed.strip_prefix("ssh://git@github.com/").unwrap_or("").to_owned()
  } else {
    return None
  }
  let path = path.strip_suffix(".git").unwrap_or(path)
  let parts = path.split("/").to_array()
  if parts.length() == 2 &&
    github_repository_component_valid(parts[0].to_owned()) &&
    github_repository_component_valid(parts[1].to_owned()) {
    Some(parts[0].to_owned() + "/" + parts[1].to_owned())
  } else {
    None
  }
}

///|
async fn github_repository_for_workspace(root : String) -> String? {
  let remotes = git_projection_command(root, ["remote"]).unwrap_or("")
  for name in remotes.split("\n") {
    let name = name.trim().to_owned()
    if name == "" || name.length() > 80 {
      continue
    }
    let url = git_projection_command(root, ["remote", "get-url", name]).unwrap_or(
      "",
    )
    match github_repository_from_remote(url) {
      Some(repo) => return Some(repo)
      None => ()
    }
  }
  None
}

///|
fn github_empty_projection(
  state : String,
  repository? : String = "",
  drafts? : Array[Json] = [],
  inline_drafts? : Array[Json] = [],
) -> Json {
  {
    "contract": "moondesk.github_context.v1",
    "state": state,
    "repository": repository,
    "branch": "",
    "pull_requests": [],
    "drafts": Json::array(drafts),
    "inline_drafts": Json::array(inline_drafts),
    "error": "",
  }
}

///|
async fn github_pull_request_context(root : String) -> Json {
  let git = read_git_repository_projection(root)
  if git.state != "ready" {
    return github_empty_projection("not_repository")
  }
  let repository = match github_repository_for_workspace(root) {
    Some(value) => value
    None => return github_empty_projection("no_github_remote")
  }
  let drafts = github_comment_drafts(root, repository)
  let inline_drafts = github_inline_drafts(root, repository)
  let output = @async.with_timeout(10000, () => {
    @process.collect_output(
      "/usr/bin/env",
      [
        "gh", "pr", "list", "--repo", repository, "--state", "open", "--limit", "20",
        "--json", "number,title,url,headRefName,headRefOid,baseRefOid,isDraft,reviewDecision,statusCheckRollup,closingIssuesReferences",
      ],
      extra_env={
        "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
        "GH_PROMPT_DISABLED": "1",
        "GH_HOST": "github.com",
        "GH_PAGER": "cat",
        "GIT_TERMINAL_PROMPT": "0",
      },
      cwd=root,
    )
  }) catch {
    _ =>
      return {
        "contract": "moondesk.github_context.v1",
        "state": "unavailable",
        "repository": repository,
        "branch": git.branch,
        "pull_requests": [],
        "drafts": Json::array(drafts),
        "inline_drafts": Json::array(inline_drafts),
        "error": "GitHub did not respond in time",
      }
  }
  let response = output.1.text() catch { _ => "" }
  if output.0 != 0 || response.length() > 256 * 1024 || response == "" {
    return {
      "contract": "moondesk.github_context.v1",
      "state": "unavailable",
      "repository": repository,
      "branch": git.branch,
      "pull_requests": [],
      "drafts": Json::array(drafts),
      "inline_drafts": Json::array(inline_drafts),
      "error": "GitHub is unavailable. Check connection and sign-in, then retry.",
    }
  }
  let parsed = @json.parse(response) catch {
    _ =>
      return github_empty_projection(
        "unavailable",
        repository~,
        drafts~,
        inline_drafts~,
      )
  }
  guard parsed is Array(pulls) else {
    return github_empty_projection(
      "unavailable",
      repository~,
      drafts~,
      inline_drafts~,
    )
  }
  let projected : Array[Json] = []
  for pull in pulls {
    let url = json_string(pull, "url", default="")
    if !url.has_prefix("https://github.com/" + repository + "/pull/") {
      continue
    }
    let checks : Array[Json] = []
    for check in json_array_items(pull, "statusCheckRollup") {
      if checks.length() >= 30 {
        break
      }
      checks.push({
        "name": json_string(
          check,
          "name",
          default=json_string(check, "context", default="Check"),
        ),
        "status": json_string(check, "status", default=""),
        "conclusion": json_string(
          check,
          "conclusion",
          default=json_string(check, "state", default=""),
        ),
      })
    }
    let issues : Array[Json] = []
    for issue in json_array_items(pull, "closingIssuesReferences") {
      if issues.length() >= 10 {
        break
      }
      let issue_url = json_string(issue, "url", default="")
      if issue_url.has_prefix("https://github.com/" + repository + "/issues/") {
        issues.push({
          "number": json_int(issue, "number", default=0),
          "title": json_string(issue, "title", default=""),
          "url": issue_url,
        })
      }
    }
    let head_oid = json_string(pull, "headRefOid", default="")
    let head_branch = json_string(pull, "headRefName", default="")
    projected.push({
      "number": json_int(pull, "number", default=0),
      "title": json_string(pull, "title", default=""),
      "url": url,
      "head_oid": head_oid,
      "head_branch": head_branch,
      "base_oid": json_string(pull, "baseRefOid", default=""),
      "head_matches": head_oid == git.head &&
      (git.branch == "" || head_branch == git.branch),
      "draft": json_bool(pull, "isDraft", default=false),
      "review_decision": json_string(pull, "reviewDecision", default=""),
      "checks": Json::array(checks),
      "closing_issues": Json::array(issues),
    })
  }
  {
    "contract": "moondesk.github_context.v1",
    "state": "ready",
    "repository": repository,
    "branch": git.branch,
    "pull_requests": Json::array(projected),
    "drafts": Json::array(drafts),
    "inline_drafts": Json::array(inline_drafts),
    "error": "",
  }
}

///|
let github_comment_draft_mutex : @async.Mutex = Mutex()

///|
fn github_comment_draft_path(root : String) -> String {
  let book_key = @desk.stable_id("github-comment-book", root)
  moonsuite_product_artifact_for_workspace_root(
    root,
    "moondesk",
    "coding/github-comment-drafts-\{book_key}.v1.json",
  )
}

///|
async fn github_comment_drafts(
  root : String,
  repository : String,
) -> Array[Json] {
  let result : Array[Json] = []
  for draft in read_json_array_file(github_comment_draft_path(root)) {
    if result.length() >= 20 {
      break
    }
    if json_string(draft, "repository", default="") == repository &&
      json_int(draft, "number", default=0) > 0 &&
      json_string(draft, "body", default="") != "" {
      result.push(draft)
    }
  }
  result
}

///|
async fn save_github_comment_draft(
  root : String,
  payload : Json,
) -> Result[Json, String] {
  let repository = match github_repository_for_workspace(root) {
    Some(value) => value
    None => return Err("This MoonBook has no GitHub remote")
  }
  let number = json_int(payload, "number", default=0)
  let head = json_string(payload, "head_oid", default="")
  let body = json_string(payload, "body", default="")
  if !(json_object_field(payload, "body") is Some(String(_))) ||
    json_string(payload, "repository", default="") != repository ||
    number <= 0 ||
    number > 1_000_000_000 ||
    head.length() != 40 ||
    !head
    .to_array()
    .all(char => (char >= '0' && char <= '9') || (char >= 'a' && char <= 'f')) ||
    body.length() > 4000 ||
    body.contains("\u{0000}") {
    return Err("Invalid PR draft")
  }
  let id = @desk.stable_id(
    "github-comment-draft",
    repository + "/" + number.to_string(),
  )
  github_comment_draft_mutex.acquire()
  defer github_comment_draft_mutex.release()
  let path = github_comment_draft_path(root)
  let records = read_json_array_file(path)
  let next = if body.trim() == "" {
    records.filter(record => json_string(record, "id", default="") != id)
  } else {
    if records.length() >= 20 &&
      !records.any(record => json_string(record, "id", default="") == id) {
      return Err("PR draft storage is full")
    }
    upsert_record_by_id(records, {
      "id": id,
      "repository": repository,
      "number": number,
      "head_oid": head,
      "body": body,
      "updated_at": @async.now().to_string(),
      "authority": "local",
    })
  }
  write_preference_records(path, next) catch {
    _ => return Err("Could not save the local PR draft")
  }
  Ok({
    "contract": "moondesk.github_comment_draft.v1",
    "state": if body.trim() == "" {
      "discarded"
    } else {
      "saved"
    },
    "repository": repository,
    "number": number,
    "head_oid": head,
  })
}

///|
async fn handle_workspace_github_comment_draft(
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
  match save_github_comment_draft(workspace.root_path, payload) {
    Ok(receipt) => send_json(conn, method_, receipt)
    Err(error) => send_api_error(conn, method_, 400, "Bad Request", error)
  }
}

///|
async fn handle_workspace_github_context(
  workspace_root : String,
  workspace_id : String,
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
  send_json(conn, method_, github_pull_request_context(workspace.root_path))
}

///|
fn github_comment_target_valid(
  payload : Json,
  repository : String,
  branch : String,
  head : String,
) -> Bool {
  let number = json_int(payload, "number", default=0)
  let body = json_string(payload, "body", default="").trim()
  number > 0 &&
  number <= 1_000_000_000 &&
  body != "" &&
  body.length() <= 4000 &&
  !body.contains("\u{0000}") &&
  json_string(payload, "repository", default="") == repository &&
  json_string(payload, "branch", default="") == branch &&
  json_string(payload, "head_oid", default="") == head &&
  head.length() == 40 &&
  head
  .to_array()
  .all(char => (char >= '0' && char <= '9') || (char >= 'a' && char <= 'f'))
}

///|
fn github_comment_url_valid(
  url : String,
  repository : String,
  number : Int,
) -> Bool {
  let prefix = "https://github.com/" + repository
  let suffix = "/" + number.to_string() + "#issuecomment-"
  let id = if url.has_prefix(prefix + "/pull" + suffix) {
    url.strip_prefix(prefix + "/pull" + suffix).unwrap_or("")
  } else {
    url.strip_prefix(prefix + "/issues" + suffix).unwrap_or("")
  }
  id != "" && id.to_array().all(char => char >= '0' && char <= '9')
}

///|
fn github_pull_head_matches(
  pull : Json,
  branch : String,
  head : String,
) -> Bool {
  let remote_head = json_object_field_or_empty(pull, "head")
  json_string(pull, "state", default="") == "open" &&
  json_string(remote_head, "sha", default="") == head &&
  (branch == "" || json_string(remote_head, "ref", default="") == branch)
}

///|
async fn github_api_json(
  root : String,
  args : Array[String],
) -> Result[Json, String] {
  let output = @async.with_timeout(12000, () => {
    @process.collect_output(
      "/usr/bin/env",
      ["gh", "api", ..args],
      extra_env={
        "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
        "GH_PROMPT_DISABLED": "1",
        "GH_HOST": "github.com",
        "GH_PAGER": "cat",
        "GIT_TERMINAL_PROMPT": "0",
      },
      cwd=root,
    )
  }) catch {
    _ => return Err("GitHub did not respond. Check the PR before retrying.")
  }
  if output.0 != 0 {
    return Err("GitHub rejected the request. Check sign-in and PR permissions.")
  }
  let response = output.1.text() catch {
    _ => return Err("GitHub response is unreadable")
  }
  if response == "" || response.length() > 256 * 1024 {
    return Err("GitHub response exceeds the display limit")
  }
  let parsed = @json.parse(response) catch {
    _ => return Err("GitHub returned invalid JSON")
  }
  Ok(parsed)
}

///|
async fn publish_github_pull_comment(
  root : String,
  payload : Json,
) -> Result[Json, String] {
  let repository = match github_repository_for_workspace(root) {
    Some(value) => value
    None => return Err("This MoonBook has no GitHub remote")
  }
  let git = read_git_repository_projection(root)
  if git.state != "ready" || git.head == "" {
    return Err("The Git branch is unavailable. Refresh repository changes.")
  }
  if !github_comment_target_valid(payload, repository, git.branch, git.head) {
    return Err(
      "The PR draft no longer matches this branch and commit. Refresh GitHub context.",
    )
  }
  let number = json_int(payload, "number", default=0)
  let pull_path = "repos/" + repository + "/pulls/" + number.to_string()
  let pull = match github_api_json(root, [pull_path]) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if !github_pull_head_matches(pull, git.branch, git.head) {
    return Err(
      "The PR changed or closed. Refresh GitHub context before publishing.",
    )
  }
  let body = json_string(payload, "body", default="").trim().to_owned()
  let comment_path = "repos/" +
    repository +
    "/issues/" +
    number.to_string() +
    "/comments"
  let published = match
    github_api_json(root, [
      "--method",
      "POST",
      comment_path,
      "-f",
      "body=" + body,
    ]) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let url = json_string(published, "html_url", default="")
  if !github_comment_url_valid(url, repository, number) {
    return Err(
      "GitHub may have posted the comment. Check the PR before retrying.",
    )
  }
  let draft_cleared = save_github_comment_draft(root, {
      "repository": repository,
      "number": number,
      "head_oid": git.head,
      "body": "",
    })
    is Ok(_)
  Ok({
    "contract": "moondesk.github_comment.v1",
    "state": "published",
    "repository": repository,
    "number": number,
    "head_oid": git.head,
    "url": url,
    "draft_cleared": draft_cleared,
  })
}

///|
async fn handle_workspace_github_comment(
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
  match publish_github_pull_comment(workspace.root_path, payload) {
    Ok(receipt) => send_json(conn, method_, receipt)
    Err(error) => send_api_error(conn, method_, 409, "Conflict", error)
  }
}
