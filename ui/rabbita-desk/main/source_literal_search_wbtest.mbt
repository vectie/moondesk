///|
fn literal_search_test_state(text : String) -> SourcePaneState {
  let loading = update_source_pane(
    init_source_pane("book-demo", "session"),
    RequestSource("src/main.mbt"),
  )
  let preview = @desk.preview(
    @desk.file_entry(workspace_id="book-demo", path="src/main.mbt"),
    body=text,
  )
  update_source_pane(
    loading,
    PreviewResult(source_pane_identity(loading), Ok(preview)),
  )
}

///|
test "source literal search renders real count navigation case and replacement controls" {
  let ready = literal_search_test_state("😀 cat CAT cat")
  let query = update_source_pane(ready, FindQuery("cat"))
  assert_eq(source_literal_summary(query), "0/2 matches")
  let selected = update_source_pane(query, FindNext)
  assert_eq(source_literal_summary(selected), "1/2 matches")
  let next = update_source_pane(selected, FindNext)
  assert_eq(source_literal_summary(next), "2/2 matches")
  assert_eq(
    source_literal_summary(update_source_pane(next, FindNext)),
    "1/2 matches",
  )
  assert_eq(
    source_literal_summary(update_source_pane(selected, FindPrevious)),
    "2/2 matches",
  )
  let insensitive = update_source_pane(selected, FindCaseSensitive(false))
  assert_eq(source_literal_summary(insensitive), "0/3 matches")
  let html = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_source_editor(fn(_) { @rabbita.none }, insensitive),
    ),
  )
  for
    control in [
      "source-find", "source-find-next", "source-find-previous", "source-match-case",
      "source-replacement", "source-replace-next", "source-replace-all", "source-undo",
      "source-redo",
    ] {
    assert_true(html.contains("data-testid=\"" + control + "\""))
  }
  assert_true(html.contains("0/3 matches"))
  assert_true(html.contains("data-search-engine=\"moonedit\""))
}

///|
test "source literal replace all is one undo step and independent per tab" {
  let ready = literal_search_test_state("cat cat CAT")
  let query = update_source_pane(
    update_source_pane(ready, FindQuery("cat")),
    FindCaseSensitive(false),
  )
  let replacement = update_source_pane(query, FindReplacement("猫$1\\"))
  let replaced = update_source_pane(replacement, ReplaceAll)
  assert_eq(replaced.draft, "猫$1\\ 猫$1\\ 猫$1\\")
  assert_eq(replaced.status, "Replaced 3 matches")
  assert_eq(replaced.search.undo.length(), 1)
  assert_true(source_pane_dirty(replaced))
  let undone = update_source_pane(replaced, UndoEdit)
  assert_eq(undone.draft, "cat cat CAT")
  assert_false(source_pane_dirty(undone))
  assert_true(undone.search.undo.is_empty())
  let redone = update_source_pane(undone, RedoEdit)
  assert_eq(redone.draft, replaced.draft)
  let other = update_source_pane(redone, RequestSource("src/other.mbt"))
  assert_true(other.search.undo.is_empty())
  let back = update_source_pane(other, SwitchBuffer("src/main.mbt"))
  assert_eq(back.search.query, "cat")
  assert_eq(update_source_pane(back, UndoEdit).draft, ready.draft)
}

///|
test "source literal replacement shares ordinary edit history and current selection" {
  let ready = literal_search_test_state("cat cat")
  let draft = update_source_pane(ready, EditDraft("cat cat cat"))
  let query = update_source_pane(draft, FindQuery("cat"))
  let selected = update_source_pane(
    update_source_pane(query, FindNext),
    FindNext,
  )
  let replaced = update_source_pane(
    update_source_pane(selected, FindReplacement("dog")),
    ReplaceNext,
  )
  assert_eq(replaced.draft, "cat dog cat")
  assert_eq(source_literal_summary(replaced), "2/2 matches")
  let undo_replace = update_source_pane(replaced, UndoEdit)
  assert_eq(undo_replace.draft, "cat cat cat")
  assert_eq(update_source_pane(undo_replace, UndoEdit).draft, "cat cat")
  let empty = update_source_pane(replaced, FindQuery(""))
  assert_eq(update_source_pane(empty, ReplaceAll).draft, replaced.draft)
}

///|
test "source literal replacement travels through save command and reopens persisted text" {
  @js.async_test(async fn() {
    let fixture = source_save_http_fixture()
    let state = update_source_pane(
      update_source_pane(
        literal_search_test_state("cat CAT cat"),
        FindQuery("cat"),
      ),
      FindReplacement("dog"),
    )
    let cell = Ref({ ..init_model(), source_pane: state, })
    source_save_action_send(fixture, cell, SourcePane(ReplaceAll))
    assert_eq(cell.val.source_pane.draft, "dog CAT dog")
    assert_eq(source_save_request_count(fixture), 0)
    source_save_action_send(fixture, cell, SourcePane(Save))
    guard @json.parse(source_save_http_requests(fixture)) is Array(requests) else {
      fail("Expected save request")
    }
    assert_eq(handoff_text(requests[0], "method"), "POST")
    assert_eq(
      handoff_text(requests[0], "url"),
      @desk.workspace_endpoint_url("book-demo", "source"),
    )
    assert_eq(
      handoff_field(requests[0], "body"),
      (
        {
          "path": "src/main.mbt",
          "content": "dog CAT dog",
          "expected_content": "cat CAT cat",
        } : Json),
    )
    let saving = cell.val.source_pane
    source_save_action_send(fixture, cell, SourcePane(ReplaceNext))
    assert_true(cell.val.source_pane == saving)
    ignore(
      source_save_http_resolve(
        fixture,
        0,
        200,
        source_save_test_success("dog CAT dog").stringify(),
      ).wait(),
    )
    assert_false(source_pane_dirty(cell.val.source_pane))
    source_save_action_send(
      fixture,
      cell,
      SourcePane(CloseBuffer("src/main.mbt")),
    )
    assert_true(cell.val.source_pane.content is Empty)
    source_save_action_send(
      fixture,
      cell,
      SourcePane(RequestSource("src/main.mbt")),
    )
    assert_eq(source_save_request_count(fixture), 2)
    let read = cell.val.source_pane
    assert_true(read.content is Loading)
    let preview = @desk.preview(
      @desk.file_entry(workspace_id="book-demo", path="src/main.mbt"),
      body="dog CAT dog",
    )
    ignore(
      source_save_http_resolve(fixture, 1, 200, preview.to_json().stringify()).wait(),
    )
    assert_eq(cell.val.source_pane.draft, "dog CAT dog")
    assert_false(source_pane_dirty(cell.val.source_pane))
  })
}
