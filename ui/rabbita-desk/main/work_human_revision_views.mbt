///|
fn render_work_human_revision(
  dispatch : Dispatch[Msg],
  handoff : WorkHandoffState,
  target : WorkHandoffTarget,
  _canonical : WorkHandoffCanonical,
) -> @rabbita.Html {
  if handoff.output_hint is Null {
    return @html.nothing
  }
  let state = handoff.human_revision
  section(
    class="work-human-revision",
    attrs=@html.Attrs::build().data_set("testid", "work-human-revision"),
    [
      h3("2 · Edit this output yourself"),
      if !state.enabled {
        p(
          "This work link is inspection-only. Open the current unaccepted task in MoonProj to edit an output; accepted tasks keep their existing report.",
        )
      } else {
        div([
          p(
            "Edit one UTF-8 text output, up to 256 KiB. The base is the current file when opened, which may differ from the agent’s original bytes.",
          ),
          p(
            "Save revision for this task retains a separate human-authored version. It leaves the agent’s working file untouched.",
          ),
          if ["idle", "open_failed"].contains(state.phase) {
            button(
              attrs=@html.Attrs::build().disabled(
                handoff.phase != "ready" ||
                handoff_text(handoff.output, "state") != "ready",
              ),
              on_click=dispatch(WorkHandoff(HumanRevision(RevisionOpen))),
              "Edit current text file",
            )
          } else {
            @html.nothing
          },
          if ["editing", "saving", "retry", "conflict"].contains(state.phase) {
            div([
              p("Human edit · " + handoff_text(handoff.output_hint, "path")),
              if !(state.operation is Null) {
                p(
                  "Revision identity: " +
                  handoff_text(state.operation, "revision_id"),
                )
              } else {
                @html.nothing
              },
              textarea(
                value=state.draft,
                rows=18,
                attrs=@html.Attrs::build()
                  .disabled(state.phase != "editing")
                  .aria_label("Human-edited output"),
                on_input=value => {
                  dispatch(WorkHandoff(HumanRevision(RevisionDraft(value))))
                },
                "",
              ),
              if state.base_digest != "" {
                p("Base file SHA-256: " + state.base_digest)
              } else {
                @html.nothing
              },
              if !state.local_saved {
                p(
                  attrs=@html.Attrs::build().role("alert"),
                  "This edit is not retained in this browser. Keep this page open and copy the text before leaving.",
                )
              } else {
                p(
                  "Draft and pending save identity are retained in this browser for this exact output.",
                )
              },
              if work_human_revision_utf8_length(state.draft) > 262144 {
                p(
                  "This text exceeds the 256 KiB UTF-8 limit. Shorten it before saving.",
                )
              } else if state.draft.contains("\u0000") {
                p(
                  "Binary NUL characters are not supported in a text revision. Your draft is preserved.",
                )
              } else {
                @html.nothing
              },
              render_work_human_revision_comparison(
                state.baseline,
                state.draft,
                "Review my changes",
                "baseline file for this edit",
                if state.phase == "editing" {
                  "my draft"
                } else {
                  "retained draft for this save"
                },
              ),
              if ["editing", "retry"].contains(state.phase) {
                button(
                  attrs=@html.Attrs::build().disabled(
                    handoff.phase != "ready" ||
                    work_human_revision_utf8_length(state.draft) > 262144 ||
                    state.draft.contains("\u0000") ||
                    (state.phase == "editing" && state.draft == state.baseline),
                  ),
                  on_click=dispatch(WorkHandoff(HumanRevision(RevisionSave))),
                  if state.phase == "retry" {
                    "Recover this same save and revision"
                  } else {
                    "Save revision for this task"
                  },
                )
              } else {
                @html.nothing
              },
              button(
                on_click=dispatch(WorkHandoff(HumanRevision(RevisionCopy))),
                "Copy my edit",
              ),
              match state.current_content {
                Some(current) if state.phase == "conflict" =>
                  details(open=true, [
                    summary("Current file after the conflict"),
                    p(
                      "The working file changed since editing began. Compare all three versions before choosing a new baseline.",
                    ),
                    render_work_human_revision_comparison(
                      state.baseline,
                      current,
                      "What changed in the working file?",
                      "baseline file for this edit",
                      "current working file",
                    ),
                    render_work_human_revision_comparison(
                      current,
                      state.draft,
                      "Compare current file with my draft",
                      "current working file",
                      "my preserved draft",
                    ),
                    button(
                      on_click=dispatch(
                        WorkHandoff(HumanRevision(RevisionRebase)),
                      ),
                      "Use this file as the new baseline; keep my draft",
                    ),
                  ])
                _ => @html.nothing
              },
            ])
          } else {
            @html.nothing
          },
          if state.message != "" {
            p(
              attrs=@html.Attrs::build().role("status").aria_live("polite"),
              state.message,
            )
          } else {
            @html.nothing
          },
          if state.phase == "saved" {
            let revision = state.revision
            let id = handoff_text(revision, "revision_id")
            let back = work_human_revision_return_url(
              target.return_to,
              target.task_id,
              id,
            )
            div([
              h3("3 · Return your saved revision"),
              p("Human-authored revision · " + id),
              p(
                "Retained SHA-256: " +
                handoff_text(handoff_field(revision, "content"), "sha256"),
              ),
              render_work_human_revision_comparison(
                state.baseline,
                state.draft,
                "Review my saved changes",
                "baseline file for this edit",
                "confirmed retained human revision",
              ),
              a(
                href=work_human_revision_download_url(state.draft),
                download="human-revision.txt",
                "Download this retained revision",
              ),
              if back == "" {
                p(
                  "Return link unavailable. Reopen this exact task in MoonProj and select revision " +
                  id,
                )
              } else {
                a(
                  href=back,
                  attrs=@html.Attrs::build().rel("noreferrer"),
                  "Return this human revision to MoonProj for review",
                )
              },
              p(
                "MoonProj will read this retained revision. The working file is unchanged by this save. Selecting, reporting and accepting remain separate actions; no agent execution or promotion receipt is created.",
              ),
              button(
                on_click=dispatch(WorkHandoff(HumanRevision(RevisionOpen))),
                "Edit another revision of the current file",
              ),
            ])
          } else {
            @html.nothing
          },
        ])
      },
    ],
  )
}

///|
fn render_work_human_revision_pending(
  dispatch : Dispatch[Msg],
  handoff : WorkHandoffState,
) -> @rabbita.Html {
  let state = handoff.human_revision
  if handoff.canonical is Some(_) || state.operation is Null {
    return @html.nothing
  }
  details(open=true, [
    summary("Retained human revision operation · confirmation pending"),
    p("Revision identity: " + handoff_text(state.operation, "revision_id")),
    p(
      "Capture may already exist. Return confirmation is pending native identity verification. Refresh exact work to retry; your exact draft is retained below.",
    ),
    render_work_human_revision_comparison(
      state.baseline,
      state.draft,
      "Review my retained changes",
      "baseline file for this edit",
      "retained draft; save confirmation pending",
    ),
    button(
      on_click=dispatch(WorkHandoff(HumanRevision(RevisionCopy))),
      "Copy retained draft",
    ),
  ])
}
