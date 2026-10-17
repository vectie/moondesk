///|
fn line_authoring_test_selected(
  state : SourcePaneState,
  sl : Int32,
  sc : Int32,
  el : Int32,
  ec : Int32,
) -> SourcePaneState {
  {
    ..state,
    search: {
      ..state.search,
      selection: Some(
        @edit.Range::new(
          @edit.Position::new(sl, sc),
          @edit.Position::new(el, ec),
        ),
      ),
    },
  }
}

///|
test "line authoring controls expose indentation choices and keyboard shortcuts" {
  let ready = literal_search_test_state("code")
  let html = render_test_dom(
    @rabbita.static_cell(render_source_editor(fn(_) { @rabbita.none }, ready)),
  )
  for
    control in [
      "source-line-actions", "source-indent-lines", "source-outdent-lines", "source-duplicate-lines",
      "source-indent-2", "source-indent-4", "source-indent-tab",
    ] {
    assert_true(html.contains("data-testid=\"" + control + "\""))
  }
  assert_true(html.contains("Ctrl/Cmd+]"))
  assert_true(html.contains("Alt+Shift+Down"))
  assert_true(html.contains("aria-pressed=\"true\""))
  assert_eq(
    source_line_shortcut("]", true, false, false, false),
    Some(IndentLines(false)),
  )
  assert_eq(
    source_line_shortcut("[", true, false, false, false),
    Some(IndentLines(true)),
  )
  assert_eq(
    source_line_shortcut("ArrowDown", false, true, true, false),
    Some(DuplicateLines),
  )
  assert_eq(source_line_shortcut("]", true, false, false, true), None)
  assert_eq(source_line_shortcut("]", true, false, true, false), None)
  assert_eq(source_line_shortcut("ArrowDown", true, true, true, false), None)
  assert_eq(source_line_shortcut("Tab", false, false, false, false), None)
}

///|
test "selected line indent duplicate and outdent share atomic source history" {
  let original = "fn main {\nprintln(\"Hello 🚀\")\nprintln(\"Launch\")\n}\n"
  let selected = line_authoring_test_selected(
    literal_search_test_state(original),
    1,
    0,
    3,
    0,
  )
  let indented = update_source_pane(selected, IndentLines(false))
  assert_eq(
    indented.draft,
    "fn main {\n  println(\"Hello 🚀\")\n  println(\"Launch\")\n}\n",
  )
  assert_eq(indented.search.undo.length(), 1)
  assert_eq(indented.search.selection.unwrap().end.line, 3)
  let outdented = update_source_pane(indented, IndentLines(true))
  assert_eq(outdented.draft, original)
  let restored = update_source_pane(outdented, UndoEdit)
  assert_eq(restored.draft, indented.draft)
  let duplicated = update_source_pane(
    line_authoring_test_selected(restored, 2, 4, 2, 5),
    DuplicateLines,
  )
  assert_eq(
    duplicated.draft,
    "fn main {\n  println(\"Hello 🚀\")\n  println(\"Launch\")\n  println(\"Launch\")\n}\n",
  )
  assert_eq(duplicated.search.selection.unwrap().start.line, 3)
  assert_eq(duplicated.search.selection.unwrap().end.line, 4)
  assert_eq(duplicated.search.undo.length(), 2)
  assert_eq(update_source_pane(duplicated, UndoEdit).draft, restored.draft)
  assert_eq(
    update_source_pane(update_source_pane(duplicated, UndoEdit), RedoEdit).draft,
    duplicated.draft,
  )
  assert_true(source_pane_dirty(duplicated))
}

///|
test "indentation preferences and drafts survive tabs without adding text history" {
  let initial = literal_search_test_state("one\ntwo\n")
  let four = update_source_pane(initial, SetLineIndent(FourSpaces))
  assert_false(source_pane_dirty(four))
  assert_true(four.search.undo.is_empty())
  let edited = update_source_pane(four, IndentLines(false))
  assert_eq(edited.draft, "    one\ntwo\n")
  let other = update_source_pane(edited, RequestSource("other.txt"))
  let restored = update_source_pane(other, SwitchBuffer("src/main.mbt"))
  assert_eq(restored.search.indentation, FourSpaces)
  assert_eq(restored.draft, edited.draft)
  assert_eq(update_source_pane(restored, UndoEdit).draft, initial.draft)
  let tabs = update_source_pane(initial, SetLineIndent(Tab))
  assert_eq(update_source_pane(tabs, IndentLines(false)).draft, "\tone\ntwo\n")
}

///|
test "line authoring no-op preserves redo and disabled source states do not mutate" {
  let initial = literal_search_test_state("plain")
  let undone = update_source_pane(
    update_source_pane(initial, DuplicateLines),
    UndoEdit,
  )
  let no_op = update_source_pane(undone, IndentLines(true))
  assert_eq(no_op.draft, "plain")
  assert_true(no_op.search.undo.is_empty())
  assert_eq(update_source_pane(no_op, RedoEdit).draft, "plain\nplain")
  let loading = update_source_pane(
    init_source_pane("book-demo", ""),
    RequestSource("src/main.mbt"),
  )
  let saving = update_source_pane(
    update_source_pane(initial, DuplicateLines),
    Save,
  )
  for state in [init_source_pane("book-demo", ""), loading, saving] {
    for
      action in [
        IndentLines(false),
        IndentLines(true),
        DuplicateLines,
        SetLineIndent(Tab),
      ] {
      assert_eq(update_source_pane(state, action), state)
    }
    let html = render_test_dom(
      @rabbita.static_cell(
        render_source_line_authoring(fn(_) { @rabbita.none }, state),
      ),
    )
    assert_true(html.contains("disabled"))
  }
}

///|
extern "js" fn line_authoring_mock_selection(
  text : String,
  start : Int32,
  end : Int32,
) -> @js.Value =
  #| (text, start, end) => {
  #|   const previous = globalThis.document;
  #|   globalThis.document = { querySelector: () => ({ value: text, selectionStart: start, selectionEnd: end }) };
  #|   return previous;
  #| }

///|
extern "js" fn line_authoring_restore_selection(previous : @js.Value) -> Unit =
  #| previous => { globalThis.document = previous; }

///|
test "line actions capture current textarea UTF16 selection before reducing" {
  let text = "😀zero\none\ntwo\nend"
  let ready = literal_search_test_state(text)
  let previous = line_authoring_mock_selection(text, 7, 15)
  defer line_authoring_restore_selection(previous)
  let (_, next) = source_pane_action(
    fn(_) { @rabbita.none },
    IndentLines(false),
    { ..init_model(), source_pane: ready, },
  )
  assert_eq(next.source_pane.draft, "😀zero\n  one\n  two\nend")
  assert_eq(
    next.source_pane.search.selection.unwrap().start,
    @edit.Position::new(1, 2),
  )
  assert_eq(
    next.source_pane.search.selection.unwrap().end,
    @edit.Position::new(3, 0),
  )
  assert_eq(
    update_source_pane(next.source_pane, UndoEdit).search.selection,
    Some(@edit.Range::new(@edit.Position::new(1, 0), @edit.Position::new(3, 0))),
  )
}
