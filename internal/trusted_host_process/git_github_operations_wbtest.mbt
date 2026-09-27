///|
test "Git host operations reject path and ref escape" {
  assert_false(git_remote_url("-upload-pack=evil").valid)
  assert_false(git_diff_untracked("../outside").valid)
  assert_false(git_diff_tracked("src/main.mbt", "../outside").valid)
  assert_false(git_pr_ref(42, "bad-head").valid)
  assert_true(git_diff_tracked("src/main.mbt", "").valid)
}

///|
test "GitHub host operations bind repository and publish target" {
  assert_false(github_list_pulls("owner/../repo").valid)
  assert_false(github_get_pull_files("owner/repo", 42, 16).valid)
  assert_true(github_get_pull_files("owner/repo", 42, 15).valid)
  assert_false(github_post_pr_comment("owner/repo", 42, "").valid)
  assert_false(
    github_post_pr_line(
      "owner/repo", 42, "0123456789012345678901234567890123456789", "../outside",
      "RIGHT", 4, "review",
    ).valid,
  )
  assert_true(github_get_pull("owner/repo", 42).valid)
}
