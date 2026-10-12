///|
test "checklist source reducer creates marks removes and undoes with CRLF Unicode" {
  let original = "😀plan\r\nreview\r\nend"
  let selected = line_authoring_test_selected(
    literal_search_test_state(original),
    0,
    2,
    2,
    0,
  )
  let created = update_source_pane(selected, EditChecklist(CreateTasks))
  assert_eq(created.draft, "- [ ] 😀plan\r\n- [ ] review\r\nend")
  assert_eq(created.search.undo.length(), 1)
  assert_eq(created.search.selection.unwrap().start.column, 8)
  let repeated = update_source_pane(created, EditChecklist(CreateTasks))
  assert_eq(repeated.search.undo.length(), 1)
  let completed = update_source_pane(repeated, EditChecklist(CompleteTasks))
  assert_eq(completed.draft, "- [x] 😀plan\r\n- [x] review\r\nend")
  let reopened = update_source_pane(completed, EditChecklist(ReopenTasks))
  assert_eq(reopened.draft, created.draft)
  let removed = update_source_pane(reopened, EditChecklist(RemoveTasks))
  assert_eq(removed.draft, original)
  assert_eq(update_source_pane(removed, UndoEdit).draft, reopened.draft)
  let undone = update_source_pane(created, UndoEdit)
  assert_eq(undone.draft, original)
  assert_eq(undone.search.selection, selected.search.selection)
  assert_eq(update_source_pane(undone, RedoEdit).draft, created.draft)
}

///|
test "checklist UI captures real UTF16 selection and excludes fenced lines" {
  let text = "😀intro\n```\n- [ ] code\n```\nreview\nend"
  let previous = line_authoring_mock_selection(text, 8, 34)
  defer line_authoring_restore_selection(previous)
  let (_, next) = source_pane_action(
    fn(_) { @rabbita.none },
    EditChecklist(CreateTasks),
    { ..init_model(), source_pane: literal_search_test_state(text), },
  )
  assert_eq(
    next.source_pane.draft,
    "😀intro\n```\n- [ ] code\n```\n- [ ] review\nend",
  )
  assert_eq(next.source_pane.search.undo.length(), 1)
  let html = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_source_editor(fn(_) { @rabbita.none }, next.source_pane),
    ),
  )
  for id in ["create", "complete", "reopen", "remove"] {
    assert_true(html.contains("data-testid=\"source-checklist-" + id + "\""))
  }
  assert_true(html.contains("Mark incomplete"))
  assert_true(html.contains("fenced code is skipped"))
}

///|
test "checklist synthetic authoring output and rendered controls" {
  let input = "Release review\n\nReview 😀 screenshots\nConfirm 中文 copy\n```md\n- [ ] literal example\n```\n"
  let selected = line_authoring_test_selected(
    literal_search_test_state(input),
    2,
    0,
    4,
    0,
  )
  let created = update_source_pane(selected, EditChecklist(CreateTasks))
  let completed = update_source_pane(
    line_authoring_test_selected(created, 2, 0, 3, 0),
    EditChecklist(CompleteTasks),
  )
  assert_eq(
    completed.draft,
    "Release review\n\n- [x] Review 😀 screenshots\n- [ ] Confirm 中文 copy\n```md\n- [ ] literal example\n```\n",
  )
  assert_eq(
    update_source_pane(update_source_pane(completed, UndoEdit), RedoEdit).draft,
    completed.draft,
  )
  println("CHECKLIST_ACTUAL_BEGIN")
  println(completed.draft)
  println("CHECKLIST_ACTUAL_END")
  println("CHECKLIST_HTML_BEGIN")
  println(
    @rabbita.render_to_string(
      @rabbita.static_cell(
        render_source_line_authoring(fn(_) { @rabbita.none }, completed),
      ),
    ),
  )
  println("CHECKLIST_HTML_END")
}

///|
test "checklist controls cannot modify unavailable or saving source" {
  let ready = literal_search_test_state("plain")
  let saving = update_source_pane(
    update_source_pane(ready, EditChecklist(CreateTasks)),
    Save,
  )
  for state in [init_source_pane("book-demo", ""), saving] {
    for
      action in [
        @edit.MarkdownChecklistAction::CreateTasks,
        CompleteTasks,
        ReopenTasks,
        RemoveTasks,
      ] {
      assert_eq(update_source_pane(state, EditChecklist(action)), state)
    }
    let html = @rabbita.render_to_string(
      @rabbita.static_cell(
        render_source_line_authoring(fn(_) { @rabbita.none }, state),
      ),
    )
    assert_true(html.contains("disabled"))
  }
}
