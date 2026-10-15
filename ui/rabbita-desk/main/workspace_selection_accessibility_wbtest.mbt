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
  assert_true(markup.contains("aria-label=\"Chat with Alpha\""))
  assert_true(markup.contains("aria-label=\"Start a task with Alpha\""))
  assert_true(markup.contains("aria-label=\"Chat with Beta\""))
  assert_true(markup.contains("aria-label=\"Start a task with Beta\""))
}

///|
test "MoonBook chat selects the clicked book and opens its chat in one action" {
  let (_, opened) = update(
    code_mode_test_dispatch,
    OpenMoonBook("book-beta", Chat),
    {
      ..init_model(),
      workspace_mode: Desk,
      selected_workspace_id: "book-alpha",
      selected_path: "wiki/alpha.md",
      wiki_chat_entries: [{ role: "user", content: "Alpha history", }],
    },
  )
  assert_eq(opened.selected_workspace_id, "book-beta")
  assert_true(opened.workspace_mode is MoonWiki)
  assert_true(opened.wiki_chat_entries.is_empty())
  assert_false(opened.selected_path == "wiki/alpha.md")
}

///|
test "opening actions on the current MoonBook preserves its chat and file context" {
  let base = {
    ..init_model(),
    workspace_mode: Desk,
    selected_workspace_id: "book-alpha",
    selected_path: "wiki/notes.md",
    wiki_chat_entries: [{ role: "user", content: "Keep this conversation", }],
  }
  for action in [Chat, StartTask] {
    let (_, opened) = update(
      code_mode_test_dispatch,
      OpenMoonBook("book-alpha", action),
      base,
    )
    assert_eq(opened.selected_workspace_id, "book-alpha")
    assert_eq(opened.wiki_chat_entries.length(), 1)
    assert_eq(opened.selected_path, "wiki/notes.md")
  }
  let (_, task) = update(
    code_mode_test_dispatch,
    OpenMoonBook("book-beta", StartTask),
    base,
  )
  assert_eq(task.selected_workspace_id, "book-beta")
  assert_true(task.workspace_mode is Desk)
  assert_eq(task.wiki_agent_task_id, "")
}

///|
test "MoonBook actions retain the existing unsaved document navigation behavior" {
  for action in [Chat, StartTask] {
    let (_, pending) = update_navigation_actions(
      code_mode_test_dispatch,
      OpenMoonBook("book-beta", action),
      {
        ..init_model(),
        workspace_mode: Desk,
        selected_workspace_id: "book-alpha",
        markdown_editor_path: "wiki/notes.md",
        markdown_editor_content: "Unsaved draft",
      },
    )
    assert_eq(pending.selected_workspace_id, "book-alpha")
    assert_true(
      pending.pending_markdown_navigation ==
      PendingMoonBookAction("book-beta", action),
    )
    let (_, confirmed) = update_navigation_actions(
      code_mode_test_dispatch,
      ConfirmDiscardMarkdownNavigation,
      pending,
    )
    assert_eq(confirmed.selected_workspace_id, "book-beta")
  }
}

///|
test "a deferred book switch cannot open chat in the previous MoonBook" {
  let (_, opened) = update_navigation_actions(
    code_mode_test_dispatch,
    OpenMoonBook("book-beta", Chat),
    {
      ..init_model(),
      workspace_mode: Desk,
      selected_workspace_id: "book-alpha",
      git_review_note: "Unsent review note",
    },
  )
  assert_eq(opened.selected_workspace_id, "book-alpha")
  assert_true(opened.workspace_mode is Desk)
}

///|
test "MoonBook search filters the single library without changing selection" {
  let base = {
    ..init_model(),
    selected_workspace_id: "book-alpha",
    workspaces: [
      @desk.workspace(
        id="book-alpha",
        name="Research",
        root_path="/tmp/books/alpha",
        kind=MoonBook,
      ),
      @desk.workspace(
        id="book-beta",
        name="Planning",
        root_path="/tmp/books/beta",
        kind=MoonBook,
      ),
    ],
  }
  for query in [" RESEARCH ", "book-alpha", "alpha"] {
    let (_, filtered) = update(
      code_mode_test_dispatch,
      SetMoonBookQuery(query),
      base,
    )
    assert_eq(matching_moonbooks(filtered).length(), 1)
    assert_eq(matching_moonbooks(filtered)[0].id, "book-alpha")
    assert_eq(filtered.workspaces.length(), 2)
    assert_eq(filtered.selected_workspace_id, "book-alpha")
  }
  assert_true(
    matching_moonbooks({ ..base, moonbook_query: "nonexistent", }).is_empty(),
  )
  assert_eq(matching_moonbooks(base).length(), 2)
}
