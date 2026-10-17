///|
fn outline_test_state(text : String) -> SourcePaneState {
  let loading = update_source_pane(
    init_source_pane("book-demo", "session"),
    RequestSource("launch.md"),
  )
  let preview = @desk.preview(
    @desk.file_entry(workspace_id="book-demo", path="launch.md"),
    body=text,
  )
  update_source_pane(
    loading,
    PreviewResult(source_pane_identity(loading), Ok(preview)),
  )
}

///|
test "Markdown outline renders actionable headings from the current unsaved draft" {
  let ready = outline_test_state(
    "# Launch 🚀\n## Build\n### Tests\n## Ship <now>\n",
  )
  let selected = update_source_pane(ready, SelectMarkdownSection(1))
  assert_eq(
    selected.search.selection,
    Some(@edit.Range::new(@edit.Position::new(1, 0), @edit.Position::new(3, 0))),
  )
  assert_true(selected.search.undo.is_empty())
  let html = render_test_dom(
    @rabbita.static_cell(
      render_source_editor(fn(_) { @rabbita.none }, selected),
    ),
  )
  for
    control in [
      "source-outline", "source-outline-select-1", "source-outline-up-1", "source-outline-down-1",
    ] {
    assert_true(html.contains("data-testid=\"" + control + "\""))
  }
  assert_true(html.contains("Markdown sections · 4"))
  assert_true(html.contains("Ship &lt;now&gt;"))
  assert_true(html.contains("aria-pressed=\"true\""))
  let edited = update_source_pane(selected, EditDraft("# Revised\n## Next\n"))
  let next_html = render_test_dom(
    @rabbita.static_cell(render_source_outline(fn(_) { @rabbita.none }, edited)),
  )
  assert_true(next_html.contains("Revised"))
  assert_false(next_html.contains("Build"))
  assert_false(
    source_outline_supported(literal_search_test_state("# Code comment")),
  )
}

///|
test "Markdown section moves share edit history and persist across source tabs" {
  let original = "# Launch\nIntro\n## Build\nCode\n### Tests\nUnit\n## Ship\nRelease\n"
  let ready = outline_test_state(original)
  let selected = update_source_pane(ready, SelectMarkdownSection(2))
  let moved = update_source_pane(selected, MoveMarkdownSection(2, false))
  let expected = "# Launch\nIntro\n## Ship\nRelease\n## Build\nCode\n### Tests\nUnit\n"
  assert_eq(moved.draft, expected)
  assert_eq(moved.search.undo.length(), 1)
  assert_true(source_pane_dirty(moved))
  assert_eq(moved.search.selection.unwrap().start.line, 4)
  let undone = update_source_pane(moved, UndoEdit)
  assert_eq(undone.draft, original)
  assert_eq(undone.search.selection, selected.search.selection)
  assert_eq(update_source_pane(undone, RedoEdit).draft, expected)
  let other = update_source_pane(moved, RequestSource("other.md"))
  let restored = update_source_pane(other, SwitchBuffer("launch.md"))
  assert_eq(restored.draft, expected)
  assert_eq(update_source_pane(restored, UndoEdit).draft, original)
  let back = update_source_pane(moved, MoveMarkdownSection(4, true))
  assert_eq(back.draft, original)
  assert_eq(update_source_pane(ready, MoveMarkdownSection(2, true)), ready)
}
