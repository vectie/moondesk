///|
fn assert_mobile_action_before(
  markup : String,
  first : String,
  second : String,
) -> Unit raise {
  guard markup.find(first) is Some(first_index) else {
    fail("Missing first action: " + first)
  }
  guard markup.find(second) is Some(second_index) else {
    fail("Missing second action: " + second)
  }
  assert_true(first_index < second_index)
}

///|
fn mobile_action_markup(model : Model) -> String {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  render_test_dom(@rabbita.static_cell(render_desk_mode(dispatch, model)))
}

///|
test "empty library starts with creation import and receive before file tools" {
  let model = cold_start_test_model(false, "/tmp/moonsuite/books", [])
  let markup = mobile_action_markup(model)
  for
    control in [
      "data-testid=\"desk-create-book\"", "data-testid=\"desk-import-book-folder\"",
      "data-testid=\"desk-import-book-archive\"", "data-testid=\"agent-import-choose\"",
    ] {
    assert_mobile_action_before(markup, control, "data-testid=\"desk-back\"")
    assert_mobile_action_before(
      markup, control, "data-testid=\"moongate-summary\"",
    )
  }
  assert_mobile_action_before(
    markup, "data-testid=\"desk-book-controls\"", "class=\"desk-browser\"",
  )
  assert_mobile_action_before(
    markup, "class=\"desk-browser\"", "data-testid=\"desk-details\"",
  )
  assert_mobile_action_before(
    markup, "data-testid=\"desk-cold-start\"", "data-testid=\"desk-add-moonbook\"",
  )
}

///|
test "multiple Books put switching and add controls before optional setup and file tools" {
  let model = {
    ..cold_start_test_model(false, "/tmp/moonsuite/books", [
      cold_start_test_workspace("book-a"),
      cold_start_test_workspace("book-b"),
    ]),
    selected_workspace_id: "book-b",
  }
  let markup = mobile_action_markup(model)
  assert_mobile_action_before(
    markup, "data-workspace-id=\"book-a\"", "data-workspace-id=\"book-b\"",
  )
  assert_mobile_action_before(
    markup, "data-workspace-id=\"book-b\"", "data-testid=\"desk-add-moonbook\"",
  )
  assert_mobile_action_before(
    markup, "data-testid=\"desk-add-moonbook\"", "data-testid=\"desk-library-storage-details\"",
  )
  assert_mobile_action_before(
    markup, "data-testid=\"desk-add-moonbook\"", "data-testid=\"moongate-summary\"",
  )
  assert_mobile_action_before(
    markup, "data-testid=\"desk-add-moonbook\"", "data-testid=\"desk-back\"",
  )
  assert_true(markup.contains("aria-pressed=\"true\""))
  assert_false(markup.contains("tabindex=\"1\""))
}

///|
test "secondary Book diagnostics remain collapsed while first creation is open" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = cold_start_test_model(false, "/tmp/moonsuite/books", [])
  let diagnostics = render_test_dom(
    @rabbita.static_cell(render_desk_library_diagnostics(dispatch, model)),
  )
  assert_false(diagnostics.contains(" open>"))
  let closed_add = render_test_dom(
    @rabbita.static_cell(render_new_moonbook_panel(dispatch, model)),
  )
  assert_false(closed_add.contains(" open>"))
  let first_add = render_test_dom(
    @rabbita.static_cell(render_new_moonbook_panel_open(dispatch, model)),
  )
  assert_true(first_add.contains(" open>"))
  assert_eq(first_add.split(" open>").count(), 2)
}

///|
test "Book loading and recovery remain ahead of collapsed diagnostics" {
  for
    model in [
      init_model(),
      cold_start_test_model(false, "", []),
      {
        ..cold_start_test_model(false, "/tmp/moonsuite/books", []),
        workspace_catalog_state: Some(RecoverableError),
        workspace_catalog_error: "catalog request failed",
      },
    ] {
    let markup = mobile_action_markup(model)
    assert_mobile_action_before(
      markup, "data-testid=\"desk-cold-start\"", "data-testid=\"desk-library-storage-details\"",
    )
    assert_true(markup.contains(desk_empty_library_title(model)))
    assert_true(markup.contains(desk_empty_library_message(model)))
    assert_false(markup.contains("data-testid=\"desk-add-moonbook\""))
  }
  let unavailable = mobile_action_markup(cold_start_test_model(false, "", []))
  assert_true(unavailable.contains("Choose library folder"))
  let failed = mobile_action_markup({
    ..cold_start_test_model(false, "/tmp/moonsuite/books", []),
    workspace_catalog_state: Some(RecoverableError),
  })
  assert_true(failed.contains("Refresh"))
}

///|
test "document original action remains available without exposing living artifacts" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  for
    path in [
      "documents/report.pdf", "documents/report.docx", "documents/report.xlsx", "documents/report.pptx",
    ] {
    let model = {
      ..init_model(),
      selected_workspace_id: "book-demo",
      selected_path: path,
    }
    let markup = render_test_dom(
      @rabbita.static_cell(render_wiki_document_viewer(dispatch, model)),
    )
    assert_true(markup.contains("data-testid=\"wiki-open-original\""))
    assert_true(markup.contains("Open original"))
    assert_true(markup.contains("/api/workspaces/book-demo/raw?"))
  }
  let living = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "book/site/generated/living/decisions/index.html",
  }
  let markup = render_test_dom(
    @rabbita.static_cell(render_wiki_document_viewer(dispatch, living)),
  )
  assert_false(markup.contains("data-testid=\"wiki-open-original\""))
  assert_false(markup.contains("Open original"))
  assert_true(markup.contains("sandbox=\"allow-scripts\""))
}
