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
