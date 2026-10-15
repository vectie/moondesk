///|
pub fn git_history(offset : Int) -> GitReadOperation {
  {
    args: [
      "log",
      "--max-count=41",
      "--skip=\{offset}",
      "--format=%H%x00%P%x00%an%x00%aI%x00%s%x00",
      "HEAD",
      "--",
    ],
    valid: offset >= 0,
    allow_diff_exit: false,
  }
}

///|
pub fn git_review_branches() -> GitReadOperation {
  {
    args: [
      "for-each-ref", "--format=%(refname:short)", "refs/heads", "refs/remotes",
    ],
    valid: true,
    allow_diff_exit: false,
  }
}

///|
pub fn git_review_worktrees() -> GitReadOperation {
  {
    args: ["worktree", "list", "--porcelain"],
    valid: true,
    allow_diff_exit: false,
  }
}

///|
fn review_ref_valid(value : String) -> Bool {
  value != "" &&
  !value.has_prefix("-") &&
  !value.contains("\u0000") &&
  !value.contains("\n") &&
  !value.contains("..")
}

///|
pub fn git_compare_base(base : String) -> GitReadOperation {
  {
    args: [
      "diff",
      "--no-ext-diff",
      "--no-textconv",
      "--no-color",
      "--unified=3",
      base + "...HEAD",
      "--",
    ],
    valid: review_ref_valid(base),
    allow_diff_exit: false,
  }
}

///|
pub fn git_finding_diff(base : String, path : String) -> GitReadOperation {
  {
    args: [
      "diff",
      "--no-ext-diff",
      "--no-textconv",
      "--no-color",
      base,
      "--",
      ":(literal)" + path,
    ],
    valid: safe_git_oid(base) && safe_git_relative_path(path),
    allow_diff_exit: false,
  }
}

///|
pub fn git_revision_file(
  oid : String,
  path : String,
  parent : Bool,
) -> GitReadOperation {
  {
    args: ["show", oid + (if parent { "^" } else { "" }) + ":" + path],
    valid: safe_git_oid(oid) && safe_git_relative_path(path),
    allow_diff_exit: false,
  }
}

///|
pub async fn git_workflow_change(
  root : String,
  action : String,
  value : String,
) -> Result[String, String] {
  let args = match action {
    "stage" if safe_git_relative_path(value) =>
      ["add", "--", ":(literal)" + value]
    "unstage" if safe_git_relative_path(value) =>
      ["restore", "--staged", "--", ":(literal)" + value]
    "commit" if value.trim() != "" => ["commit", "-m", value]
    "switch" if review_ref_valid(value) => ["switch", value]
    "branch" if review_ref_valid(value) => ["switch", "-c", value]
    _ => return Err("Choose a file, branch or commit message first")
  }
  let output = @async.with_timeout(30000, () => {
    @process.collect_output("/usr/bin/git", args, cwd=root, extra_env={
      "GIT_TERMINAL_PROMPT": "0",
      "GIT_PAGER": "cat",
    })
  }) catch {
    _ =>
      return Err(
        "Git is still busy. Refresh the repository before trying again.",
      )
  }
  if output.0 != 0 {
    return Err(
      output.2.text() catch {
        _ => "Git could not complete this action"
      },
    )
  }
  Ok(output.1.text() catch { _ => "Git action completed" })
}

///|
pub async fn git_create_worktree(
  root : String,
  target : String,
  branch : String,
) -> Result[String, String] {
  if !safe_absolute_path(root) ||
    !safe_absolute_path(target) ||
    !review_ref_valid(branch) {
    return Err("Enter a branch name for the worktree")
  }
  let output = @async.with_timeout(30000, () => {
    @process.collect_output(
      "/usr/bin/git",
      ["worktree", "add", "-b", branch, target, "HEAD"],
      cwd=root,
      extra_env={ "GIT_TERMINAL_PROMPT": "0" },
    )
  }) catch {
    _ => return Err("Worktree creation is still busy. Refresh before retrying.")
  }
  if output.0 != 0 {
    return Err(output.2.text() catch { _ => "Could not create the worktree" })
  }
  Ok(target)
}

///|
pub fn git_commit_diff(oid : String) -> GitReadOperation {
  {
    args: [
      "-c", "core.quotePath=false", "show", "--format=", "--first-parent", "--root",
      "--no-ext-diff", "--no-textconv", "--no-color", "--unified=3", oid, "--",
    ],
    valid: safe_git_oid(oid),
    allow_diff_exit: false,
  }
}

///|
pub fn github_review_threads(
  repository : String,
  number : Int,
  cursor : String,
) -> GitHubOperation {
  let parts = repository.split("/").to_array()
  let owner = parts.get(0).map(v => v.to_owned()).unwrap_or("")
  let name = parts.get(1).map(v => v.to_owned()).unwrap_or("")
  let args = [
    "api",
    "graphql",
    "-f",
    "query=query($owner:String!,$name:String!,$number:Int!,$cursor:String){repository(owner:$owner,name:$name){pullRequest(number:$number){url title headRefOid comments(last:50){pageInfo{hasPreviousPage} nodes{body url createdAt author{login}}} reviewThreads(first:40,after:$cursor){pageInfo{hasNextPage endCursor} nodes{id isResolved isOutdated path line originalLine comments(first:50){pageInfo{hasNextPage} nodes{id body url createdAt author{login}}}}}}}}",
    "-f",
    "owner=" + owner,
    "-f",
    "name=" + name,
    "-F",
    "number=\{number}",
  ]
  if cursor != "" {
    args.push("-f")
    args.push("cursor=" + cursor)
  }
  {
    args,
    valid: safe_github_repository(repository) && safe_pr_number(number),
    timeout_ms: 12000,
  }
}

///|
pub fn github_reply_thread(
  thread_id : String,
  body : String,
) -> GitHubOperation {
  {
    args: [
      "api",
      "graphql",
      "-f",
      "query=mutation($id:ID!,$body:String!){addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$id,body:$body}){comment{id url}}}",
      "-f",
      "id=" + thread_id,
      "-f",
      "body=" + body,
    ],
    valid: thread_id != "" && safe_github_body(body),
    timeout_ms: 12000,
  }
}

///|
pub fn github_resolve_thread(
  thread_id : String,
  resolved : Bool,
) -> GitHubOperation {
  let operation = if resolved {
    "resolveReviewThread"
  } else {
    "unresolveReviewThread"
  }
  {
    args: [
      "api",
      "graphql",
      "-f",
      "query=mutation($id:ID!){" +
      operation +
      "(input:{threadId:$id}){thread{id isResolved}}}",
      "-f",
      "id=" + thread_id,
    ],
    valid: thread_id != "",
    timeout_ms: 12000,
  }
}
