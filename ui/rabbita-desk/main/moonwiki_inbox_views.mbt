///|
fn render_inbox_pane(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(class="activity-pane", [
    div(class="pane-heading", [
      div([p(class="eyebrow", "safe writes"), h2("Inbox")]),
      button(
        class="icon-button",
        title="Load Selection",
        on_click=dispatch(LoadSelectionIntoInbox),
        "L",
      ),
    ]),
    section(class="side-section", [
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
        placeholder="Draft markdown before it enters durable wiki pages.",
        on_input=fn(value) { dispatch(SetInboxContent(value)) },
        "",
      ),
      div(class="toolbar-actions stack-actions", [
        button(
          class="secondary-button",
          on_click=dispatch(LoadSelectionIntoInbox),
          "Load Selection",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(StageSelectedLink),
          "Link Selection",
        ),
      ]),
      button(
        class="primary-button full",
        on_click=dispatch(SaveInboxNote),
        "Save Inbox Note",
      ),
      p(class="status-line", model.inbox_status),
    ]),
    section(class="side-section", [
      h3("Import"),
      input(
        class="line-input",
        value=model.import_url,
        placeholder="https://...",
        on_input=fn(value) { dispatch(SetImportUrl(value)) },
      ),
      textarea(
        class="side-textarea compact-textarea",
        rows=4,
        value=model.import_note,
        placeholder="Why this belongs in the inbox.",
        on_input=fn(value) { dispatch(SetImportNote(value)) },
        "",
      ),
      div(class="toolbar-actions stack-actions", [
        button(
          class="secondary-button",
          on_click=dispatch(ImportUrlToInbox),
          "Import URL",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(ImportLocalFiles),
          "Import Files",
        ),
      ]),
      div(class="import-dropzone", [
        span(class="record-kind", "local"),
        strong("File and Image Intake"),
        small("Queued drops and pasted images are staged as inbox imports."),
      ]),
    ]),
    section(class="side-section", [
      h3("Preview"),
      pre(class="source-block compact", code(model.inbox_content)),
    ]),
  ])
}
