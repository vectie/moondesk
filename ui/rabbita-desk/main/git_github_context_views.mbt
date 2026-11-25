///|
fn render_github_context(
  dispatch : Dispatch[Msg],
  model : Model,
  branch : String,
) -> @rabbita.Html {
  if model.github_context_loading {
    return p(
      class="mooncode-git-note",
      attrs=@html.Attrs::build().data_set("i18n", "code.github_checking"),
      "Checking GitHub pull requests…",
    )
  }
  if model.github_context_error != "" {
    let repository = match model.github_context {
      Some(context) => context.repository
      None => ""
    }
    return div([
      p(class="mooncode-git-note", model.github_context_error),
      render_github_unmatched_draft(
        dispatch, model, repository, "GitHub context is unavailable; your PR draft remains here.",
      ),
      match model.github_context {
        Some(context) =>
          render_github_inline_draft_inventory(dispatch, model, context)
        None => @html.nothing
      },
    ])
  }
  guard model.github_context is Some(context) else { return @html.nothing }
  if context.state == "no_github_remote" {
    return @html.nothing
  }
  if context.state != "ready" {
    return div([
      p(
        class="mooncode-git-note",
        if context.error == "" {
          "GitHub context is unavailable."
        } else {
          context.error
        },
      ),
      render_github_unmatched_draft(
        dispatch,
        model,
        context.repository,
        "The PR cannot be checked while GitHub is unavailable.",
      ),
      div(
        context.drafts
        .filter(draft => {
          model.github_comment_workspace_id != mooncode_git_workspace_id(model) ||
          model.github_comment_number != draft.number
        })
        .map(draft => {
          div(class="mooncode-github-comment-draft", [
            strong("Saved local draft for PR #" + draft.number.to_string()),
            button(
              class="mooncode-git-open",
              on_click=dispatch(OpenGitHubSavedDraft(draft.number)),
              "Open saved draft",
            ),
          ])
        }),
      ),
      render_github_inline_draft_inventory(dispatch, model, context),
    ])
  }
  if context.branch != branch {
    return div([
      p(class="mooncode-git-note", "GitHub context is stale. Refresh changes."),
      render_github_unmatched_draft(
        dispatch,
        model,
        context.repository,
        "The branch changed; refresh before posting.",
      ),
    ])
  }
  let orphan_drafts : Array[@rabbita.Html] = []
  for draft in context.drafts {
    if orphan_drafts.length() >= 20 {
      break
    }
    if context.pull_requests.any(pull => pull.number == draft.number) ||
      (
        model.github_comment_workspace_id == mooncode_git_workspace_id(model) &&
        model.github_comment_number == draft.number
      ) {
      continue
    }
    orphan_drafts.push(
      div(class="mooncode-github-comment-draft", [
        strong("Saved local draft for PR #" + draft.number.to_string()),
        a(
          href="https://github.com/" +
            context.repository +
            "/pull/" +
            draft.number.to_string(),
          target=Blank,
          rel="noreferrer",
          "Open PR on GitHub",
        ),
        button(
          class="mooncode-git-open",
          on_click=dispatch(OpenGitHubSavedDraft(draft.number)),
          disabled=model.github_comment_saving ||
            model.github_comment_saving_draft,
          "Open saved draft",
        ),
      ]),
    )
  }
  section(
    class="mooncode-github-context",
    attrs=@html.Attrs::build()
      .aria_label("GitHub pull requests")
      .data_set("i18n-aria-label", "code.github_context_aria")
      .data_set("testid", "mooncode-github-context"),
    [
      div(class="mooncode-github-heading", [
        strong("GitHub · " + context.repository),
        span(
          attrs=@html.Attrs::build()
            .data_set(
              "i18n",
              if branch == "" {
                "code.github_open_prs_detached"
              } else {
                "code.github_open_prs"
              },
            )
            .data_set(
              "i18n-params",
              (
                {
                  "count": context.pull_requests.length(),
                  "branch": if branch == "" {
                    "detached HEAD"
                  } else {
                    branch
                  },
                } : Json).stringify(),
            ),
          context.pull_requests.length().to_string() +
          " open PRs · local " +
          (if branch == "" { "detached HEAD" } else { branch }),
        ),
      ]),
      if model.github_checkout_workspace_id == mooncode_git_workspace_id(model) &&
        model.github_checkout_status != "" {
        let status_key = match model.github_checkout_status {
          "Creating an isolated PR worktree…" =>
            "code.github_checkout_pending"
          "PR worktree ready. Open its MoonBook to review and code there." =>
            "code.github_checkout_ready"
          "PR checkout response did not match the requested commit." =>
            "code.github_checkout_invalid"
          status if status.has_prefix("PR checkout failed. ") =>
            "code.github_checkout_failed"
          _ => ""
        }
        let failure_prefix = "PR checkout failed. "
        let status_params = if status_key == "code.github_checkout_failed" {
          (
            { "error": model.github_checkout_status[failure_prefix.length():] } :
            Json).stringify()
        } else {
          ""
        }
        div(
          class="mooncode-github-checkout-status",
          attrs=@html.Attrs::build().role("status").aria_live("polite"),
          [
            p(
              attrs=@html.Attrs::build()
                .data_set("i18n", status_key)
                .data_set("i18n-params", status_params),
              model.github_checkout_status,
            ),
            if model.github_checkout_target_workspace_id != "" {
              button(
                class="mooncode-git-open",
                attrs=@html.Attrs::build().data_set(
                  "i18n", "code.github_checkout_open",
                ),
                on_click=dispatch(OpenCheckedOutGitHubPull),
                "Open PR MoonBook",
              )
            } else {
              @html.nothing
            },
          ],
        )
      } else {
        @html.nothing
      },
      if context.pull_requests.is_empty() {
        p(
          class="mooncode-git-note",
          attrs=@html.Attrs::build().data_set("i18n", "code.github_no_open_prs"),
          "No open pull requests in this repository",
        )
      } else {
        div(
          context.pull_requests.map(pull => {
            let failed = pull.checks
              .filter(check => {
                [
                  "FAILURE", "ERROR", "TIMED_OUT", "CANCELLED", "failure", "error",
                ].contains(check.conclusion)
              })
              .length()
            let check_views : Array[@rabbita.Html] = []
            for index in 0..<pull.checks.length().min(8) {
              let check = pull.checks[index]
              let status = if check.conclusion != "" {
                check.conclusion
              } else if check.status != "" {
                check.status
              } else {
                "unknown"
              }
              check_views.push(
                div(class="mooncode-github-check", [
                  span(check.name + " ·"),
                  span(
                    attrs=@html.Attrs::build().data_set(
                      "i18n",
                      github_check_status_i18n_key(status),
                    ),
                    status,
                  ),
                ]),
              )
            }
            div(class="mooncode-github-pull", [
              a(
                href=pull.url,
                target=Blank,
                rel="noreferrer",
                "#" + pull.number.to_string() + " " + pull.title,
              ),
              if pull.draft {
                span(
                  attrs=@html.Attrs::build().data_set(
                    "i18n", "code.github_draft",
                  ),
                  "Draft",
                )
              } else {
                @html.nothing
              },
              span(
                class="mooncode-github-head-state" +
                  (if pull.head_matches {
                    " is-current"
                  } else {
                    " is-different"
                  }),
                attrs=@html.Attrs::build().data_set(
                  "i18n",
                  if pull.head_matches {
                    "code.github_head_matches"
                  } else {
                    "code.github_head_differs"
                  },
                ),
                if pull.head_matches {
                  "Local HEAD matches"
                } else {
                  "PR head differs"
                },
              ),
              span(
                attrs=@html.Attrs::build()
                  .data_set(
                    "i18n",
                    if pull.checks.is_empty() {
                      "code.github_checks_unreported"
                    } else if failed > 0 {
                      "code.github_checks_failing"
                    } else {
                      "code.github_checks_reported"
                    },
                  )
                  .data_set(
                    "i18n-params",
                    ({ "failed": failed, "total": pull.checks.length() } : Json).stringify(),
                  ),
                if pull.checks.is_empty() {
                  "Checks not reported"
                } else if failed > 0 {
                  failed.to_string() +
                  " failing of " +
                  pull.checks.length().to_string() +
                  " checks"
                } else {
                  pull.checks.length().to_string() + " checks reported"
                },
              ),
              if pull.review_decision == "" {
                @html.nothing
              } else {
                span(
                  attrs=@html.Attrs::build().data_set(
                    "i18n",
                    github_review_decision_i18n_key(pull.review_decision),
                  ),
                  pull.review_decision,
                )
              },
              if !pull.head_matches && pull.head_oid != "" {
                span(
                  attrs=@html.Attrs::build()
                    .data_set("i18n", "code.github_pr_head")
                    .data_set(
                      "i18n-params",
                      (
                        {
                          "head": pull.head_oid[:pull.head_oid.length().min(8)].to_owned(),
                        } : Json).stringify(),
                    ),
                  "PR head " +
                  pull.head_oid[:pull.head_oid.length().min(8)].to_owned(),
                )
              } else {
                @html.nothing
              },
              if pull.base_oid == "" {
                @html.nothing
              } else {
                span(
                  attrs=@html.Attrs::build()
                    .data_set("i18n", "code.github_pr_base")
                    .data_set(
                      "i18n-params",
                      (
                        {
                          "base": pull.base_oid[:pull.base_oid.length().min(8)].to_owned(),
                        } : Json).stringify(),
                    ),
                  "PR base " +
                  pull.base_oid[:pull.base_oid.length().min(8)].to_owned(),
                )
              },
              if pull.head_matches ||
                (
                  model.github_comment_workspace_id ==
                  mooncode_git_workspace_id(model) &&
                  model.github_comment_number == pull.number
                ) {
                if model.github_comment_workspace_id ==
                  mooncode_git_workspace_id(model) &&
                  model.github_comment_number == pull.number {
                  div(class="mooncode-github-comment-draft", [
                    p(
                      attrs=@html.Attrs::build()
                        .data_set("i18n", "code.github_conversation_context")
                        .data_set(
                          "i18n-params",
                          (
                            {
                              "head": pull.head_oid[:pull.head_oid
                              .length()
                              .min(8)].to_owned(),
                            } : Json).stringify(),
                        ),
                      "PR conversation comment at " +
                      pull.head_oid[:pull.head_oid.length().min(8)].to_owned() +
                      " · visible on GitHub to everyone with access to this PR",
                    ),
                    if model.git_projection is Some(projection) &&
                      !projection.changes.is_empty() {
                      p(
                        attrs=@html.Attrs::build().data_set(
                          "i18n", "code.github_local_edits_excluded",
                        ),
                        "The local working changes listed above are not part of this PR commit.",
                      )
                    } else {
                      @html.nothing
                    },
                    textarea(
                      class="mooncode-git-review-note",
                      attrs=@html.Attrs::build()
                        .aria_label("GitHub PR comment draft")
                        .data_set(
                          "i18n-aria-label", "code.github_comment_draft_aria",
                        )
                        .data_set(
                          "i18n-placeholder", "code.github_comment_placeholder",
                        )
                        .disabled(
                          model.github_comment_saving ||
                          model.github_comment_saving_draft ||
                          model.github_comment_published_url != "",
                        ),
                      rows=3,
                      value=model.github_comment_draft,
                      placeholder="Write a comment for the PR conversation",
                      on_input=fn(value) {
                        dispatch(SetGitHubCommentDraft(value))
                      },
                      "",
                    ),
                    div(class="mooncode-git-review-actions", [
                      button(
                        class="mooncode-git-open",
                        attrs=@html.Attrs::build().data_set(
                          "i18n", "code.github_save_local",
                        ),
                        on_click=dispatch(SaveGitHubCommentDraft),
                        disabled=model.github_comment_saving ||
                          model.github_comment_saving_draft ||
                          model.github_comment_saved ||
                          model.github_comment_draft.trim() == "" ||
                          model.github_comment_draft.length() > 4000 ||
                          model.github_comment_published_url != "",
                        "Save locally",
                      ),
                      button(
                        class="mooncode-git-open",
                        attrs=@html.Attrs::build().data_set(
                          "i18n", "code.github_post_pr",
                        ),
                        on_click=dispatch(PublishGitHubComment),
                        disabled=model.github_comment_saving ||
                          model.github_comment_saving_draft ||
                          model.github_comment_published_url != "" ||
                          model.github_comment_draft.trim() == "" ||
                          model.github_comment_draft.length() > 4000 ||
                          !pull.head_matches ||
                          model.github_comment_head != pull.head_oid,
                        "Post to PR",
                      ),
                      button(
                        class="mooncode-git-open",
                        attrs=@html.Attrs::build().data_set(
                          "i18n", "code.github_discard_draft",
                        ),
                        on_click=dispatch(DiscardGitHubComment),
                        disabled=model.github_comment_saving ||
                          model.github_comment_saving_draft,
                        "Discard draft",
                      ),
                    ]),
                    div(
                      attrs=@html.Attrs::build()
                        .role("status")
                        .aria_live("polite"),
                      [
                        if model.github_comment_published_url != "" {
                          a(
                            href=model.github_comment_published_url,
                            target=Blank,
                            rel="noreferrer",
                            attrs=@html.Attrs::build().data_set(
                              "i18n", "code.github_posted_open",
                            ),
                            "Comment posted · open on GitHub",
                          )
                        } else {
                          @html.nothing
                        },
                        if model.github_comment_saving {
                          p(
                            attrs=@html.Attrs::build().data_set(
                              "i18n", "code.github_posting",
                            ),
                            "Posting to GitHub…",
                          )
                        } else if model.github_comment_saving_draft {
                          p(
                            attrs=@html.Attrs::build().data_set(
                              "i18n", "code.github_saving_draft",
                            ),
                            "Saving local draft…",
                          )
                        } else if model.github_comment_error != "" {
                          div(class="mooncode-git-error", [
                            p(model.github_comment_error),
                          ])
                        } else if !pull.head_matches ||
                          model.github_comment_head != pull.head_oid {
                          p(
                            attrs=@html.Attrs::build().data_set(
                              "i18n", "code.github_pr_moved",
                            ),
                            "The PR moved to another commit. Refresh changes; this draft remains here.",
                          )
                        } else if model.github_comment_saved {
                          p(
                            attrs=@html.Attrs::build().data_set(
                              "i18n", "code.github_draft_saved",
                            ),
                            "Draft saved locally in this MoonBook",
                          )
                        } else if model.github_comment_draft != "" {
                          p(
                            attrs=@html.Attrs::build().data_set(
                              "i18n", "code.github_unsaved_draft",
                            ),
                            "Unsaved PR draft",
                          )
                        } else {
                          @html.nothing
                        },
                      ],
                    ),
                  ])
                } else {
                  button(
                    class="mooncode-git-open",
                    attrs=@html.Attrs::build().data_set(
                      "i18n", "code.github_write_comment",
                    ),
                    on_click=dispatch(BeginGitHubComment(pull.number)),
                    disabled=model.github_comment_saving,
                    "Write PR comment",
                  )
                }
              } else {
                @html.nothing
              },
              if pull.head_matches {
                button(
                  class="mooncode-git-open",
                  attrs=@html.Attrs::build().data_set(
                    "i18n", "code.github_review_files",
                  ),
                  on_click=dispatch(OpenGitHubInlineReview(pull.number)),
                  disabled=model.github_inline_saving ||
                    (
                      model.github_inline_draft.trim() != "" &&
                      model.github_inline_number != pull.number
                    ),
                  "Review PR files",
                )
              } else {
                button(
                  class="mooncode-git-open",
                  attrs=@html.Attrs::build().data_set(
                    "i18n", "code.github_checkout",
                  ),
                  on_click=dispatch(CheckoutGitHubPull(pull.number)),
                  disabled=model.github_checkout_pending ||
                    pull.head_oid.length() != 40,
                  "Open isolated worktree",
                )
              },
              if check_views.is_empty() {
                @html.nothing
              } else {
                div(class="mooncode-github-checks", check_views)
              },
              if pull.closing_issues.is_empty() {
                @html.nothing
              } else {
                div(
                  class="mooncode-github-issues",
                  pull.closing_issues.map(issue => {
                    a(
                      href=issue.url,
                      target=Blank,
                      rel="noreferrer",
                      "Issue #" + issue.number.to_string() + " " + issue.title,
                    )
                  }),
                )
              },
            ])
          }),
        )
      },
      if model.github_comment_workspace_id == mooncode_git_workspace_id(model) &&
        model.github_comment_number > 0 &&
        model.github_comment_draft != "" &&
        !context.pull_requests.any(pull => {
          pull.number == model.github_comment_number
        }) {
        render_github_unmatched_draft(
          dispatch,
          model,
          context.repository,
          "This PR is no longer in the open list. Check it on GitHub before posting elsewhere.",
        )
      } else {
        @html.nothing
      },
      div(orphan_drafts),
      render_github_inline_draft_inventory(dispatch, model, context),
    ],
  )
}

