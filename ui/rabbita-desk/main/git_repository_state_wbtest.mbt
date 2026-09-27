///|
#warnings("-alert_unstable")
test "Code repository context shows branch, paths, and truthful change states" {
  let projection : GitRepositoryProjection = {
    state: "ready",
    branch: "feature/workbench",
    head: "abc123",
    has_remote: false,
    changes: [
      {
        path: "src/main.mbt",
        previous_path: "",
        index_status: "M",
        worktree_status: " ",
      },
      {
        path: "src/new name.mbt",
        previous_path: "src/old.mbt",
        index_status: "R",
        worktree_status: " ",
      },
      {
        path: "src/gone.mbt",
        previous_path: "",
        index_status: "D",
        worktree_status: " ",
      },
    ],
    truncated: false,
    error: "",
  }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-a",
    git_projection_workspace_id: "book-a",
    git_projection: Some(projection),
  }
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_git_repository_context(code_mode_test_dispatch, model),
    ),
  )
  assert_true(markup.contains("feature/workbench"))
  assert_true(markup.contains("Changes · 3"))
  assert_true(markup.contains("Staged Modified"))
  assert_true(markup.contains("src/new name.mbt"))
  assert_true(markup.contains("data-action=\"git-open-source\""))
  assert_true(markup.contains("From src/old.mbt"))
  assert_true(markup.contains("data-i18n=\"code.repo_previous_path\""))
  assert_true(markup.contains("Deleted"))
  assert_true(markup.contains("Review changes to src/gone.mbt"))
  assert_true(markup.contains("3 of 3 files"))
  let (_, searched) = update_mooncode_actions(
    code_mode_test_dispatch,
    SetGitChangeQuery("NEW NAME"),
    model,
  )
  let searched_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_git_repository_context(code_mode_test_dispatch, searched),
    ),
  )
  assert_true(searched_markup.contains("1 of 3 files"))
  assert_true(searched_markup.contains("src/new name.mbt"))
  assert_false(searched_markup.contains("Review changes to src/gone.mbt"))
  let (_, reviewed_only) = update_mooncode_actions(
    code_mode_test_dispatch,
    SetGitChangeFilter("reviewed"),
    model,
  )
  let reviewed_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_git_repository_context(code_mode_test_dispatch, reviewed_only),
    ),
  )
  assert_true(reviewed_markup.contains("No changed files match"))
  let (_, rejected) = update_mooncode_actions(
    code_mode_test_dispatch,
    OpenGitChange("../../escape"),
    model,
  )
  assert_eq(rejected.source_pane.requested_path, "")
}

///|
test "GitHub publication keeps a precise stale-head rejection" {
  let response : Json = {
    "ok": false,
    "status": "error",
    "error": "The PR changed. Refresh its remote diff before posting.",
  }
  assert_eq(
    github_publication_error(response),
    "The PR changed. Refresh its remote diff before posting.",
  )
  assert_eq(
    github_publication_error({ "ok": false }),
    "Publication response is uncertain. Check the PR before retrying.",
  )
}

///|
#warnings("-alert_unstable")
test "Code diff result stays scoped to the selected file and HEAD" {
  let projection : GitRepositoryProjection = {
    state: "ready",
    branch: "main",
    head: "abc123",
    has_remote: false,
    changes: [
      {
        path: "src/main.mbt",
        previous_path: "",
        index_status: "M",
        worktree_status: " ",
      },
    ],
    truncated: false,
    error: "",
  }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-a",
    git_projection_workspace_id: "book-a",
    git_projection: Some(projection),
  }
  let (_, opened) = update_mooncode_actions(
    code_mode_test_dispatch,
    OpenGitDiff("src/main.mbt"),
    model,
  )
  assert_eq(opened.git_diff_path, "src/main.mbt")
  assert_true(opened.git_diff_loading)
  let diff : GitDiffProjection = {
    state: "ready",
    path: "src/main.mbt",
    previous_path: "",
    head: "abc123",
    body: "@@ -1 +1 @@\n-old\n+new\n@@ -10 +10 @@\n-before\n+after\n",
    digest: "sha256:test",
    error: "",
  }
  let (_, stale) = update_mooncode_actions(
    code_mode_test_dispatch,
    LoadedGitDiff("book-a", "src/main.mbt", "different", Ok(diff)),
    opened,
  )
  assert_true(stale.git_diff is None)
  let (_, loaded) = update_mooncode_actions(
    code_mode_test_dispatch,
    LoadedGitDiff("book-a", "src/main.mbt", "abc123", Ok(diff)),
    opened,
  )
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_git_repository_context(code_mode_test_dispatch, loaded),
    ),
  )
  assert_true(markup.contains("Compared with HEAD"))
  assert_true(markup.contains("Reviewing 1 of 1 changed files"))
  assert_true(markup.contains("Review previous file"))
  assert_true(markup.contains("Review next file"))
  assert_true(markup.contains("+new"))
  assert_false(markup.contains("+after"))
  assert_true(markup.contains("Hunk 1 of 2"))
  assert_true(markup.contains("mooncode-git-diff-line add"))
  assert_true(markup.contains("Select right line 1 for a review note"))
  let (_, selected_line) = update_mooncode_actions(
    code_mode_test_dispatch,
    SelectGitDiffLine("right", 1),
    loaded,
  )
  assert_eq(selected_line.git_diff_selected_line, 1)
  let selected_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_git_repository_context(code_mode_test_dispatch, selected_line),
    ),
  )
  assert_true(selected_markup.contains("Save line note"))
  let (_, second_hunk) = update_mooncode_actions(
    code_mode_test_dispatch,
    SelectGitDiffHunk(1),
    loaded,
  )
  let second_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_git_repository_context(code_mode_test_dispatch, second_hunk),
    ),
  )
  assert_true(second_markup.contains("Hunk 2 of 2"))
  assert_true(second_markup.contains("+after"))
  assert_false(second_markup.contains("+new"))
  let (_, invalid_hunk) = update_mooncode_actions(
    code_mode_test_dispatch,
    SelectGitDiffHunk(2),
    second_hunk,
  )
  assert_eq(invalid_hunk.git_diff_hunk_index, 1)
  assert_eq(second_hunk.git_diff_selected_line, 0)
  let failed_diff : GitDiffProjection = {
    state: "error",
    path: "src/main.mbt",
    previous_path: "",
    head: "abc123",
    body: "",
    digest: "",
    error: "File diff exceeds the 256 KiB review limit",
  }
  let (_, failed) = update_mooncode_actions(
    code_mode_test_dispatch,
    LoadedGitDiff("book-a", "src/main.mbt", "abc123", Ok(failed_diff)),
    opened,
  )
  let failure_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_git_repository_context(code_mode_test_dispatch, failed),
    ),
  )
  assert_true(
    failure_markup.contains("File diff exceeds the 256 KiB review limit"),
  )
  let binary_diff : GitDiffProjection = {
    state: "binary",
    path: "src/main.mbt",
    previous_path: "",
    head: "abc123",
    body: "diff --git a/src/main.mbt b/src/main.mbt\nBinary files differ\n",
    digest: "sha256:binary",
    error: "",
  }
  let (_, binary) = update_mooncode_actions(
    code_mode_test_dispatch,
    LoadedGitDiff("book-a", "src/main.mbt", "abc123", Ok(binary_diff)),
    opened,
  )
  let binary_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_git_repository_context(code_mode_test_dispatch, binary),
    ),
  )
  assert_true(binary_markup.contains("Binary change"))
  assert_true(binary_markup.contains("Mark reviewed"))
  assert_true(binary_markup.contains("Save file note"))
}

///|
test "Code repository result cannot cross workspace selection" {
  let projection : GitRepositoryProjection = {
    state: "not_repository",
    branch: "",
    head: "",
    has_remote: false,
    changes: [],
    truncated: false,
    error: "",
  }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-b",
    git_projection_workspace_id: "book-b",
  }
  let (_, next) = update_mooncode_actions(
    code_mode_test_dispatch,
    LoadedGitRepositoryProjection("book-a", 0, Ok(projection)),
    model,
  )
  assert_true(next.git_projection is None)
  assert_eq(next.git_projection_workspace_id, "book-b")
  let (_, old_generation) = update_mooncode_actions(
    code_mode_test_dispatch,
    LoadedGitRepositoryProjection("book-b", 1, Ok(projection)),
    model,
  )
  assert_true(old_generation.git_projection is None)
}

///|
#warnings("-alert_unstable")
test "review progress follows current HEAD and unsent notes block file switches" {
  let projection : GitRepositoryProjection = {
    state: "ready",
    branch: "main",
    head: "head-a",
    has_remote: false,
    changes: [
      {
        path: "a.mbt",
        previous_path: "",
        index_status: "M",
        worktree_status: " ",
      },
      {
        path: "b.mbt",
        previous_path: "",
        index_status: "M",
        worktree_status: " ",
      },
    ],
    truncated: false,
    error: "",
  }
  let progress : GitReviewProgress = {
    state: "ready",
    head: "head-a",
    total: 2,
    reviewed: 1,
    needs_changes: 0,
    pending: 1,
    truncated: false,
    files: [
      { path: "a.mbt", status: "reviewed", },
      { path: "b.mbt", status: "pending", },
    ],
  }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-a",
    git_projection_workspace_id: "book-a",
    git_projection: Some(projection),
    git_diff_workspace_id: "book-a",
    git_diff_path: "a.mbt",
    git_review_note: "Keep this note",
  }
  let (_, current) = update_mooncode_actions(
    code_mode_test_dispatch,
    LoadedGitReviewProgress("book-a", 0, "head-a", Ok(progress)),
    model,
  )
  assert_true(current.git_review_progress is Some(_))
  let complete : GitReviewProgress = {
    ..progress,
    reviewed: 2,
    pending: 0,
    files: [
      { path: "a.mbt", status: "reviewed", },
      { path: "b.mbt", status: "reviewed", },
    ],
  }
  let complete_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_git_repository_context(code_mode_test_dispatch, {
        ..current,
        git_review_progress: Some(complete),
        git_diff_path: "",
        git_review_note: "",
      }),
    ),
  )
  assert_true(complete_markup.contains("Open MoonBook review"))
  assert_true(complete_markup.contains("separate decision"))
  let (_, outdated_progress) = update_mooncode_actions(
    code_mode_test_dispatch,
    LoadedGitReviewProgress("book-a", 1, "head-a", Ok(progress)),
    { ..model, git_review_progress: None, },
  )
  assert_true(outdated_progress.git_review_progress is None)
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_git_repository_context(code_mode_test_dispatch, current),
    ),
  )
  assert_true(markup.contains("1 reviewed · 0 needs changes · 1 pending"))
  let (_, blocked) = update_mooncode_actions(
    code_mode_test_dispatch,
    OpenGitDiff("b.mbt"),
    current,
  )
  assert_eq(blocked.git_diff_path, "a.mbt")
  assert_eq(blocked.git_review_note, "Keep this note")
  let (_, closed) = update_mooncode_actions(
    code_mode_test_dispatch,
    CloseGitDiff,
    blocked,
  )
  assert_eq(closed.git_diff_path, "a.mbt")
  let (_, refreshed) = update_mooncode_actions(
    code_mode_test_dispatch,
    RefreshGitRepositoryProjection("book-a"),
    closed,
  )
  assert_eq(refreshed.git_review_note, "Keep this note")
  let (_, other_session) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    SelectMoonCodeSession("another-session"),
    refreshed,
  )
  assert_eq(other_session.git_review_note, "Keep this note")
  assert_eq(other_session.selected_mooncode_session_id, "")
  let (_, other_book) = select_workspace_action(
    code_mode_test_dispatch, "book-b", refreshed,
  )
  assert_eq(other_book.selected_workspace_id, "book-a")
  let (_, discarded) = update_mooncode_actions(
    code_mode_test_dispatch,
    SetGitReviewNote(""),
    refreshed,
  )
  let (_, opened) = update_mooncode_actions(
    code_mode_test_dispatch,
    OpenGitDiff("b.mbt"),
    discarded,
  )
  assert_eq(opened.git_diff_path, "b.mbt")
  let (_, stale) = update_mooncode_actions(
    code_mode_test_dispatch,
    LoadedGitReviewProgress("book-a", 0, "old-head", Ok(progress)),
    opened,
  )
  assert_true(stale.git_review_progress is Some(_))
}

///|
#warnings("-alert_unstable")
test "local Code review is tied to the loaded patch and preserves failed notes" {
  let diff : GitDiffProjection = {
    state: "ready",
    path: "src/main.mbt",
    previous_path: "",
    head: "head-a",
    body: "@@ -1 +1 @@\n-old\n+new\n",
    digest: "sha256:patch-a",
    error: "",
  }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-a",
    git_diff_workspace_id: "book-a",
    git_diff_path: diff.path,
    git_diff: Some(diff),
    git_review_note: "Please check this line",
  }
  let (_, saving) = update_mooncode_actions(
    code_mode_test_dispatch,
    SaveGitReview("comment"),
    model,
  )
  assert_true(saving.git_review_saving)
  let (_, failed) = update_mooncode_actions(
    code_mode_test_dispatch,
    SavedGitReview("book-a", diff.path, diff.digest, Err("stale patch")),
    saving,
  )
  assert_eq(failed.git_review_note, "Please check this line")
  assert_eq(failed.git_review_error, "stale patch")
  let (_, cannot_close_while_saving) = update_mooncode_actions(
    code_mode_test_dispatch,
    CloseGitDiff,
    saving,
  )
  assert_eq(cannot_close_while_saving.git_diff_path, diff.path)
  let review : GitReviewProjection = {
    path: diff.path,
    head: diff.head,
    digest: diff.digest,
    diff_state: "ready",
    records: [
      {
        path: None,
        kind: "decision",
        action: "reviewed",
        hunk: "",
        side: None,
        line: None,
        note: "",
      },
    ],
    stale_records: [],
    stale_count: 1,
  }
  let (_, loaded) = update_mooncode_actions(
    code_mode_test_dispatch,
    LoadedGitReview("book-a", diff.path, diff.digest, Ok(review)),
    model,
  )
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_git_review_controls(code_mode_test_dispatch, loaded, diff),
    ),
  )
  assert_true(markup.contains("Reviewed locally"))
  assert_true(markup.contains("earlier review record"))
  let (_, stale) = update_mooncode_actions(
    code_mode_test_dispatch,
    LoadedGitReview("book-a", diff.path, "sha256:other", Ok(review)),
    model,
  )
  assert_true(stale.git_review is None)
}

///|
test "Git review save accepts only the exact local record" {
  let diff : GitDiffProjection = {
    state: "ready",
    path: "code.mbt",
    previous_path: "",
    head: "head-a",
    body: "@@ -1 +1 @@\n-old\n+new\n",
    digest: "sha256:patch-a",
    error: "",
  }
  let saved : Json = {
    "path": "code.mbt",
    "digest": "sha256:patch-a",
    "action": "comment",
    "authority": "local",
  }
  assert_true(git_review_save_ack(saved, diff, "comment") is Ok(_))
  assert_true(git_review_save_ack(saved, diff, "reviewed") is Err(_))
  assert_true(
    git_review_save_ack({ "error": { "message": "conflict" } }, diff, "comment")
    is Err(_),
  )
  assert_eq(
    git_review_save_ack(
      { "error": { "message": "Invalid review record" } },
      diff,
      "comment",
    ),
    Err("Invalid review record"),
  )
}

///|
#warnings("-alert_unstable")
test "GitHub context names remote authority and refuses stale branch responses" {
  let repository : GitRepositoryProjection = {
    state: "ready",
    branch: "feature/review",
    head: "local-head",
    has_remote: true,
    changes: [],
    truncated: false,
    error: "",
  }
  let context : GitHubContextProjection = {
    state: "ready",
    repository: "vectie/moondesk",
    branch: "feature/review",
    pull_requests: [
      {
        number: 42,
        title: "Improve Code review",
        url: "https://github.com/vectie/moondesk/pull/42",
        head_oid: "remote-head",
        base_oid: "base-head",
        head_matches: false,
        draft: true,
        review_decision: "REVIEW_REQUIRED",
        checks: [{ name: "build", status: "COMPLETED", conclusion: "FAILURE", }],
        closing_issues: [
          {
            number: 21,
            title: "Review flow",
            url: "https://github.com/vectie/moondesk/issues/21",
          },
        ],
      },
    ],
    drafts: [],
    inline_drafts: [],
    error: "",
  }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-a",
    git_projection_workspace_id: "book-a",
    git_projection: Some(repository),
  }
  let (_, loaded) = update_mooncode_actions(
    code_mode_test_dispatch,
    LoadedGitHubContext("book-a", "local-head", "feature/review", Ok(context)),
    model,
  )
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_github_context(code_mode_test_dispatch, loaded, "feature/review"),
    ),
  )
  assert_true(markup.contains("PR head differs"))
  assert_true(markup.contains("1 failing of 1 checks"))
  assert_true(markup.contains("Issue #21"))
  let (_, stale) = update_mooncode_actions(
    code_mode_test_dispatch,
    LoadedGitHubContext(
      "book-a",
      "previous-head",
      "feature/review",
      Ok(context),
    ),
    model,
  )
  assert_true(stale.github_context is None)
}

///|
#warnings("-alert_unstable")
test "GitHub PR comment draft survives failed publication and rejects stale result" {
  let head = "0123456789abcdef0123456789abcdef01234567"
  let repository : GitRepositoryProjection = {
    state: "ready",
    branch: "feature/review",
    head,
    has_remote: true,
    changes: [],
    truncated: false,
    error: "",
  }
  let context : GitHubContextProjection = {
    state: "ready",
    repository: "owner/repo",
    branch: "feature/review",
    pull_requests: [
      {
        number: 42,
        title: "Review",
        url: "https://github.com/owner/repo/pull/42",
        head_oid: head,
        base_oid: "base-head",
        head_matches: true,
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
  let model = {
    ..init_model(),
    selected_workspace_id: "book-a",
    git_projection_workspace_id: "book-a",
    git_projection: Some(repository),
    github_context: Some(context),
  }
  let context_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_github_context(code_mode_test_dispatch, model, "feature/review"),
    ),
  )
  assert_true(context_markup.contains("PR base base-hea"))
  assert_true(context_markup.contains("code.github_pr_base"))
  let (_, opened) = update_mooncode_actions(
    code_mode_test_dispatch,
    BeginGitHubComment(42),
    model,
  )
  assert_eq(opened.github_comment_number, 42)
  let (_, drafted) = update_mooncode_actions(
    code_mode_test_dispatch,
    SetGitHubCommentDraft("Please review this"),
    opened,
  )
  let (_, saving) = update_mooncode_actions(
    code_mode_test_dispatch,
    PublishGitHubComment,
    drafted,
  )
  assert_true(saving.github_comment_saving)
  let (_, failed) = update_mooncode_actions(
    code_mode_test_dispatch,
    PublishedGitHubComment("book-a", 42, head, Err("offline")),
    saving,
  )
  assert_eq(failed.github_comment_draft, "Please review this")
  assert_eq(failed.github_comment_error, "offline")
  let (_, stale) = update_mooncode_actions(
    code_mode_test_dispatch,
    PublishedGitHubComment("book-b", 42, head, Ok("unexpected")),
    failed,
  )
  assert_eq(stale.github_comment_draft, "Please review this")
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_github_context(code_mode_test_dispatch, failed, "feature/review"),
    ),
  )
  assert_true(markup.contains("PR conversation comment"))
  assert_true(markup.contains("Please review this"))
  assert_true(markup.contains("offline"))
  let disconnected = {
    ..failed,
    github_context: Some({
      ..context,
      state: "unavailable",
      pull_requests: [],
      error: "GitHub offline",
    }),
  }
  let disconnected_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_github_context(
        code_mode_test_dispatch, disconnected, "feature/review",
      ),
    ),
  )
  assert_true(disconnected_markup.contains("Please review this"))
  assert_true(disconnected_markup.contains("Save locally"))
  let changed_pull = {
    ..context.pull_requests[0],
    head_oid: "ffffffffffffffffffffffffffffffffffffffff",
    base_oid: "base-head",
    head_matches: false,
  }
  let moved = {
    ..failed,
    github_context: Some({ ..context, pull_requests: [changed_pull], }),
    github_comment_error: "",
  }
  let moved_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_github_context(code_mode_test_dispatch, moved, "feature/review"),
    ),
  )
  assert_true(moved_markup.contains("Please review this"))
  assert_true(moved_markup.contains("PR moved to another commit"))
}

///|
#warnings("-alert_unstable")
test "GitHub saved draft restores and discard waits for storage receipt" {
  let head = "0123456789abcdef0123456789abcdef01234567"
  let repository : GitRepositoryProjection = {
    state: "ready",
    branch: "feature/review",
    head,
    has_remote: true,
    changes: [],
    truncated: false,
    error: "",
  }
  let context : GitHubContextProjection = {
    state: "ready",
    repository: "owner/repo",
    branch: "feature/review",
    pull_requests: [
      {
        number: 42,
        title: "Review",
        url: "https://github.com/owner/repo/pull/42",
        head_oid: head,
        base_oid: "base-head",
        head_matches: true,
        draft: false,
        review_decision: "",
        checks: [],
        closing_issues: [],
      },
    ],
    drafts: [{ number: 42, head_oid: head, body: "Saved on disk", }],
    inline_drafts: [],
    error: "",
  }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-a",
    git_projection_workspace_id: "book-a",
    git_projection: Some(repository),
    github_context: Some(context),
  }
  let offline = {
    ..model,
    github_context: Some({ ..context, state: "unavailable", pull_requests: [], }),
  }
  let offline_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_github_context(code_mode_test_dispatch, offline, "feature/review"),
    ),
  )
  assert_true(offline_markup.contains("Saved local draft for PR #42"))
  let (_, offline_opened) = update_mooncode_actions(
    code_mode_test_dispatch,
    OpenGitHubSavedDraft(42),
    offline,
  )
  assert_eq(offline_opened.github_comment_draft, "Saved on disk")
  let (_, opened) = update_mooncode_actions(
    code_mode_test_dispatch,
    BeginGitHubComment(42),
    model,
  )
  assert_eq(opened.github_comment_draft, "Saved on disk")
  assert_true(opened.github_comment_saved)
  let (_, discarding) = update_mooncode_actions(
    code_mode_test_dispatch,
    DiscardGitHubComment,
    opened,
  )
  assert_true(discarding.github_comment_saving_draft)
  assert_eq(discarding.github_comment_draft, "Saved on disk")
  let (_, failed) = update_mooncode_actions(
    code_mode_test_dispatch,
    SavedGitHubCommentDraft("book-a", 42, head, true, Err("disk full")),
    discarding,
  )
  assert_eq(failed.github_comment_draft, "Saved on disk")
  let (_, discarded) = update_mooncode_actions(
    code_mode_test_dispatch,
    SavedGitHubCommentDraft("book-a", 42, head, true, Ok(())),
    failed,
  )
  assert_eq(discarded.github_comment_number, 0)
  assert_eq(discarded.github_comment_draft, "")
}

///|
#warnings("-alert_unstable")
test "GitHub remote line review stays bound to exact PR head and retains failed post" {
  let head = "0123456789abcdef0123456789abcdef01234567"
  let repository : GitRepositoryProjection = {
    state: "ready",
    branch: "feature/review",
    head,
    has_remote: true,
    changes: [],
    truncated: false,
    error: "",
  }
  let context : GitHubContextProjection = {
    state: "ready",
    repository: "owner/repo",
    branch: "feature/review",
    pull_requests: [
      {
        number: 42,
        title: "Review",
        url: "https://github.com/owner/repo/pull/42",
        head_oid: head,
        base_oid: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        head_matches: true,
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
  let model = {
    ..init_model(),
    selected_workspace_id: "book-a",
    git_projection_workspace_id: "book-a",
    git_projection: Some(repository),
    github_context: Some(context),
  }
  let (_, opened) = update_mooncode_actions(
    code_mode_test_dispatch,
    OpenGitHubInlineReview(42),
    model,
  )
  assert_true(opened.github_inline_loading)
  let remote : GitHubInlineReviewProjection = {
    state: "ready",
    repository: "owner/repo",
    number: 42,
    branch: "feature/review",
    head_oid: head,
    base_oid: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    files: [
      {
        path: "src/main.mbt",
        previous_path: "src/old.mbt",
        status: "modified",
        additions: 1,
        deletions: 1,
        patch: "@@ -1 +1 @@\n-old\n+new\n",
        digest: "sha256:fixture",
        commentable: true,
      },
    ],
    drafts: [],
    truncated: false,
    error: "Some PR files unavailable",
  }
  let (_, stale) = update_mooncode_actions(
    code_mode_test_dispatch,
    LoadedGitHubInlineReview("book-a", 42, "other-head", Ok(remote)),
    opened,
  )
  assert_true(stale.github_inline_review is None)
  let (_, loaded) = update_mooncode_actions(
    code_mode_test_dispatch,
    LoadedGitHubInlineReview("book-a", 42, head, Ok(remote)),
    opened,
  )
  assert_eq(loaded.github_inline_path, "src/main.mbt")
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_github_inline_review(
        code_mode_test_dispatch, loaded, "book-a", head,
      ),
    ),
  )
  assert_true(markup.contains("PR base to head"))
  assert_true(markup.contains("From src/old.mbt"))
  assert_true(markup.contains("Some PR files unavailable"))
  assert_true(markup.contains("Select PR right line 1"))
  let (_, selected) = update_mooncode_actions(
    code_mode_test_dispatch,
    SelectGitHubInlineLine("@@ -1 +1 @@", "right", 1),
    loaded,
  )
  let (_, drafted) = update_mooncode_actions(
    code_mode_test_dispatch,
    SetGitHubInlineDraft("Check this line"),
    selected,
  )
  let (_, anchor_guarded) = update_mooncode_actions(
    code_mode_test_dispatch,
    SelectGitHubInlineLine("@@ -1 +1 @@", "left", 1),
    drafted,
  )
  assert_eq(anchor_guarded.github_inline_side, "right")
  assert_eq(anchor_guarded.github_inline_draft, "Check this line")
  assert_true(anchor_guarded.github_inline_error.contains("Save or discard"))
  let (_, posting) = update_mooncode_actions(
    code_mode_test_dispatch,
    PublishGitHubInlineComment,
    drafted,
  )
  assert_true(posting.github_inline_saving)
  let (_, failed) = update_mooncode_actions(
    code_mode_test_dispatch,
    PublishedGitHubInlineComment(
      "book-a",
      42,
      head,
      "src/main.mbt",
      Err("offline"),
    ),
    posting,
  )
  assert_eq(failed.github_inline_draft, "Check this line")
  assert_eq(failed.github_inline_error, "offline")
  let (_, refreshing) = update_mooncode_actions(
    code_mode_test_dispatch,
    OpenGitHubInlineReview(42),
    failed,
  )
  let (_, unavailable) = update_mooncode_actions(
    code_mode_test_dispatch,
    LoadedGitHubInlineReview("book-a", 42, head, Err("network unavailable")),
    refreshing,
  )
  assert_true(unavailable.github_inline_review is None)
  assert_eq(unavailable.github_inline_draft, "Check this line")
  let (_, saving_draft) = update_mooncode_actions(
    code_mode_test_dispatch,
    SaveGitHubInlineDraft,
    failed,
  )
  assert_true(saving_draft.github_inline_saving_draft)
  let (_, saved_draft) = update_mooncode_actions(
    code_mode_test_dispatch,
    SavedGitHubInlineDraft("book-a", 42, head, false, Ok(())),
    saving_draft,
  )
  assert_true(saved_draft.github_inline_saved)
  guard saved_draft.github_context is Some(saved_context) else {
    fail("context")
  }
  assert_eq(saved_context.inline_drafts.length(), 1)
  let (_, next_line) = update_mooncode_actions(
    code_mode_test_dispatch,
    SelectGitHubInlineLine("@@ -1 +1 @@", "left", 1),
    saved_draft,
  )
  assert_eq(next_line.github_inline_side, "left")
  assert_eq(next_line.github_inline_draft, "")
  let (_, next_text) = update_mooncode_actions(
    code_mode_test_dispatch,
    SetGitHubInlineDraft("Check deletion"),
    next_line,
  )
  let (_, next_saving) = update_mooncode_actions(
    code_mode_test_dispatch,
    SaveGitHubInlineDraft,
    next_text,
  )
  let (_, next_saved) = update_mooncode_actions(
    code_mode_test_dispatch,
    SavedGitHubInlineDraft("book-a", 42, head, false, Ok(())),
    next_saving,
  )
  guard next_saved.github_context is Some(two_drafts) else { fail("context") }
  assert_eq(two_drafts.inline_drafts.length(), 2)
}

///|
#warnings("-alert_unstable")
test "saved PR line draft remains accessible when GitHub is offline" {
  let head = "0123456789abcdef0123456789abcdef01234567"
  let draft : GitHubInlineDraftProjection = {
    number: 42,
    head_oid: head,
    base_oid: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    path: "src/main.mbt",
    digest: "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    hunk: "@@ -1 +1 @@",
    side: "right",
    line: 1,
    body: "Retained line note",
  }
  let context : GitHubContextProjection = {
    state: "unavailable",
    repository: "owner/repo",
    branch: "feature/review",
    pull_requests: [],
    drafts: [],
    inline_drafts: [draft],
    error: "GitHub is offline",
  }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-a",
    git_projection_workspace_id: "book-a",
    github_context: Some(context),
  }
  let inventory = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_github_context(code_mode_test_dispatch, model, "feature/review"),
    ),
  )
  assert_true(inventory.contains("Open saved line draft"))
  let (_, opened) = update_mooncode_actions(
    code_mode_test_dispatch,
    OpenGitHubSavedInlineDraft(draft),
    model,
  )
  assert_eq(opened.github_inline_draft, "Retained line note")
  assert_true(opened.github_inline_saved)
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_github_inline_review(
        code_mode_test_dispatch, opened, "book-a", head,
      ),
    ),
  )
  assert_true(markup.contains("Retained line note"))
  assert_true(markup.contains("remote PR patch is unavailable"))
  let (_, edited) = update_mooncode_actions(
    code_mode_test_dispatch,
    SetGitHubInlineDraft("Updated unsaved note"),
    opened,
  )
  let (_, preserved) = update_mooncode_actions(
    code_mode_test_dispatch,
    OpenGitHubSavedInlineDraft(draft),
    edited,
  )
  assert_eq(preserved.github_inline_draft, "Updated unsaved note")
  let (_, discarding) = update_mooncode_actions(
    code_mode_test_dispatch,
    DiscardGitHubInlineDraft,
    opened,
  )
  assert_true(discarding.github_inline_saving_draft)
  assert_eq(discarding.github_inline_draft, "Retained line note")
  let (_, failed) = update_mooncode_actions(
    code_mode_test_dispatch,
    SavedGitHubInlineDraft("book-a", 42, head, true, Err("disk full")),
    discarding,
  )
  assert_eq(failed.github_inline_draft, "Retained line note")
  let (_, discarded) = update_mooncode_actions(
    code_mode_test_dispatch,
    SavedGitHubInlineDraft("book-a", 42, head, true, Ok(())),
    failed,
  )
  assert_eq(discarded.github_inline_draft, "")
  guard discarded.github_context is Some(discarded_context) else {
    fail("context")
  }
  assert_eq(discarded_context.inline_drafts.length(), 0)
}
