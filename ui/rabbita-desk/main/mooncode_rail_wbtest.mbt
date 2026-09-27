///|
test "Code rail folds empty unselected MoonBooks without hiding the selected book" {
  let model = {
    ..init_model(),
    selected_workspace_id: "book-a",
    workspaces: [
      @desk.workspace(
        id="book-a",
        name="Book A",
        root_path="/tmp/moonsuite/books/book-a",
        kind=MoonBook,
      ),
      @desk.workspace(
        id="book-b",
        name="Book B",
        root_path="/tmp/moonsuite/books/book-b",
        kind=MoonBook,
      ),
    ],
  }
  let children = mooncode_session_list_children(code_mode_test_dispatch, model)
  assert_true(children.get("group:workspace:book-a") is Some(_))
  assert_true(children.get("group:workspace:book-b") is None)
  assert_true(children.get("other-books") is Some(_))
  let searching = {
    ..model,
    mooncode_session_query: "Book B",
    mooncode_sessions: [
      {
        ..code_mode_test_session("book-b-chat", workspace_id="book-b"),
        title: "Book B",
      },
    ],
  }
  let search_children = mooncode_session_list_children(
    code_mode_test_dispatch, searching,
  )
  assert_true(search_children.get("group:workspace:book-b") is Some(_))
  assert_true(search_children.get("other-books") is None)
}

///|
test "Code rail names completed and stopped sessions by outcome" {
  let completed = {
    ..code_mode_test_session("finished", workspace_id="book-a"),
    status: "done",
  }
  let stopped = { ..completed, status: "cancelled", }
  assert_eq(mooncode_session_status_line(completed), "Completed")
  assert_eq(
    mooncode_session_status_i18n_key(completed),
    "code.session_completed",
  )
  assert_eq(mooncode_session_status_line(stopped), "Stopped")
  assert_eq(mooncode_session_status_i18n_key(stopped), "code.session_stopped")
}
