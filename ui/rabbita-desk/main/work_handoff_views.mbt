///|
fn render_work_handoff_rail(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  aside(class="activity-pane mooncode-rail", [
    h2("Captured work"),
    p(
      "Inspect the original execution and any separately captured human follow-ups. Ordinary chat is available after Exit.",
    ),
    button(on_click=dispatch(WorkHandoff(Exit)), "Exit inspection"),
    button(on_click=dispatch(NewMoonCodeSession), "New chat"),
    render_work_resume(dispatch, model),
  ])
}

///|
fn render_work_handoff(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let state = model.work_handoff
  guard state.target is Some(target) else { return @html.nothing }
  let return_url = handoff_safe_return(target.return_to, target.task_id)
  section(
    class="preview-center mooncode-center work-handoff",
    attrs=@html.Attrs::build().data_set("testid", "work-handoff"),
    [
      section(
        class="work-handoff-banner",
        attrs=@html.Attrs::build().role("status").aria_live("polite"),
        [
          h2(
            if state.human_revision.enabled && !(state.output_hint is Null) {
              "MoonProj work · human-edited output"
            } else if state.continuation.enabled {
              "MoonProj work · fresh human follow-up"
            } else {
              "MoonProj work · inspection only"
            },
          ),
          p(state.message),
          render_work_human_revision_pending(dispatch, state),
          p(
            "Task: " +
            target.task_id +
            " · Original command: " +
            target.command_id,
          ),
          details(class="technical-details", [
            summary("Work identity and navigation"),
            p("MoonProj task / run: " + target.task_id + " / " + target.run_id),
            p(
              "Original session / command: " +
              target.session_id +
              " / " +
              target.command_id,
            ),
            p("Requested book root: " + target.book_root),
          ]),
          p(
            if state.human_revision.enabled && !(state.output_hint is Null) {
              "Save your own revision of this output, then return it for review. Original execution and accepted reports remain separate."
            } else if state.continuation.enabled {
              "A follow-up creates a fresh command with the captured model and context. Original Resume remains a separate action in MoonProj. Returning a result does not accept it."
            } else {
              "This view does not submit a follow-up or import a result. Accepted tasks also remain inspection-only."
            },
          ),
          if return_url == "" {
            p("Return link unavailable. Reopen the exact task in MoonProj.")
          } else {
            a(
              href=return_url,
              attrs=@html.Attrs::build().rel("noreferrer"),
              "Return to MoonProj · " + handoff_return_host(return_url),
            )
          },
          button(
            attrs=@html.Attrs::build().disabled(
              state.phase == "loading" ||
              state.phase == "invalid_request" ||
              ["opening", "saving"].contains(state.human_revision.phase),
            ),
            on_click=dispatch(WorkHandoff(Resolve)),
            "Refresh exact work",
          ),
          button(on_click=dispatch(WorkHandoff(Exit)), "Exit inspection"),
        ],
      ),
      match state.canonical {
        None =>
          p(
            "The URL is a navigation hint until this Desk host resolves it. No other chat is opened here.",
          )
        Some(canonical) =>
          div([
            h3("1 · Inspect result"),
            p("Book: " + @desk.display_name(canonical.root_path)),
            button(
              attrs=@html.Attrs::build().disabled(
                work_learning_refresh_pending(model),
              ),
              on_click=dispatch(WorkHandoff(ReviewLearning(state.generation))),
              "Review this Book’s learning",
            ),
            if work_learning_refresh_pending(model) {
              p(
                "Finish or recover the current follow-up before opening Learning Review; it may still refresh this view.",
              )
            } else {
              @html.nothing
            },
            p(
              "Original execution: " +
              canonical.claim_status +
              " · " +
              handoff_display(canonical.receipt_status),
            ),
            render_work_output(state, canonical),
            render_work_human_revision(dispatch, state, target, canonical),
            if state.output_hint is Null {
              match state.session {
                Some(session) =>
                  render_work_handoff_original_result(
                    model,
                    session,
                    target.command_id,
                    dispatch~,
                  )
                None =>
                  p(
                    "Original result text is not available yet. Refresh exact work to read its saved transcript.",
                  )
              }
            } else {
              @html.nothing
            },
            if state.session_error != "" {
              p(state.session_error)
            } else {
              @html.nothing
            },
            render_work_handoff_context(state.context, canonical),
            details(class="technical-details", [
              summary("Captured original command details"),
              p(
                "Workspace: " +
                canonical.workspace_id +
                " · " +
                canonical.root_path,
              ),
              p(
                "Action: " +
                canonical.action +
                " · Claim: " +
                canonical.claim_status +
                " · Receipt: " +
                handoff_display(canonical.receipt_status),
              ),
              p("Captured model: " + handoff_display(canonical.model)),
              p("Captured context: " + handoff_display(canonical.context_path)),
            ]),
            if state.output_hint is Null {
              render_work_continuation(dispatch, state, target, canonical)
            } else {
              details([
                summary("Agent follow-ups and their separate results"),
                render_work_continuation(dispatch, state, target, canonical),
              ])
            },
            details([
              summary("Session transcript"),
              p(
                "Later turns may appear below. The originating command and captured model/context above remain fixed.",
              ),
              match state.session {
                None =>
                  p(
                    if state.session_error == "" {
                      "Reading the saved transcript…"
                    } else {
                      "Refresh exact work to retry the transcript."
                    },
                  )
                Some(session) =>
                  render_work_handoff_transcript(model, session, dispatch~)
              },
            ]),
            if state.files_error != "" {
              p(state.files_error)
            } else {
              @html.nothing
            },
            details([
              summary("Workspace files · read only"),
              render_work_handoff_files(dispatch, state, canonical),
            ]),
          ])
      },
    ],
  )
}

///|
fn render_work_handoff_context(
  context : Json,
  canonical : WorkHandoffCanonical,
) -> @rabbita.Html {
  let state = handoff_text(context, "state")
  let message = handoff_text(context, "message")
  let expected = handoff_text(context, "expected_sha256")
  let actual = handoff_text(context, "actual_sha256")
  if state == "ready" &&
    handoff_text(context, "path") == canonical.context_path &&
    canonical.context_path != "" &&
    handoff_text(context, "integrity") == "verified" &&
    expected != "" &&
    expected == actual {
    details([
      summary("Read original command context"),
      p(
        "The Desk host verified these bytes against the content-addressed digest in the original command's captured context path.",
      ),
      p("Verified SHA-256: " + actual),
      pre(handoff_text(context, "text")),
    ])
  } else {
    div([
      p(
        "Context inspection: " +
        (if message != "" {
          message
        } else if canonical.context_path == "" {
          "No context was recorded for this legacy command."
        } else {
          "Unavailable or not verified. Refresh exact work to retry."
        }),
      ),
      if state == "mismatch" {
        p(
          "Captured digest: " +
          expected +
          " · Current file digest: " +
          actual +
          ". Changed file text is not shown as original context.",
        )
      } else {
        @html.nothing
      },
    ])
  }
}

///|
fn handoff_display(value : String) -> String {
  if value == "" {
    "Not recorded"
  } else {
    value
  }
}

///|
fn render_work_handoff_transcript(
  model : Model,
  session : MoonCodeSession,
  dispatch? : Dispatch[Msg],
) -> @rabbita.Html {
  let items = mooncode_transcript_items(model, session)
  if items.is_empty() {
    return p("No canonical transcript has been recorded for this session yet.")
  }
  div(
    class="mooncode-transcript",
    items.map(item => {
      match item.message {
        Some(row) =>
          div(class="mooncode-message " + row.role, [
            strong(row.role + " · command " + row.command_id),
            if row.role == "user" && !row.content_parts.is_empty() {
              render_mooncode_ordered_user_content(
                session.id,
                row.command_id,
                row.content_parts,
              )
            } else {
              pre(row.content)
            },
            match dispatch {
              Some(dispatch) =>
                render_work_learning_action(dispatch, model, row)
              None => @html.nothing
            },
          ])
        None =>
          match item.activity {
            None => @html.nothing
            Some(row) =>
              details([
                summary(
                  row.title +
                  " · " +
                  row.status +
                  " · command " +
                  row.command_id,
                ),
                pre(row.detail),
                div(
                  row.evidence.map(evidence => {
                    div([
                      strong(evidence.title + " · " + evidence.state),
                      pre(evidence.detail),
                      pre(evidence.command),
                      pre(evidence.output),
                      pre(evidence.diff),
                      p(evidence.path),
                    ])
                  }),
                ),
              ])
          }
      }
    }),
  )
}

///|
fn render_work_handoff_files(
  dispatch : Dispatch[Msg],
  state : WorkHandoffState,
  canonical : WorkHandoffCanonical,
) -> @rabbita.Html {
  section(class="work-handoff-files", [
    h3("Workspace files · read only"),
    p(if state.directory == "" { "/" } else { state.directory }),
    button(on_click=dispatch(WorkHandoff(Browse(""))), "Root folder"),
    button(
      on_click=dispatch(WorkHandoff(Browse(parent_path(state.directory)))),
      "Parent folder",
    ),
    button(
      on_click=dispatch(WorkHandoff(Browse(state.directory))),
      "Refresh files",
    ),
    if state.files_loading {
      p("Reading files…")
    } else if state.files_error != "" {
      p(state.files_error)
    } else if state.entries.is_empty() {
      p("This folder is empty.")
    } else {
      @html.nothing
    },
    div(
      state.entries.map(entry => {
        if entry.workspace_id != canonical.workspace_id {
          return @html.nothing
        }
        match handoff_relative_path(canonical.root_path, entry.path) {
          None => @html.nothing
          Some(path) =>
            if entry.kind == Directory {
              button(
                on_click=dispatch(WorkHandoff(Browse(path))),
                entry.display_name + "/",
              )
            } else if entry.readable {
              a(
                href=@desk.workspace_file_url(canonical.workspace_id, path),
                target=Blank,
                attrs=@html.Attrs::build().rel("noopener noreferrer"),
                entry.display_name,
              )
            } else {
              span(entry.display_name + " (unreadable)")
            }
        }
      }),
    ),
  ])
}

///|
fn render_work_handoff_original_result(
  model : Model,
  session : MoonCodeSession,
  command_id : String,
  dispatch? : Dispatch[Msg],
) -> @rabbita.Html {
  let rows = mooncode_transcript_items(model, session).filter_map(item => {
    match item.message {
      Some(row) if row.command_id == command_id && row.role == "assistant" =>
        Some(row)
      _ => None
    }
  })
  section([
    h3("Original command result · " + command_id),
    if rows.is_empty() {
      p(
        "No saved assistant result is recorded for this exact command. The complete session transcript remains below.",
      )
    } else {
      div(
        rows.map(row => {
          div([
            pre(row.content),
            match dispatch {
              Some(dispatch) =>
                render_work_learning_action(dispatch, model, row)
              None => @html.nothing
            },
          ])
        }),
      )
    },
  ])
}
