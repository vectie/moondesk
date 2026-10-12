///|
extern "js" fn inline_mock_backward(
  text : String,
  start : Int,
  end : Int,
) -> @js.Value =
  #| (text, start, end) => {
  #|   const previous = globalThis.document;
  #|   globalThis.document = { querySelector: () => ({ value: text, selectionStart: start, selectionEnd: end, selectionDirection: 'backward' }) };
  #|   return previous;
  #| }

///|
test "inline toolbar captures actual backward UTF16 selection with one undo step" {
  let text = "Review 😀 release"
  let previous = inline_mock_backward(text, 7, 9)
  defer line_authoring_restore_selection(previous)
  let (_, next) = source_pane_action(
    fn(_) { @rabbita.none },
    WrapMarkdown(Bold),
    { ..init_model(), source_pane: literal_search_test_state(text), },
  )
  assert_eq(next.source_pane.draft, "Review **😀** release")
  assert_eq(next.source_pane.search.undo.length(), 1)
  assert_eq(next.source_pane.search.selection.unwrap().start.column, 11)
  assert_eq(next.source_pane.search.selection.unwrap().end.column, 9)
  let undone = update_source_pane(next.source_pane, UndoEdit)
  assert_eq(undone.draft, text)
  assert_eq(update_source_pane(undone, RedoEdit).draft, next.source_pane.draft)
  let html = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_source_editor(fn(_) { @rabbita.none }, next.source_pane),
    ),
  )
  for id in ["bold", "italic", "code"] {
    assert_true(html.contains("data-testid=\"source-inline-" + id + "\""))
  }
  assert_true(html.contains("not a toggle"))
  println("INLINE_HTML_BEGIN")
  println(html)
  println("INLINE_HTML_END")
}

///|
test "inline source journey produces actual Markdown and retains CRLF" {
  let input = "Release 😀\r\nUse `status` today\r\n"
  let bold = update_source_pane(
    line_authoring_test_selected(literal_search_test_state(input), 0, 0, 0, 10),
    WrapMarkdown(Bold),
  )
  let code = update_source_pane(
    line_authoring_test_selected(bold, 1, 4, 1, 12),
    WrapMarkdown(Code),
  )
  assert_eq(code.draft, "**Release 😀**\r\nUse `` `status` `` today\r\n")
  assert_eq(code.search.undo.length(), 2)
  assert_eq(
    update_source_pane(update_source_pane(code, UndoEdit), RedoEdit).draft,
    code.draft,
  )
  println("INLINE_ACTUAL_BEGIN")
  println(code.draft)
  println("INLINE_ACTUAL_END")
}

///|
test "inline empty multiline repeated and unavailable states remain explicit" {
  let empty = update_source_pane(
    literal_search_test_state(""),
    WrapMarkdown(Code),
  )
  assert_eq(empty.draft, "``")
  assert_eq(empty.search.selection.unwrap().start.column, 1)
  let selected = line_authoring_test_selected(
    literal_search_test_state("a\nb"),
    1,
    1,
    0,
    0,
  )
  let wrapped = update_source_pane(selected, WrapMarkdown(Italic))
  assert_eq(wrapped.draft, "*a\nb*")
  let repeated = update_source_pane(wrapped, WrapMarkdown(Italic))
  assert_eq(repeated.draft, "**a\nb**")
  assert_eq(repeated.search.undo.length(), 2)
  assert_eq(repeated.search.selection.unwrap().start, @edit.Position::new(1, 1))
  assert_eq(repeated.search.selection.unwrap().end, @edit.Position::new(0, 2))
  let stale = line_authoring_test_selected(
    literal_search_test_state("short"),
    5,
    0,
    5,
    4,
  )
  let rejected = update_source_pane(stale, WrapMarkdown(Bold))
  assert_eq(rejected.draft, "short")
  assert_eq(rejected.search.undo.length(), 0)
  assert_true(rejected.status.contains("Select text again"))
  let saving = update_source_pane(wrapped, Save)
  for state in [saving, init_source_pane("book-demo", "")] {
    assert_eq(update_source_pane(state, WrapMarkdown(Bold)), state)
    let html = @rabbita.render_to_string(
      @rabbita.static_cell(
        render_source_line_authoring(fn(_) { @rabbita.none }, state),
      ),
    )
    assert_true(html.contains("disabled"))
  }
}
