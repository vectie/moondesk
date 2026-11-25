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
fn github_inline_file_group(path : String) -> String {
  if !path.contains("/") {
    return "/"
  }
  for segment in path.split("/") {
    return segment.to_owned()
  }
  "/"
}

///|
fn render_github_inline_file_button(
  dispatch : Dispatch[Msg],
  model : Model,
  file : GitHubInlineFileProjection,
) -> @rabbita.Html {
  button(
    class="mooncode-git-open" +
      (if file.path == model.github_inline_path { " active" } else { "" }),
    attrs=@html.Attrs::build()
      .aria_label("Review PR file " + file.path)
      .data_set("i18n-aria-label", "code.github_review_file_aria")
      .data_set("i18n-params", ({ "path": file.path } : Json).stringify())
      .aria_pressed(
        if file.path == model.github_inline_path {
          "true"
        } else {
          "false"
        },
      ),
    on_click=dispatch(SelectGitHubInlineFile(file.path)),
    disabled=model.github_inline_saving || model.github_inline_saving_draft,
    file.path,
  )
}

///|
fn render_github_inline_file_groups(
  dispatch : Dispatch[Msg],
  model : Model,
  files : Array[GitHubInlineFileProjection],
) -> @rabbita.Html {
  let order : Array[String] = []
  let grouped : Map[String, Array[GitHubInlineFileProjection]] = Map([])
  for file in files {
    let group = github_inline_file_group(file.path)
    if !grouped.contains(group) {
      order.push(group)
      grouped[group] = []
    }
    let siblings = grouped.get(group).unwrap_or([])
    siblings.push(file)
    grouped[group] = siblings
  }
  div(
    class="mooncode-github-inline-files",
    order.map(group => {
      let siblings = grouped.get(group).unwrap_or([])
      div(
        class="mooncode-github-file-group" +
          (if group == github_inline_file_group(model.github_inline_path) {
            " selected"
          } else {
            ""
          }),
        attrs=@html.Attrs::build().role("group").aria_label(group),
        [
          div(class="mooncode-github-file-group-heading", [
            span(group),
            span(siblings.length().to_string()),
          ]),
          div(
            class="mooncode-github-file-group-items",
            attrs=@html.Attrs::build().role("list"),
            siblings.map(file => {
              div(attrs=@html.Attrs::build().role("listitem"), [
                render_github_inline_file_button(dispatch, model, file),
              ])
            }),
          ),
        ],
      )
    }),
  )
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
        div(class="mooncode-git-review-recovery", [
          p(
            class="mooncode-git-review-error",
            attrs=@html.Attrs::build().role("status").aria_live("polite"),
            model.github_inline_error,
          ),
          button(
            class="mooncode-git-open",
            attrs=@html.Attrs::build().data_set("i18n", "code.retry"),
            on_click=dispatch(
              OpenGitHubInlineReview(model.github_inline_number),
            ),
            "Retry",
          ),
        ])
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
              render_github_inline_file_groups(dispatch, model, visible_files),
              if review.truncated {
                p(
                  class="mooncode-git-note",
                  attrs=@html.Attrs::build().data_set(
                    "i18n", "code.github_files_truncated",
                  ),
                  "GitHub has more than 300 files; only the first 300 are shown.",
                )
              } else {
                @html.nothing
              },
              file_view,
              if model.github_inline_line > 0 || model.github_inline_draft != "" {
                div(class="mooncode-github-comment-draft", [
                  p(
                    attrs=@html.Attrs::build()
                      .data_set(
                        "i18n",
                        if model.github_inline_line <= 0 {
                          "code.github_line_reanchor"
                        } else if model.github_inline_side == "left" {
                          "code.github_line_location_left"
                        } else {
                          "code.github_line_location_right"
                        },
                      )
                      .data_set(
                        "i18n-params",
                        (
                          {
                            "path": model.github_inline_path,
                            "line": model.github_inline_line,
                          } : Json).stringify(),
                      ),
                    if model.github_inline_line > 0 {
                      "Line comment on " +
                      model.github_inline_path +
                      " · " +
                      model.github_inline_side +
                      " line " +
                      model.github_inline_line.to_string()
                    } else {
                      "Retained draft needs a new line in " +
                      model.github_inline_path
                    },
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
                  attrs=@html.Attrs::build()
                    .data_set(
                      "i18n",
                      if model.github_inline_side == "left" {
                        "code.github_saved_line_location_left"
                      } else {
                        "code.github_saved_line_location_right"
                      },
                    )
                    .data_set(
                      "i18n-params",
                      (
                        {
                          "path": model.github_inline_path,
                          "line": model.github_inline_line,
                        } : Json).stringify(),
                    ),
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
    attrs=@html.Attrs::build()
      .aria_label("Saved PR line drafts")
      .data_set("i18n-aria-label", "code.github_saved_lines_aria"),
    context.inline_drafts.map(draft => {
      div(class="mooncode-github-comment-draft", [
        strong(
          attrs=@html.Attrs::build()
            .data_set("i18n", "code.github_saved_line_summary")
            .data_set(
              "i18n-params",
              ({ "number": draft.number, "path": draft.path } : Json).stringify(),
            ),
          "Saved line draft · PR #" +
          draft.number.to_string() +
          " · " +
          draft.path,
        ),
        span(
          attrs=@html.Attrs::build()
            .data_set(
              "i18n",
              if draft.side == "left" {
                "code.github_saved_line_side_left"
              } else {
                "code.github_saved_line_side_right"
              },
            )
            .data_set(
              "i18n-params",
              ({ "line": draft.line } : Json).stringify(),
            ),
          draft.side + " line " + draft.line.to_string(),
        ),
        button(
          class="mooncode-git-open",
          attrs=@html.Attrs::build().data_set(
            "i18n", "code.github_open_saved_line",
          ),
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
