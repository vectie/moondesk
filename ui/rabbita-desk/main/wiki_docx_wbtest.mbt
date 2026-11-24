///|
test "Wiki DOCX edits prose across runs and multiple paragraphs in one save" {
  let first = {
    ..office_test_item("p0", "r0", 0, 0),
    text: "Hello ",
    bold: true,
  }
  let second = {
    ..office_test_item("p0", "r1", 0, 1),
    text: "world😀",
    italic: true,
  }
  let third = {
    ..office_test_item("p1", "r0", 1, 0),
    text: "Second paragraph",
  }
  let initial = office_test_state(OfficeDocx, first)
  let document = {
    ..initial.document.unwrap(),
    path: "thesis.docx",
    items: [first, second, third],
  }
  let state = {
    ..initial,
    document: Some(document),
    path: document.path,
    draft_items: document.items,
    document_editing: true,
  }
  let edited = update_office_editor(
    state,
    OfficeEditParagraph(0, "Hello reader😀"),
  )
  assert_eq(edited.draft_items.map(item => item.text), [
    "Hello ", "reader😀", "Second paragraph",
  ])
  assert_true(edited.draft_items[0].bold)
  assert_true(edited.draft_items[1].italic)
  let edited = update_office_editor(
    edited,
    OfficeEditParagraph(1, "Second revision"),
  )
  let payload = office_editor_save_body(edited)
  assert_eq(json_field_string(payload, "operation", default=""), "docx-text")
  guard payload is { "edits": Array(edits), .. } else {
    fail("expected changes")
  }
  assert_eq(edits.length(), 2)
  assert_true(update_office_editor(edited, OfficeSave).saving)
  let cancelled = update_office_editor(edited, OfficeCancelDocumentEdit)
  assert_false(office_editor_dirty(cancelled))
  assert_false(cancelled.document_editing)
  let pending = update_office_editor(state, OfficeDocumentPending(true))
  assert_true(office_editor_dirty(pending))
  assert_eq(pending.draft_items, document.items)
  let committed = update_office_editor(
    pending,
    OfficeCommitDocument([(0, "New body text"), (1, "Second change")]),
  )
  assert_true(committed.saving)
  assert_false(committed.document_pending)
  assert_eq(
    committed.draft_items
    .filter(item => item.section_index == 0)
    .map(item => item.text)
    .join(""),
    "New body text",
  )
  assert_false(
    office_editor_dirty(update_office_editor(pending, OfficeCancelDocumentEdit)),
  )
  let markup = render_test_dom(
    @rabbita.static_cell(
      render_wiki_document_viewer(office_view_test_dispatch, {
        ..init_model(),
        selected_path: "thesis.docx",
        office_editor: edited,
      }),
    ),
  )
  assert_true(markup.contains("wiki-docx-document"))
  assert_true(markup.contains("wiki-docx-save"))
  assert_false(markup.contains("office-nav-item"))
  assert_false(markup.contains("Structured Office editor"))
  let model = {
    ..init_model(),
    workspace_mode: MoonWiki,
    selected_path: "thesis.docx",
    office_editor: edited,
  }
  let (_, blocked) = update_navigation_actions(
    office_view_test_dispatch,
    SelectWorkspaceMode(MoonCode),
    model,
  )
  assert_true(blocked.workspace_mode is MoonWiki)
  assert_eq(blocked.office_editor.draft_items, edited.draft_items)
}

///|
test "prose replacement handles insertion deletion and Unicode without changing sibling text" {
  let item = { ..office_test_item("p0", "r0", 0, 0), text: "甲😀乙", }
  let initial = {
    ..office_test_state(OfficeDocx, item),
    document_editing: true,
  }
  for
    text in [
      "甲😎乙", "甲😀新增乙", "", "😀", "甲😀乙suffix", "prefix甲😀乙",
    ] {
    let next = update_office_editor(initial, OfficeEditParagraph(0, text))
    assert_eq(next.draft_items[0].text, text)
  }
}
