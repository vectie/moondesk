///|
/// A closed Git read operation. Callers choose one reviewed form; they cannot
/// pass a Git subcommand or process environment through this type.
pub struct GitReadOperation {
  args : Array[String]
  valid : Bool
  allow_diff_exit : Bool
}

///|
/// A closed GitHub request. The constructors below bind every route and
/// method; no caller receives a generic `gh api` argument capability.
pub struct GitHubOperation {
  args : Array[String]
  valid : Bool
  timeout_ms : Int
}

///|
fn safe_git_component(value : String) -> Bool {
  value != "" &&
  value != "." &&
  value != ".." &&
  value.length() <= 100 &&
  !value.has_prefix("-") &&
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
fn safe_github_repository(repository : String) -> Bool {
  let parts = repository.split("/").to_array()
  parts.length() == 2 &&
  safe_git_component(parts[0].to_owned()) &&
  safe_git_component(parts[1].to_owned())
}

///|
fn safe_git_oid(value : String) -> Bool {
  value.length() == 40 &&
  value
  .to_array()
  .all(char => (char >= '0' && char <= '9') || (char >= 'a' && char <= 'f'))
}

///|
fn safe_pr_number(number : Int) -> Bool {
  number > 0 && number <= 1_000_000_000
}

///|
fn safe_git_relative_path(path : String) -> Bool {
  if path == "" ||
    path.length() > 4096 ||
    path.has_prefix("/") ||
    path.contains("\u{0000}") ||
    path.contains("\n") ||
    path.contains("\r") {
    return false
  }
  path.split("/").all(segment => segment != "..")
}

///|
fn safe_github_body(body : String) -> Bool {
  body.trim() != "" && body.length() <= 4000 && !body.contains("\u{0000}")
}

///|
pub fn git_top_level() -> GitReadOperation {
  {
    args: ["rev-parse", "--show-toplevel"],
    valid: true,
    allow_diff_exit: false,
  }
}

///|
pub fn git_status() -> GitReadOperation {
  {
    args: ["status", "--porcelain=v1", "-z", "--untracked-files=all"],
    valid: true,
    allow_diff_exit: false,
  }
}

///|
pub fn git_branch() -> GitReadOperation {
  { args: ["branch", "--show-current"], valid: true, allow_diff_exit: false, }
}

///|
pub fn git_head() -> GitReadOperation {
  {
    args: ["rev-parse", "--verify", "HEAD"],
    valid: true,
    allow_diff_exit: false,
  }
}

///|
pub fn git_common_dir() -> GitReadOperation {
  {
    args: ["rev-parse", "--path-format=absolute", "--git-common-dir"],
    valid: true,
    allow_diff_exit: false,
  }
}

///|
pub fn git_pr_ref(number : Int, head : String) -> GitReadOperation {
  {
    args: ["rev-parse", "--verify", "refs/moondesk/pr/\{number}/\{head}"],
    valid: safe_pr_number(number) && safe_git_oid(head),
    allow_diff_exit: false,
  }
}

///|
pub fn git_remotes() -> GitReadOperation {
  { args: ["remote"], valid: true, allow_diff_exit: false, }
}

///|
pub fn git_remote_url(name : String) -> GitReadOperation {
  {
    args: ["remote", "get-url", name],
    valid: safe_git_component(name),
    allow_diff_exit: false,
  }
}

///|
pub fn git_diff_tracked(
  path : String,
  previous_path : String,
) -> GitReadOperation {
  let args = [
    "diff",
    "--no-ext-diff",
    "--no-textconv",
    "--no-color",
    "--unified=3",
    "HEAD",
    "--",
    ":(literal)" + path,
  ]
  if previous_path != "" {
    args.push(":(literal)" + previous_path)
  }
  {
    args,
    valid: safe_git_relative_path(path) &&
    (previous_path == "" || safe_git_relative_path(previous_path)),
    allow_diff_exit: false,
  }
}

///|
pub fn git_diff_untracked(path : String) -> GitReadOperation {
  {
    args: [
      "diff", "--no-index", "--no-ext-diff", "--no-textconv", "--no-color", "--unified=3",
      "--", "/dev/null", path,
    ],
    valid: safe_git_relative_path(path),
    allow_diff_exit: true,
  }
}

///|
pub async fn git_read(
  root : String,
  operation : GitReadOperation,
) -> Result[String, String] {
  if !safe_absolute_path(root) || !operation.valid {
    return Err("Git operation is outside the reviewed host boundary")
  }
  let output = @async.with_timeout(8000, () => {
    @process.collect_output(
      "/usr/bin/git",
      [
        "-c",
        "core.hooksPath=/dev/null",
        "-c",
        "core.fsmonitor=false",
        "-c",
        "diff.external=",
        ..operation.args,
      ],
      extra_env={
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
      },
      inherit_env=false,
      cwd=root,
    )
  }) catch {
    _ => return Err("Git did not respond in time")
  }
  if output.0 != 0 && !(operation.allow_diff_exit && output.0 == 1) {
    return Err("Git could not read this repository")
  }
  let content = output.1.text() catch {
    _ => return Err("Repository paths are not valid UTF-8")
  }
  if content.length() > 256 * 1024 {
    return Err("Git output exceeds the review limit")
  }
  Ok(content)
}

///|
pub async fn git_fetch_pr(
  root : String,
  remote : String,
  number : Int,
  head : String,
) -> Bool {
  if !safe_absolute_path(root) ||
    !safe_git_component(remote) ||
    !safe_pr_number(number) ||
    !safe_git_oid(head) {
    return false
  }
  let private_ref = "refs/moondesk/pr/\{number}/\{head}"
  let output = @async.with_timeout(60000, () => {
    @process.collect_output(
      "/usr/bin/git",
      [
        "-c",
        "core.hooksPath=/dev/null",
        "-c",
        "core.fsmonitor=false",
        "-c",
        "protocol.ext.allow=never",
        "fetch",
        "--quiet",
        "--no-tags",
        remote,
        "+refs/pull/\{number}/head:\{private_ref}",
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
pub async fn git_add_pr_worktree(
  root : String,
  books_root : String,
  target : String,
  head : String,
) -> Bool {
  if !safe_absolute_path(root) ||
    !safe_absolute_path(books_root) ||
    !safe_absolute_path(target) ||
    !safe_git_oid(head) ||
    path_parent(target) != books_root {
    return false
  }
  let output = @async.with_timeout(60000, () => {
    @process.collect_output(
      "/usr/bin/git",
      [
        "-c", "core.hooksPath=/dev/null", "-c", "core.fsmonitor=false", "-c", "protocol.ext.allow=never",
        "worktree", "add", "--quiet", "--detach", target, head,
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
pub fn github_list_pulls(repository : String) -> GitHubOperation {
  {
    args: [
      "pr", "list", "--repo", repository, "--state", "open", "--limit", "20", "--json",
      "number,title,url,headRefName,headRefOid,baseRefOid,isDraft,reviewDecision,statusCheckRollup,closingIssuesReferences",
    ],
    valid: safe_github_repository(repository),
    timeout_ms: 10000,
  }
}

///|
pub fn github_get_pull(repository : String, number : Int) -> GitHubOperation {
  {
    args: ["api", "repos/\{repository}/pulls/\{number}"],
    valid: safe_github_repository(repository) && safe_pr_number(number),
    timeout_ms: 12000,
  }
}

///|
pub fn github_get_pull_files(
  repository : String,
  number : Int,
  page : Int,
) -> GitHubOperation {
  {
    args: [
      "api",
      "repos/\{repository}/pulls/\{number}/files?per_page=20&page=\{page}",
    ],
    valid: safe_github_repository(repository) &&
    safe_pr_number(number) &&
    page >= 1 &&
    page <= 15,
    timeout_ms: 12000,
  }
}

///|
pub fn github_post_pr_comment(
  repository : String,
  number : Int,
  body : String,
) -> GitHubOperation {
  {
    args: [
      "api",
      "--method",
      "POST",
      "repos/\{repository}/issues/\{number}/comments",
      "-f",
      "body=" + body,
    ],
    valid: safe_github_repository(repository) &&
    safe_pr_number(number) &&
    safe_github_body(body),
    timeout_ms: 12000,
  }
}

///|
pub fn github_post_pr_line(
  repository : String,
  number : Int,
  head : String,
  path : String,
  side : String,
  line : Int,
  body : String,
) -> GitHubOperation {
  {
    args: [
      "api",
      "--method",
      "POST",
      "repos/\{repository}/pulls/\{number}/comments",
      "-f",
      "body=" + body,
      "-f",
      "commit_id=" + head,
      "-f",
      "path=" + path,
      "-f",
      "side=" + side,
      "-F",
      "line=\{line}",
    ],
    valid: safe_github_repository(repository) &&
    safe_pr_number(number) &&
    safe_git_oid(head) &&
    safe_git_relative_path(path) &&
    (side == "LEFT" || side == "RIGHT") &&
    line > 0 &&
    line <= 10_000_000 &&
    safe_github_body(body),
    timeout_ms: 12000,
  }
}

///|
pub async fn github_request(
  root : String,
  operation : GitHubOperation,
) -> Result[String, String] {
  if !safe_absolute_path(root) || !operation.valid {
    return Err("GitHub operation is outside the reviewed host boundary")
  }
  let output = @async.with_timeout(operation.timeout_ms, () => {
    @process.collect_output(
      "/usr/bin/env",
      ["gh", ..operation.args],
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
    _ => return Err("GitHub did not respond. Check connection and sign-in.")
  }
  if output.0 != 0 {
    return Err("GitHub rejected the request. Check sign-in and PR permissions.")
  }
  let content = output.1.text() catch {
    _ => return Err("GitHub response is unreadable")
  }
  if content == "" || content.length() > 256 * 1024 {
    return Err("GitHub response exceeds the display limit")
  }
  Ok(content)
}
