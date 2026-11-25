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
fn github_check_status_i18n_key(status : String) -> String {
  match status {
    "SUCCESS" | "success" => "code.github_check_success"
    "FAILURE" | "failure" => "code.github_check_failure"
    "ERROR" | "error" | "STARTUP_FAILURE" => "code.github_check_error"
    "TIMED_OUT" => "code.github_check_timed_out"
    "CANCELLED" | "cancelled" => "code.github_check_cancelled"
    "ACTION_REQUIRED" => "code.github_check_action_required"
    "NEUTRAL" => "code.github_check_neutral"
    "SKIPPED" => "code.github_check_skipped"
    "STALE" => "code.github_check_stale"
    "IN_PROGRESS" => "code.github_check_in_progress"
    "QUEUED" | "PENDING" => "code.github_check_queued"
    "COMPLETED" => "code.github_check_completed"
    "unknown" => "code.github_check_unknown"
    _ => ""
  }
}

///|
fn github_review_decision_i18n_key(decision : String) -> String {
  match decision {
    "APPROVED" => "code.github_review_approved"
    "CHANGES_REQUESTED" => "code.github_review_changes_requested"
    "REVIEW_REQUIRED" => "code.github_review_required"
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
            div(
              class="mooncode-git-review-comment",
              attrs=@html.Attrs::build()
                .data_set("review-finding", record.note)
                .data_set("path", diff.path)
                .data_set("revision", diff.head)
                .data_set("line", record.line.unwrap_or(0).to_string()),
              [
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
              ],
            ),
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
fn render_git_repository_context(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let workspace_id = mooncode_git_workspace_id(model)
  if workspace_id == "" {
    return @html.nothing
  }
  let refresh = button(
    class="mooncode-git-refresh moon-icon-button",
    attrs=@html.Attrs::build()
      .data_set("testid", "mooncode-git-refresh")
      .aria_label("Refresh repository changes")
      .data_set("i18n-aria-label", "code.repo_refresh"),
    on_click=dispatch(RefreshGitRepositoryProjection(workspace_id)),
    disabled=model.git_projection_loading ||
      model.git_review_saving ||
      model.git_review_note.trim() != "",
    [ui_icon("refresh")],
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
          interface_label(
            "code.repo_changes_loading", "Reading repository changes…",
          ),
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
    return section(class="mooncode-git-context", [
      span(
        interface_label(
          "code.repo_not_loaded", "Repository changes have not been loaded.",
        ),
      ),
      refresh,
    ])
  }
  if projection.state == "not_repository" {
    return section(class="mooncode-git-context", [
      span(
        interface_label(
          "code.repo_not_git", "This MoonBook is not a Git repository.",
        ),
      ),
      refresh,
    ])
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
          span(
            attrs=@html.Attrs::build().data_set(
              "i18n",
              if projection.branch != "" {
                ""
              } else if projection.head == "" {
                "code.repo_new_repository"
              } else {
                "code.repo_detached_head"
              },
            ),
            branch,
          ),
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
      div(
        attrs=@html.Attrs::build()
          .data_set("runtime", "review-workflow-v1")
          .data_set("workspace-id", workspace_id),
        @html.nothing,
      ),
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
