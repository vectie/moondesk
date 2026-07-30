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
        input(
          attrs=@html.Attrs::build()
            .data_set("testid", "office-path")
            .aria_label("Office workspace path"),
          value=state.path_input,
          placeholder="documents/report.docx",
          on_input=fn(value) { dispatch(OfficeEditor(OfficeSetPath(value))) },
        ),
        button(
          class="secondary-button",
          attrs=@html.Attrs::build().data_set("testid", "office-open"),
          disabled=state.loading,
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
          attrs=@html.Attrs::build().data_set("testid", "office-close"),
          disabled=office_editor_dirty(state),
          on_click=dispatch(OfficeEditor(OfficeClose)),
          "Close",
        ),
        button(
          class="secondary-button",
          attrs=@html.Attrs::build().data_set("testid", "office-reopen"),
          disabled=office_editor_dirty(state) || state.path == "",
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
            @desk.workspace_endpoint_url(state.workspace_id, "office/export") +
            "?path=" +
            state.path
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
                attrs=@html.Attrs::build().data_set("testid", "office-text"),
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
                      input(value=item.formula, on_input=fn(value) {
                        dispatch(OfficeEditor(OfficeEditFormula(value)))
                      }),
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
          div(
            class="office-warnings",
            document.warnings.map(warning => p(warning)),
          )
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
