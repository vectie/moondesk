///|
extern "js" fn source_table_import_evidence(
  text : String,
  html : String,
) -> Unit =
  #| (text, html) => {
  #|   const output = globalThis.process?.env?.MOONDESK_TABLE_EVIDENCE;
  #|   if (output) {
  #|     const fs = require('node:fs');
  #|     fs.writeFileSync(output + '/status-imported.md', text);
  #|     fs.writeFileSync(output + '/table-import-rendered.html', html);
  #|   }
  #| }

///|
test "table toolbar exposes CSV and TSV conversions in the source editor" {
  let ready = literal_search_test_state("Item,Status\nLaunch,Ready")
  let html = render_test_dom(
    @rabbita.static_cell(render_source_editor(fn(_) { @rabbita.none }, ready)),
  )
  assert_true(html.contains("data-testid=\"source-table-csv\""))
  assert_true(html.contains("data-testid=\"source-table-tsv\""))
  assert_true(html.contains("CSV → Markdown table"))
  assert_true(html.contains("TSV → Markdown table"))
  assert_true(html.contains("Undo restores the original data"))
}

///|
test "CSV selection becomes a useful table through the real action path and atomic history" {
  let input = "# Launch status\n\nItem,Owner,Notes\nLaunch,Ana,\"Ready, pending QA\"\nDocs,李,\"Line one\nLine two | checked\"\n\nNext: publish.\n"
  let original = literal_search_test_state(input)
  let start = "# Launch status\n\n".length()
  let end = input.length() - "\nNext: publish.\n".length()
  let previous = line_authoring_mock_selection(input, start, end)
  let (_, model) = source_pane_action(
    fn(_) { @rabbita.none },
    ConvertDelimitedTable(Comma),
    { ..init_model(), source_pane: original, },
  )
  line_authoring_restore_selection(previous)
  let converted = model.source_pane
  let expected = "# Launch status\n\n| Item | Owner | Notes |\n| --- | --- | --- |\n| Launch | Ana | Ready,&#32;pending&#32;QA |\n| Docs | 李 | Line&#32;one<br>Line&#32;two&#32;&#124;&#32;checked |\n\nNext: publish.\n"
  assert_eq(converted.draft, expected)
  assert_eq(converted.search.undo.length(), 1)
  assert_true(source_pane_dirty(converted))
  assert_eq(
    converted.search.selection.unwrap().start,
    @edit.Position::new(2, 0),
  )
  let undone = update_source_pane(converted, UndoEdit)
  assert_eq(undone.draft, input)
  assert_eq(
    undone.search.selection,
    Some(@edit.Range::new(@edit.Position::new(2, 0), @edit.Position::new(6, 0))),
  )
  assert_false(source_pane_dirty(undone))
  let redone = update_source_pane(undone, RedoEdit)
  assert_eq(redone.draft, expected)
  assert_eq(redone.search.selection, converted.search.selection)
  let saving = update_source_pane(redone, Save)
  assert_true(saving.saving)
  assert_eq(saving.pending_save.unwrap().content, expected)
  let html = render_test_dom(
    @rabbita.static_cell(render_source_editor(fn(_) { @rabbita.none }, redone)),
  )
  source_table_import_evidence(redone.draft, html)
}

///|
test "TSV import preserves Unicode selections and selected conversion survives a tab switch" {
  let input = "😀 Summary\n\nName\tCount\n李\t2"
  let selected = line_authoring_test_selected(
    literal_search_test_state(input),
    2,
    0,
    3,
    3,
  )
  let converted = update_source_pane(
    selected,
    ConvertDelimitedTable(TabSeparated),
  )
  assert_eq(
    converted.draft,
    "😀 Summary\n\n| Name | Count |\n| --- | --- |\n| 李 | 2 |\n",
  )
  let other = update_source_pane(converted, RequestSource("other.md"))
  let restored = update_source_pane(other, SwitchBuffer("src/main.mbt"))
  assert_eq(restored.draft, converted.draft)
  assert_eq(restored.search.selection, converted.search.selection)
  assert_eq(update_source_pane(restored, UndoEdit).draft, input)
}

///|
test "malformed table data explains the correction without disturbing draft or redo" {
  let input = "A,B\n1"
  let selected = line_authoring_test_selected(
    literal_search_test_state(input),
    0,
    0,
    1,
    1,
  )
  let edited = update_source_pane(selected, EditDraft("other"))
  let undone = update_source_pane(edited, UndoEdit)
  let rejected = update_source_pane(undone, ConvertDelimitedTable(Comma))
  assert_eq(rejected.draft, input)
  assert_eq(rejected.search, undone.search)
  assert_true(
    rejected.status.contains("record 2 has 1 fields; the header has 2"),
  )
  assert_eq(update_source_pane(rejected, RedoEdit).draft, "other")
  let none = update_source_pane(
    literal_search_test_state("A,B"),
    ConvertDelimitedTable(Comma),
  )
  assert_true(none.status.contains("Select CSV or TSV text"))
  assert_eq(none.draft, "A,B")
  assert_true(
    source_table_import_error(InvalidTableQuote(record=3, field=2)).contains(
      "record 3, field 2",
    ),
  )
}

///|
test "table controls stay inactive when source is unavailable loading or saving" {
  let initial = literal_search_test_state("A,B\n1,2")
  let saving = update_source_pane(
    update_source_pane(initial, EditDraft("A,B\n3,4")),
    Save,
  )
  let loading = update_source_pane(
    init_source_pane("book-demo", ""),
    RequestSource("file.md"),
  )
  for state in [init_source_pane("book-demo", ""), loading, saving] {
    for delimiter in [@edit.TableDelimiter::Comma, TabSeparated] {
      assert_eq(
        update_source_pane(state, ConvertDelimitedTable(delimiter)),
        state,
      )
    }
    let html = render_test_dom(
      @rabbita.static_cell(
        render_source_table_import(fn(_) { @rabbita.none }, state),
      ),
    )
    assert_true(html.contains("disabled"))
  }
}
