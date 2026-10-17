///|
test "JSON layout captures actual backward textarea selection and shared undo redo" {
  let text = "Prefix 😀 { \"a\" : [ 1 , 2 ] } suffix\r\n"
  let previous = inline_mock_backward(text, 10, 29)
  defer line_authoring_restore_selection(previous)
  let (_, changed) = source_pane_action(
    fn(_) { @rabbita.none },
    LayoutJson(Compact),
    { ..init_model(), source_pane: literal_search_test_state(text), },
  )
  let source = changed.source_pane
  assert_eq(source.draft, "Prefix 😀 {\"a\":[1,2]} suffix\r\n")
  assert_eq(source.search.undo.length(), 1)
  assert_eq(source.search.selection.unwrap().start, @edit.Position::new(0, 21))
  assert_eq(source.search.selection.unwrap().end, @edit.Position::new(0, 10))
  assert_true(source_pane_dirty(source))
  let undone = update_source_pane(source, UndoEdit)
  assert_eq(undone.draft, text)
  assert_eq(undone.search.selection.unwrap().start.column, 29)
  assert_eq(undone.search.selection.unwrap().end.column, 10)
  let redone = update_source_pane(undone, RedoEdit)
  assert_eq(redone.draft, source.draft)
  assert_eq(redone.search.selection, source.search.selection)
  let switched = update_source_pane(redone, RequestSource("other.json"))
  let restored = update_source_pane(switched, SwitchBuffer("src/main.mbt"))
  assert_eq(restored.draft, source.draft)
  assert_eq(update_source_pane(restored, UndoEdit).draft, text)
}

///|
test "JSON layout produces token exact CRLF fixture and rendered controls" {
  let text = "{\"id\": 900719925474099312345, \"id\": -0.00E+09,\"label\":\"東京😀\",\"escaped\":\"\\u4e2D\", \"items\":[true,null]}\r\n"
  let before = literal_search_test_state(text)
  let source = update_source_pane(before, LayoutJson(Pretty))
  assert_eq(
    source.draft,
    "{\r\n  \"id\": 900719925474099312345,\r\n  \"id\": -0.00E+09,\r\n  \"label\": \"東京😀\",\r\n  \"escaped\": \"\\u4e2D\",\r\n  \"items\": [\r\n    true,\r\n    null\r\n  ]\r\n}\r\n",
  )
  assert_eq(source.search.undo.length(), 1)
  assert_eq(source.search.selection.unwrap().start, @edit.Position::new(0, 0))
  assert_eq(source.search.selection.unwrap().end, @edit.Position::new(10, 0))
  let compact = update_source_pane(source, LayoutJson(Compact))
  assert_eq(
    compact.draft,
    "{\"id\":900719925474099312345,\"id\":-0.00E+09,\"label\":\"東京😀\",\"escaped\":\"\\u4e2D\",\"items\":[true,null]}\r\n",
  )
  assert_eq(compact.search.undo.length(), 2)
  assert_eq(update_source_pane(compact, UndoEdit).draft, source.draft)
  let html = render_test_dom(
    @rabbita.static_cell(render_source_editor(fn(_) { @rabbita.none }, source)),
  )
  for id in ["pretty", "compact"] {
    assert_true(html.contains("data-testid=\"source-json-" + id + "\""))
  }
  assert_true(html.contains("selection, or whole draft with a caret"))
  assert_true(html.contains("preserves exact tokens and duplicate keys"))
  println("JSON_BEFORE_BEGIN")
  println(text)
  println("JSON_BEFORE_END")
  println("JSON_PRETTY_BEGIN")
  println(source.draft)
  println("JSON_PRETTY_END")
  println("JSON_COMPACT_BEGIN")
  println(compact.draft)
  println("JSON_COMPACT_END")
  println("JSON_HTML_BEGIN")
  println(html)
  println("JSON_HTML_END")
}

///|
test "JSON layout invalid input stale selection noops and unavailable states are inert" {
  let before = literal_search_test_state("{\"a\":1}")
  let pretty = update_source_pane(before, LayoutJson(Pretty))
  let undone = update_source_pane(pretty, UndoEdit)
  let noop = update_source_pane(undone, LayoutJson(Compact))
  assert_eq(noop.draft, before.draft)
  assert_eq(noop.search, undone.search)
  assert_eq(update_source_pane(noop, RedoEdit).draft, pretty.draft)
  let selected = line_authoring_test_selected(undone, 0, 1, 0, 3)
  let failed = update_source_pane(selected, LayoutJson(Pretty))
  assert_eq(failed.draft, selected.draft)
  assert_eq(failed.search, selected.search)
  assert_true(failed.status.contains("Invalid JSON at UTF-16 offset 2"))
  assert_true(failed.status.contains("draft unchanged"))
  assert_eq(update_source_pane(failed, RedoEdit).draft, pretty.draft)
  let stale = line_authoring_test_selected(before, 9, 0, 9, 2)
  let rejected = update_source_pane(stale, LayoutJson(Pretty))
  assert_eq(rejected.draft, stale.draft)
  assert_eq(rejected.search, stale.search)
  assert_true(rejected.status.contains("Select text again"))
  let saving = update_source_pane(pretty, Save)
  let loading = update_source_pane(
    init_source_pane("book-demo", ""),
    RequestSource("data.json"),
  )
  for state in [saving, loading, init_source_pane("book-demo", "")] {
    for layout in [@edit.JsonLayout::Pretty, Compact] {
      assert_eq(update_source_pane(state, LayoutJson(layout)), state)
    }
    let html = render_test_dom(
      @rabbita.static_cell(
        render_source_json_layout(fn(_) { @rabbita.none }, state),
      ),
    )
    assert_true(html.contains("disabled"))
  }
}

///|
test "JSON layout uses per buffer indentation preference and caret whole draft" {
  let selected = line_authoring_test_selected(
    literal_search_test_state("{\"a\":1}"),
    0,
    4,
    0,
    4,
  )
  let tabs = update_source_pane(selected, SetLineIndent(Tab))
  let formatted = update_source_pane(tabs, LayoutJson(Pretty))
  assert_eq(formatted.draft, "{\n\t\"a\": 1\n}")
  assert_eq(formatted.search.undo.length(), 1)
  let four = update_source_pane(formatted, SetLineIndent(FourSpaces))
  let reformatted = update_source_pane(four, LayoutJson(Pretty))
  assert_eq(reformatted.draft, "{\n    \"a\": 1\n}")
  assert_eq(reformatted.search.undo.length(), 2)
}
