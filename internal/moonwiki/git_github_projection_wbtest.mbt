///|
test "GitHub PR comment target is bound to the discovered repository and exact HEAD" {
  let head = "0123456789abcdef0123456789abcdef01234567"
  let payload : Json = {
    "repository": "owner/repo",
    "branch": "feature/review",
    "number": 42,
    "head_oid": head,
    "body": "Please review the failure path.",
  }
  assert_true(
    github_comment_target_valid(payload, "owner/repo", "feature/review", head),
  )
  assert_false(
    github_comment_target_valid(payload, "other/repo", "feature/review", head),
  )
  assert_false(github_comment_target_valid(payload, "owner/repo", "main", head))
  assert_false(
    github_comment_target_valid(
      payload, "owner/repo", "feature/review", "ffffffffffffffffffffffffffffffffffffffff",
    ),
  )
  assert_false(
    github_comment_target_valid(
      {
        "repository": "owner/repo",
        "branch": "feature/review",
        "number": 0,
        "head_oid": head,
        "body": "A note",
      },
      "owner/repo",
      "feature/review",
      head,
    ),
  )
  assert_false(
    github_comment_target_valid(
      {
        "repository": "owner/repo",
        "branch": "feature/review",
        "number": 42,
        "head_oid": head,
        "body": "before\u{0000}after",
      },
      "owner/repo",
      "feature/review",
      head,
    ),
  )
  assert_true(
    github_comment_url_valid(
      "https://github.com/owner/repo/issues/42#issuecomment-17", "owner/repo", 42,
    ),
  )
  assert_true(
    github_comment_url_valid(
      "https://github.com/owner/repo/pull/42#issuecomment-17", "owner/repo", 42,
    ),
  )
  assert_false(
    github_comment_url_valid(
      "https://github.com/other/repo/issues/42#issuecomment-17", "owner/repo", 42,
    ),
  )
  let pull : Json = {
    "state": "open",
    "head": { "ref": "feature/review", "sha": head },
  }
  assert_true(github_pull_head_matches(pull, "feature/review", head))
  assert_true(github_pull_head_matches(pull, "", head))
  assert_false(github_pull_head_matches(pull, "main", head))
  assert_false(
    github_pull_head_matches(
      pull, "feature/review", "ffffffffffffffffffffffffffffffffffffffff",
    ),
  )
}

///|
async test "GitHub PR conversation draft survives reload and can be discarded" {
  @moonlib/fsx.with_temporary_directory("moondesk-github-draft-", root => {
    let initialized = @process.collect_output(
      "/usr/bin/git",
      ["init", "--quiet"],
      cwd=root,
    )
    assert_eq(initialized.0, 0)
    let remote = @process.collect_output(
      "/usr/bin/git",
      ["remote", "add", "origin", "https://github.com/owner/repo.git"],
      cwd=root,
    )
    assert_eq(remote.0, 0)
    let payload : Json = {
      "repository": "owner/repo",
      "number": 42,
      "head_oid": "0123456789abcdef0123456789abcdef01234567",
      "body": "Review the failure path",
    }
    assert_true(save_github_comment_draft(root, payload) is Ok(_))
    let restored = github_comment_drafts(root, "owner/repo")
    assert_eq(restored.length(), 1)
    assert_eq(
      json_string(restored[0], "body", default=""),
      "Review the failure path",
    )
    assert_eq(github_comment_drafts(root, "other/repo").length(), 0)
    let malformed : Json = {
      "repository": "owner/repo",
      "number": 42,
      "head_oid": "0123456789abcdef0123456789abcdef01234567",
      "body": 17,
    }
    assert_true(save_github_comment_draft(root, malformed) is Err(_))
    let nul_body : Json = {
      "repository": "owner/repo",
      "number": 42,
      "head_oid": "0123456789abcdef0123456789abcdef01234567",
      "body": "before\u{0000}after",
    }
    assert_true(save_github_comment_draft(root, nul_body) is Err(_))
    assert_eq(github_comment_drafts(root, "owner/repo").length(), 1)
    let discard : Json = {
      "repository": "owner/repo",
      "number": 42,
      "head_oid": "0123456789abcdef0123456789abcdef01234567",
      "body": "",
    }
    assert_true(save_github_comment_draft(root, discard) is Ok(_))
    assert_eq(github_comment_drafts(root, "owner/repo").length(), 0)
  })
}
