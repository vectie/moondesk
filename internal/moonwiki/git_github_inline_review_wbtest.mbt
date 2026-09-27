///|
fn github_inline_test_with_field(
  payload : Json,
  key : String,
  value : Json,
) -> Json {
  let fields : Map[String, Json] = Map([])
  match payload {
    Object(source) =>
      for name, item in source.iter2() {
        fields[name] = item
      }
    _ => ()
  }
  fields[key] = value
  Json::object(fields)
}

///|
test "GitHub inline comment validates exact remote patch and changed line" {
  let base = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  let head = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  let patch = "@@ -4,2 +4,2 @@\n-before\n+after\n context\n"
  let file = github_inline_file_projection(
    {
      "filename": "src/main.mbt",
      "status": "modified",
      "additions": 1,
      "deletions": 1,
      "patch": patch,
    },
    base,
    head,
  ).unwrap()
  let binary = github_inline_file_projection(
    { "filename": "assets/logo.png", "status": "modified" },
    base,
    head,
  ).unwrap()
  assert_false(json_bool(binary, "commentable", default=true))
  let snapshot : Json = {
    "repository": "owner/repo",
    "number": 42,
    "branch": "feature/review",
    "head_oid": head,
    "base_oid": base,
    "files": [file],
  }
  let payload : Json = {
    "repository": "owner/repo",
    "number": 42,
    "branch": "feature/review",
    "head_oid": head,
    "base_oid": base,
    "path": "src/main.mbt",
    "digest": json_string(file, "digest", default=""),
    "hunk": "@@ -4,2 +4,2 @@",
    "side": "right",
    "line": 4,
    "body": "Check this change",
  }
  assert_true(github_inline_comment_target_valid(payload, snapshot))
  assert_false(
    github_inline_comment_target_valid(
      github_inline_test_with_field(payload, "line", 99),
      snapshot,
    ),
  )
  assert_false(
    github_inline_comment_target_valid(
      github_inline_test_with_field(payload, "digest", "sha256:old"),
      snapshot,
    ),
  )
  assert_false(
    github_inline_comment_target_valid(
      github_inline_test_with_field(
        payload, "head_oid", "dddddddddddddddddddddddddddddddddddddddd",
      ),
      snapshot,
    ),
  )
  assert_false(
    github_inline_comment_target_valid(
      github_inline_test_with_field(
        payload, "base_oid", "cccccccccccccccccccccccccccccccccccccccc",
      ),
      snapshot,
    ),
  )
  assert_false(
    github_inline_comment_target_valid(
      github_inline_test_with_field(payload, "body", "bad\u{0000}body"),
      snapshot,
    ),
  )
  assert_true(
    github_inline_comment_url_valid(
      "https://github.com/owner/repo/pull/42#discussion_r123", "owner/repo", 42,
    ),
  )
  assert_false(
    github_inline_comment_url_valid(
      "https://github.com/owner/repo/pull/42#discussion_rbad", "owner/repo", 42,
    ),
  )
}

///|
async test "GitHub line draft persists without network and discards by PR" {
  @moonlib/fsx.with_temporary_directory("moondesk-inline-draft-", root => {
    assert_eq(
      @process.collect_output("/usr/bin/git", ["init", "--quiet"], cwd=root).0,
      0,
    )
    assert_eq(
      @process.collect_output(
        "/usr/bin/git",
        ["remote", "add", "origin", "https://github.com/owner/repo.git"],
        cwd=root,
      ).0,
      0,
    )
    let payload : Json = {
      "repository": "owner/repo",
      "number": 42,
      "head_oid": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      "base_oid": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      "path": "src/main.mbt",
      "digest": "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
      "hunk": "@@ -1 +1 @@",
      "side": "right",
      "line": 1,
      "body": "Review this line",
    }
    assert_true(save_github_inline_draft(root, payload) is Ok(_))
    let restored = github_inline_drafts(root, "owner/repo")
    assert_eq(restored.length(), 1)
    assert_eq(json_string(restored[0], "body", default=""), "Review this line")
    let second = github_inline_test_with_field(payload, "side", "left")
    assert_true(save_github_inline_draft(root, second) is Ok(_))
    assert_eq(github_inline_drafts(root, "owner/repo").length(), 2)
    assert_eq(github_inline_drafts(root, "other/repo").length(), 0)
    let malformed = github_inline_test_with_field(
      payload, "body", "bad\u{0000}body",
    )
    assert_true(save_github_inline_draft(root, malformed) is Err(_))
    let discard = github_inline_test_with_field(payload, "body", "")
    assert_true(save_github_inline_draft(root, discard) is Ok(_))
    let remaining = github_inline_drafts(root, "owner/repo")
    assert_eq(remaining.length(), 1)
    assert_eq(json_string(remaining[0], "side", default=""), "left")
    let discard_second = github_inline_test_with_field(second, "body", "")
    assert_true(save_github_inline_draft(root, discard_second) is Ok(_))
    assert_eq(github_inline_drafts(root, "owner/repo").length(), 0)
  })
}
