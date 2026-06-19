///|
fn render_mooncode_patch_set_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="mooncode-review-board patch-set-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "file review object"),
        h3("Patch Set"),
      ]),
      span(class="record-kind", model.mooncode_patch_set_status),
    ]),
    match model.mooncode_patch_set {
      Some(patch_set) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Patches", patch_set.patch_count.to_string()),
            info_chip("Pending", patch_set.pending_patch_count.to_string()),
            info_chip("Accepted", patch_set.accepted_patch_count.to_string()),
            info_chip("Rejected", patch_set.rejected_patch_count.to_string()),
            info_chip("Applied", patch_set.applied_patch_count.to_string()),
            info_chip("Reverted", patch_set.reverted_patch_count.to_string()),
            info_chip(
              "Runtime applied",
              patch_set.runtime_applied_patch_count.to_string(),
            ),
            info_chip(
              "Runtime proof",
              patch_set.runtime_patch_proof_count.to_string(),
            ),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Manifest", patch_set.manifest_path),
            info_row("Recorded", patch_set.recorded_at),
            info_row("Status", patch_set.status),
            info_row("Execution", patch_set.execution_status),
          ]),
          if patch_set.patches.length() == 0 {
            p(class="status-line", "no staged file patches")
          } else {
            div(
              class="mooncode-review-list patch-set-list",
              patch_set.patches[:mooncode_patch_set_limit(patch_set.patches)].map(
                patch => render_mooncode_patch_set_entry(dispatch, patch),
              ),
            )
          },
        ])
      None =>
        p(
          class="status-line",
          "No durable MoonBook patch set has been recorded for this session yet.",
        )
    },
  ])
}

///|
fn mooncode_patch_set_limit(entries : Array[MoonCodePatchSetEntry]) -> Int {
  if entries.length() > 6 {
    6
  } else {
    entries.length()
  }
}

///|
fn render_mooncode_patch_set_entry(
  dispatch : Dispatch[Msg],
  patch : MoonCodePatchSetEntry,
) -> @rabbita.Html {
  div(class="mooncode-review-item " + patch.review_state, [
    div(class="mooncode-review-head", [
      div([
        strong(if patch.path == "" { patch.title } else { patch.path }),
        small(patch.review_state + " / " + patch.created_at),
        small("execution: " + patch.execution_state),
      ]),
      div(class="toolbar-actions", [
        if patch.path == "" {
          span(class="hidden-inline", "")
        } else {
          button(
            class="secondary-button",
            on_click=dispatch(OpenQuickPath(patch.path)),
            "Open",
          )
        },
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("accept", patch.path)),
          "Accept",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("reject", patch.path)),
          "Reject",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("apply_patch", patch.path)),
          "Apply",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("revert_patch", patch.path)),
          "Revert",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("package", patch.path)),
          "Package",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("commit", patch.path)),
          "Commit",
        ),
      ]),
    ]),
    div(class="mooncode-stats", [
      info_chip("Gate", mooncode_optional_text_label(patch.gate_status)),
      info_chip("Next", mooncode_optional_text_label(patch.next_action)),
      info_chip("Accepts", patch.accepted_review_count.to_string()),
      info_chip("Rejects", patch.rejected_review_count.to_string()),
      info_chip("Applies", patch.applied_review_count.to_string()),
      info_chip("Reverts", patch.reverted_review_count.to_string()),
      info_chip("Runtime", patch.runtime_proof_count.to_string()),
      info_chip("Executed", if patch.execution_verified { "yes" } else { "no" }),
      info_chip("Packages", patch.package_review_count.to_string()),
      info_chip("Hunks", patch.hunk_count.to_string()),
    ]),
    match patch.blocked_reason {
      Some(reason) =>
        if reason == "" {
          span(class="hidden-inline", "")
        } else {
          p(class="mooncode-event-detail", reason)
        }
      None => span(class="hidden-inline", "")
    },
    render_mooncode_patch_hunks(dispatch, patch),
    if patch.diff_present {
      pre(class="source-block compact", code(patch.diff))
    } else {
      p(class="mooncode-event-detail", patch.detail)
    },
  ])
}

///|
fn render_mooncode_patch_hunks(
  dispatch : Dispatch[Msg],
  patch : MoonCodePatchSetEntry,
) -> @rabbita.Html {
  if patch.hunks.length() == 0 {
    p(class="status-line", "no hunk metadata")
  } else {
    div(
      class="mooncode-hunk-list",
      patch.hunks[:mooncode_patch_hunk_limit(patch.hunks)].map(hunk => {
        div(class="mooncode-hunk " + hunk.review_state, [
          div(class="mooncode-event-head", [
            span(class="record-kind", hunk.id),
            strong(if hunk.header == "" { "synthetic" } else { hunk.header }),
          ]),
          div(class="mooncode-stats", [
            info_chip("Gate", mooncode_optional_text_label(hunk.gate_status)),
            info_chip("Next", mooncode_optional_text_label(hunk.next_action)),
            info_chip("State", hunk.review_state),
            info_chip("Exec", hunk.execution_state),
            info_chip("+", hunk.added_lines.to_string()),
            info_chip("-", hunk.removed_lines.to_string()),
            info_chip("ctx", hunk.context_lines.to_string()),
            info_chip("Accepts", hunk.accepted_review_count.to_string()),
            info_chip("Rejects", hunk.rejected_review_count.to_string()),
            info_chip("Runtime", hunk.runtime_proof_count.to_string()),
          ]),
          div(class="toolbar-actions hunk-actions", [
            button(
              class="secondary-button",
              on_click=dispatch(RunMoonCodeCommandForPath("accept", hunk.target)),
              "Accept",
            ),
            button(
              class="secondary-button",
              on_click=dispatch(RunMoonCodeCommandForPath("reject", hunk.target)),
              "Reject",
            ),
            button(
              class="secondary-button",
              on_click=dispatch(
                RunMoonCodeCommandForPath("apply_patch", hunk.target),
              ),
              "Apply",
            ),
            button(
              class="secondary-button",
              on_click=dispatch(
                RunMoonCodeCommandForPath("revert_patch", hunk.target),
              ),
              "Revert",
            ),
          ]),
          match hunk.blocked_reason {
            Some(reason) =>
              if reason == "" {
                span(class="hidden-inline", "")
              } else {
                small(class="status-line", reason)
              }
            None => span(class="hidden-inline", "")
          },
        ])
      }),
    )
  }
}

///|
fn mooncode_patch_hunk_limit(hunks : Array[MoonCodePatchHunk]) -> Int {
  if hunks.length() > 4 {
    4
  } else {
    hunks.length()
  }
}
