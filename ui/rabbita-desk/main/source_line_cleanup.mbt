///|
fn update_source_line_cleanup(
  state : SourcePaneState,
  action : @edit.LineCleanupAction,
) -> SourcePaneState {
  guard source_pane_editable(state) else { return state }
  let document = source_literal_document(state)
  if state.search.selection is Some(range) &&
    (
      !document.contains_position(range.start) ||
      !document.contains_position(range.end)
    ) {
    return { ..state, status: "Select text again before cleaning up lines", }
  }
  match
    document.cleanup_selected_lines(
      action,
      expected_revision=document.revision(),
    ) {
    Err(_) => { ..state, status: "Could not clean up the selected lines", }
    Ok(result) => {
      if !result.changed {
        return {
          ..state,
          status: if result.input_lines < 2 {
            "Select at least two lines to sort or remove duplicates"
          } else {
            "Selected lines already match; no changes"
          },
        }
      }
      let selected = document.selections()[0]
      let next = source_literal_record(
        state,
        document.text(),
        Some(@edit.Range::new(selected.anchor, selected.active)),
      )
      let status = match action {
        RemoveDuplicates => {
          let removed = result.input_lines - result.output_lines
          let noun = if removed == 1 { "line" } else { "lines" }
          "Removed \{removed} duplicate \{noun}; first occurrences kept, unsaved changes"
        }
        SortAscending | SortDescending =>
          "Sorted \{result.output_lines} lines; literal case-sensitive order, unsaved changes"
      }
      source_pane_commit_active({ ..next, status, })
    }
  }
}

///|
fn render_source_line_cleanup(
  dispatch : Dispatch[Msg],
  source : SourcePaneState,
) -> @rabbita.Html {
  div(
    attrs=@html.Attrs::build().aria_label("Sort and deduplicate selected lines"),
    [@edit.LineCleanupAction::SortAscending, SortDescending, RemoveDuplicates].map(action => {
        let (id, label, help) = match action {
          SortAscending =>
            (
              "ascending", "Sort ascending", "Case-sensitive UTF-16 order; numbers are literal text",
            )
          SortDescending =>
            (
              "descending", "Sort descending", "Reverse case-sensitive UTF-16 order; numbers are literal text",
            )
          RemoveDuplicates =>
            (
              "unique", "Keep unique lines", "Keep the first exact occurrence in original order; spaces and case matter",
            )
        }
        button(
          class="secondary-button",
          attrs=@html.Attrs::build()
            .data_set("testid", "source-cleanup-" + id)
            .title(help),
          disabled=!source_pane_editable(source),
          on_click=dispatch(SourcePane(CleanupLines(action))),
          label,
        )
      },
    ),
  )
}
