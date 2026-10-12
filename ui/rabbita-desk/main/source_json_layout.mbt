///|
fn update_source_json_layout(
  state : SourcePaneState,
  layout : @edit.JsonLayout,
) -> SourcePaneState {
  guard source_pane_editable(state) else { return state }
  let document = source_literal_document(state)
  if state.search.selection is Some(range) &&
    (
      !document.contains_position(range.start) ||
      !document.contains_position(range.end)
    ) {
    return { ..state, status: "Select text again before changing JSON layout", }
  }
  match
    document.layout_json_selection(
      layout,
      expected_revision=document.revision(),
      indentation=state.search.indentation,
    ) {
    Err(error) => {
      let detail = match error {
        InvalidJson(offset~, message~) =>
          "Invalid JSON at UTF-16 offset \{offset}: \{message}"
        InputTooLarge => "JSON input exceeds 1 Mi UTF-16 units"
        NestingTooDeep => "JSON exceeds 64 nested containers"
        OutputTooLarge => "Formatted JSON exceeds 4 Mi UTF-16 units"
        Editor(_) => "Could not apply JSON layout to this revision"
      }
      {
        ..state,
        status: detail +
        "; draft unchanged (offsets start at the selection, or draft with a caret)",
      }
    }
    Ok(false) =>
      { ..state, status: "JSON already has this layout; no changes", }
    Ok(true) => {
      let selected = document.selections()[0]
      let next = source_literal_record(
        state,
        document.text(),
        Some(@edit.Range::new(selected.anchor, selected.active)),
      )
      source_pane_commit_active({
        ..next,
        status: "JSON layout changed; exact tokens kept, unsaved changes",
      })
    }
  }
}

///|
fn render_source_json_layout(
  dispatch : Dispatch[Msg],
  source : SourcePaneState,
) -> @rabbita.Html {
  div(
    class="source-editor-line-actions",
    attrs=@html.Attrs::build().aria_label("JSON layout"),
    [
      div(
        [@edit.JsonLayout::Pretty, Compact].map(layout => {
          let (id, label) = match layout {
            Pretty => ("pretty", "Format JSON")
            Compact => ("compact", "Compact JSON")
          }
          button(
            class="secondary-button",
            attrs=@html.Attrs::build()
              .data_set("testid", "source-json-" + id)
              .title(
                "Selected JSON value, or whole draft with a caret; preserves exact tokens and duplicate keys",
              ),
            disabled=!source_pane_editable(source),
            on_click=dispatch(SourcePane(LayoutJson(layout))),
            label,
          )
        }),
      ),
      span(
        class="source-line-help",
        "JSON: selection, or whole draft with a caret. Uses Indent with. Strict JSON only; Undo works as usual.",
      ),
    ],
  )
}
