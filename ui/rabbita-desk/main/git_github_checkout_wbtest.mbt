///|
#warnings("-alert_unstable")
test "PR checkout uses exact remote head and exposes an isolated MoonBook" {
  let head = "0123456789abcdef0123456789abcdef01234567"
  let repository : GitRepositoryProjection = {
    state: "ready",
    branch: "main",
    head: "ffffffffffffffffffffffffffffffffffffffff",
    has_remote: true,
    changes: [],
    truncated: false,
    error: "",
  }
  let context : GitHubContextProjection = {
    state: "ready",
    repository: "owner/repo",
    branch: "main",
    pull_requests: [
      {
        number: 42,
        title: "Review",
        url: "https://github.com/owner/repo/pull/42",
        head_oid: head,
        base_oid: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        head_matches: false,
        draft: false,
        review_decision: "",
        checks: [],
        closing_issues: [],
      },
    ],
    drafts: [],
    inline_drafts: [],
    error: "",
  }
  let source = @desk.workspace(
    id="book-a",
    name="Source",
    root_path="/tmp/books/source",
    kind=MoonBook,
  )
  let target = @desk.workspace(
    id="pr-book",
    name="PR #42",
    root_path="/tmp/books/code-pr-42-01234567",
    kind=MoonBook,
  )
  let model = {
    ..init_model(),
    selected_workspace_id: "book-a",
    workspaces: [source],
    git_projection_workspace_id: "book-a",
    git_projection: Some(repository),
    github_context: Some(context),
  }
  let (_, pending) = update_mooncode_actions(
    code_mode_test_dispatch,
    CheckoutGitHubPull(42),
    model,
  )
  assert_true(pending.github_checkout_pending)
  let pending_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_github_context(code_mode_test_dispatch, pending, "main"),
    ),
  )
  assert_true(pending_markup.contains("Creating an isolated PR worktree"))
  let receipt : GitHubCheckoutProjection = {
    contract: "moondesk.github_checkout.v1",
    repository: "owner/repo",
    number: 42,
    head_oid: head,
    workspace: target,
  }
  let (_, stale) = update_mooncode_actions(
    code_mode_test_dispatch,
    CheckedOutGitHubPull(
      "book-a",
      42,
      "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      Ok(receipt),
    ),
    pending,
  )
  assert_true(stale.github_checkout_pending)
  let (_, failed) = update_mooncode_actions(
    code_mode_test_dispatch,
    CheckedOutGitHubPull("book-a", 42, head, Err("GitHub timed out")),
    pending,
  )
  assert_false(failed.github_checkout_pending)
  let failed_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_github_context(code_mode_test_dispatch, failed, "main"),
    ),
  )
  assert_true(
    failed_markup.contains("data-i18n=\"code.github_checkout_failed\""),
  )
  assert_true(failed_markup.contains("GitHub timed out"))
  assert_true(failed_markup.contains("Open isolated worktree"))
  let (_, retrying) = update_mooncode_actions(
    code_mode_test_dispatch,
    CheckoutGitHubPull(42),
    failed,
  )
  assert_true(retrying.github_checkout_pending)
  assert_eq(retrying.github_checkout_head_oid, head)
  let (_, ready) = update_mooncode_actions(
    code_mode_test_dispatch,
    CheckedOutGitHubPull("book-a", 42, head, Ok(receipt)),
    pending,
  )
  assert_false(ready.github_checkout_pending)
  assert_true(has_workspace(ready.workspaces, "pr-book"))
  assert_eq(ready.github_checkout_target_workspace_id, "pr-book")
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_github_context(code_mode_test_dispatch, ready, "main"),
    ),
  )
  assert_true(markup.contains("Open PR MoonBook"))
  assert_true(markup.contains("Open isolated worktree"))
  assert_true(markup.contains("data-i18n=\"code.github_checkout\""))
}
