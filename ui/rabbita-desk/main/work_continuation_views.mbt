///|
fn render_work_continuation(
  dispatch : Dispatch[Msg],
  handoff : WorkHandoffState,
  target : WorkHandoffTarget,
  canonical : WorkHandoffCanonical,
) -> @rabbita.Html {
  let state = handoff.continuation
  let current = work_continuation_current(state)
  let selected = state.records
    .filter(record => {
      handoff_text(record, "continuation_id") == state.selected_return &&
      handoff_text(record, "state") == "completed" &&
      handoff_text(record, "admission") == "accepted" &&
      work_continuation_input_verified(record)
    })
    .get(0)
  section(class="work-continuation", [
    h3("2 · Request a change"),
    h3("Pending guidance"),
    p(
      "Session-wide pending human guidance is separate from this fresh input. Existing native semantics remain in effect; old checkpoints and approvals are not imported.",
    ),
    if state.guidance_state != "ready" {
      p(
        "Pending guidance is unavailable. Refresh exact work to inspect it before submitting.",
      )
    } else if state.pending_guidance.is_empty() {
      p("No pending native guidance was reported.")
    } else {
      div(
        state.pending_guidance.map(item => {
          div([
            strong(
              handoff_text(item, "command_id") +
              " · " +
              handoff_text(item, "receipt_status"),
            ),
            pre(handoff_text(item, "text")),
          ])
        }),
      )
    },
    if !state.enabled {
      p(
        "Inspection only. Open Continue this work from a currently unaccepted MoonProj task to create a follow-up.",
      )
    } else {
      div([
        h3("New human instruction"),
        p("Based on command: " + state.prior_command),
        if state.phase == "draft" &&
          handoff.phase == "ready" &&
          !work_continuation_draft_prior_valid(target, state) {
          p(
            "The draft's prior result is not verified here. Refresh exact work or choose a verified prior result before submitting.",
          )
        } else {
          @html.nothing
        },
        details(class="technical-details", [
          summary("Instruction context"),
          p(
            "Captured model: " +
            canonical.model +
            " · Original context: " +
            canonical.context_path,
          ),
        ]),
        button(
          attrs=@html.Attrs::build().disabled(state.phase != "draft"),
          on_click=dispatch(
            WorkHandoff(FollowUp(Prior(state.draft_token, target.command_id))),
          ),
          "Use original execution as prior result",
        ),
        textarea(
          value=state.draft,
          maxlength=65536,
          attrs=@html.Attrs::build().disabled(state.phase != "draft"),
          on_input=value => {
            dispatch(WorkHandoff(FollowUp(Draft(state.draft_token, value))))
          },
          "",
        ),
        if state.phase == "draft" || state.draft_status == "retire_failed" {
          p(
            attrs=@html.Attrs::build().aria_live("polite"),
            work_continuation_draft_status(state),
          )
        } else {
          @html.nothing
        },
        if state.phase == "draft" {
          div([
            if ["storage_failed", "too_large"].contains(state.draft_status) {
              div([
                button(
                  on_click=dispatch(
                    WorkHandoff(FollowUp(Draft(state.draft_token, state.draft))),
                  ),
                  "Retry saving draft locally",
                ),
                button(
                  on_click=dispatch(
                    WorkHandoff(FollowUp(CopyDraft(state.draft_token))),
                  ),
                  "Copy draft",
                ),
              ])
            } else {
              @html.nothing
            },
            if state.draft != "" ||
              state.draft_status == "invalid" ||
              state.draft_status == "storage_failed" {
              button(
                on_click=dispatch(
                  WorkHandoff(FollowUp(DiscardDraft(state.draft_token))),
                ),
                "Discard unsent draft",
              )
            } else {
              @html.nothing
            },
          ])
        } else {
          @html.nothing
        },
        p(
          "The exact instruction and operation identity are saved in this browser before submission. The host captures the immutable input and uses a fresh command/horizon. Browsing files or changing ordinary chat preferences does not change it.",
        ),
        if state.phase == "draft" || state.phase == "missing" {
          button(
            attrs=@html.Attrs::build().disabled(
              handoff.phase != "ready" || state.draft.trim().is_empty(),
            ),
            on_click=dispatch(WorkHandoff(FollowUp(Submit))),
            if state.phase == "missing" {
              "Retry same saved operation (not yet captured)"
            } else {
              "Capture and start fresh follow-up"
            },
          )
        } else {
          p(
            "Saved operation: " +
            handoff_text(state.operation, "continuation_id") +
            " · " +
            state.phase,
          )
        },
        if state.phase == "saved" &&
          (
            !work_continuation_settled(current) ||
            handoff_text(current, "input_status") == "missing"
          ) {
          button(
            on_click=dispatch(WorkHandoff(FollowUp(Resume))),
            if handoff_text(current, "input_status") == "missing" {
              "Restore captured input for this exact follow-up"
            } else {
              "Resume this exact follow-up"
            },
          )
        } else {
          @html.nothing
        },
        if ["uncertain", "recovering", "storage_failed", "conflict"].contains(
            state.phase,
          ) {
          button(
            on_click=dispatch(WorkHandoff(FollowUp(Recover))),
            "Recover saved operation",
          )
        } else {
          @html.nothing
        },
        if state.phase != "conflict" && work_continuation_settled(current) {
          button(
            on_click=dispatch(WorkHandoff(FollowUp(New))),
            "Prepare another distinct follow-up",
          )
        } else {
          @html.nothing
        },
        if (state.phase == "storage_failed" && !state.prior_uncertainty) ||
          (state.phase == "missing" && !state.admission_possible) {
          button(
            on_click=dispatch(WorkHandoff(FollowUp(New))),
            "Discard uncaptured input and prepare a new instruction",
          )
        } else {
          @html.nothing
        },
        if state.error != "" {
          p(state.error)
        } else {
          @html.nothing
        },
      ])
    },
    h3("3 · Return selected result"),
    p(
      "Distinct human follow-ups. Select the completed result you want MoonProj to review.",
    ),
    div(
      state.records.map(record => {
        div([
          strong(
            handoff_text(record, "command_id") +
            " · " +
            handoff_text(record, "state"),
          ),
          p(
            "Input status: " +
            handoff_text(record, "input_status") +
            " · Native runtime: " +
            handoff_text(record, "runtime_status") +
            " · " +
            handoff_text(record, "message"),
          ),
          pre(handoff_text(record, "instruction")),
          details(class="technical-details", [
            summary("Follow-up identity and context"),
            p(
              "Operation: " +
              handoff_text(record, "continuation_id") +
              " · Admission: " +
              handoff_text(record, "admission"),
            ),
            p(
              "Historical prior result: " +
              handoff_text(record, "prior_result_command_id") +
              " · Captured model: " +
              handoff_text(record, "model"),
            ),
            p(
              "Immutable input: " +
              handoff_text(handoff_field(record, "input"), "path") +
              " · SHA-256: " +
              handoff_text(handoff_field(record, "input"), "sha256"),
            ),
          ]),
          pre(handoff_text(record, "summary")),
          pre(handoff_text(record, "error")),
          render_work_continuation_outputs(
            target,
            record,
            allow_edit=handoff.human_revision.enabled,
          ),
          details([
            summary("Exact result references"),
            pre(handoff_field(record, "evidence").stringify()),
            pre(handoff_field(record, "output_refs").stringify()),
          ]),
          if handoff_text(record, "state") == "completed" &&
            handoff_text(record, "admission") == "accepted" &&
            work_continuation_input_verified(record) {
            button(
              on_click=dispatch(
                WorkHandoff(
                  FollowUp(
                    SelectReturn(handoff_text(record, "continuation_id")),
                  ),
                ),
              ),
              if state.selected_return ==
                handoff_text(record, "continuation_id") {
                "Selected exact result"
              } else {
                "Select this exact result for return"
              },
            )
          } else {
            @html.nothing
          },
          if state.enabled &&
            state.phase == "draft" &&
            work_continuation_settled(record) &&
            work_continuation_input_verified(record) {
            button(
              on_click=dispatch(
                WorkHandoff(
                  FollowUp(
                    Prior(state.draft_token, handoff_text(record, "command_id")),
                  ),
                ),
              ),
              "Use this as historical prior result",
            )
          } else {
            @html.nothing
          },
        ])
      }),
    ),
    match selected {
      None =>
        p(
          "Choose a completed exact follow-up above before returning its result. Later commands never replace your selection.",
        )
      Some(record) => {
        let back = work_continuation_return_url(
          target.return_to,
          target.task_id,
          target.run_id,
          handoff_text(record, "continuation_id"),
          handoff_text(record, "command_id"),
        )
        if back == "" {
          p(
            "Return link unavailable. Open the exact task in MoonProj and inspect this command identity.",
          )
        } else {
          a(
            href=back,
            attrs=@html.Attrs::build().rel("noreferrer"),
            "Return selected result to MoonProj for review · " +
            handoff_text(record, "command_id"),
          )
        }
      }
    },
  ])
}
