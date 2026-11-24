///|
test "initial code file opens only after its known Book loads" {
  let previous = {
    ..init_model(),
    workspace_mode: MoonCode,
    loading: true,
    selected_workspace_id: "book-research",
    selected_path: "wiki/slides/pages/01.page",
    source_pane: init_source_pane("book-research", ""),
  }
  let ready = {
    ..previous,
    loading: false,
    workspaces: [requested_selection_test_workspace("book-research")],
  }
  let (_, opened) = open_initial_code_file(
    code_mode_test_dispatch, previous, ready,
  )
  assert_eq(opened.source_pane.requested_path, "wiki/slides/pages/01.page")
  assert_true(opened.source_pane.content is Loading)
  let (_, refreshed) = open_initial_code_file(
    code_mode_test_dispatch, ready, opened,
  )
  assert_eq(refreshed.source_pane, opened.source_pane)
  let (_, missing) = open_initial_code_file(code_mode_test_dispatch, previous, {
    ..ready,
    workspaces: [],
  })
  assert_true(missing.source_pane.content is Empty)
}

///|
test "initial Office file opens its real structured editor, never an empty text buffer" {
  let previous = {
    ..init_model(),
    workspace_mode: MoonCode,
    loading: true,
    selected_workspace_id: "book-research",
    selected_path: "wiki/proposal.docx",
    source_pane: init_source_pane("book-research", ""),
  }
  let ready = {
    ..previous,
    loading: false,
    workspaces: [requested_selection_test_workspace("book-research")],
  }
  let (_, opened) = open_initial_code_file(
    code_mode_test_dispatch, previous, ready,
  )
  assert_eq(opened.office_editor.path, "wiki/proposal.docx")
  assert_true(opened.office_editor.loading)
  assert_true(opened.workspace_mode is MoonWiki)
  assert_true(opened.source_pane.content is Empty)
  let markup = render_test_dom(
    @rabbita.static_cell(
      render_mooncode_workspace_editors(code_mode_test_dispatch, opened),
    ),
  )
  assert_true(markup.contains("data-testid=\"office-editor\""))
  assert_true(!markup.contains("data-testid=\"source-editor\""))
}
