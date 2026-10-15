///|
fn parse_git_history(text : String, offset : Int) -> Json {
  let fields = text.split("\u0000").to_array()
  let commits : Array[Json] = []
  let mut index = 0
  while index + 4 < fields.length() {
    let oid = fields[index].trim().to_owned()
    if oid != "" {
      commits.push({
        "oid": oid,
        "parents": fields[index + 1].to_owned(),
        "author": fields[index + 2].to_owned(),
        "date": fields[index + 3].to_owned(),
        "subject": fields[index + 4].to_owned(),
      })
    }
    index += 5
  }
  let more = commits.length() > 40
  if more {
    let _ = commits.pop()
  }
  {
    "commits": Json::array(commits),
    "has_more": more,
    "next_offset": offset + commits.length(),
  }
}

///|
async fn read_git_review_threads(
  root : String,
  number : Int,
  cursor : String,
) -> Result[Json, String] {
  let repository = match github_repository_for_workspace(root) {
    Some(value) => value
    None => return Err("This book has no GitHub repository")
  }
  let response = match
    @trusted_host.github_request(
      root,
      @trusted_host.github_review_threads(repository, number, cursor),
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let value = @json.parse(response) catch {
    _ => return Err("GitHub returned an unreadable discussion")
  }
  if json_object_field(value, "errors") is Some(_) {
    return Err(
      "GitHub could not load this discussion. Check the pull request and try again.",
    )
  }
  match value {
    {
      "data": { "repository": { "pullRequest": Object(_) as pull, .. }, .. },
      ..
    } => Ok(pull)
    _ => Err("Pull request not found")
  }
}

///|
async fn handle_workspace_git_workflow(
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
  let root = workspace.root_path
  let result : Result[Json, String] = if method_ is Post {
    match read_json_body(body) {
      None => Err("Invalid request")
      Some(payload) => {
        let action = json_string(payload, "action", default="")
        if action == "worktree" {
          let branch = json_string(payload, "value", default="")
            .trim()
            .to_owned()
          let folder = @desk.stable_id("code-worktree", root + "/" + branch)
          let target = @pathx.join(
            workspace_context(workspace_root).books_root,
            folder,
          )
          match @trusted_host.git_create_worktree(root, target, branch) {
            Err(error) =>
              send_api_error(conn, method_, 400, "Bad Request", error)
            Ok(_) => {
              let mut id = ""
              for book in discover_workspaces(workspace_root) {
                if book.root_path == target {
                  id = book.id
                }
              }
              send_json(conn, method_, {
                "state": "saved",
                "workspace_id": id,
                "path": target,
                "branch": branch,
              })
            }
          }
          return
        }
        if action == "stage" ||
          action == "unstage" ||
          action == "commit" ||
          action == "switch" ||
          action == "branch" {
          match
            @trusted_host.git_workflow_change(
              root,
              action,
              json_string(payload, "value", default=""),
            ) {
            Ok(output) =>
              send_json(conn, method_, { "state": "saved", "output": output })
            Err(error) =>
              send_api_error(conn, method_, 400, "Bad Request", error)
          }
          return
        }
        let thread_id = json_string(payload, "thread_id", default="")
        let operation = if action == "reply" {
          Some(
            @trusted_host.github_reply_thread(
              thread_id,
              json_string(payload, "body", default=""),
            ),
          )
        } else if action == "resolve" {
          Some(
            @trusted_host.github_resolve_thread(
              thread_id,
              json_bool(payload, "resolved", default=true),
            ),
          )
        } else if action == "comment" {
          match github_repository_for_workspace(root) {
            Some(repository) =>
              Some(
                @trusted_host.github_post_pr_comment(
                  repository,
                  json_int(payload, "number", default=0),
                  json_string(payload, "body", default=""),
                ),
              )
            None => None
          }
        } else {
          None
        }
        match operation {
          None => Err("Unknown discussion action")
          Some(operation) =>
            match @trusted_host.github_request(root, operation) {
              Err(error) => Err(error)
              Ok(response) => {
                let value = @json.parse(response) catch { _ => Json::null() }
                if json_object_field(value, "errors") is Some(_) ||
                  value == Json::null() {
                  Err(
                    "GitHub could not save this change. Your reply is kept for retry.",
                  )
                } else {
                  Ok({ "state": "saved" })
                }
              }
            }
        }
      }
    }
  } else {
    let action = query_value(request_path, "action").unwrap_or("history")
    if action == "workspace" {
      let branches = @trusted_host.git_read(
        root,
        @trusted_host.git_review_branches(),
      ).unwrap_or("")
      let worktrees = @trusted_host.git_read(
        root,
        @trusted_host.git_review_worktrees(),
      ).unwrap_or("")
      let records : Array[Json] = []
      let books = discover_workspaces(workspace_root)
      for block in worktrees.split("\n\n") {
        let mut path = ""
        let mut branch = ""
        for line in block.split("\n") {
          if line.has_prefix("worktree ") {
            path = line[9:].to_owned()
          }
          if line.has_prefix("branch refs/heads/") {
            branch = line[18:].to_owned()
          }
        }
        if path == "" {
          continue
        }
        let mut id = ""
        for book in books {
          if book.root_path == path {
            id = book.id
          }
        }
        records.push({
          "path": path,
          "branch": branch,
          "workspace_id": id,
          "current": path == root,
        })
      }
      Ok({
        "branches": Json::array(
          branches
          .split("\n")
          .filter(v => v != "")
          .map(v => Json::string(v.to_owned()))
          .to_array(),
        ),
        "worktrees": Json::array(records),
        "repository": read_git_repository_projection(root).to_json(),
      })
    } else if action == "finding-diff" {
      let base = query_value(request_path, "base").unwrap_or("")
      let path = decode_query_value(
        query_value(request_path, "path").unwrap_or(""),
      )
      match
        @trusted_host.git_read(root, @trusted_host.git_finding_diff(base, path)) {
        Ok(value) => Ok({ "body": value })
        Err(error) =>
          Err(
            "The reviewed revision may not be available in this worktree. Open the PR worktree or fetch its branch, then retry. " +
            error,
          )
      }
    } else if action == "compare" {
      let base = decode_query_value(
        query_value(request_path, "base").unwrap_or(""),
      )
      match @trusted_host.git_read(root, @trusted_host.git_compare_base(base)) {
        Ok(value) => Ok({ "body": value })
        Err(error) => Err(error)
      }
    } else if action == "structure" {
      let oid = query_value(request_path, "oid").unwrap_or("")
      let path = decode_query_value(
        query_value(request_path, "path").unwrap_or(""),
      )
      let previous_path = decode_query_value(
        query_value(request_path, "previous_path").unwrap_or(path),
      )
      let before = @trusted_host.git_read(
        root,
        @trusted_host.git_revision_file(
          oid,
          if previous_path == "" {
            path
          } else {
            previous_path
          },
          true,
        ),
      ).unwrap_or("")
      let after = @trusted_host.git_read(
        root,
        @trusted_host.git_revision_file(oid, path, false),
      ).unwrap_or("")
      Ok({ "before": before, "after": after })
    } else if action == "history" {
      let offset = @string.parse_int(
        query_value(request_path, "offset").unwrap_or("0"),
      ) catch {
        _ => 0
      }
      match
        @trusted_host.git_read(root, @trusted_host.git_history(offset.max(0))) {
        Ok(value) => Ok(parse_git_history(value, offset.max(0)))
        Err(error) => Err(error)
      }
    } else if action == "commit" {
      let oid = query_value(request_path, "oid").unwrap_or("")
      match @trusted_host.git_read(root, @trusted_host.git_commit_diff(oid)) {
        Ok(value) => Ok({ "oid": oid, "body": value })
        Err(error) => Err(error)
      }
    } else if action == "discussions" {
      let number = @string.parse_int(
        query_value(request_path, "number").unwrap_or("0"),
      ) catch {
        _ => 0
      }
      let cursor = decode_query_value(
        query_value(request_path, "cursor").unwrap_or(""),
      )
      read_git_review_threads(root, number, cursor)
    } else {
      Err("Unknown review view")
    }
  }
  match result {
    Ok(value) => send_json(conn, method_, value)
    Err(error) => send_api_error(conn, method_, 400, "Bad Request", error)
  }
}
