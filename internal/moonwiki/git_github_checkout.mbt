///|
fn github_checkout_oid_valid(oid : String) -> Bool {
  oid.length() == 40 &&
  oid
  .to_array()
  .all(char => (char >= '0' && char <= '9') || (char >= 'a' && char <= 'f'))
}

///|
fn github_checkout_request_valid(payload : Json, repository : String) -> Bool {
  let number = json_int(payload, "number", default=0)
  json_string(payload, "repository", default="") == repository &&
  number > 0 &&
  number <= 1_000_000_000 &&
  github_checkout_oid_valid(json_string(payload, "head_oid", default=""))
}

///|
fn github_checkout_live_pull_valid(
  pull : Json,
  repository : String,
  number : Int,
  head_oid : String,
) -> Bool {
  let base = json_object_field_or_empty(pull, "base")
  let base_repo = json_object_field_or_empty(base, "repo")
  let head = json_object_field_or_empty(pull, "head")
  json_int(pull, "number", default=0) == number &&
  json_string(pull, "state", default="") == "open" &&
  json_string(base_repo, "full_name", default="") == repository &&
  json_string(head, "sha", default="") == head_oid
}

///|
fn github_checkout_folder_name(number : Int, head_oid : String) -> String {
  "code-pr-\{number}-" + head_oid[:8].to_owned()
}

///|
async fn github_checkout_existing_worktree_matches(
  book_root : String,
  target : String,
  head_oid : String,
) -> Bool {
  if !(@fs.kind(target, follow_symlink=false) is Directory) {
    return false
  }
  let source_common = git_projection_command(book_root, [
      "rev-parse", "--path-format=absolute", "--git-common-dir",
    ])
    .unwrap_or("")
    .trim()
    .to_owned()
  let target_common = git_projection_command(target, [
      "rev-parse", "--path-format=absolute", "--git-common-dir",
    ])
    .unwrap_or("")
    .trim()
    .to_owned()
  let target_head = git_projection_command(target, [
      "rev-parse", "--verify", "HEAD",
    ])
    .unwrap_or("")
    .trim()
    .to_owned()
  source_common != "" &&
  source_common == target_common &&
  target_head == head_oid
}

///|
async fn github_checkout_worktree_response(
  suite_root : String,
  target : String,
  repository : String,
  number : Int,
  head_oid : String,
) -> Result[Json, (Int, String)] {
  for workspace in discover_workspaces(suite_root) {
    if workspace.root_path == target {
      return Ok({
        "contract": "moondesk.github_checkout.v1",
        "repository": repository,
        "number": number,
        "head_oid": head_oid,
        "workspace": workspace.to_json(),
      })
    }
  }
  Err((503, "The PR worktree exists but is not visible as a MoonBook"))
}

///|
async fn github_remote_name_for_repository(
  root : String,
  repository : String,
) -> String? {
  let names = git_projection_command(root, ["remote"]).unwrap_or("")
  for raw_name in names.split("\n") {
    let name = raw_name.trim().to_owned()
    if !github_repository_component_valid(name) || name.has_prefix("-") {
      continue
    }
    let url = git_projection_command(root, ["remote", "get-url", name]).unwrap_or(
      "",
    )
    if github_repository_from_remote(url) == Some(repository) {
      return Some(name)
    }
  }
  None
}

///|
async fn github_checkout_git_write(
  root : String,
  args : Array[String],
  timeout_ms : Int,
) -> Bool {
  let output = @async.with_timeout(timeout_ms, () => {
    @process.collect_output(
      "/usr/bin/git",
      [
        "-c", "core.hooksPath=/dev/null", "-c", "core.fsmonitor=false", "-c", "protocol.ext.allow=never",
        ..args,
      ],
      extra_env={
        "GIT_TERMINAL_PROMPT": "0",
        "GIT_ASKPASS": "/usr/bin/false",
        "GIT_PAGER": "cat",
      },
      cwd=root,
    )
  }) catch {
    _ => return false
  }
  output.0 == 0
}

///|
async fn github_checkout_pull_worktree(
  suite_root : String,
  book_root : String,
  payload : Json,
) -> Result[Json, (Int, String)] {
  let repository = match github_repository_for_workspace(book_root) {
    Some(value) => value
    None => return Err((409, "This MoonBook has no GitHub remote"))
  }
  if !github_checkout_request_valid(payload, repository) {
    return Err((400, "Invalid PR checkout request"))
  }
  let git = read_git_repository_projection(book_root)
  if git.state != "ready" {
    return Err((409, "This MoonBook is not a ready Git repository"))
  }
  let number = json_int(payload, "number", default=0)
  let head_oid = json_string(payload, "head_oid", default="")
  let pull = match
    github_api_json(book_root, ["repos/\{repository}/pulls/\{number}"]) {
    Ok(value) => value
    Err(error) => return Err((503, error))
  }
  if !github_checkout_live_pull_valid(pull, repository, number, head_oid) {
    return Err((409, "The PR changed or closed. Refresh GitHub context."))
  }
  let remote = match github_remote_name_for_repository(book_root, repository) {
    Some(value) => value
    None => return Err((409, "The matching GitHub remote is unavailable"))
  }
  let name = github_checkout_folder_name(number, head_oid)
  let target = @pathx.join(workspace_context(suite_root).books_root, name)
  if @fsx.exists(target) {
    if !github_checkout_existing_worktree_matches(book_root, target, head_oid) {
      return Err((409, "A different folder already uses this PR worktree name"))
    }
    return github_checkout_worktree_response(
      suite_root, target, repository, number, head_oid,
    )
  }
  let private_ref = "refs/moondesk/pr/\{number}/\{head_oid}"
  let refspec = "+refs/pull/\{number}/head:\{private_ref}"
  if !github_checkout_git_write(
      book_root,
      ["fetch", "--quiet", "--no-tags", remote, refspec],
      60000,
    ) {
    return Err((503, "Could not fetch this PR from the matching GitHub remote"))
  }
  let fetched = git_projection_command(book_root, [
      "rev-parse", "--verify", private_ref,
    ])
    .unwrap_or("")
    .trim()
    .to_owned()
  if fetched != head_oid {
    return Err((409, "The PR head changed while fetching. Refresh and retry."))
  }
  if !github_checkout_git_write(
      book_root,
      ["worktree", "add", "--quiet", "--detach", target, head_oid],
      60000,
    ) {
    return Err((409, "Could not create an isolated PR worktree"))
  }
  let checked_out = git_projection_command(target, [
      "rev-parse", "--verify", "HEAD",
    ])
    .unwrap_or("")
    .trim()
    .to_owned()
  if checked_out != head_oid {
    return Err((409, "The PR worktree did not resolve to the verified head"))
  }
  github_checkout_worktree_response(
    suite_root, target, repository, number, head_oid,
  )
}

///|
async fn handle_workspace_github_checkout(
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
  match
    github_checkout_pull_worktree(workspace_root, workspace.root_path, payload) {
    Ok(result) => send_json(conn, method_, result)
    Err((code, error)) =>
      send_api_error(
        conn,
        method_,
        code,
        if code == 400 {
          "Bad Request"
        } else if code == 409 {
          "Conflict"
        } else {
          "Service Unavailable"
        },
        error,
      )
  }
}
