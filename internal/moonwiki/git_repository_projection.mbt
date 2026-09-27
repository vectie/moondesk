///|
struct GitChangeProjection {
  path : String
  previous_path : String
  index_status : String
  worktree_status : String
} derive(ToJson)

///|
struct GitRepositoryProjection {
  state : String
  branch : String
  head : String
  has_remote : Bool
  changes : Array[GitChangeProjection]
  truncated : Bool
  error : String
} derive(ToJson)

///|
struct GitDiffProjection {
  state : String
  path : String
  previous_path : String
  head : String
  body : String
  digest : String
  error : String
} derive(ToJson)

///|
fn empty_git_projection(
  state : String,
  error? : String = "",
) -> GitRepositoryProjection {
  {
    state,
    branch: "",
    head: "",
    has_remote: false,
    changes: [],
    truncated: false,
    error,
  }
}

///|
fn git_projection_environment() -> Map[String, String] {
  {
    "HOME": "/dev/null",
    "PATH": "/usr/bin:/bin",
    "LANG": "C",
    "LC_ALL": "C",
    "GIT_CONFIG_NOSYSTEM": "1",
    "GIT_CONFIG_GLOBAL": "/dev/null",
    "GIT_TERMINAL_PROMPT": "0",
    "GIT_OPTIONAL_LOCKS": "0",
    "GIT_ASKPASS": "/usr/bin/false",
    "GIT_PAGER": "cat",
  }
}

///|
async fn git_projection_command(
  root : String,
  args : Array[String],
  limit_error? : String = "Repository change list exceeds the display limit",
  allow_diff_exit? : Bool = false,
) -> Result[String, String] {
  let output = @async.with_timeout(8000, () => {
    @process.collect_output(
      "/usr/bin/git",
      [
        "-c", "core.hooksPath=/dev/null", "-c", "core.fsmonitor=false", "-c", "diff.external=",
        ..args,
      ],
      extra_env=git_projection_environment(),
      inherit_env=false,
      cwd=root,
    )
  }) catch {
    _ => return Err("Git did not respond in time")
  }
  if output.0 != 0 && !(allow_diff_exit && output.0 == 1) {
    return Err("Git could not read this repository")
  }
  let text = output.1.text() catch {
    _ => return Err("Repository paths are not valid UTF-8")
  }
  if text.length() > 256 * 1024 {
    return Err(limit_error)
  }
  Ok(text)
}

///|
fn empty_git_diff(
  state : String,
  path : String,
  error? : String = "",
) -> GitDiffProjection {
  { state, path, previous_path: "", head: "", body: "", digest: "", error, }
}

///|
async fn read_git_diff_projection(
  root : String,
  path : String,
) -> GitDiffProjection {
  let repository = read_git_repository_projection(root)
  read_git_diff_for_repository(root, path, repository)
}

///|
async fn read_git_diff_for_repository(
  root : String,
  path : String,
  repository : GitRepositoryProjection,
) -> GitDiffProjection {
  if repository.state != "ready" {
    return empty_git_diff(
      "error",
      path,
      error=if repository.error == "" {
        "This workspace is not a Git repository"
      } else {
        repository.error
      },
    )
  }
  let mut selected : GitChangeProjection? = None
  for change in repository.changes {
    if change.path == path {
      selected = Some(change)
      break
    }
  }
  let change = match selected {
    Some(change) => change
    None =>
      return {
        state: "error",
        path,
        previous_path: "",
        head: repository.head,
        body: "",
        digest: "",
        error: "File is not in the current change list",
      }
  }
  let untracked = change.index_status == "?" && change.worktree_status == "?"
  if repository.head == "" && !untracked {
    return {
      state: "no_baseline",
      path,
      previous_path: change.previous_path,
      head: "",
      body: "",
      digest: "",
      error: "",
    }
  }
  let args = if untracked {
    [
      "diff", "--no-index", "--no-ext-diff", "--no-textconv", "--no-color", "--unified=3",
      "--", "/dev/null", path,
    ]
  } else {
    [
      "diff",
      "--no-ext-diff",
      "--no-textconv",
      "--no-color",
      "--unified=3",
      "HEAD",
      "--",
      ":(literal)" + path,
    ]
  }
  if !untracked && change.previous_path != "" {
    args.push(":(literal)" + change.previous_path)
  }
  let body = match
    git_projection_command(
      root,
      args,
      limit_error="File diff exceeds the 256 KiB review limit",
      allow_diff_exit=untracked,
    ) {
    Ok(body) => body
    Err(error) =>
      return {
        state: "error",
        path,
        previous_path: change.previous_path,
        head: repository.head,
        body: "",
        digest: "",
        error,
      }
  }
  let state = if body.contains("Binary files ") && body.contains(" differ") {
    "binary"
  } else if body == "" {
    "no_diff"
  } else {
    "ready"
  }
  {
    state,
    path,
    previous_path: change.previous_path,
    head: repository.head,
    body,
    digest: if state == "ready" || state == "binary" {
      "sha256:" +
      @crypto.bytes_to_hex_string(
        @crypto.sha256(
          @encoding/utf8.encode(
            repository.head +
            "\n" +
            path +
            "\n" +
            change.previous_path +
            "\n" +
            body,
          ).to_fixedarray(),
        ),
      )
    } else {
      ""
    },
    error: "",
  }
}

///|
fn parse_git_status_projection(
  status : String,
) -> Result[(Array[GitChangeProjection], Bool), String] {
  let records = status.split("\u0000").to_array()
  let changes : Array[GitChangeProjection] = []
  let mut index = 0
  let mut truncated = false
  while index < records.length() {
    let record = records[index].to_owned()
    if record == "" && index == records.length() - 1 {
      break
    }
    if record.length() < 4 || record[2:3] != " " {
      return Err("Git returned an unreadable change list")
    }
    let index_status = record[0:1].to_owned()
    let worktree_status = record[1:2].to_owned()
    let path = record[3:].to_owned()
    index += 1
    let mut previous_path = ""
    if index_status == "R" ||
      index_status == "C" ||
      worktree_status == "R" ||
      worktree_status == "C" {
      if index >= records.length() || records[index] == "" {
        return Err("Git returned an incomplete rename")
      }
      previous_path = records[index].to_owned()
      index += 1
    }
    let generated_untracked = index_status == "?" &&
      worktree_status == "?" &&
      (
        path == "_build" ||
        path.has_prefix("_build/") ||
        path == ".mooncakes" ||
        path.has_prefix(".mooncakes/")
      )
    if path == ".moonsuite" ||
      path.has_prefix(".moonsuite/") ||
      generated_untracked {
      continue
    }
    if changes.length() < 300 {
      changes.push({ path, previous_path, index_status, worktree_status, })
    } else {
      truncated = true
    }
  }
  Ok((changes, truncated))
}

///|
async fn read_git_repository_projection(
  root : String,
) -> GitRepositoryProjection {
  let canonical_root = @fs.realpath(root) catch {
    _ =>
      return empty_git_projection("error", error="MoonBook path is unavailable")
  }
  let top_level = match
    git_projection_command(canonical_root, ["rev-parse", "--show-toplevel"]) {
    Ok(value) => value.trim().to_owned()
    Err(error) =>
      if @fs.exists(@pathx.join(canonical_root, ".git")) {
        return empty_git_projection("error", error~)
      } else {
        return empty_git_projection("not_repository")
      }
  }
  if top_level != canonical_root {
    return empty_git_projection("not_repository")
  }
  let status = match
    git_projection_command(canonical_root, [
      "status", "--porcelain=v1", "-z", "--untracked-files=all",
    ]) {
    Ok(value) => value
    Err(error) => return empty_git_projection("error", error~)
  }
  let (changes, truncated) = match parse_git_status_projection(status) {
    Ok(value) => value
    Err(error) => return empty_git_projection("error", error~)
  }
  let branch = git_projection_command(canonical_root, [
      "branch", "--show-current",
    ])
    .unwrap_or("")
    .trim()
    .to_owned()
  let head = git_projection_command(canonical_root, [
      "rev-parse", "--verify", "HEAD",
    ])
    .unwrap_or("")
    .trim()
    .to_owned()
  let remote = git_projection_command(canonical_root, ["remote"])
    .unwrap_or("")
    .trim()
    .to_owned()
  {
    state: "ready",
    branch,
    head,
    has_remote: remote != "",
    changes,
    truncated,
    error: "",
  }
}

///|
async fn handle_workspace_git_projection(
  workspace_root : String,
  workspace_id : String,
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
  send_json(
    conn,
    method_,
    read_git_repository_projection(workspace.root_path).to_json(),
  )
}

///|
async fn handle_workspace_git_diff(
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
    Some((_, clean)) if clean != "" && clean == path =>
      send_json(
        conn,
        method_,
        read_git_diff_projection(workspace.root_path, clean).to_json(),
      )
    _ => send_api_error(conn, method_, 400, "Bad Request", "Invalid file path")
  }
}
