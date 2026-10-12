///|
#skip("Requires isolated status.md fixture host; see docs/TABLE_IMPORT.md")
test "table conversion opens selected CSV converts undoes saves and reopens through HTTP" {
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
    source_literal_live_send(cell, RequestSource("status.md"))
    for attempt in 0..<250 {
      if !(cell.val.source_pane.content is Loading) {
        break
      }
      assert_true(attempt < 249, msg="Table fixture open timed out")
      ignore(source_literal_live_tick().wait())
    }
    let initial = "# Launch status\n\nItem,Owner,Notes\nLaunch,Ana,\"Ready, pending QA\"\nDocs,李,\"Line one\nLine two | checked\"\n\nNext: publish.\n"
    assert_eq(cell.val.source_pane.draft, initial)
    cell.val = {
      ..cell.val,
      source_pane: line_authoring_test_selected(
        cell.val.source_pane,
        2,
        0,
        6,
        0,
      ),
    }
    source_literal_live_send(cell, ConvertDelimitedTable(Comma))
    let expected = "# Launch status\n\n| Item | Owner | Notes |\n| --- | --- | --- |\n| Launch | Ana | Ready,&#32;pending&#32;QA |\n| Docs | 李 | Line&#32;one<br>Line&#32;two&#32;&#124;&#32;checked |\n\nNext: publish.\n"
    assert_eq(cell.val.source_pane.draft, expected)
    assert_eq(cell.val.source_pane.search.undo.length(), 1)
    source_literal_live_send(cell, UndoEdit)
    assert_eq(cell.val.source_pane.draft, initial)
    source_literal_live_send(cell, RedoEdit)
    assert_eq(cell.val.source_pane.draft, expected)
    source_literal_live_send(cell, Save)
    for attempt in 0..<250 {
      if !cell.val.source_pane.saving {
        break
      }
      assert_true(attempt < 249, msg="Table fixture save timed out")
      ignore(source_literal_live_tick().wait())
    }
    assert_eq(cell.val.source_pane.status, "Saved")
    assert_false(source_pane_dirty(cell.val.source_pane))
    source_literal_live_send(cell, CloseBuffer("status.md"))
    assert_true(cell.val.source_pane.content is Empty)
    source_literal_live_send(cell, RequestSource("status.md"))
    for attempt in 0..<250 {
      if !(cell.val.source_pane.content is Loading) {
        break
      }
      assert_true(attempt < 249, msg="Table fixture reopen timed out")
      ignore(source_literal_live_tick().wait())
    }
    assert_eq(cell.val.source_pane.draft, expected)
    assert_false(source_pane_dirty(cell.val.source_pane))
  })
}
