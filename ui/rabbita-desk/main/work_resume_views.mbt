///|
fn render_work_resume(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  let state = model.work_resume
  let scope = work_resume_scope(model)
  if scope == "" && !work_handoff_active(model) {
    return @html.nothing
  }
  section(
    class="desk-quick-access",
    attrs=@html.Attrs::build().data_set("testid", "work-resume"),
    [
      h3("Resume work"),
      p(
        "Saved on this browser for this Book and library. Reopen in a new tab to keep your current work here; the host checks the exact identity again.",
      ),
      if scope == "" {
        p(
          "This host did not provide a verified library scope. Work remains usable, but no shortcut is saved.",
        )
      } else if state.status == "unavailable" ||
        state.status == "storage_failed" {
        p(
          "Shortcuts could not be saved or read. Browser storage is blocked or full; existing saved shortcuts may return. Your work and drafts are unchanged.",
        )
      } else if state.status == "invalid" {
        p(
          "Stored shortcuts are malformed or from an unsupported version. They are not opened; clear this Book’s shortcuts to start again.",
        )
      } else if state.entries.is_empty() {
        p(
          "No saved work for this Book yet. Exact work appears here after a successful host lookup.",
        )
      } else {
        @html.nothing
      },
      if scope != "" && state.scope == scope {
        div(
          state.entries.map(entry => {
            let query = handoff_text(entry, "query")
            let route = @json.parse(work_handoff_query_json(query)) catch {
              _ => Json::null()
            }
            if !work_resume_entry_valid(entry, scope) {
              return @html.nothing
            }
            div(class="work-resume-entry", [
              strong(handoff_text(entry, "title")),
              p(
                "Last observed original command: " +
                handoff_text(entry, "observed") +
                ". Reopen to refresh; this is not a current or acceptance status.",
              ),
              p(
                if handoff_text(route, "work_mode") == "follow_up" {
                  "Follow-up workspace · existing unsent drafts restore after reopening"
                } else {
                  "Inspection only"
                },
              ),
              details([
                summary("Exact work identity"),
                p(
                  "Task / run: " +
                  handoff_text(route, "work_task") +
                  " / " +
                  handoff_text(route, "work_run"),
                ),
                p(
                  "Session / original command: " +
                  handoff_text(route, "session") +
                  " / " +
                  handoff_text(route, "command"),
                ),
                if handoff_text(route, "work_output_command") != "" {
                  div([
                    p("Output file: " + handoff_text(route, "work_output_path")),
                    p(
                      "Output command / evidence: " +
                      handoff_text(route, "work_output_command") +
                      " / " +
                      handoff_text(route, "work_output_evidence"),
                    ),
                  ])
                } else {
                  @html.nothing
                },
              ]),
              a(
                href=query,
                target=Blank,
                attrs=@html.Attrs::build().rel("noopener noreferrer"),
                "Reopen saved work (new tab)",
              ),
              button(
                on_click=dispatch(ForgetResumableWork(scope, query)),
                "Forget shortcut",
              ),
            ])
          }),
        )
      } else {
        @html.nothing
      },
      if scope != "" && (!state.entries.is_empty() || state.status == "invalid") {
        button(
          on_click=dispatch(ClearResumableWork(scope)),
          "Clear this Book’s shortcuts",
        )
      } else {
        @html.nothing
      },
    ],
  )
}
