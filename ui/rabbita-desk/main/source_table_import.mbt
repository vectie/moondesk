///|
fn source_table_import_error(error : @edit.TableImportError) -> String {
  match error {
    EmptyTableInput | EmptyTableSelection =>
      "Select CSV or TSV text, including its header row, then convert it"
    InvalidTableQuote(record~, field~) =>
      "Table record \{record}, field \{field}: use double quotes around a complete field and double any quote inside it"
    UnequalTableWidth(record~, expected~, actual~) =>
      "Table record \{record} has \{actual} fields; the header has \{expected}. Check the delimiter and missing cells"
    TableEditFailed(_) => "Could not replace this selection with a table"
  }
}

///|
fn update_source_table_import(
  state : SourcePaneState,
  delimiter : @edit.TableDelimiter,
) -> SourcePaneState {
  guard source_pane_editable(state) else { return state }
  let document = source_literal_document(state)
  match
    document.convert_selection_to_table(
      delimiter,
      expected_revision=document.revision(),
    ) {
    Err(error) => { ..state, status: source_table_import_error(error), }
    Ok(range) => {
      let next = source_literal_record(state, document.text(), Some(range))
      source_pane_commit_active({
        ..next,
        status: "Converted selected text to a Markdown table; unsaved changes",
      })
    }
  }
}

///|
fn render_source_table_import(
  dispatch : Dispatch[Msg],
  source : SourcePaneState,
) -> @rabbita.Html {
  let enabled = source_pane_editable(source)
  div(
    class="source-editor-line-actions",
    attrs=@html.Attrs::build()
      .data_set("testid", "source-table-import")
      .aria_label("Import a Markdown table"),
    [
      span("Selected data"),
      button(
        class="secondary-button",
        attrs=@html.Attrs::build()
          .data_set("testid", "source-table-csv")
          .title(
            "Convert selected comma-separated text, using its first record as the header",
          ),
        disabled=!enabled,
        on_click=dispatch(SourcePane(ConvertDelimitedTable(Comma))),
        "CSV → Markdown table",
      ),
      button(
        class="secondary-button",
        attrs=@html.Attrs::build()
          .data_set("testid", "source-table-tsv")
          .title(
            "Convert selected tab-separated spreadsheet text, using its first record as the header",
          ),
        disabled=!enabled,
        on_click=dispatch(SourcePane(ConvertDelimitedTable(TabSeparated))),
        "TSV → Markdown table",
      ),
      span(
        class="source-line-help",
        "Paste or select rows including headers. Quoted cells work. Undo restores the original data.",
      ),
    ],
  )
}
