///|
fn git_change_code_label(code : String) -> String {
  match code {
    "M" => "Modified"
    "A" => "Added"
    "D" => "Deleted"
    "R" => "Renamed"
    "C" => "Copied"
    "U" => "Conflict"
    "?" => "Untracked"
    "!" => "Ignored"
    _ => "Changed"
  }
}

///|
fn git_change_status_label(change : GitChangeProjection) -> String {
  if change.index_status == "?" && change.worktree_status == "?" {
    return "Untracked"
  }
  let labels : Array[String] = []
  if change.index_status != " " {
    labels.push("Staged " + git_change_code_label(change.index_status))
  }
  if change.worktree_status != " " {
    labels.push("Working " + git_change_code_label(change.worktree_status))
  }
  labels.join(" · ")
}

///|
fn git_change_status_i18n_key(change : GitChangeProjection) -> String {
  if change.index_status == "?" && change.worktree_status == "?" {
    return "code.git_untracked"
  }
  let prefix = if change.index_status != " " && change.worktree_status == " " {
    "code.git_staged_"
  } else if change.index_status == " " && change.worktree_status != " " {
    "code.git_working_"
  } else {
    return ""
  }
  let code = if change.index_status != " " {
    change.index_status
  } else {
    change.worktree_status
  }
  match code {
    "M" => prefix + "modified"
    "A" => prefix + "added"
    "D" => prefix + "deleted"
    "R" => prefix + "renamed"
    "C" => prefix + "copied"
    "U" => prefix + "conflict"
    "!" => prefix + "ignored"
    _ => ""
  }
}

///|
fn git_change_review_status(
  progress : GitReviewProgress?,
  path : String,
) -> String {
  match progress {
    Some(value) =>
      for file in value.files {
        if file.path == path {
          return file.status
        }
      }
    None => ()
  }
  "pending"
}

///|
fn git_change_filter_button(
  dispatch : Dispatch[Msg],
  selected : String,
  filter : String,
  label : String,
  i18n_key : String,
) -> @rabbita.Html {
  button(
    class="mooncode-git-filter" +
      (if selected == filter { " active" } else { "" }),
    attrs=@html.Attrs::build()
      .aria_pressed(if selected == filter { "true" } else { "false" })
      .data_set("i18n", i18n_key),
    on_click=dispatch(SetGitChangeFilter(filter)),
    label,
  )
}

///|
fn render_git_review_controls(
  dispatch : Dispatch[Msg],
  model : Model,
  diff : GitDiffProjection,
) -> @rabbita.Html {
  if (diff.state != "ready" && diff.state != "binary") || diff.digest == "" {
    return @html.nothing
  }
  let mut decision = "Not reviewed"
  let mut decision_key = "code.review_pending"
  let comments : Array[@rabbita.Html] = []
  match model.git_review {
    Some(review) if review.path == diff.path && review.digest == diff.digest =>
      for record in review.records {
        if record.kind == "decision" {
          decision = if record.action == "reviewed" {
            "Reviewed locally"
          } else {
            "Changes requested locally"
          }
          decision_key = if record.action == "reviewed" {
            "code.review_reviewed"
          } else {
            "code.review_needs_changes"
          }
        } else if record.kind == "comment" {
          comments.push(
            div(class="mooncode-git-review-comment", [
              strong(
                attrs=@html.Attrs::build()
                  .data_set(
                    "i18n",
                    if record.line.unwrap_or(0) > 0 {
                      if record.side.unwrap_or("") == "left" {
                        "code.review_old_line"
                      } else {
                        "code.review_new_line"
                      }
                    } else if record.hunk == "" {
                      "code.review_file_note"
                    } else {
                      ""
                    },
                  )
                  .data_set(
                    "i18n-params",
                    ({ "line": record.line.unwrap_or(0) } : Json).stringify(),
                  ),
                if record.line.unwrap_or(0) > 0 {
                  (if record.side.unwrap_or("") == "left" {
                    "Old line "
                  } else {
                    "New line "
                  }) +
                  record.line.unwrap_or(0).to_string()
                } else if record.hunk == "" {
                  "File note"
                } else {
                  record.hunk
                },
              ),
              p(record.note),
            ]),
          )
        }
      }
    _ => ()
  }
  let busy = model.git_review_loading || model.git_review_saving
  div(
    class="mooncode-git-review-controls",
    attrs=@html.Attrs::build()
      .data_set("testid", "mooncode-git-review-controls")
      .aria_label("Local file review")
      .data_set("i18n-aria-label", "code.review_aria"),
    [
      div(class="mooncode-git-review-status", [
        strong(
          attrs=@html.Attrs::build().data_set("i18n", decision_key),
          decision,
        ),
        span(
          attrs=@html.Attrs::build().data_set("i18n", "code.review_scope"),
          "Saved only in this MoonBook · tied to this exact patch",
        ),
      ]),
      if model.git_review is Some(review) && review.stale_count > 0 {
        div(class="mooncode-git-review-stale", [
          p(
            attrs=@html.Attrs::build()
              .data_set("i18n", "code.review_stale_records")
              .data_set(
                "i18n-params",
                ({ "count": review.stale_count } : Json).stringify(),
              ),
            review.stale_count.to_string() +
            " earlier review record(s) belong to a different patch or previous path.",
          ),
          div(
            review.stale_records.map(record => {
              div(class="mooncode-git-review-comment", [
                strong(
                  record.path.unwrap_or(diff.path) + " · " + record.action,
                ),
                if record.note == "" {
                  @html.nothing
                } else {
                  p(record.note)
                },
              ])
            }),
          ),
        ])
      } else {
        @html.nothing
      },
      div(comments),
      textarea(
        class="mooncode-git-review-note",
        attrs=@html.Attrs::build()
          .aria_label("Local review note")
          .data_set("i18n-aria-label", "code.review_note_aria")
          .data_set("i18n-placeholder", "code.review_note_placeholder")
          .data_set("testid", "mooncode-git-review-note")
          .disabled(busy),
        rows=2,
        value=model.git_review_note,
        placeholder="Add a note about this file or selected hunk",
        on_input=fn(value) { dispatch(SetGitReviewNote(value)) },
        "",
      ),
      div(class="mooncode-git-review-actions", [
        button(
          class="mooncode-git-open",
          attrs=@html.Attrs::build().data_set("i18n", "code.review_mark"),
          on_click=dispatch(SaveGitReview("reviewed")),
          disabled=busy,
          "Mark reviewed",
        ),
        button(
          class="mooncode-git-open",
          attrs=@html.Attrs::build().data_set(
            "i18n", "code.review_request_changes",
          ),
          on_click=dispatch(SaveGitReview("needs_changes")),
          disabled=busy || model.git_review_note.trim() == "",
          "Request changes",
        ),
        button(
          class="mooncode-git-open",
          attrs=@html.Attrs::build().data_set(
            "i18n",
            if model.git_diff_selected_line > 0 {
              "code.review_save_line_note"
            } else if diff.state == "binary" || !diff.body.contains("\n@@ ") {
              "code.review_save_file_note"
            } else {
              "code.review_save_hunk_note"
            },
          ),
          on_click=dispatch(SaveGitReview("comment")),
          disabled=busy || model.git_review_note.trim() == "",
          if model.git_diff_selected_line > 0 {
            "Save line note"
          } else if diff.state == "binary" || !diff.body.contains("\n@@ ") {
            "Save file note"
          } else {
            "Save hunk note"
          },
        ),
        if model.git_review_note != "" {
          button(
            class="mooncode-git-open",
            attrs=@html.Attrs::build().data_set(
              "i18n", "code.review_discard_note",
            ),
            on_click=dispatch(SetGitReviewNote("")),
            disabled=busy,
            "Discard note",
          )
        } else {
          @html.nothing
        },
      ]),
      div(attrs=@html.Attrs::build().role("status").aria_live("polite"), [
        if model.git_review_loading {
          p(
            attrs=@html.Attrs::build().data_set("i18n", "code.review_loading"),
            "Loading local review…",
          )
        } else if model.git_review_saving {
          p(
            attrs=@html.Attrs::build().data_set("i18n", "code.review_saving"),
            "Saving local review…",
          )
        } else if model.git_review_error != "" {
          div(class="mooncode-git-review-error", [
            p(model.git_review_error),
            button(
              class="mooncode-git-open",
              attrs=@html.Attrs::build().data_set(
                "i18n", "code.review_refresh_diff",
              ),
              on_click=dispatch(RefreshGitDiff),
              "Refresh file diff",
            ),
          ])
        } else {
          @html.nothing
        },
      ]),
    ],
  )
}

///|
fn render_github_unmatched_draft(
  dispatch : Dispatch[Msg],
  model : Model,
  repository : String,
  reason : String,
) -> @rabbita.Html {
  if model.github_comment_workspace_id != mooncode_git_workspace_id(model) ||
    model.github_comment_number <= 0 ||
    model.github_comment_draft == "" {
    return @html.nothing
  }
  div(class="mooncode-github-comment-draft", [
    strong("Local PR draft for #" + model.github_comment_number.to_string()),
    p(reason),
    if repository == "" {
      @html.nothing
    } else {
      a(
        href="https://github.com/" +
          repository +
          "/pull/" +
          model.github_comment_number.to_string(),
        target=Blank,
        rel="noreferrer",
        attrs=@html.Attrs::build().data_set(
          "i18n", "code.github_open_on_github",
        ),
        "Open PR on GitHub",
      )
    },
    textarea(
      class="mooncode-git-review-note",
      attrs=@html.Attrs::build()
        .aria_label("Retained GitHub PR draft")
        .data_set("i18n-aria-label", "code.github_retained_draft_aria")
        .disabled(
          model.github_comment_saving ||
          model.github_comment_saving_draft ||
          model.github_comment_published_url != "",
        ),
      rows=3,
      value=model.github_comment_draft,
      on_input=fn(value) { dispatch(SetGitHubCommentDraft(value)) },
      "",
    ),
    div(class="mooncode-git-review-actions", [
      button(
        class="mooncode-git-open",
        attrs=@html.Attrs::build().data_set("i18n", "code.github_save_local"),
        on_click=dispatch(SaveGitHubCommentDraft),
        disabled=repository == "" ||
          model.github_comment_saving ||
          model.github_comment_saving_draft ||
          model.github_comment_saved ||
          model.github_comment_draft.trim() == "" ||
          model.github_comment_draft.length() > 4000,
        "Save locally",
      ),
      button(
        class="mooncode-git-open",
        attrs=@html.Attrs::build().data_set("i18n", "code.github_discard_draft"),
        on_click=dispatch(DiscardGitHubComment),
        disabled=repository == "" ||
          model.github_comment_saving ||
          model.github_comment_saving_draft,
        "Discard draft",
      ),
    ]),
    if model.github_comment_error == "" {
      @html.nothing
    } else {
      p(
        attrs=@html.Attrs::build().role("status").aria_live("polite"),
        model.github_comment_error,
      )
    },
  ])
}

///|
fn render_github_inline_review(
  dispatch : Dispatch[Msg],
  model : Model,
  workspace_id : String,
  head : String,
) -> @rabbita.Html {
  if model.github_inline_workspace_id != workspace_id ||
    model.github_inline_number <= 0 {
    return @html.nothing
  }
  let mut file_view : @rabbita.Html = @html.nothing
  match model.github_inline_review {
    Some(review) if review.head_oid == head =>
      for file in review.files {
        if file.path != model.github_inline_path {
          continue
        }
        let hunks = git_diff_hunks(file.patch)
        let index = model.github_inline_hunk_index.min(
          (hunks.length() - 1).max(0),
        )
        let lines : Array[@rabbita.Html] = []
        let mut hunk = ""
        let mut old_line = 0
        let mut new_line = 0
        if !hunks.is_empty() {
          for row in hunks[index] {
            let kind = if row.has_prefix("@@ ") {
              "hunk"
            } else if row.has_prefix("+") {
              "add"
            } else if row.has_prefix("-") {
              "delete"
            } else {
              "context"
            }
            if kind == "hunk" {
              hunk = row
              old_line = git_diff_hunk_start(row, "left")
              new_line = git_diff_hunk_start(row, "right")
            }
            let mut side = ""
            let mut number = 0
            if kind == "add" {
              side = "right"
              number = new_line
              new_line += 1
            } else if kind == "delete" {
              side = "left"
              number = old_line
              old_line += 1
            } else if kind == "context" && row.has_prefix(" ") {
              side = "right"
              number = new_line
              old_line += 1
              new_line += 1
            }
            let selected = hunk == model.github_inline_hunk &&
              side == model.github_inline_side &&
              number == model.github_inline_line &&
              number > 0
            lines.push(
              div(
                class="mooncode-git-diff-line " +
                  kind +
                  (if selected { " selected" } else { "" }),
                [
                  if number > 0 && hunk != "" {
                    button(
                      class="mooncode-git-line-number",
                      attrs=@html.Attrs::build()
                        .aria_label(
                          "Select PR " + side + " line " + number.to_string(),
                        )
                        .data_set(
                          "i18n-aria-label",
                          if side == "left" {
                            "code.github_select_old_line"
                          } else {
                            "code.github_select_new_line"
                          },
                        )
                        .data_set(
                          "i18n-params",
                          ({ "line": number } : Json).stringify(),
                        )
                        .aria_pressed(if selected { "true" } else { "false" }),
                      on_click=dispatch(
                        SelectGitHubInlineLine(hunk, side, number),
                      ),
                      disabled=model.github_inline_saving ||
                        model.github_inline_saving_draft,
                      number.to_string(),
                    )
                  } else {
                    span(class="mooncode-git-line-number", "")
                  },
                  span(row),
                ],
              ),
            )
          }
        }
        file_view = div(class="mooncode-github-inline-file", [
          strong(file.path),
          if file.previous_path == "" {
            @html.nothing
          } else {
            span(
              attrs=@html.Attrs::build()
                .data_set("i18n", "code.repo_previous_path")
                .data_set(
                  "i18n-params",
                  ({ "path": file.previous_path } : Json).stringify(),
                ),
              "From " + file.previous_path,
            )
          },
          p(
            class="mooncode-git-note",
            file.status +
            " · +" +
            file.additions.to_string() +
            " / -" +
            file.deletions.to_string() +
            " · PR base to head",
          ),
          if hunks.length() > 1 {
            div(class="mooncode-git-hunk-nav", [
              span(
                "Hunk " +
                (index + 1).to_string() +
                " of " +
                hunks.length().to_string(),
              ),
              button(
                class="mooncode-git-open",
                attrs=@html.Attrs::build().data_set(
                  "i18n", "code.repo_previous_hunk",
                ),
                on_click=dispatch(SelectGitHubInlineHunk((index - 1).max(0))),
                disabled=index == 0,
                "Previous hunk",
              ),
              button(
                class="mooncode-git-open",
                attrs=@html.Attrs::build().data_set(
                  "i18n", "code.repo_next_hunk",
                ),
                on_click=dispatch(
                  SelectGitHubInlineHunk((index + 1).min(hunks.length() - 1)),
                ),
                disabled=index == hunks.length() - 1,
                "Next hunk",
              ),
            ])
          } else {
            @html.nothing
          },
          if file.commentable {
            div(
              class="mooncode-git-diff-lines",
              attrs=@html.Attrs::build()
                .role("region")
                .aria_label("PR diff for " + file.path),
              lines,
            )
          } else {
            p(
              class="mooncode-git-note",
              attrs=@html.Attrs::build().data_set(
                "i18n", "code.github_no_commentable_patch",
              ),
              "GitHub has no commentable text patch for this file.",
            )
          },
        ])
        break
      }
    _ => ()
  }
  section(
    class="mooncode-github-inline-review",
    attrs=@html.Attrs::build()
      .aria_label("GitHub PR file review")
      .data_set("i18n-aria-label", "code.github_file_review_aria")
      .data_set("testid", "mooncode-github-inline-review"),
    [
      div(class="mooncode-git-diff-heading", [
        div([
          strong(
            attrs=@html.Attrs::build()
              .data_set("i18n", "code.github_remote_files")
              .data_set(
                "i18n-params",
                ({ "number": model.github_inline_number } : Json).stringify(),
              ),
            "PR #" + model.github_inline_number.to_string() + " · remote files",
          ),
          span(
            attrs=@html.Attrs::build().data_set(
              "i18n", "code.github_public_comments",
            ),
            "Comments here are public on GitHub to PR readers",
          ),
        ]),
        button(
          class="mooncode-git-open",
          attrs=@html.Attrs::build().data_set("i18n", "common.close"),
          on_click=dispatch(CloseGitHubInlineReview),
          disabled=model.github_inline_saving ||
            model.github_inline_saving_draft ||
            (
              model.github_inline_draft.trim() != "" &&
              !model.github_inline_saved
            ),
          "Close",
        ),
      ]),
      if model.git_projection is Some(projection) &&
        !projection.changes.is_empty() {
        p(
          class="mooncode-git-note",
          attrs=@html.Attrs::build().data_set(
            "i18n", "code.github_remote_excludes_local",
          ),
          "Local staged and working edits are not part of this remote PR patch.",
        )
      } else {
        @html.nothing
      },
      if model.github_inline_loading {
        p(
          attrs=@html.Attrs::build().data_set(
            "i18n", "code.github_reading_files",
          ),
          "Reading PR files…",
        )
      } else if model.github_inline_error != "" &&
        model.github_inline_review is None &&
        model.github_inline_draft == "" {
        p(class="mooncode-git-review-error", model.github_inline_error)
      } else {
        match model.github_inline_review {
          Some(review) if review.head_oid == head => {
            let query = model.github_inline_query.trim().to_lower()
            let visible_files = review.files.filter(file => {
              query == "" ||
              file.path.to_lower().contains(query) ||
              file.previous_path.to_lower().contains(query)
            })
            div([
              if review.error == "" {
                @html.nothing
              } else {
                p(
                  class="mooncode-git-review-error",
                  attrs=@html.Attrs::build().role("status").aria_live("polite"),
                  review.error,
                )
              },
              div(class="mooncode-git-filters", [
                input(
                  class="mooncode-git-search",
                  attrs=@html.Attrs::build()
                    .aria_label("Find PR file")
                    .data_set("i18n-aria-label", "code.github_find_file")
                    .data_set("i18n-placeholder", "code.github_find_file"),
                  value=model.github_inline_query,
                  placeholder="Find PR file",
                  on_input=fn(value) { dispatch(SetGitHubInlineQuery(value)) },
                ),
                span(
                  class="mooncode-git-filter-count",
                  attrs=@html.Attrs::build()
                    .data_set("i18n", "code.github_filter_count")
                    .data_set(
                      "i18n-params",
                      (
                        {
                          "visible": visible_files.length(),
                          "total": review.files.length(),
                        } : Json).stringify(),
                    ),
                  "\{visible_files.length()} of \{review.files.length()} PR files",
                ),
              ]),
              if visible_files.is_empty() {
                p(
                  class="mooncode-git-note",
                  attrs=@html.Attrs::build().data_set(
                    "i18n", "code.github_no_matching_files",
                  ),
                  "No PR files match this search.",
                )
              } else {
                @html.nothing
              },
              div(
                class="mooncode-github-inline-files",
                attrs=@html.Attrs::build().role("list"),
                visible_files.map(file => {
                  div(attrs=@html.Attrs::build().role("listitem"), [
                    button(
                      class="mooncode-git-open" +
                        (if file.path == model.github_inline_path {
                          " active"
                        } else {
                          ""
                        }),
                      attrs=@html.Attrs::build()
                        .aria_label("Review PR file " + file.path)
                        .aria_pressed(
                          if file.path == model.github_inline_path {
                            "true"
                          } else {
                            "false"
                          },
                        ),
                      on_click=dispatch(SelectGitHubInlineFile(file.path)),
                      disabled=model.github_inline_saving ||
                        model.github_inline_saving_draft,
                      file.path,
                    ),
                  ])
                }),
              ),
              if review.truncated {
                p(
                  class="mooncode-git-note",
                  "GitHub has more than 300 files; only the first 300 are shown.",
                )
              } else {
                @html.nothing
              },
              file_view,
              if model.github_inline_line > 0 || model.github_inline_draft != "" {
                div(class="mooncode-github-comment-draft", [
                  p(
                    (if model.github_inline_line > 0 {
                      "Line comment on "
                    } else {
                      "Retained draft needs a new line in "
                    }) +
                    model.github_inline_path +
                    (if model.github_inline_line > 0 {
                      " · " +
                      model.github_inline_side +
                      " line " +
                      model.github_inline_line.to_string()
                    } else {
                      ""
                    }),
                  ),
                  textarea(
                    class="mooncode-git-review-note",
                    attrs=@html.Attrs::build()
                      .aria_label("GitHub line comment draft")
                      .data_set(
                        "i18n-aria-label", "code.github_line_draft_aria",
                      ),
                    rows=3,
                    value=model.github_inline_draft,
                    on_input=fn(value) { dispatch(SetGitHubInlineDraft(value)) },
                    disabled=model.github_inline_saving ||
                      model.github_inline_saving_draft ||
                      model.github_inline_published_url != "",
                    "",
                  ),
                  div(class="mooncode-git-review-actions", [
                    button(
                      class="mooncode-git-open",
                      attrs=@html.Attrs::build().data_set(
                        "i18n", "code.github_save_local",
                      ),
                      on_click=dispatch(SaveGitHubInlineDraft),
                      disabled=model.github_inline_saving ||
                        model.github_inline_saving_draft ||
                        model.github_inline_saved ||
                        model.github_inline_draft.trim() == "" ||
                        model.github_inline_draft.length() > 4000 ||
                        model.github_inline_line <= 0 ||
                        model.github_inline_published_url != "",
                      "Save locally",
                    ),
                    button(
                      class="mooncode-git-open",
                      attrs=@html.Attrs::build().data_set(
                        "i18n", "code.github_post_line",
                      ),
                      on_click=dispatch(PublishGitHubInlineComment),
                      disabled=model.github_inline_saving ||
                        model.github_inline_saving_draft ||
                        model.github_inline_draft.trim() == "" ||
                        model.github_inline_draft.length() > 4000 ||
                        model.github_inline_line <= 0 ||
                        model.github_inline_published_url != "",
                      "Post line comment",
                    ),
                    button(
                      class="mooncode-git-open",
                      attrs=@html.Attrs::build().data_set(
                        "i18n", "code.github_discard_draft",
                      ),
                      on_click=dispatch(DiscardGitHubInlineDraft),
                      disabled=model.github_inline_saving ||
                        model.github_inline_saving_draft ||
                        model.github_inline_draft == "",
                      "Discard draft",
                    ),
                  ]),
                ])
              } else {
                p(
                  class="mooncode-git-note",
                  attrs=@html.Attrs::build().data_set(
                    "i18n", "code.github_select_line",
                  ),
                  "Select a diff line to comment on the PR.",
                )
              },
            ])
          }
          _ =>
            if model.github_inline_draft != "" {
              div(class="mooncode-github-comment-draft", [
                p(
                  "Saved line draft for " +
                  model.github_inline_path +
                  " · " +
                  model.github_inline_side +
                  " line " +
                  model.github_inline_line.to_string(),
                ),
                p(
                  class="mooncode-git-note",
                  attrs=@html.Attrs::build().data_set(
                    "i18n", "code.github_patch_unavailable",
                  ),
                  "The remote PR patch is unavailable. Refresh GitHub context before posting.",
                ),
                textarea(
                  class="mooncode-git-review-note",
                  attrs=@html.Attrs::build()
                    .aria_label("Saved GitHub line draft")
                    .data_set(
                      "i18n-aria-label", "code.github_saved_line_draft_aria",
                    ),
                  rows=3,
                  value=model.github_inline_draft,
                  on_input=fn(value) { dispatch(SetGitHubInlineDraft(value)) },
                  disabled=model.github_inline_saving_draft,
                  "",
                ),
                div(class="mooncode-git-review-actions", [
                  button(
                    class="mooncode-git-open",
                    attrs=@html.Attrs::build().data_set(
                      "i18n", "code.github_save_local",
                    ),
                    on_click=dispatch(SaveGitHubInlineDraft),
                    disabled=model.github_inline_saving_draft ||
                      model.github_inline_saved ||
                      model.github_inline_draft.trim() == "" ||
                      model.github_inline_draft.length() > 4000,
                    "Save locally",
                  ),
                  button(
                    class="mooncode-git-open",
                    attrs=@html.Attrs::build().data_set(
                      "i18n", "code.github_discard_draft",
                    ),
                    on_click=dispatch(DiscardGitHubInlineDraft),
                    disabled=model.github_inline_saving_draft,
                    "Discard draft",
                  ),
                ]),
              ])
            } else {
              p(
                class="mooncode-git-note",
                attrs=@html.Attrs::build().data_set(
                  "i18n", "code.github_files_unavailable",
                ),
                "PR files are unavailable. Refresh GitHub context.",
              )
            }
        }
      },
      div(attrs=@html.Attrs::build().role("status").aria_live("polite"), [
        if model.github_inline_published_url != "" {
          div([
            a(
              href=model.github_inline_published_url,
              target=Blank,
              rel="noreferrer",
              attrs=@html.Attrs::build().data_set(
                "i18n", "code.github_line_posted_open",
              ),
              "Line comment posted · open on GitHub",
            ),
            if model.github_inline_error != "" &&
              model.github_inline_record is Some(_) {
              div([
                p(
                  attrs=@html.Attrs::build().data_set(
                    "i18n", "code.github_posted_draft_uncleared",
                  ),
                  "The posted comment is live, but its saved local draft could not be cleared.",
                ),
                p(model.github_inline_error),
                button(
                  class="mooncode-git-open",
                  attrs=@html.Attrs::build().data_set(
                    "i18n", "code.github_clear_saved_draft",
                  ),
                  on_click=dispatch(DiscardGitHubInlineDraft),
                  disabled=model.github_inline_saving_draft,
                  "Clear saved draft",
                ),
              ])
            } else {
              @html.nothing
            },
          ])
        } else if model.github_inline_saving {
          p(
            attrs=@html.Attrs::build().data_set(
              "i18n", "code.github_posting_line",
            ),
            "Posting line comment to GitHub…",
          )
        } else if model.github_inline_saving_draft {
          p(
            attrs=@html.Attrs::build().data_set(
              "i18n", "code.github_saving_line_draft",
            ),
            "Saving local line draft…",
          )
        } else if model.github_inline_error != "" {
          div(class="mooncode-git-error", [p(model.github_inline_error)])
        } else if model.github_inline_saved {
          p(
            attrs=@html.Attrs::build().data_set(
              "i18n", "code.github_line_draft_saved",
            ),
            "Line draft saved locally in this MoonBook",
          )
        } else if model.github_inline_draft != "" {
          p(
            attrs=@html.Attrs::build().data_set(
              "i18n", "code.github_unsaved_line_draft",
            ),
            "Unsaved line draft · save locally before leaving this view",
          )
        } else {
          @html.nothing
        },
      ]),
    ],
  )
}

///|
fn render_github_inline_draft_inventory(
  dispatch : Dispatch[Msg],
  model : Model,
  context : GitHubContextProjection,
) -> @rabbita.Html {
  if context.inline_drafts.is_empty() {
    return @html.nothing
  }
  div(
    class="mooncode-github-inline-drafts",
    attrs=@html.Attrs::build().aria_label("Saved PR line drafts"),
    context.inline_drafts.map(draft => {
      div(class="mooncode-github-comment-draft", [
        strong(
          "Saved line draft · PR #" +
          draft.number.to_string() +
          " · " +
          draft.path,
        ),
        span(draft.side + " line " + draft.line.to_string()),
        button(
          class="mooncode-git-open",
          on_click=dispatch(OpenGitHubSavedInlineDraft(draft)),
          disabled=model.github_inline_saving ||
            model.github_inline_saving_draft ||
            (
              model.github_inline_draft.trim() != "" &&
              !model.github_inline_saved
            ),
          "Open saved line draft",
        ),
      ])
    }),
  )
}

///|
fn render_github_context(
  dispatch : Dispatch[Msg],
  model : Model,
  branch : String,
) -> @rabbita.Html {
  if model.github_context_loading {
    return p(class="mooncode-git-note", "Checking GitHub pull requests…")
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
      .data_set("testid", "mooncode-github-context"),
    [
      div(class="mooncode-github-heading", [
        strong("GitHub · " + context.repository),
        span(
          attrs=@html.Attrs::build()
            .data_set("i18n", "code.github_open_prs")
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
          _ => ""
        }
        div(
          class="mooncode-github-checkout-status",
          attrs=@html.Attrs::build().role("status").aria_live("polite"),
          [
            p(
              attrs=@html.Attrs::build().data_set("i18n", status_key),
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
              check_views.push(
                span(
                  check.name +
                  " · " +
                  (if check.conclusion != "" {
                    check.conclusion
                  } else if check.status != "" {
                    check.status
                  } else {
                    "unknown"
                  }),
                ),
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
                span(pull.review_decision)
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

///|
fn render_git_diff_panel(
  dispatch : Dispatch[Msg],
  model : Model,
  workspace_id : String,
  head : String,
) -> @rabbita.Html {
  if model.git_diff_path == "" || model.git_diff_workspace_id != workspace_id {
    return @html.nothing
  }
  let body = if model.git_diff_loading {
    p("Loading file diff…")
  } else if model.git_diff_error != "" {
    p(class="mooncode-git-diff-message", model.git_diff_error)
  } else {
    match model.git_diff {
      Some(diff) if diff.path == model.git_diff_path && diff.head == head =>
        match diff.state {
          "untracked" =>
            p(
              class="mooncode-git-diff-message",
              "Untracked file · no Git baseline yet. Open the file to inspect its contents.",
            )
          "no_baseline" =>
            p(
              class="mooncode-git-diff-message",
              "This repository has no commit yet. Open the file to inspect its contents.",
            )
          "binary" =>
            div([
              p(
                class="mooncode-git-diff-message",
                "Binary change · a text diff is unavailable. Review the file with an appropriate viewer, then record a file-level decision here.",
              ),
              render_git_review_controls(dispatch, model, diff),
            ])
          "no_diff" =>
            p(
              class="mooncode-git-diff-message",
              "Git returned no text changes for this file. Refresh the change list if it changed again.",
            )
          "ready" => {
            let hunks = git_diff_hunks(diff.body)
            let hunk_index = model.git_diff_hunk_index.min(
              (hunks.length() - 1).max(0),
            )
            let lines : Array[@rabbita.Html] = []
            let mut old_line = 0
            let mut new_line = 0
            for line in hunks[hunk_index] {
              let kind = if line.has_prefix("@@") {
                "hunk"
              } else if line.has_prefix("rename ") ||
                line.has_prefix("new file") ||
                line.has_prefix("deleted file") {
                "meta"
              } else if line.has_prefix("+") {
                "add"
              } else if line.has_prefix("-") {
                "delete"
              } else {
                "context"
              }
              if kind == "hunk" {
                old_line = git_diff_hunk_start(line, "left")
                new_line = git_diff_hunk_start(line, "right")
              }
              let mut side = ""
              let mut number = 0
              if kind == "add" {
                side = "right"
                number = new_line
                new_line += 1
              } else if kind == "delete" {
                side = "left"
                number = old_line
                old_line += 1
              } else if kind == "context" && line.has_prefix(" ") {
                side = "right"
                number = new_line
                old_line += 1
                new_line += 1
              }
              let selected = side == model.git_diff_selected_side &&
                number > 0 &&
                number == model.git_diff_selected_line
              lines.push(
                div(
                  class="mooncode-git-diff-line " +
                    kind +
                    (if selected { " selected" } else { "" }),
                  [
                    if number > 0 {
                      button(
                        class="mooncode-git-line-number",
                        attrs=@html.Attrs::build().aria_label(
                          "Select " +
                          side +
                          " line " +
                          number.to_string() +
                          " for a review note",
                        ),
                        on_click=dispatch(SelectGitDiffLine(side, number)),
                        number.to_string(),
                      )
                    } else {
                      span(class="mooncode-git-line-number", "")
                    },
                    span(line),
                  ],
                ),
              )
            }
            div([
              if hunks.length() > 1 {
                div(class="mooncode-git-hunk-nav", [
                  span(
                    "Hunk " +
                    (hunk_index + 1).to_string() +
                    " of " +
                    hunks.length().to_string(),
                  ),
                  button(
                    class="mooncode-git-open",
                    attrs=@html.Attrs::build()
                      .aria_label("Previous diff hunk")
                      .data_set(
                        "i18n-aria-label", "code.repo_previous_hunk_aria",
                      )
                      .data_set("i18n", "code.repo_previous_hunk"),
                    on_click=dispatch(
                      SelectGitDiffHunk((hunk_index - 1).max(0)),
                    ),
                    disabled=hunk_index == 0,
                    "Previous hunk",
                  ),
                  button(
                    class="mooncode-git-open",
                    attrs=@html.Attrs::build()
                      .aria_label("Next diff hunk")
                      .data_set("i18n-aria-label", "code.repo_next_hunk_aria")
                      .data_set("i18n", "code.repo_next_hunk"),
                    on_click=dispatch(
                      SelectGitDiffHunk(
                        (hunk_index + 1).min(hunks.length() - 1),
                      ),
                    ),
                    disabled=hunk_index == hunks.length() - 1,
                    "Next hunk",
                  ),
                ])
              } else {
                @html.nothing
              },
              div(
                class="mooncode-git-diff-lines",
                attrs=@html.Attrs::build()
                  .role("region")
                  .aria_label("Diff for " + diff.path),
                lines,
              ),
              render_git_review_controls(dispatch, model, diff),
            ])
          }
          _ => p(class="mooncode-git-diff-message", diff.error)
        }
      _ =>
        p(
          class="mooncode-git-diff-message",
          attrs=@html.Attrs::build().data_set("i18n", "code.repo_diff_stale"),
          "File diff is stale. Refresh changes and retry.",
        )
    }
  }
  let previous_path = match model.git_diff {
    Some(diff) if diff.path == model.git_diff_path => diff.previous_path
    _ => ""
  }
  section(
    class="mooncode-git-diff-panel",
    attrs=@html.Attrs::build()
      .data_set("testid", "mooncode-git-diff-panel")
      .aria_label("Review file change")
      .data_set("i18n-aria-label", "code.repo_review_file_aria"),
    [
      div(class="mooncode-git-diff-heading", [
        div([
          strong(model.git_diff_path),
          if previous_path == "" {
            @html.nothing
          } else {
            span(
              attrs=@html.Attrs::build()
                .data_set("i18n", "code.repo_previous_path")
                .data_set(
                  "i18n-params",
                  ({ "path": previous_path } : Json).stringify(),
                ),
              "From " + previous_path,
            )
          },
          span(
            attrs=@html.Attrs::build().data_set(
              "i18n", "code.repo_compared_with_head",
            ),
            "Compared with HEAD · staged and working changes",
          ),
        ]),
        button(
          class="mooncode-git-open",
          attrs=@html.Attrs::build()
            .aria_label("Close file diff")
            .data_set("i18n-aria-label", "code.repo_close_diff_aria")
            .data_set("i18n", "common.close"),
          on_click=dispatch(CloseGitDiff),
          disabled=model.git_review_saving,
          "Close",
        ),
      ]),
      body,
      if model.git_diff_error != "" && model.git_review_note != "" {
        div(class="mooncode-git-review-controls", [
          p(
            attrs=@html.Attrs::build().data_set(
              "i18n", "code.repo_unsent_note_preserved",
            ),
            "Your unsent note is preserved here. Copy it before changing workspaces or refreshing the change list.",
          ),
          textarea(
            class="mooncode-git-review-note",
            attrs=@html.Attrs::build()
              .aria_label("Unsent local review note")
              .data_set("i18n-aria-label", "code.repo_unsent_note_aria"),
            rows=3,
            value=model.git_review_note,
            on_input=fn(value) { dispatch(SetGitReviewNote(value)) },
            "",
          ),
          button(
            class="mooncode-git-open",
            attrs=@html.Attrs::build().data_set(
              "i18n", "code.review_discard_note",
            ),
            on_click=dispatch(SetGitReviewNote("")),
            "Discard note",
          ),
        ])
      } else {
        @html.nothing
      },
    ],
  )
}

///|
fn render_git_repository_context(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let workspace_id = mooncode_git_workspace_id(model)
  if workspace_id == "" {
    return @html.nothing
  }
  let refresh = button(
    class="mooncode-git-refresh",
    attrs=@html.Attrs::build()
      .data_set("testid", "mooncode-git-refresh")
      .aria_label("Refresh repository changes")
      .data_set("i18n-aria-label", "code.repo_refresh"),
    on_click=dispatch(RefreshGitRepositoryProjection(workspace_id)),
    disabled=model.git_projection_loading ||
      model.git_review_saving ||
      model.git_review_note.trim() != "",
    span(
      attrs=@html.Attrs::build().data_set("i18n", "common.refresh"),
      "Refresh",
    ),
  )
  if model.git_projection_loading {
    return section(
      class="mooncode-git-context",
      attrs=@html.Attrs::build()
        .aria_label("Repository changes")
        .data_set("i18n-aria-label", "code.repo_changes"),
      [
        span(
          attrs=@html.Attrs::build().data_set(
            "i18n", "code.repo_changes_loading",
          ),
          "Reading repository changes…",
        ),
        refresh,
      ],
    )
  }
  if model.git_projection_error != "" {
    return section(
      class="mooncode-git-context",
      attrs=@html.Attrs::build()
        .aria_label("Repository changes")
        .data_set("i18n-aria-label", "code.repo_changes"),
      [span(model.git_projection_error), refresh],
    )
  }
  guard model.git_projection_workspace_id == workspace_id &&
    model.git_projection is Some(projection) else {
    return @html.nothing
  }
  if projection.state == "not_repository" {
    return @html.nothing
  }
  if projection.state != "ready" {
    return section(
      class="mooncode-git-context",
      attrs=@html.Attrs::build().aria_label("Repository changes"),
      [span(projection.error), refresh],
    )
  }
  let branch = if projection.branch != "" {
    projection.branch
  } else if projection.head == "" {
    "New repository"
  } else {
    "Detached HEAD"
  }
  let progress = match model.git_review_progress {
    Some(value) if value.head == projection.head &&
      value.total == projection.changes.length() => Some(value)
    _ => None
  }
  let query = model.git_change_query.trim().to_lower()
  let visible_changes = projection.changes.filter(change => {
    (query == "" || change.path.to_lower().contains(query)) &&
    (
      model.git_change_filter == "all" ||
      git_change_review_status(progress, change.path) == model.git_change_filter
    )
  })
  let mut selected_index = -1
  if model.git_diff_workspace_id == workspace_id {
    for index in 0..<projection.changes.length() {
      if projection.changes[index].path == model.git_diff_path {
        selected_index = index
        break
      }
    }
  }
  section(
    class="mooncode-git-context",
    attrs=@html.Attrs::build()
      .aria_label("Repository changes")
      .data_set("testid", "mooncode-git-context"),
    [
      div(class="mooncode-git-heading", [
        div([
          strong(
            attrs=@html.Attrs::build()
              .data_set("i18n", "code.repo_change_count")
              .data_set(
                "i18n-params",
                ({ "count": projection.changes.length() } : Json).stringify(),
              ),
            "Changes · " + projection.changes.length().to_string(),
          ),
          match progress {
            Some(value) =>
              span(
                attrs=@html.Attrs::build()
                  .data_set(
                    "i18n",
                    if value.truncated {
                      "code.repo_review_progress_truncated"
                    } else {
                      "code.repo_review_progress"
                    },
                  )
                  .data_set(
                    "i18n-params",
                    (
                      {
                        "reviewed": value.reviewed,
                        "needs": value.needs_changes,
                        "pending": value.pending,
                      } : Json).stringify(),
                  ),
                value.reviewed.to_string() +
                " reviewed · " +
                value.needs_changes.to_string() +
                " needs changes · " +
                value.pending.to_string() +
                " pending" +
                (if value.truncated {
                  " · showing first 300 files"
                } else {
                  ""
                }),
              )
            None => @html.nothing
          },
          span(branch),
          span(
            attrs=@html.Attrs::build().data_set(
              "i18n",
              if projection.has_remote {
                "code.repo_remote_configured"
              } else {
                "code.repo_local_only"
              },
            ),
            if projection.has_remote {
              "Remote configured"
            } else {
              "Local only"
            },
          ),
        ]),
        refresh,
      ]),
      if projection.changes.is_empty() {
        p(
          class="mooncode-git-empty",
          attrs=@html.Attrs::build().data_set("i18n", "code.repo_clean"),
          "Working tree is clean",
        )
      } else if selected_index < 0 {
        div(class="mooncode-git-filters", [
          input(
            class="mooncode-git-search",
            attrs=@html.Attrs::build()
              .aria_label("Find changed file")
              .data_set("i18n-aria-label", "code.repo_find_file")
              .data_set("i18n-placeholder", "code.repo_find_file"),
            value=model.git_change_query,
            placeholder="Find changed file",
            on_input=fn(value) { dispatch(SetGitChangeQuery(value)) },
          ),
          div(class="mooncode-git-filter-options", [
            git_change_filter_button(
              dispatch,
              model.git_change_filter,
              "all",
              "All",
              "code.repo_filter_all",
            ),
            git_change_filter_button(
              dispatch,
              model.git_change_filter,
              "pending",
              "Pending",
              "code.repo_filter_pending",
            ),
            git_change_filter_button(
              dispatch,
              model.git_change_filter,
              "reviewed",
              "Reviewed",
              "code.repo_filter_reviewed",
            ),
            git_change_filter_button(
              dispatch,
              model.git_change_filter,
              "needs_changes",
              "Needs changes",
              "code.repo_filter_needs_changes",
            ),
          ]),
          span(
            class="mooncode-git-filter-count",
            attrs=@html.Attrs::build()
              .data_set("i18n", "code.repo_filter_count")
              .data_set(
                "i18n-params",
                (
                  {
                    "visible": visible_changes.length(),
                    "total": projection.changes.length(),
                  } : Json).stringify(),
              ),
            "\{visible_changes.length()} of \{projection.changes.length()} files",
          ),
        ])
      } else {
        @html.nothing
      },
      if projection.changes.is_empty() {
        @html.nothing
      } else if selected_index >= 0 {
        div(class="mooncode-git-review-nav", [
          span(
            attrs=@html.Attrs::build()
              .data_set("i18n", "code.repo_reviewing_file")
              .data_set(
                "i18n-params",
                (
                  {
                    "current": selected_index + 1,
                    "total": projection.changes.length(),
                  } : Json).stringify(),
              ),
            "Reviewing " +
            (selected_index + 1).to_string() +
            " of " +
            projection.changes.length().to_string() +
            " changed files",
          ),
          button(
            class="mooncode-git-open",
            attrs=@html.Attrs::build().data_set(
              "i18n", "code.repo_back_to_list",
            ),
            on_click=dispatch(CloseGitDiff),
            disabled=model.git_review_saving ||
              model.git_review_note.trim() != "",
            "Back to list",
          ),
          button(
            class="mooncode-git-open",
            attrs=@html.Attrs::build()
              .aria_label("Review previous file")
              .data_set("i18n-aria-label", "code.repo_previous_aria")
              .data_set("i18n", "code.repo_previous"),
            on_click=dispatch(
              OpenGitDiff(projection.changes[(selected_index - 1).max(0)].path),
            ),
            disabled=selected_index == 0 ||
              model.git_review_saving ||
              model.git_review_note.trim() != "",
            "Previous",
          ),
          button(
            class="mooncode-git-open",
            attrs=@html.Attrs::build()
              .aria_label("Review next file")
              .data_set("i18n-aria-label", "code.repo_next_aria")
              .data_set("i18n", "code.repo_next"),
            on_click=dispatch(
              OpenGitDiff(
                projection.changes[(selected_index + 1).min(
                  projection.changes.length() - 1,
                )].path,
              ),
            ),
            disabled=selected_index == projection.changes.length() - 1 ||
              model.git_review_saving ||
              model.git_review_note.trim() != "",
            "Next",
          ),
        ])
      } else if visible_changes.is_empty() {
        p(
          class="mooncode-git-empty",
          attrs=@html.Attrs::build().data_set("i18n", "code.repo_no_match"),
          "No changed files match this search or review filter.",
        )
      } else {
        div(
          class="mooncode-git-list",
          attrs=@html.Attrs::build().role("list"),
          visible_changes.map(change => {
            let unavailable = change.index_status == "D" ||
              change.worktree_status == "D"
            let review_status = git_change_review_status(progress, change.path)
            div(
              class="mooncode-git-change",
              attrs=@html.Attrs::build().role("listitem"),
              [
                div(class="mooncode-git-change-detail", [
                  span(class="mooncode-git-change-path", change.path),
                  div(class="mooncode-git-change-state", [
                    span(
                      attrs=@html.Attrs::build().data_set(
                        "i18n",
                        git_change_status_i18n_key(change),
                      ),
                      git_change_status_label(change),
                    ),
                    if change.previous_path == "" {
                      @html.nothing
                    } else {
                      span(
                        attrs=@html.Attrs::build()
                          .data_set("i18n", "code.repo_previous_path")
                          .data_set(
                            "i18n-params",
                            ({ "path": change.previous_path } : Json).stringify(),
                          ),
                        "From " + change.previous_path,
                      )
                    },
                    if review_status == "reviewed" {
                      span(
                        attrs=@html.Attrs::build().data_set(
                          "i18n", "code.review_reviewed",
                        ),
                        "Reviewed locally",
                      )
                    } else if review_status == "needs_changes" {
                      span(
                        attrs=@html.Attrs::build().data_set(
                          "i18n", "code.review_needs_changes",
                        ),
                        "Changes requested locally",
                      )
                    } else {
                      @html.nothing
                    },
                  ]),
                ]),
                button(
                  class="mooncode-git-open",
                  attrs=@html.Attrs::build()
                    .aria_label("Review changes to " + change.path)
                    .data_set("i18n-aria-label", "code.repo_review_change_aria")
                    .data_set(
                      "i18n-params",
                      ({ "path": change.path } : Json).stringify(),
                    )
                    .data_set("i18n", "code.repo_review_action"),
                  on_click=dispatch(OpenGitDiff(change.path)),
                  "Review",
                ),
                button(
                  class="mooncode-git-open",
                  attrs=@html.Attrs::build()
                    .aria_label("Open " + change.path + " in source editor")
                    .data_set("i18n-aria-label", "code.repo_open_source_aria")
                    .data_set(
                      "i18n-params",
                      ({ "path": change.path } : Json).stringify(),
                    )
                    .data_set(
                      "i18n",
                      if unavailable {
                        "code.repo_deleted_action"
                      } else {
                        "code.repo_open_action"
                      },
                    )
                    .data_set("action", "git-open-source"),
                  on_click=dispatch(OpenGitChange(change.path)),
                  disabled=unavailable ||
                    model.git_review_saving ||
                    model.git_review_note.trim() != "",
                  if unavailable {
                    "Deleted"
                  } else {
                    "Open"
                  },
                ),
              ],
            )
          }),
        )
      },
      if projection.truncated {
        p(
          class="mooncode-git-note",
          attrs=@html.Attrs::build().data_set("i18n", "code.repo_truncated"),
          "Showing the first 300 changed files. Refresh after narrowing the repository changes.",
        )
      } else {
        @html.nothing
      },
      match progress {
        Some(value) if !value.truncated &&
          value.reviewed > 0 &&
          value.pending == 0 &&
          value.needs_changes == 0 =>
          div(class="mooncode-git-review-complete", [
            strong(
              attrs=@html.Attrs::build().data_set(
                "i18n", "code.repo_review_complete",
              ),
              "Git changes reviewed locally at last refresh",
            ),
            span(
              attrs=@html.Attrs::build().data_set(
                "i18n", "code.repo_outcome_separate",
              ),
              "MoonBook outcome review is a separate decision.",
            ),
            button(
              class="mooncode-git-open",
              attrs=@html.Attrs::build().data_set(
                "i18n", "code.repo_open_book_review",
              ),
              on_click=dispatch(SelectWorkspaceMode(ReviewWorkspace)),
              disabled=model.git_review_saving ||
                model.git_review_note.trim() != "",
              "Open MoonBook review",
            ),
          ])
        _ => @html.nothing
      },
      render_github_context(dispatch, model, projection.branch),
      render_github_inline_review(
        dispatch,
        model,
        workspace_id,
        projection.head,
      ),
      render_git_diff_panel(dispatch, model, workspace_id, projection.head),
    ],
  )
}
