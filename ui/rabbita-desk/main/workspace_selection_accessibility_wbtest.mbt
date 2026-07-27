///|
#warnings("-alert_unstable")
test "MoonBook rows expose exactly one semantic selection" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_desk_workspace_sidebar(dispatch, {
        ..init_model(),
        selected_workspace_id: "book-alpha",
        workspaces: [
          @desk.workspace(
            id="book-alpha",
            name="Alpha",
            root_path="/tmp/books/alpha",
            kind=MoonBook,
          ),
          @desk.workspace(
            id="book-beta",
            name="Beta",
            root_path="/tmp/books/beta",
            kind=MoonBook,
          ),
        ],
      }),
    ),
  )
  assert_eq(markup.split("aria-pressed=\"true\"").length(), 2)
  assert_eq(markup.split("aria-pressed=\"false\"").length(), 2)
  assert_true(markup.contains("desk-workspace-row active status-ready"))
  assert_true(markup.contains("data-workspace-id=\"book-alpha\""))
  assert_true(markup.contains("data-workspace-id=\"book-beta\""))
  assert_true(markup.contains(">Alpha</strong>"))
  assert_true(markup.contains(">Beta</strong>"))
}
