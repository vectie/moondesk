///|
extern "js" fn source_line_authoring_evidence(html : String) -> Unit =
  #| html => {
  #|   const output = globalThis.process?.env?.MOONDESK_LINE_EVIDENCE;
  #|   if (output) require('node:fs').writeFileSync(output + '/line-authoring-rendered.html', html);
  #| }

///|
#skip("Requires the isolated line-authoring fixture host; see docs/LINE_AUTHORING.md")
test "line authoring live host indents duplicates edits saves and reopens a draft" {
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
    source_literal_live_send(cell, RequestSource("src/main.mbt"))
    for attempt in 0..<250 {
      if !(cell.val.source_pane.content is Loading) {
        break
      }
      assert_true(attempt < 249, msg="Host source open timed out")
      ignore(source_literal_live_tick().wait())
    }
    let initial = "fn main {\nprintln(\"Hello 🚀\")\nprintln(\"Launch\")\n}\n"
    assert_eq(cell.val.source_pane.draft, initial)
    cell.val = {
      ..cell.val,
      source_pane: line_authoring_test_selected(
        cell.val.source_pane,
        1,
        0,
        3,
        0,
      ),
    }
    source_literal_live_send(cell, IndentLines(false))
    let indented = "fn main {\n  println(\"Hello 🚀\")\n  println(\"Launch\")\n}\n"
    assert_eq(cell.val.source_pane.draft, indented)
    source_literal_live_send(cell, IndentLines(true))
    assert_eq(cell.val.source_pane.draft, initial)
    source_literal_live_send(cell, UndoEdit)
    assert_eq(cell.val.source_pane.draft, indented)
    source_literal_live_send(cell, FindQuery("println(\"Launch\")"))
    source_literal_live_send(cell, FindNext)
    source_literal_live_send(cell, DuplicateLines)
    let duplicated = "fn main {\n  println(\"Hello 🚀\")\n  println(\"Launch\")\n  println(\"Launch\")\n}\n"
    assert_eq(cell.val.source_pane.draft, duplicated)
    assert_eq(cell.val.source_pane.search.selection.unwrap().start.line, 3)
    source_literal_live_send(cell, UndoEdit)
    assert_eq(cell.val.source_pane.draft, indented)
    source_literal_live_send(cell, RedoEdit)
    assert_eq(cell.val.source_pane.draft, duplicated)
    let expected = "fn main {\n  println(\"Hello 🚀\")\n  println(\"Launch\")\n  println(\"Ready\")\n}\n"
    source_literal_live_send(cell, EditDraft(expected))
    let html = @rabbita.render_to_string(
      @rabbita.static_cell(
        render_source_editor(fn(_) { @rabbita.none }, cell.val.source_pane),
      ),
    )
    assert_true(html.contains("source-duplicate-lines"))
    assert_true(html.contains("source-indent-lines"))
    source_line_authoring_evidence(html)
    source_literal_live_send(cell, Save)
    for attempt in 0..<250 {
      if !cell.val.source_pane.saving {
        break
      }
      assert_true(attempt < 249, msg="Host source save timed out")
      ignore(source_literal_live_tick().wait())
    }
    assert_eq(cell.val.source_pane.status, "Saved")
    assert_false(source_pane_dirty(cell.val.source_pane))
    source_literal_live_send(cell, CloseBuffer("src/main.mbt"))
    source_literal_live_send(cell, RequestSource("src/main.mbt"))
    for attempt in 0..<250 {
      if !(cell.val.source_pane.content is Loading) {
        break
      }
      assert_true(attempt < 249, msg="Host source reopen timed out")
      ignore(source_literal_live_tick().wait())
    }
    assert_eq(cell.val.source_pane.draft, expected)
    assert_false(source_pane_dirty(cell.val.source_pane))
  })
}
