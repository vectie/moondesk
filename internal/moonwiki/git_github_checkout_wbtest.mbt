///|
test "PR checkout requires exact repository and open head before worktree creation" {
  let oid = "0123456789abcdef0123456789abcdef01234567"
  let request : Json = {
    "repository": "owner/repo",
    "number": 42,
    "head_oid": oid,
  }
  let live : Json = {
    "number": 42,
    "state": "open",
    "head": { "sha": oid },
    "base": { "repo": { "full_name": "owner/repo" } },
  }
  assert_true(github_checkout_request_valid(request, "owner/repo"))
  assert_false(github_checkout_request_valid(request, "other/repo"))
  assert_true(github_checkout_live_pull_valid(live, "owner/repo", 42, oid))
  assert_false(github_checkout_live_pull_valid(live, "owner/repo", 43, oid))
  assert_false(
    github_checkout_live_pull_valid(
      live, "owner/repo", 42, "ffffffffffffffffffffffffffffffffffffffff",
    ),
  )
  assert_false(github_checkout_live_pull_valid(live, "other/repo", 42, oid))
  assert_eq(github_checkout_folder_name(42, oid), "code-pr-42-01234567")
}

///|
async test "isolated PR worktree leaves dirty source files in place" {
  @moonlib/fsx.with_temporary_directory("moondesk-pr-worktree-", root => {
    let source = @pathx.join(root, "source")
    let target = @pathx.join(root, "code-pr-42-01234567")
    @fsx.make_directory(source, recursive=true, exists_ok=true)
    assert_eq(
      @process.collect_output("/usr/bin/git", ["init", "--quiet"], cwd=source).0,
      0,
    )
    @fsx.write_to_file(@pathx.join(source, "file.txt"), "base\n", create=0o600)
    assert_eq(
      @process.collect_output("/usr/bin/git", ["add", "file.txt"], cwd=source).0,
      0,
    )
    assert_eq(
      @process.collect_output(
        "/usr/bin/git",
        [
          "-c", "user.name=Test", "-c", "user.email=test@local", "commit", "--quiet",
          "-m", "base",
        ],
        cwd=source,
      ).0,
      0,
    )
    let head = git_projection_command(source, @trusted_host.git_head())
      .unwrap()
      .trim()
      .to_owned()
    @fsx.write_to_file(
      @pathx.join(source, "file.txt"),
      "unsaved\n",
      create=0o600,
    )
    assert_true(@trusted_host.git_add_pr_worktree(source, root, target, head))
    assert_eq(
      git_projection_command(target, @trusted_host.git_head())
      .unwrap()
      .trim()
      .to_owned(),
      head,
    )
    assert_true(github_checkout_existing_worktree_matches(source, target, head))
    assert_false(
      github_checkout_existing_worktree_matches(
        source, target, "ffffffffffffffffffffffffffffffffffffffff",
      ),
    )
    assert_eq(
      git_projection_command(source, @trusted_host.git_status()).unwrap(),
      " M file.txt\u{0000}",
    )
  })
}
