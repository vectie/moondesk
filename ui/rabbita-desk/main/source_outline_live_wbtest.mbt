///|
extern "js" fn source_outline_evidence(html : String) -> Unit =
  #| html => {
  #|   const output = globalThis.process?.env?.MOONDESK_OUTLINE_EVIDENCE;
  #|   if (output) require('node:fs').writeFileSync(output + '/outline-rendered.html', html);
  #| }

///|
/// Disposable fixture host, configured like source_literal_live_wbtest.mbt.
#skip("Requires the isolated Markdown fixture host; see docs/MARKDOWN_OUTLINE.md")
test "Markdown authoring live host opens reorders edits saves and reopens a section" {
  @js.async_test(async fn() {
    let origin = source_literal_live_origin()
    let workspace = source_literal_live_workspace()
    assert_true(origin.has_prefix("http://127.0.0.1:"))
    assert_true(workspace != "")
    let previous = source_literal_live_fetch(origin)
    defer source_save_http_restore(previous)
    let cell = Ref({
      ..init_model(),
      source_pane: init_source_pane(workspace, ""),
    })
    source_literal_live_send(cell, RequestSource("launch-plan.md"))
    for attempt in 0..<250 {
      if !(cell.val.source_pane.content is Loading) {
        break
      }
      assert_true(attempt < 249, msg="Host Markdown open timed out")
      ignore(source_literal_live_tick().wait())
    }
    let initial = cell.val.source_pane.draft
    let headings = source_literal_document(cell.val.source_pane).markdown_outline()
    assert_eq(headings.map(h => h.title), [
      "Launch plan 🚀", "Release checklist", "Smoke tests", "Customer communication",
      "Metrics", "Appendix",
    ])
    let line = headings[3].heading.start.line
    source_literal_live_send(cell, SelectMarkdownSection(line))
    assert_eq(cell.val.source_pane.search.selection, Some(headings[3].section))
    source_literal_live_send(cell, MoveMarkdownSection(line, true))
    let reordered = cell.val.source_pane.draft
    assert_eq(
      source_literal_document(cell.val.source_pane)
      .markdown_outline()
      .map(h => h.title),
      [
        "Launch plan 🚀", "Customer communication", "Release checklist", "Smoke tests",
        "Metrics", "Appendix",
      ],
    )
    assert_eq(cell.val.source_pane.search.undo.length(), 1)
    source_literal_live_send(cell, UndoEdit)
    assert_eq(cell.val.source_pane.draft, initial)
    source_literal_live_send(cell, RedoEdit)
    assert_eq(cell.val.source_pane.draft, reordered)
    source_literal_live_send(
      cell,
      EditDraft(
        reordered.replace(old="Draft launch email", new="Launch email ready"),
      ),
    )
    let expected = cell.val.source_pane.draft
    assert_true(expected.contains("Launch email ready for the pilot group."))
    let html = render_test_dom(
      @rabbita.static_cell(
        render_source_editor(fn(_) { @rabbita.none }, cell.val.source_pane),
      ),
    )
    assert_true(html.contains("Markdown sections · 6"))
    assert_true(html.contains("source-outline-select-4"))
    source_outline_evidence(html)
    source_literal_live_send(cell, Save)
    for attempt in 0..<250 {
      if !cell.val.source_pane.saving {
        break
      }
      assert_true(attempt < 249, msg="Host Markdown save timed out")
      ignore(source_literal_live_tick().wait())
    }
    assert_eq(cell.val.source_pane.status, "Saved")
    assert_false(source_pane_dirty(cell.val.source_pane))
    source_literal_live_send(cell, CloseBuffer("launch-plan.md"))
    source_literal_live_send(cell, RequestSource("launch-plan.md"))
    for attempt in 0..<250 {
      if !(cell.val.source_pane.content is Loading) {
        break
      }
      assert_true(attempt < 249, msg="Host Markdown reopen timed out")
      ignore(source_literal_live_tick().wait())
    }
    assert_eq(cell.val.source_pane.draft, expected)
    assert_false(source_pane_dirty(cell.val.source_pane))
    assert_eq(
      source_literal_document(cell.val.source_pane).markdown_outline()[1].title,
      "Customer communication",
    )
  })
}
