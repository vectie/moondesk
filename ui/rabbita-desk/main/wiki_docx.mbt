///|
// Retain original run boundaries/styles outside the user's text replacement.
// Users edit prose; OOXML coordinates never appear in the document UI.
fn office_docx_edit_paragraph(
  state : OfficeEditorState,
  paragraph : Int32,
  text : String,
) -> OfficeEditorState {
  let runs = state.draft_items.filter(item => item.section_index == paragraph)
  if runs.is_empty() {
    return state
  }
  let original = runs.map(item => item.text).join("")
  if original == text {
    return state
  }
  let mut prefix = 0
  while prefix < original.length() &&
        prefix < text.length() &&
        original[prefix] == text[prefix] {
    prefix += 1
  }
  let mut suffix = 0
  while suffix < original.length() - prefix &&
        suffix < text.length() - prefix &&
        original[original.length() - suffix - 1] ==
        text[text.length() - suffix - 1] {
    suffix += 1
  }
  // Snap boundaries away from UTF-16 surrogate pairs.
  if prefix > 0 &&
    prefix < original.length() &&
    original[prefix] >= 0xDC00 &&
    original[prefix] <= 0xDFFF {
    prefix -= 1
  }
  if suffix > 0 &&
    suffix < original.length() &&
    original[original.length() - suffix] >= 0xDC00 &&
    original[original.length() - suffix] <= 0xDFFF {
    suffix -= 1
  }
  let replacement = text[prefix:text.length() - suffix].to_owned()
  let mut offset = 0
  let mut inserted = false
  let draft_items = state.draft_items.map(item => {
    if item.section_index != paragraph {
      return item
    }
    let start = offset
    let end = start + item.text.length()
    offset = end
    let before = if prefix > start {
      item.text[:(prefix - start).min(item.text.length())].to_owned()
    } else {
      ""
    }
    let after_start = original.length() - suffix
    let after = if after_start < end {
      item.text[(after_start - start).max(0):].to_owned()
    } else {
      ""
    }
    let middle = if !inserted &&
      (
        prefix < end ||
        (end == original.length() && (item.text != "" || original.is_empty()))
      ) {
      inserted = true
      replacement
    } else {
      ""
    }
    { ..item, text: before + middle + after, }
  })
  { ..state, draft_items, status: "Unsaved changes", }
}

///|
fn wiki_docx_input(dispatch : Dispatch[Msg], input : String) -> @rabbita.Cmd {
  let payload = @json.parse(input) catch { _ => return @rabbita.none }
  match payload {
    { "action": String("dirty"), .. } =>
      return dispatch(
        OfficeEditor(
          OfficeDocumentPending(
            json_field_bool(payload, "dirty", default=false),
          ),
        ),
      )
    { "action": String("save"), "paragraphs": Array(values), .. } => {
      let edits : Array[(Int32, String)] = []
      for value in values {
        guard value
          is { "paragraph": Number(index, ..), "text": String(text), .. } else {
          return @rabbita.none
        }
        edits.push((index.to_int(), text))
      }
      return dispatch(OfficeEditor(OfficeCommitDocument(edits)))
    }
    _ => ()
  }
  guard payload is { "paragraph": Number(index, ..), "text": String(text), .. } else {
    return @rabbita.none
  }
  dispatch(OfficeEditor(OfficeEditParagraph(index.to_int(), text)))
}

///|
fn render_wiki_docx(
  dispatch : Dispatch[Msg],
  state : OfficeEditorState,
) -> @rabbita.Html {
  let paragraphs : Array[Json] = []
  let mut section_index = -1
  let mut runs : Array[Json] = []
  for item in state.draft_items {
    if item.section_index != section_index {
      if section_index >= 0 {
        paragraphs.push({ "index": section_index, "runs": runs })
      }
      section_index = item.section_index
      runs = []
    }
    runs.push({
      "text": item.text,
      "bold": item.bold,
      "italic": item.italic,
      "underline": item.underline,
    })
  }
  if section_index >= 0 {
    paragraphs.push({ "index": section_index, "runs": runs })
  }
  div(class="wiki-docx-surface", [
    if state.conflict_baseline is Some(_) {
      div(class="wiki-docx-error", attrs=@html.Attrs::build().role("alert"), [
        p(
          flow_system_text(
            "The file changed elsewhere. Your edits are still here.",
          ),
        ),
        button(
          class="secondary-button",
          on_click=dispatch(OfficeEditor(OfficeReloadConflict)),
          flow_system_text("Reload saved document"),
        ),
      ])
    } else if !state.saving &&
      state.status != "" &&
      state.status != "Opened supported Office subset" &&
      state.status != "Unsaved changes" &&
      state.status != "Saved Office bytes; close and reopen are available" {
      p(attrs=@html.Attrs::build().role("alert"), state.status)
    } else {
      @html.nothing
    },
    div(
      class="wiki-docx-host",
      attrs=@html.Attrs::build()
        .data_set("testid", "wiki-docx-document")
        .data_set("workspace-id", state.workspace_id)
        .data_set("document-path", state.path)
        .data_set(
          "source-url",
          office_editor_endpoint_url(
            state.workspace_id,
            "office/export",
            state.path,
          ),
        )
        .data_set(
          "identity",
          state.workspace_id +
          ":" +
          state.path +
          ":" +
          state.request_generation.to_string(),
        )
        .data_set(
          "editing",
          if state.document_editing {
            "true"
          } else {
            "false"
          },
        )
        .data_set(
          "dirty",
          if office_editor_dirty(state) {
            "true"
          } else {
            "false"
          },
        )
        .data_set("saving", if state.saving { "true" } else { "false" }),
      [
        pre(
          attrs=@html.Attrs::build().hidden(true).data_set("docx-model", "true"),
          Json(paragraphs).stringify(),
        ),
        input(
          attrs=@html.Attrs::build().hidden(true).data_set("docx-input", "true"),
          on_input=input => wiki_docx_input(dispatch, input),
        ),
      ],
    ),
  ])
}
