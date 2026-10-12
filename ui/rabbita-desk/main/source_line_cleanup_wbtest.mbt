///|
test "line cleanup actual textarea selection sorts deduplicates and undoes atomically" {
  let text = "Inventory 😀\nbeta\nalpha\nbeta\nZebra\nFooter"
  let previous = inline_mock_backward(text, 13, 35)
  defer line_authoring_restore_selection(previous)
  let (_, sorted) = source_pane_action(
    fn(_) { @rabbita.none },
    CleanupLines(SortAscending),
    { ..init_model(), source_pane: literal_search_test_state(text), },
  )
  assert_eq(
    sorted.source_pane.draft,
    "Inventory 😀\nZebra\nalpha\nbeta\nbeta\nFooter",
  )
  assert_eq(sorted.source_pane.search.undo.length(), 1)
  assert_eq(
    sorted.source_pane.search.selection.unwrap().start,
    @edit.Position::new(5, 0),
  )
  assert_eq(
    sorted.source_pane.search.selection.unwrap().end,
    @edit.Position::new(1, 0),
  )
  let unique = update_source_pane(
    sorted.source_pane,
    CleanupLines(RemoveDuplicates),
  )
  assert_eq(unique.draft, "Inventory 😀\nZebra\nalpha\nbeta\nFooter")
  assert_true(unique.status.contains("Removed 1 duplicate line;"))
  assert_eq(unique.search.undo.length(), 2)
  assert_eq(unique.search.selection.unwrap().start, @edit.Position::new(4, 0))
  let once = update_source_pane(unique, UndoEdit)
  assert_eq(once.draft, sorted.source_pane.draft)
  let twice = update_source_pane(once, UndoEdit)
  assert_eq(twice.draft, text)
  let redone = update_source_pane(update_source_pane(twice, RedoEdit), RedoEdit)
  assert_eq(redone.draft, unique.draft)
  assert_eq(redone.search.selection, unique.search.selection)
  assert_true(source_pane_dirty(unique))
  let html = @rabbita.render_to_string(
    @rabbita.static_cell(render_source_editor(fn(_) { @rabbita.none }, unique)),
  )
  for id in ["ascending", "descending", "unique"] {
    assert_true(html.contains("data-testid=\"source-cleanup-" + id + "\""))
  }
  assert_true(html.contains("first exact occurrence in original order"))
  println("CLEANUP_HTML_BEGIN")
  println(html)
  println("CLEANUP_HTML_END")
}

///|
test "line cleanup synthetic CRLF inventory retains boundary and buffer history" {
  let original = "Inventory 😀\r\nbeta\r\nalpha\r\nbeta\r\nZebra\r\nFooter\r\n"
  let initial = line_authoring_test_selected(
    literal_search_test_state(original),
    1,
    0,
    5,
    0,
  )
  let unique = update_source_pane(initial, CleanupLines(RemoveDuplicates))
  assert_eq(
    unique.draft,
    "Inventory 😀\r\nbeta\r\nalpha\r\nZebra\r\nFooter\r\n",
  )
  let sorted = update_source_pane(unique, CleanupLines(SortAscending))
  assert_eq(
    sorted.draft,
    "Inventory 😀\r\nZebra\r\nalpha\r\nbeta\r\nFooter\r\n",
  )
  assert_eq(sorted.search.undo.length(), 2)
  let switched = update_source_pane(sorted, RequestSource("other.txt"))
  let restored = update_source_pane(switched, SwitchBuffer("src/main.mbt"))
  assert_eq(restored.draft, sorted.draft)
  assert_eq(update_source_pane(restored, UndoEdit).draft, unique.draft)
  println("CLEANUP_ACTUAL_BEGIN")
  println(sorted.draft)
  println("CLEANUP_ACTUAL_END")
}

///|
test "line cleanup noops preserve redo and reject stale or unavailable selection" {
  let initial = line_authoring_test_selected(
    literal_search_test_state("a\nb\n"),
    0,
    0,
    2,
    0,
  )
  let sorted = update_source_pane(initial, CleanupLines(SortDescending))
  let undone = update_source_pane(sorted, UndoEdit)
  let noop = update_source_pane(undone, CleanupLines(RemoveDuplicates))
  assert_eq(noop.draft, initial.draft)
  assert_eq(noop.search.undo.length(), 0)
  assert_eq(update_source_pane(noop, RedoEdit).draft, sorted.draft)
  let caret = update_source_pane(
    literal_search_test_state("a\nb"),
    CleanupLines(SortDescending),
  )
  assert_eq(caret.draft, "a\nb")
  assert_true(caret.status.contains("at least two lines"))
  let stale = line_authoring_test_selected(initial, 7, 0, 8, 0)
  let rejected = update_source_pane(stale, CleanupLines(RemoveDuplicates))
  assert_eq(rejected.draft, stale.draft)
  assert_eq(rejected.search, stale.search)
  assert_true(rejected.status.contains("Select text again"))
  let saving = update_source_pane(sorted, Save)
  let loading = update_source_pane(
    init_source_pane("book-demo", ""),
    RequestSource("notes.txt"),
  )
  for state in [saving, loading, init_source_pane("book-demo", "")] {
    for
      action in [
        @edit.LineCleanupAction::SortAscending,
        SortDescending,
        RemoveDuplicates,
      ] {
      assert_eq(update_source_pane(state, CleanupLines(action)), state)
    }
    let html = @rabbita.render_to_string(
      @rabbita.static_cell(
        render_source_line_cleanup(fn(_) { @rabbita.none }, state),
      ),
    )
    assert_true(html.contains("disabled"))
  }
}
