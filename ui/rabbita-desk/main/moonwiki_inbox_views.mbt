///|
fn render_inbox_pane(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(class="activity-pane user-pane", [
    div(class="pane-heading", [
      div([p(class="eyebrow", "Capture"), h2("Inbox")]),
    ]),
    section(class="side-section", [
      h3("New note"),
      input(
        class="line-input",
        value=model.inbox_title,
        placeholder="Note title",
        on_input=fn(value) { dispatch(SetInboxTitle(value)) },
      ),
      textarea(
        class="side-textarea",
        rows=10,
        value=model.inbox_content,
        placeholder="Write down an idea, observation, or source note.",
        on_input=fn(value) { dispatch(SetInboxContent(value)) },
        "",
      ),
      button(
        class="primary-button full",
        on_click=dispatch(SaveInboxNote),
        "Save note",
      ),
      p(class="status-line", wiki_inbox_status_label(model.inbox_status)),
    ]),
    details(class="wiki-disclosure", [
      summary(class="wiki-disclosure-summary", "Add a link or files"),
      div(class="wiki-disclosure-body", [
        input(
          class="line-input",
          value=model.import_url,
          placeholder="Paste a link",
          on_input=fn(value) { dispatch(SetImportUrl(value)) },
        ),
        textarea(
          class="side-textarea compact-textarea",
          rows=3,
          value=model.import_note,
          placeholder="Add a note about why this matters.",
          on_input=fn(value) { dispatch(SetImportNote(value)) },
          "",
        ),
        div(class="toolbar-actions stack-actions", [
          button(
            class="secondary-button",
            on_click=dispatch(ImportUrlToInbox),
            "Add link",
          ),
          button(
            class="secondary-button",
            on_click=dispatch(ImportLocalFiles),
            "Add files",
          ),
        ]),
        button(
          class="secondary-button full",
          on_click=dispatch(LoadSelectionIntoInbox),
          "Use selected page",
        ),
        button(
          class="secondary-button full",
          on_click=dispatch(StageSelectedLink),
          "Link selected page",
        ),
      ]),
    ]),
    details(class="wiki-disclosure", [
      summary(class="wiki-disclosure-summary", "Preview note"),
      div(class="wiki-disclosure-body", [
        pre(class="source-block compact", code(model.inbox_content)),
      ]),
    ]),
  ])
}
