///|
test "synthesis submits provenance paths to the general chat" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let base = { ..init_model(), selected_workspace_id: "book-demo" }
  let (_, submitted) = update_workspace_features(
    dispatch,
    workspace_feature_msg(
      "start-synthesis",
      first="brief",
      second="Evidence brief",
      third="wiki/a.md\nwiki/b.md",
    ),
    base,
  )
  let prompt = submitted.request_prompt
  assert_true(prompt.contains("@wiki/a.md"))
  assert_eq(submitted.wiki_chat_file_paths, ["wiki/a.md", "wiki/b.md"])
  assert_true(prompt.contains("Preserve source links"))
  assert_true(prompt.contains("actionable warnings"))
}

///|
test "synthesis accepts pinned answer excerpts without treating them as files" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let base = { ..init_model(), selected_workspace_id: "book-demo" }
  let (_, submitted) = update_workspace_features(
    dispatch,
    workspace_feature_msg(
      "start-synthesis",
      first="brief",
      second="Answer brief",
      third="note:A concise answer with evidence\nwiki/source.md",
    ),
    base,
  )
  assert_eq(submitted.wiki_chat_file_paths, ["wiki/source.md"])
  assert_true(submitted.request_prompt.contains("Pinned conversation excerpts"))
  assert_true(
    submitted.request_prompt.contains("A concise answer with evidence"),
  )
}

///|
test "document conversation archive restores only visible entries and task cursor" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let base = { ..init_model(), selected_workspace_id: "book-demo" }
  let (_, restored) = update_workspace_features(
    dispatch,
    workspace_feature_msg(
      "restore-thread",
      first="task-visible-1",
      second="",
      third="[{\"role\":\"user\",\"content\":\"Check this\"},{\"role\":\"assistant\",\"content\":\"No warning found\"}]",
    ),
    base,
  )
  assert_eq(restored.wiki_agent_task_id, "task-visible-1")
  assert_eq(restored.wiki_chat_entries.length(), 2)
  assert_eq(restored.wiki_chat_entries[1].content, "No warning found")
  assert_eq(restored.wiki_chat_stream_cursor, "start")
}

///|
test "workspace bridge projects transcript changes without duplicating content" {
  let model = {
    ..init_model(),
    selected_path: "documents/report.docx",
    wiki_chat_entries: [
      { role: "user", content: "Check this" },
      { role: "assistant", content: "No warning found" },
    ],
  }
  let text = workspace_features_state_payload(model).stringify()
  assert_true(text.contains("chat_count"))
  assert_true(text.contains("chat_tail_role"))
  assert_true(text.contains("chat_tail_bytes"))
  assert_true(text.contains("documents/report.docx"))
  assert_false(text.contains("No warning found"))
  assert_false(text.to_lower().contains("reasoning"))
}

///|
#warnings("-alert_unstable")
test "Find and Add and quiet work center render as accessible product surfaces" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = init_model()
  let search_markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_workspace_feature_overlays(dispatch, model)),
  )
  assert_true(
    search_markup.contains("data-testid=\"workspace-feature-overlays\""),
  )
  let state = workspace_features_state_payload(model).stringify()
  assert_true(state.contains("workspace"))
  assert_true(state.contains("recent_paths"))
  assert_true(state.contains("\"search_state\""))
  assert_true(state.contains("\"first-use-empty\""))
  assert_true(state.contains("task_id"))
  assert_true(state.contains("office"))
  let work_markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_quiet_work_center(dispatch, model)),
  )
  assert_true(work_markup.contains("data-testid=\"quiet-work-center\""))
  assert_true(work_markup.contains("Export Work Package"))
}

///|
#warnings("-alert_unstable")
test "automation cards explain scope, policy, cadence, and manual run" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let goal : StandingGoalRecord = @json.from_json({
    "id": "goal-1",
    "title": "Watch reports",
    "prompt": "Check approved reports for material changes",
    "target_book_id": "book-demo",
    "cadence_ticks": 60,
    "next_due_tick": 120,
    "last_run_tick": null,
    "enabled": true,
    "source_policy": "approved-sites",
    "review_policy": "bookkeeper-review",
  })
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_automation_card(dispatch, goal)),
  )
  assert_true(markup.contains("data-testid=\"automation-card-host\""))
  assert_true(markup.contains("approved-sites"))
  assert_true(markup.contains("Watch reports"))
}

///|
test "background results append once and reject malformed events" {
  let base = {
    ..init_model(),
    wiki_chat_entries: [{ role: "user", content: "Watch this workbook" }],
  }
  let payload = "[{\"contract\":\"moondesk.document_automation_result.v1\",\"kind\":\"background_result\",\"id\":\"result-1\",\"status\":\"Completed\",\"title\":\"Workbook check complete\"},{\"contract\":\"unexpected\",\"kind\":\"background_result\",\"id\":\"bad\"}]"
  let (_, appended) = append_wiki_chat_background_results(base, payload)
  assert_eq(appended.wiki_chat_entries.length(), 2)
  assert_eq(appended.wiki_chat_entries[1].role, "background_result")
  assert_true(appended.wiki_chat_entries[1].content.contains("result-1"))
  let (_, deduplicated) = append_wiki_chat_background_results(appended, payload)
  assert_eq(deduplicated.wiki_chat_entries.length(), 2)
}

///|
#warnings("-alert_unstable")
test "PDF preview uses the bounded workspace viewer surface" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let path = "documents/report.pdf"
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: path,
    preview: Some(
      @desk.preview(@desk.file_entry(workspace_id="book-demo", path~), body=""),
    ),
  }
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_preview_center(dispatch, model)),
  )
  assert_true(markup.contains("data-testid=\"pdf-preview-frame\""))
  assert_true(markup.contains("data-source-path=\"documents/report.pdf\""))
  assert_true(markup.contains("/api/workspaces/book-demo/raw?"))
  assert_false(markup.contains("file://"))
  assert_true(wiki_document_path_supported(path))
  assert_eq(wiki_document_kind_label(path), Some("PDF"))
  assert_eq(
    json_field_string(
      wiki_chat_submission_body(model),
      "document_path",
      default="",
    ),
    path,
  )
}
