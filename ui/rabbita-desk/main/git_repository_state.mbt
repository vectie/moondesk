///|
struct GitChangeProjection {
  path : String
  previous_path : String
  index_status : String
  worktree_status : String
} derive(FromJson)

///|
struct GitRepositoryProjection {
  state : String
  branch : String
  head : String
  has_remote : Bool
  changes : Array[GitChangeProjection]
  truncated : Bool
  error : String
} derive(FromJson)

///|
struct GitDiffProjection {
  state : String
  path : String
  previous_path : String
  head : String
  body : String
  digest : String
  error : String
} derive(FromJson)

///|
struct GitReviewRecord {
  path : String?
  kind : String
  action : String
  hunk : String
  side : String?
  line : Int?
  note : String
} derive(FromJson)

///|
struct GitReviewProjection {
  path : String
  head : String
  digest : String
  diff_state : String
  records : Array[GitReviewRecord]
  stale_records : Array[GitReviewRecord]
  stale_count : Int
} derive(FromJson)

///|
struct GitReviewFileProgress {
  path : String
  status : String
} derive(FromJson)

///|
struct GitReviewProgress {
  state : String
  head : String
  total : Int
  reviewed : Int
  needs_changes : Int
  pending : Int
  truncated : Bool
  files : Array[GitReviewFileProgress]
} derive(FromJson)

///|
fn fetch_git_review_progress_cmd(
  dispatch : Dispatch[Msg],
  workspace_id : String,
  generation : Int,
  head : String,
) -> @rabbita.Cmd {
  let url = @desk.desktop_api_url([
    "api", "workspaces", workspace_id, "git", "review", "progress",
  ])
  @http.get(url).expect_json(result => {
    let decoded : Result[GitReviewProgress, String] = match result {
      Ok(payload) =>
        Ok(@json.from_json(payload)) catch {
          _ => Err("Review progress response is unreadable")
        }
      Err(error) => Err(error.to_string())
    }
    dispatch(LoadedGitReviewProgress(workspace_id, generation, head, decoded))
  })
}

///|
struct GitHubCheckProjection {
  name : String
  status : String
  conclusion : String
} derive(FromJson)

///|
struct GitHubIssueProjection {
  number : Int
  title : String
  url : String
} derive(FromJson)

///|
struct GitHubPullProjection {
  number : Int
  title : String
  url : String
  head_oid : String
  base_oid : String
  head_matches : Bool
  draft : Bool
  review_decision : String
  checks : Array[GitHubCheckProjection]
  closing_issues : Array[GitHubIssueProjection]
} derive(FromJson)

///|
struct GitHubContextProjection {
  state : String
  repository : String
  branch : String
  pull_requests : Array[GitHubPullProjection]
  drafts : Array[GitHubCommentDraftProjection]
  inline_drafts : Array[GitHubInlineDraftProjection]
  error : String
} derive(FromJson)

///|
struct GitHubCommentDraftProjection {
  number : Int
  head_oid : String
  body : String
} derive(FromJson)

///|
fn fetch_github_context_cmd(
  dispatch : Dispatch[Msg],
  workspace_id : String,
  head : String,
  branch : String,
) -> @rabbita.Cmd {
  let url = @desk.desktop_api_url([
    "api", "workspaces", workspace_id, "git", "github",
  ])
  @http.get(url).expect_json(result => {
    let decoded : Result[GitHubContextProjection, String] = match result {
      Ok(payload) =>
        Ok(@json.from_json(payload)) catch {
          _ => Err("GitHub response is unreadable")
        }
      Err(error) => Err(error.to_string())
    }
    dispatch(LoadedGitHubContext(workspace_id, head, branch, decoded))
  })
}

///|
struct GitHubInlineFileProjection {
  path : String
  previous_path : String
  status : String
  additions : Int
  deletions : Int
  patch : String
  digest : String
  commentable : Bool
} derive(FromJson)

///|
struct GitHubInlineReviewProjection {
  state : String
  repository : String
  number : Int
  branch : String
  head_oid : String
  base_oid : String
  files : Array[GitHubInlineFileProjection]
  drafts : Array[GitHubInlineDraftProjection]
  truncated : Bool
  error : String
} derive(FromJson)

///|
struct GitHubInlineDraftProjection {
  number : Int
  head_oid : String
  base_oid : String
  path : String
  digest : String
  hunk : String
  side : String
  line : Int
  body : String
} derive(FromJson)

///|
fn github_inline_same_draft_anchor(
  left : GitHubInlineDraftProjection,
  right : GitHubInlineDraftProjection,
) -> Bool {
  left.number == right.number &&
  left.head_oid == right.head_oid &&
  left.base_oid == right.base_oid &&
  left.path == right.path &&
  left.digest == right.digest &&
  left.hunk == right.hunk &&
  left.side == right.side &&
  left.line == right.line
}

///|
fn save_github_inline_draft_cmd(
  dispatch : Dispatch[Msg],
  workspace_id : String,
  repository : String,
  draft : GitHubInlineDraftProjection,
  discard : Bool,
) -> @rabbita.Cmd {
  let payload : Json = {
    "repository": repository,
    "number": draft.number,
    "head_oid": draft.head_oid,
    "base_oid": draft.base_oid,
    "path": draft.path,
    "digest": draft.digest,
    "hunk": draft.hunk,
    "side": draft.side,
    "line": draft.line,
    "body": if discard {
      ""
    } else {
      draft.body
    },
  }
  @http.post(
    @desk.desktop_api_url([
      "api", "workspaces", workspace_id, "git", "github", "inline", "draft",
    ]),
  )
  .with_json(payload)
  .expect_json(result => {
    let decoded : Result[Unit, String] = match result {
      Ok(value) =>
        if json_field_string(value, "state", default="") ==
          (if discard { "discarded" } else { "saved" }) &&
          json_field_int(value, "number", default=0) == draft.number &&
          json_field_string(value, "head_oid", default="") == draft.head_oid {
          Ok(())
        } else {
          Err(
            "Local PR line draft response is unreadable. Your text remains here.",
          )
        }
      Err(error) => Err(error.to_string())
    }
    dispatch(
      SavedGitHubInlineDraft(
        workspace_id,
        draft.number,
        draft.head_oid,
        discard,
        decoded,
      ),
    )
  })
}

///|
fn fetch_github_inline_review_cmd(
  dispatch : Dispatch[Msg],
  workspace_id : String,
  number : Int,
  head : String,
) -> @rabbita.Cmd {
  let url = @desk.desktop_api_url(
    ["api", "workspaces", workspace_id, "git", "github", "inline"],
    query=[("number", number.to_string())],
  )
  @http.get(url).expect_json(result => {
    let decoded : Result[GitHubInlineReviewProjection, String] = match result {
      Ok(payload) =>
        Ok(@json.from_json(payload)) catch {
          _ => Err("GitHub PR file response is unreadable")
        }
      Err(error) => Err(error.to_string())
    }
    dispatch(LoadedGitHubInlineReview(workspace_id, number, head, decoded))
  })
}

///|
fn github_publication_error(response : Json) -> String {
  let message = json_field_string(response, "error", default="").trim()
  if message != "" && message.length() <= 500 {
    message.to_owned()
  } else {
    "Publication response is uncertain. Check the PR before retrying."
  }
}

///|
fn publish_github_inline_comment_cmd(
  dispatch : Dispatch[Msg],
  workspace_id : String,
  review : GitHubInlineReviewProjection,
  file : GitHubInlineFileProjection,
  hunk : String,
  side : String,
  line : Int,
  body : String,
) -> @rabbita.Cmd {
  let payload : Json = {
    "repository": review.repository,
    "number": review.number,
    "branch": review.branch,
    "head_oid": review.head_oid,
    "base_oid": review.base_oid,
    "path": file.path,
    "digest": file.digest,
    "hunk": hunk,
    "side": side,
    "line": line,
    "body": body,
  }
  @http.post(
    @desk.desktop_api_url([
      "api", "workspaces", workspace_id, "git", "github", "inline",
    ]),
  )
  .with_json(payload)
  .expect_json(result => {
    let decoded : Result[String, String] = match result {
      Ok(value) =>
        if json_field_string(value, "state", default="") == "published" &&
          json_field_int(value, "number", default=0) == review.number &&
          json_field_string(value, "head_oid", default="") == review.head_oid &&
          json_field_string(value, "path", default="") == file.path &&
          json_field_int(value, "line", default=0) == line {
          Ok(json_field_string(value, "url", default=""))
        } else {
          Err(github_publication_error(value))
        }
      Err(error) => Err(error.to_string())
    }
    dispatch(
      PublishedGitHubInlineComment(
        workspace_id,
        review.number,
        review.head_oid,
        file.path,
        decoded,
      ),
    )
  })
}

///|
fn publish_github_comment_cmd(
  dispatch : Dispatch[Msg],
  workspace_id : String,
  repository : String,
  branch : String,
  number : Int,
  head : String,
  body : String,
) -> @rabbita.Cmd {
  let payload : Json = {
    "repository": repository,
    "branch": branch,
    "number": number,
    "head_oid": head,
    "body": body,
  }
  @http.post(
    @desk.desktop_api_url([
      "api", "workspaces", workspace_id, "git", "github", "comment",
    ]),
  )
  .with_json(payload)
  .expect_json(result => {
    let decoded : Result[String, String] = match result {
      Ok(value) =>
        if json_field_string(value, "state", default="") == "published" &&
          json_field_string(value, "head_oid", default="") == head &&
          json_field_int(value, "number", default=0) == number {
          Ok(json_field_string(value, "url", default=""))
        } else {
          Err(github_publication_error(value))
        }
      Err(error) => Err(error.to_string())
    }
    dispatch(PublishedGitHubComment(workspace_id, number, head, decoded))
  })
}

///|
fn save_github_comment_draft_cmd(
  dispatch : Dispatch[Msg],
  workspace_id : String,
  repository : String,
  number : Int,
  head : String,
  body : String,
  discard : Bool,
) -> @rabbita.Cmd {
  let payload : Json = {
    "repository": repository,
    "number": number,
    "head_oid": head,
    "body": if discard {
      ""
    } else {
      body
    },
  }
  @http.post(
    @desk.desktop_api_url([
      "api", "workspaces", workspace_id, "git", "github", "draft",
    ]),
  )
  .with_json(payload)
  .expect_json(result => {
    let decoded : Result[Unit, String] = match result {
      Ok(value) =>
        if json_field_string(value, "state", default="") ==
          (if discard { "discarded" } else { "saved" }) &&
          json_field_int(value, "number", default=0) == number &&
          json_field_string(value, "head_oid", default="") == head {
          Ok(())
        } else {
          Err("Local PR draft response is unreadable. Your text remains here.")
        }
      Err(error) => Err(error.to_string())
    }
    dispatch(
      SavedGitHubCommentDraft(workspace_id, number, head, discard, decoded),
    )
  })
}

///|
fn fetch_git_review_cmd(
  dispatch : Dispatch[Msg],
  workspace_id : String,
  path : String,
  digest : String,
) -> @rabbita.Cmd {
  let url = @desk.desktop_api_url(
    ["api", "workspaces", workspace_id, "git", "review"],
    query=[("path", path)],
  )
  @http.get(url).expect_json(result => {
    let decoded : Result[GitReviewProjection, String] = match result {
      Ok(payload) =>
        Ok(@json.from_json(payload)) catch {
          _ => Err("Review response is unreadable")
        }
      Err(error) => Err(error.to_string())
    }
    dispatch(LoadedGitReview(workspace_id, path, digest, decoded))
  })
}

///|
fn save_git_review_cmd(
  dispatch : Dispatch[Msg],
  workspace_id : String,
  diff : GitDiffProjection,
  action : String,
  note : String,
  hunk : String,
  side : String,
  line : Int,
) -> @rabbita.Cmd {
  let payload : Json = {
    "path": diff.path,
    "head": diff.head,
    "digest": diff.digest,
    "action": action,
    "note": note,
    "hunk": hunk,
    "side": side,
    "line": line,
  }
  @http.post(
    @desk.desktop_api_url(["api", "workspaces", workspace_id, "git", "review"]),
  )
  .with_json(payload)
  .expect_json(result => {
    let decoded : Result[Unit, String] = match result {
      Ok(value) => git_review_save_ack(value, diff, action)
      Err(error) => Err(error.to_string())
    }
    dispatch(SavedGitReview(workspace_id, diff.path, diff.digest, decoded))
  })
}

///|
fn git_review_save_ack(
  value : Json,
  diff : GitDiffProjection,
  action : String,
) -> Result[Unit, String] {
  if json_field_string(value, "path", default="") == diff.path &&
    json_field_string(value, "digest", default="") == diff.digest &&
    json_field_string(value, "action", default="") == action &&
    json_field_string(value, "authority", default="") == "local" {
    Ok(())
  } else {
    let problem = match value {
      Object(fields) =>
        match fields.get("error") {
          Some(error) => json_field_string(error, "message", default="")
          None => ""
        }
      _ => ""
    }
    Err(
      if problem == "" {
        "Review could not be saved. Refresh its diff; your note is still here."
      } else {
        problem
      },
    )
  }
}

///|
fn git_diff_hunk_start(header : String, side : String) -> Int {
  let parts = header.split(" ").to_array()
  if parts.length() < 3 || parts[0] != "@@" {
    return 0
  }
  let marker = if side == "left" { "-" } else { "+" }
  let span = if side == "left" { parts[1] } else { parts[2] }
  if !span.has_prefix(marker) {
    return 0
  }
  let start = span.strip_prefix(marker).unwrap_or("").split(",").to_array()[0]
  @string.parse_int(start.to_owned()) catch {
    _ => 0
  }
}

///|
// Split display hunks without changing the complete patch in the response.
// Rename and mode headers remain attached to the first hunk.
fn git_diff_hunks(body : String) -> Array[Array[String]] {
  let hunks : Array[Array[String]] = []
  let mut current : Array[String] = []
  let mut started_hunk = false
  for raw in body.split("\n") {
    let line = raw.to_owned()
    if line == "" ||
      line.has_prefix("diff --git") ||
      line.has_prefix("index ") ||
      line.has_prefix("--- a/") ||
      line == "--- /dev/null" ||
      line.has_prefix("+++ b/") ||
      line == "+++ /dev/null" {
      continue
    }
    if line.has_prefix("@@") {
      if started_hunk && !current.is_empty() {
        hunks.push(current)
        current = []
      }
      started_hunk = true
    }
    current.push(line)
  }
  if !current.is_empty() {
    hunks.push(current)
  }
  if hunks.is_empty() {
    hunks.push(["No textual hunk is available for this change."])
  }
  hunks
}

///|
fn fetch_git_diff_cmd(
  dispatch : Dispatch[Msg],
  workspace_id : String,
  path : String,
  head : String,
) -> @rabbita.Cmd {
  let url = @desk.desktop_api_url(
    ["api", "workspaces", workspace_id, "git", "diff"],
    query=[("path", path)],
  )
  @http.get(url).expect_json(result => {
    let decoded : Result[GitDiffProjection, String] = match result {
      Ok(payload) =>
        Ok(@json.from_json(payload)) catch {
          _ => Err("File diff response is unreadable")
        }
      Err(error) => Err(error.to_string())
    }
    dispatch(LoadedGitDiff(workspace_id, path, head, decoded))
  })
}

///|
fn fetch_git_repository_projection_cmd(
  dispatch : Dispatch[Msg],
  workspace_id : String,
  generation : Int,
) -> @rabbita.Cmd {
  if workspace_id == "" {
    return @rabbita.none
  }
  @http.get(@desk.workspace_endpoint_url(workspace_id, "git")).expect_json(result => {
    let decoded : Result[GitRepositoryProjection, String] = match result {
      Ok(payload) =>
        Ok(@json.from_json(payload)) catch {
          _ => Err("Repository response is unreadable")
        }
      Err(error) => Err(error.to_string())
    }
    dispatch(LoadedGitRepositoryProjection(workspace_id, generation, decoded))
  })
}

///|
fn mooncode_git_workspace_id(model : Model) -> String {
  match selected_mooncode_session(model) {
    Some(session) =>
      if mooncode_session_is_general(session) {
        ""
      } else {
        session.workspace_id
      }
    None => model.selected_workspace_id
  }
}
