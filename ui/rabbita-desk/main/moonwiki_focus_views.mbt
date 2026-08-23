///|
fn render_wiki_focus_workspace(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="wiki-focus-workspace", [
    render_wiki_chat(dispatch, model),
    render_wiki_document_viewer(dispatch, model),
  ])
}

///|
fn render_wiki_chat(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(
    class="wiki-chat",
    attrs=@html.Attrs::build().aria_label("Document chat"),
    [
      header(class="wiki-chat-header", [
        div([p(class="eyebrow", "Workspace"), h2("Chat")]),
        if office_editor_path_supported(model.selected_path) {
          span(
            class="wiki-document-chip",
            title=model.selected_path,
            @desk.display_name(model.selected_path),
          )
        } else {
          span(class="wiki-document-chip empty", "No document")
        },
      ]),
      render_wiki_warning_popup(model),
      div(
        class="wiki-chat-thread",
        attrs=@html.Attrs::build()
          .data_set("testid", "wiki-chat-thread")
          .aria_live("polite"),
        wiki_chat_messages(model),
      ),
      div(class="wiki-chat-composer", [
        if model.wiki_chat_file_paths.is_empty() {
          @html.nothing
        } else {
          div(
            class="wiki-chat-file-chips",
            [
              span(class="wiki-chat-file-hint", "Attached"),
              ..model.wiki_chat_file_paths.map(path => {
                span(class="wiki-chat-file-chip", [
                  span(path),
                  button(
                    class="wiki-chat-file-remove",
                    attrs=@html.Attrs::build().aria_label(
                      "Remove attached file " + path,
                    ),
                    on_click=dispatch(RemoveWikiChatFile(path)),
                    "×",
                  ),
                ])
              }),
            ],
          )
        },
        textarea(
          class="wiki-chat-input",
          attrs=@html.Attrs::build()
            .data_set("testid", "wiki-chat-input")
            .aria_label("Ask about this document"),
          rows=4,
          value=model.request_prompt,
          placeholder="Ask about this document, or type @ to attach a file…",
          on_input=fn(value) { dispatch(SetWikiChatPrompt(value)) },
          "",
        ),
        div(
          class="wiki-chat-dropzone",
          attrs=@html.Attrs::build()
            .data_set("testid", "wiki-chat-dropzone")
            .role("region")
            .aria_label("Drop a workspace file to attach it")
            .on_dragover(fn(event) { wiki_chat_drag_over_cmd(event) })
            .on_drop(fn(event) {
              dispatch(WikiChatDropPath(wiki_chat_drop_path(event)))
            }),
          [
            strong("Drop a workspace file here"),
            small(
              "Drag from the workspace list or search results. Nothing is imported.",
            ),
          ],
        ),
        if model.wiki_chat_file_picker_open {
          render_wiki_chat_file_picker(dispatch, model)
        } else {
          @html.nothing
        },
        div(class="wiki-chat-actions", [
          button(
            class="secondary-button",
            attrs=@html.Attrs::build()
              .data_set("testid", "wiki-chat-file-picker-toggle")
              .aria_expanded(
                if model.wiki_chat_file_picker_open {
                  "true"
                } else {
                  "false"
                },
              ),
            title="Search this workspace for a file to attach",
            on_click=dispatch(ToggleWikiChatFilePicker),
            if model.wiki_chat_file_picker_open {
              "Close file search"
            } else {
              "Attach workspace file"
            },
          ),
          button(
            class="primary-button",
            attrs=@html.Attrs::build().data_set("testid", "wiki-chat-send"),
            disabled=wiki_task_start_disabled(model),
            on_click=dispatch(SubmitWikiChat),
            "Send",
          ),
        ]),
        match wiki_chat_status(model.request_status) {
          Some(status) =>
            p(
              class="wiki-chat-status",
              attrs=@html.Attrs::build().role("status").aria_live("polite"),
              status,
            )
          None => @html.nothing
        },
      ]),
    ],
  )
}

///|
fn render_wiki_chat_file_picker(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  div(
    class="wiki-chat-file-picker",
    attrs=@html.Attrs::build()
      .data_set("testid", "wiki-chat-file-picker")
      .aria_label("Workspace file search"),
    [
      div(class="wiki-chat-file-picker-heading", [
        strong("Attach from this workspace"),
        small("Search by file name or content"),
      ]),
      input(
        class="wiki-chat-file-search",
        attrs=@html.Attrs::build()
          .data_set("testid", "wiki-chat-file-search")
          .aria_label("Search workspace files"),
        value=model.wiki_chat_file_query,
        placeholder="Search files…",
        on_input=fn(value) { dispatch(SetWikiChatFileQuery(value)) },
      ),
      p(
        class="wiki-chat-file-search-status",
        attrs=@html.Attrs::build().role("status").aria_live("polite"),
        model.wiki_chat_file_search_status,
      ),
      if model.wiki_chat_file_results.length() == 0 {
        @html.nothing
      } else {
        div(
          class="wiki-chat-file-results",
          [
            ..model.wiki_chat_file_results.map(hit => {
              button(
                class="wiki-chat-file-result",
                attrs=@html.Attrs::build()
                  .data_set("path", hit.path)
                  .draggable("true")
                  .on_dragstart(fn(event) {
                    wiki_chat_drag_start_cmd(hit.path, event)
                  }),
                on_click=dispatch(AttachWikiChatFile(hit.path)),
                [
                  strong(
                    if hit.title.trim() == "" {
                      @desk.display_name(hit.path)
                    } else {
                      hit.title
                    },
                  ),
                  small(hit.path),
                  if hit.snippet.trim() == "" {
                    @html.nothing
                  } else {
                    p(hit.snippet)
                  },
                ],
              )
            }),
          ],
        )
      },
    ],
  )
}

///|
fn wiki_chat_messages(model : Model) -> Array[@rabbita.Html] {
  let messages : Array[@rabbita.Html] = []
  for entry in model.wiki_chat_entries {
    if entry.content.trim() != "" {
      messages.push(
        div(class="wiki-chat-message " + entry.role, [
          span(
            class="wiki-chat-speaker",
            if entry.role == "user" {
              "You"
            } else {
              "MoonDesk"
            },
          ),
          p(entry.content),
        ]),
      )
    }
  }
  if messages.length() == 0 {
    messages.push(
      div(class="wiki-chat-empty", [
        h3("Ask about your document"),
        p(
          "Questions and requested changes stay beside the file. MoonDesk checks the work quietly and only interrupts for a warning.",
        ),
      ]),
    )
  }
  messages
}

///|
fn wiki_chat_status(status : String) -> String? {
  let value = status.trim().to_lower()
  if value == "" || value == "draft" || value == "ready" {
    None
  } else if value.contains("sending") ||
    value.contains("generating") ||
    value.contains("queued") ||
    value.contains("working") {
    Some("MoonDesk is working quietly…")
  } else {
    Some(status)
  }
}

///|
fn wiki_document_warnings(model : Model) -> Array[String] {
  let warnings : Array[String] = []
  match model.preview {
    Some(preview) if !office_editor_path_supported(model.selected_path) &&
      (
        model.preview_request_path == "" ||
        model.preview_request_path == model.selected_path
      ) =>
      for warning in preview.warnings {
        if wiki_warning_requires_attention(warning) &&
          !warnings.contains(warning) {
          warnings.push(warning)
        }
      }
    _ => ()
  }
  match model.office_editor.document {
    Some(document) if model.office_editor.path == model.selected_path =>
      for warning in document.warnings {
        if wiki_warning_requires_attention(warning) &&
          !warnings.contains(warning) {
          warnings.push(warning)
        }
      }
    _ => ()
  }
  warnings
}

///|
fn wiki_warning_requires_attention(warning : String) -> Bool {
  let value = warning.trim().to_lower()
  value != "" && !value.has_prefix("supported subset only")
}

///|
fn render_wiki_warning_popup(model : Model) -> @rabbita.Html {
  let warnings = wiki_document_warnings(model)
  if warnings.length() == 0 {
    @html.nothing
  } else {
    section(
      class="wiki-warning-popup",
      attrs=@html.Attrs::build()
        .data_set("testid", "wiki-warning-popup")
        .role("alert"),
      [strong("Needs attention"), ul(warnings.map(warning => li(warning)))],
    )
  }
}

///|
fn render_wiki_document_viewer(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(
    class="wiki-document-viewer",
    attrs=@html.Attrs::build().aria_label("Document viewer"),
    [
      header(class="wiki-viewer-header", [
        div(class="wiki-viewer-title", [
          h2(
            if office_editor_path_supported(model.selected_path) {
              @desk.display_name(model.selected_path)
            } else {
              "Document"
            },
          ),
          match wiki_office_kind_label(model.selected_path) {
            Some(kind) => span(class="wiki-file-kind", kind)
            None => @html.nothing
          },
        ]),
        div(class="wiki-viewer-actions", [
          button(
            class="secondary-button",
            on_click=dispatch(SelectWorkspaceMode(Desk)),
            "Choose document",
          ),
          if office_editor_path_supported(model.selected_path) {
            a(
              class="secondary-button link-button",
              href=raw_url(model, model.selected_path),
              target=Blank,
              rel="noreferrer",
              "Open original",
            )
          } else {
            @html.nothing
          },
        ]),
      ]),
      render_wiki_office_document(dispatch, model),
    ],
  )
}

///|
fn render_wiki_office_document(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  if !office_editor_path_supported(model.selected_path) {
    return div(class="wiki-viewer-empty", [
      h3("Open a document"),
      p("Choose a DOCX, XLSX, or PPTX file to view it beside the chat."),
      button(
        class="primary-button",
        on_click=dispatch(SelectWorkspaceMode(Desk)),
        "Choose document",
      ),
    ])
  }
  let state = model.office_editor
  match state.document {
    Some(document) if state.path == model.selected_path => {
      let selected = if state.selected >= 0 &&
        state.selected < state.draft_items.length() {
        state.selected
      } else {
        0
      }
      let selected_item = if state.draft_items.length() == 0 {
        None
      } else {
        Some(state.draft_items[selected])
      }
      div(class="wiki-office-view", [
        if state.draft_items.length() > 1 {
          div(
            class="wiki-office-navigation",
            attrs=@html.Attrs::build()
              .role("navigation")
              .aria_label("Document sections"),
            state.draft_items.mapi((index, item) => {
              button(
                class=if index == selected {
                  "wiki-office-nav-item active"
                } else {
                  "wiki-office-nav-item"
                },
                on_click=dispatch(OfficeEditor(OfficeSelect(index))),
                item.reference,
              )
            }),
          )
        } else {
          @html.nothing
        },
        match selected_item {
          Some(item) =>
            render_office_supported_preview(
              document.kind,
              item,
              state.draft_items,
              selected,
            )
          None =>
            div(class="wiki-viewer-empty compact", [
              h3("This document has no viewable content"),
              p("The original file is unchanged."),
            ])
        },
      ])
    }
    _ if state.loading && state.path == model.selected_path =>
      div(class="wiki-viewer-loading", [
        span(class="wiki-loading-indicator", ""),
        p("Opening document…"),
      ])
    _ =>
      div(class="wiki-viewer-empty", [
        h3("Ready to open"),
        p("Open this file in the document viewer."),
        button(
          class="primary-button",
          attrs=@html.Attrs::build().data_set("testid", "wiki-open-document"),
          on_click=dispatch(OfficeEditor(OfficeOpenPath(model.selected_path))),
          "Open document",
        ),
      ])
  }
}

///|
fn wiki_office_kind_label(path : String) -> String? {
  let lower = path.to_lower()
  if lower.has_suffix(".docx") {
    Some("DOCX")
  } else if lower.has_suffix(".xlsx") {
    Some("XLSX")
  } else if lower.has_suffix(".pptx") {
    Some("PPTX")
  } else {
    None
  }
}
