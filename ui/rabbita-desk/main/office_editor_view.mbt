///|
fn render_office_editor(
  dispatch : Dispatch[Msg],
  state : OfficeEditorState,
) -> @rabbita.Html {
  let selected = if state.selected >= 0 &&
    state.selected < state.draft_items.length() {
    Some(state.draft_items[state.selected])
  } else {
    None
  }
  section(
    class="office-editor",
    attrs=@html.Attrs::build().data_set("testid", "office-editor"),
    [
      h3("Structured Office editor"),
      p(
        "Supported subset only. Unsupported Office features remain in the saved package but are not editable.",
      ),
      div(class="office-editor-toolbar", [
        @html.label(class="editor-path-field", [
          span("Office path"),
          input(
            attrs=@html.Attrs::build()
              .data_set("testid", "office-path")
              .aria_label("Office workspace path"),
            value=state.path_input,
            placeholder="documents/report.docx",
            on_input=fn(value) { dispatch(OfficeEditor(OfficeSetPath(value))) },
          ),
        ]),
        button(
          class="secondary-button",
          attrs=@html.Attrs::build().data_set("testid", "office-open"),
          disabled=state.loading || state.saving,
          on_click=dispatch(OfficeEditor(OfficeOpen)),
          if state.loading {
            "Opening..."
          } else {
            "Open"
          },
        ),
        button(
          class="primary-button",
          attrs=@html.Attrs::build().data_set("testid", "office-save"),
          disabled=!office_editor_dirty(state) || state.saving,
          on_click=dispatch(OfficeEditor(OfficeSave)),
          if state.saving {
            "Saving..."
          } else {
            "Save"
          },
        ),
        button(
          class="secondary-button",
          attrs=@html.Attrs::build().data_set("testid", "office-discard"),
          disabled=!office_editor_dirty(state) || state.saving,
          on_click=dispatch(OfficeEditor(OfficeDiscard)),
          "Discard",
        ),
        button(
          class="secondary-button",
          attrs=@html.Attrs::build().data_set("testid", "office-close"),
          disabled=office_editor_dirty(state) || state.loading || state.saving,
          on_click=dispatch(OfficeEditor(OfficeClose)),
          "Close",
        ),
        button(
          class="secondary-button",
          attrs=@html.Attrs::build().data_set("testid", "office-reopen"),
          disabled=office_editor_dirty(state) ||
            state.path == "" ||
            state.loading ||
            state.saving,
          on_click=dispatch(OfficeEditor(OfficeReopen)),
          "Reopen saved bytes",
        ),
        a(
          class="secondary-button",
          attrs=@html.Attrs::build()
            .data_set("testid", "office-export")
            .download(state.path),
          href=if state.path == "" || office_editor_dirty(state) {
            "#"
          } else {
            office_editor_endpoint_url(
              state.workspace_id,
              "office/export",
              state.path,
            )
          },
          "Export saved Office bytes",
        ),
      ]),
      div(
        class="office-editor-nav",
        state.draft_items.mapi((index, item) => {
          button(
            class=if index == state.selected {
              "office-nav-item is-active"
            } else {
              "office-nav-item"
            },
            attrs=@html.Attrs::build().data_set("testid", "office-nav-\{index}"),
            disabled=office_editor_selected_dirty(state) &&
              index != state.selected,
            on_click=dispatch(OfficeEditor(OfficeSelect(index))),
            item.section + " · " + item.reference,
          )
        }),
      ),
      match selected {
        None =>
          p(
            class="status-line",
            "Open a DOCX, XLSX, or PPTX document to edit its supported model.",
          )
        Some(item) =>
          div(class="office-editor-fields", [
            @html.label([
              span("Text or cell value"),
              input(
                attrs=@html.Attrs::build()
                  .data_set("testid", "office-text")
                  .aria_label("Office item text")
                  .disabled(state.loading || state.saving),
                value=item.text,
                on_input=fn(value) {
                  dispatch(OfficeEditor(OfficeEditText(value)))
                },
              ),
            ]),
            match state.document {
              Some(document) =>
                match document.kind {
                  OfficeDocx =>
                    div(class="office-inline-styles", [
                      button(
                        class="secondary-button",
                        on_click=dispatch(OfficeEditor(OfficeToggleBold)),
                        if item.bold {
                          "Bold on"
                        } else {
                          "Bold"
                        },
                      ),
                      button(
                        class="secondary-button",
                        on_click=dispatch(OfficeEditor(OfficeToggleItalic)),
                        if item.italic {
                          "Italic on"
                        } else {
                          "Italic"
                        },
                      ),
                      button(
                        class="secondary-button",
                        on_click=dispatch(OfficeEditor(OfficeToggleUnderline)),
                        if item.underline {
                          "Underline on"
                        } else {
                          "Underline"
                        },
                      ),
                    ])
                  OfficeXlsx =>
                    @html.label([
                      span("Formula"),
                      input(
                        attrs=@html.Attrs::build()
                          .aria_label("Spreadsheet cell formula")
                          .data_set("testid", "office-formula")
                          .disabled(state.loading || state.saving),
                        value=item.formula,
                        on_input=fn(value) {
                          dispatch(OfficeEditor(OfficeEditFormula(value)))
                        },
                      ),
                    ])
                  OfficePptx =>
                    div(class="office-geometry", [
                      office_geometry_input(dispatch, "X", item.x, value => {
                        OfficeEditX(value)
                      }),
                      office_geometry_input(dispatch, "Y", item.y, value => {
                        OfficeEditY(value)
                      }),
                      office_geometry_input(dispatch, "Width", item.width, value => {
                        OfficeEditWidth(value)
                      }),
                      office_geometry_input(dispatch, "Height", item.height, value => {
                        OfficeEditHeight(value)
                      }),
                    ])
                }
              None => @html.nothing
            },
            match state.document {
              Some(document) =>
                render_office_supported_preview(
                  document.kind,
                  item,
                  state.draft_items,
                  state.selected,
                )
              None => @html.nothing
            },
            match state.conflict_baseline {
              Some(_) =>
                div(class="office-conflict", [
                  p(
                    "The saved file changed externally. Your dirty draft is still here.",
                  ),
                  button(
                    class="secondary-button",
                    on_click=dispatch(OfficeEditor(OfficeReloadConflict)),
                    "Reload current bytes",
                  ),
                  button(
                    class="primary-button",
                    on_click=dispatch(OfficeEditor(OfficeReplaceConflict)),
                    "Replace external bytes",
                  ),
                ])
              None => @html.nothing
            },
          ])
      },
      match state.document {
        Some(document) =>
          div(class="office-document-meta", [
            span(
              match document.kind {
                OfficeDocx => "DOCX"
                OfficeXlsx => "XLSX"
                OfficePptx => "PPTX"
              },
            ),
            span("\{document.items.length()} editable items"),
            if document.warnings.is_empty() {
              @html.nothing
            } else {
              div(
                class="office-warnings",
                document.warnings.map(warning => p(warning)),
              )
            },
          ])
        None => @html.nothing
      },
      p(
        class="office-editor-status",
        attrs=@html.Attrs::build()
          .data_set("testid", "office-status")
          .role("status")
          .aria_live("polite"),
        if office_editor_dirty(state) {
          "Unsaved changes. " + state.status
        } else {
          state.status
        },
      ),
    ],
  )
}

///|
fn render_office_supported_preview(
  kind : OfficeEditorKind,
  item : OfficeEditorItem,
  items : Array[OfficeEditorItem],
  selected : Int,
) -> @rabbita.Html {
  section(
    class="office-supported-preview",
    attrs=@html.Attrs::build()
      .data_set("testid", "office-supported-preview")
      .aria_label("Live supported-subset preview"),
    [
      div(class="office-preview-heading", [
        strong("Live supported-subset preview"),
        span(
          match kind {
            OfficeDocx => "Text styling"
            OfficeXlsx => "Cell and formula"
            OfficePptx => "Content, not slide fidelity"
          },
        ),
      ]),
      match kind {
        OfficeDocx => {
          div(
            class="office-preview-docx",
            attrs=@html.Attrs::build().data_set("testid", "office-docx-preview"),
            [
              div(class="office-preview-page", [
                div(
                  class="office-preview-docx-document",
                  office_unique_sections(items).map(section =>
                    p(
                      class="office-preview-docx-paragraph",
                      items
                      .mapi((index, run) => (index, run))
                      .filter(entry => entry.1.section == section)
                      .map(entry => {
                        let (index, run) = entry
                        span(
                          class=office_docx_run_class(
                            run,
                            selected=index == selected,
                          ),
                          if run.text == "" { " " } else { run.text },
                        )
                      }),
                    )
                  ),
                ),
              ]),
            ],
          )
        }
        OfficeXlsx =>
          div(
            class="office-preview-xlsx",
            attrs=@html.Attrs::build().data_set("testid", "office-xlsx-preview"),
            [
              div(class="office-preview-formula", [
                strong("fx"),
                span(
                  if item.formula == "" {
                    "No formula"
                  } else {
                    item.formula
                  },
                ),
              ]),
              div(
                class="office-preview-sheet office-preview-sheet-items",
                items.mapi((index, cell) =>
                  div(
                    class=if index == selected {
                      "office-preview-cell-card is-selected"
                    } else {
                      "office-preview-cell-card"
                    },
                    [
                      strong(cell.reference),
                      span(if cell.text == "" { "Empty cell" } else { cell.text }),
                    ],
                  )
                ),
              ),
            ],
          )
        OfficePptx =>
          div(
            class="office-preview-pptx",
            attrs=@html.Attrs::build().data_set("testid", "office-pptx-preview"),
            [
              div(
                class="office-preview-slide",
                items.mapi((index, shape) =>
                  div(
                    class=if index == selected {
                      "office-preview-slide-object is-selected"
                    } else {
                      "office-preview-slide-object"
                    },
                    attrs=office_pptx_shape_attrs(shape, items),
                    if shape.text == "" { "Empty text object" } else { shape.text },
                  )
                ),
              ),
              div(class="office-preview-geometry", [
                span("X \{item.x}"),
                span("Y \{item.y}"),
                span("W \{item.width}"),
                span("H \{item.height}"),
              ]),
            ],
          )
      },
    ],
  )
}

///|
fn office_unique_sections(items : Array[OfficeEditorItem]) -> Array[String] {
  let sections : Array[String] = []
  for item in items {
    if !sections.contains(item.section) {
      sections.push(item.section)
    }
  }
  sections
}

///|
fn office_docx_run_class(
  item : OfficeEditorItem,
  selected~ : Bool,
) -> String {
  "office-preview-docx-text" +
  (if item.bold { " is-bold" } else { "" }) +
  (if item.italic { " is-italic" } else { "" }) +
  (if item.underline { " is-underlined" } else { "" }) +
  (if selected { " is-selected" } else { "" })
}

///|
fn office_pptx_extent(items : Array[OfficeEditorItem]) -> (Int, Int) {
  let mut right = 1
  let mut bottom = 1
  for item in items {
    if item.x + item.width > right {
      right = item.x + item.width
    }
    if item.y + item.height > bottom {
      bottom = item.y + item.height
    }
  }
  (right, bottom)
}

///|
fn office_percent(value : Int, extent : Int) -> String {
  let bounded = if value < 0 { 0 } else { value }
  "\{bounded * 100 / extent}%"
}

///|
fn office_pptx_shape_attrs(
  item : OfficeEditorItem,
  items : Array[OfficeEditorItem],
) -> @html.Attrs {
  let (right, bottom) = office_pptx_extent(items)
  @html.Attrs::build()
  .style("left", office_percent(item.x, right))
  .style("top", office_percent(item.y, bottom))
  .style("width", office_percent(item.width, right))
  .style("height", office_percent(item.height, bottom))
}

///|
fn office_geometry_input(
  dispatch : Dispatch[Msg],
  label_text : String,
  value : Int,
  message : (Int) -> OfficeEditorMsg,
) -> @rabbita.Html {
  @html.label([
    span(label_text),
    input(value=value.to_string(), on_input=fn(text) {
      let number = @string.parse_int(text) catch { _ => return @rabbita.none }
      dispatch(OfficeEditor(message(number)))
    }),
  ])
}
