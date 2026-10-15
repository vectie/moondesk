///|
test "Book switches restore independent work and drafts" {
  let dispatch : Dispatch[Msg] = fn(_) { @rabbita.none }
  let original = {
    ..quick_access_test_model(),
    workspace_mode: MoonWiki,
    selected_path: "raw/brief.md",
    current_directory: "raw",
    desk_filter_query: "brief",
    request_prompt: "Revise the conclusion",
    work_title: "Weekly brief",
    wiki_chat_file_paths: ["raw/source.pdf"],
    selected_mooncode_session_id: "session-a",
    mooncode_prompt: "Fix the menu",
  }
  let (_, other) = select_workspace_action(dispatch, "book-b", original)
  assert_eq(other.request_prompt, "")
  let (_, restored) = select_workspace_action(dispatch, "book-a", {
    ..other,
    request_prompt: "Different work",
  })
  assert_eq(restored.selected_path, "raw/brief.md")
  assert_eq(restored.current_directory, "raw")
  assert_eq(restored.desk_filter_query, "brief")
  assert_eq(restored.request_prompt, "Revise the conclusion")
  assert_eq(restored.work_title, "Weekly brief")
  assert_true(restored.wiki_chat_file_paths == ["raw/source.pdf"])
  assert_eq(restored.selected_mooncode_session_id, "session-a")
  assert_eq(restored.mooncode_prompt, "Fix the menu")
  let (_, other_again) = select_workspace_action(dispatch, "book-b", restored)
  assert_eq(other_again.request_prompt, "Different work")
}

///|
test "Reselecting a Book retains the current conversation draft" {
  let dispatch : Dispatch[Msg] = fn(_) { @rabbita.none }
  let (_, same) = select_workspace_action(dispatch, "book-a", {
    ..quick_access_test_model(),
    request_prompt: "Unsent",
  })
  assert_eq(same.request_prompt, "Unsent")
}

///|
test "Open file routes to its working view and returns to the file position" {
  let dispatch : Dispatch[Msg] = fn(_) { @rabbita.none }
  let model = {
    ..quick_access_test_model(),
    current_directory: "raw",
    desk_filter_query: "brief",
  }
  let (_, opened) = update(dispatch, OpenWorkFile("raw/brief.md"), model)
  assert_true(opened.workspace_mode == MoonWiki)
  assert_eq(opened.selected_path, "raw/brief.md")
  assert_true(opened.wiki_chat_file_paths.contains("raw/brief.md"))
  let (_, returned) = update(dispatch, ReturnToWork, opened)
  assert_true(returned.workspace_mode == Desk)
  assert_eq(returned.current_directory, "raw")
  assert_eq(returned.desk_filter_query, "brief")
  assert_eq(returned.selected_path, "")
  assert_true(work_file_mode("src/main.mbt") == MoonCode)
  assert_true(work_file_mode("outputs/report.html") == MoonWiki)
  assert_true(work_file_mode("raw/brief.pdf") == MoonWiki)
}

///|
test "Task draft selects its view without submitting work" {
  let dispatch : Dispatch[Msg] = fn(_) { @rabbita.none }
  let (_, code) = update_workspace_features(
    dispatch,
    workspace_feature_msg(
      "draft-task",
      first="Fix menu spacing",
      second="code",
      third="Fix a bug",
    ),
    quick_access_test_model(),
  )
  assert_true(code.workspace_mode == MoonCode)
  assert_eq(code.mooncode_prompt, "Fix menu spacing")
  assert_eq(code.selected_mooncode_session_id, "")
  let (_, book) = update_workspace_features(
    dispatch,
    workspace_feature_msg(
      "draft-task",
      first="Write a brief",
      second="document",
      third="Weekly brief",
    ),
    quick_access_test_model(),
  )
  assert_true(book.workspace_mode == MoonWiki)
  assert_eq(book.request_prompt, "Write a brief")
  assert_eq(book.wiki_agent_task_id, "")
}

///|
test "Resume restores a plain document alongside its conversation and unsent draft" {
  let dispatch : Dispatch[Msg] = fn(_) { @rabbita.none }
  let (_, restored) = restore_wiki_chat_thread(
    dispatch,
    quick_access_test_model(),
    "report-task",
    "outputs/report.md",
    "[{\"role\":\"user\",\"content\":\"Write report\"}]",
    position_text="{\"title\":\"Weekly report\",\"prompt\":\"Revise conclusion\",\"files\":[\"sources/revenue.csv\"],\"directory\":\"outputs\",\"filter\":\"report\"}",
  )
  assert_true(restored.workspace_mode == MoonWiki)
  assert_eq(restored.selected_path, "outputs/report.md")
  assert_eq(restored.wiki_agent_task_id, "report-task")
  assert_eq(restored.work_title, "Weekly report")
  assert_eq(restored.request_prompt, "Revise conclusion")
  assert_true(restored.wiki_chat_file_paths == ["sources/revenue.csv"])
  assert_eq(restored.current_directory, "outputs")
  assert_eq(restored.desk_filter_query, "report")
}

///|
test "Book document editing exposes save and cancel beside the draft" {
  let dispatch : Dispatch[Msg] = fn(_) { @rabbita.none }
  let model = {
    ..quick_access_test_model(),
    workspace_mode: MoonWiki,
    selected_path: "inbox/report.md",
    markdown_editor_path: "inbox/report.md",
    markdown_editor_content: "Revised report",
    markdown_editor_original: "Original report",
  }
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_wiki_document_viewer(dispatch, model)),
  )
  assert_true(markup.contains("aria-label=\"Save document\""))
  assert_true(markup.contains("aria-label=\"Cancel editing\""))
  assert_true(markup.contains("data-markdown-action=\"save\""))
}
