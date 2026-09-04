///|
fn office_review_item_payload(item : OfficeEditorItem) -> Json {
  {
    "text": item.text,
    "formula": item.formula,
    "bold": item.bold,
    "italic": item.italic,
    "underline": item.underline,
    "x": item.x,
    "y": item.y,
    "width": item.width,
    "height": item.height,
  }
}

///|
fn office_change_review_payload(state : OfficeEditorState) -> Json {
  guard state.document is Some(document) else { return { "visible": false } }
  guard state.selected >= 0 && state.selected < document.items.length() else {
    return { "visible": false }
  }
  guard state.selected < state.draft_items.length() else {
    return { "visible": false }
  }
  let before = document.items[state.selected]
  let after = state.draft_items[state.selected]
  {
    "visible": before != after,
    "kind": match document.kind {
      OfficeDocx => "docx"
      OfficeXlsx => "xlsx"
      OfficePptx => "pptx"
    },
    "section": after.section,
    "reference": after.reference,
    "before": office_review_item_payload(before),
    "after": office_review_item_payload(after),
    "saving": state.saving,
  }
}

///|
fn render_office_change_review(
  _dispatch : Dispatch[Msg],
  state : OfficeEditorState,
) -> @rabbita.Html {
  div(
    class="office-change-review-host",
    attrs=@html.Attrs::build()
      .data_set("testid", "office-change-review-host")
      .data_set("state", office_change_review_payload(state).stringify()),
    ([] : Array[@rabbita.Html]),
  )
}
