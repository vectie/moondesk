///|
test "wiki navigation uses normal user language and compatible slugs" {
  let items = activities()
  assert_eq(items.length(), 4)
  assert_eq(items[0].label, "Pages")
  assert_eq(items[1].label, "Search")
  assert_eq(items[2].label, "Inbox")
  assert_eq(items[3].label, "Settings")
  assert_true(activity_from_slug("library") is Files)
  assert_true(activity_from_slug("files") is Files)
  assert_true(activity_from_slug("activity") is Town)
  assert_true(activity_from_slug("town") is Town)
  assert_true(activity_from_slug("review") is Runs)
  assert_true(activity_from_slug("runs") is Runs)
  assert_true(activity_from_slug("more") is Settings)
  assert_true(activity_from_slug("settings") is Settings)
  assert_eq(activity_slug(Files), "library")
  assert_eq(activity_slug(Town), "activity")
  assert_eq(activity_slug(Runs), "review")
  assert_eq(activity_slug(Settings), "more")
}

///|
test "wiki library overview keeps operational roots out of the default tree" {
  assert_true(wiki_library_overview_path_visible("wiki"))
  assert_true(wiki_library_overview_path_visible("raw"))
  assert_true(wiki_library_overview_path_visible("inbox"))
  assert_true(wiki_library_overview_path_visible("book/site/generated"))
  assert_false(wiki_library_overview_path_visible(".moonbook"))
  assert_false(wiki_library_overview_path_visible("keeper"))
  assert_false(wiki_library_overview_path_visible("moonclaw.json"))
  assert_false(wiki_library_overview_path_visible("skills"))
}

///|
#warnings("-alert_unstable")
test "wiki tree exposes stable path hooks for executable user journeys" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_tree(dispatch, {
        ..init_model(),
        selected_workspace_id: "book-demo",
        current_directory: "inbox",
        entries: [
          @desk.file_entry(
            workspace_id="book-demo",
            path="inbox/note-durable.md",
          ),
        ],
      }),
    ),
  )
  assert_true(markup.contains("data-testid=\"wiki-tree-row\""))
  assert_true(markup.contains("data-path=\"inbox/note-durable.md\""))
}

///|
test "wiki empty-book detection uses successful typed listing evidence" {
  let empty_book = {
    ..init_model(),
    selected_workspace_id: "book-empty",
    current_directory: "",
    selected_path: "",
    entries: [],
    preview: None,
    desk_entries_state: Some(LegitimateZero),
  }
  assert_true(wiki_book_is_empty(empty_book))
  assert_false(
    wiki_book_is_empty({ ..empty_book, desk_entries_state: Some(Loading) }),
  )
  assert_false(
    wiki_book_is_empty({
      ..empty_book,
      desk_entries_state: Some(RecoverableError),
    }),
  )
  assert_false(
    wiki_book_is_empty({
      ..empty_book,
      entries: [
        @desk.file_entry(workspace_id="book-empty", path="wiki/index.md"),
      ],
    }),
  )
}

///|
test "wiki capture and task composers start without accidental content" {
  let model = init_model()
  assert_eq(model.inbox_content, "")
  assert_eq(model.request_prompt, "")
  assert_eq(model.request_material_paths.length(), 0)
}

///|
fn wiki_focus_test_model(warnings : Array[String]) -> Model {
  let item : OfficeEditorItem = {
    section: "paragraph 0",
    reference: "run 0",
    section_index: 0,
    item_index: 0,
    text: "A document beside the conversation.",
    formula: "",
    bold: false,
    italic: false,
    underline: false,
    x: 0,
    y: 0,
    width: 100,
    height: 40,
  }
  let document : OfficeEditorDocument = {
    path: "documents/brief.docx",
    kind: OfficeDocx,
    items: [item],
    warnings,
    baseline: "baseline",
  }
  {
    ..init_model(),
    workspace_mode: MoonWiki,
    activity: Town,
    selected_workspace_id: "book-demo",
    selected_path: document.path,
    office_editor: {
      ..init_office_editor("book-demo"),
      path_input: document.path,
      path: document.path,
      document: Some(document),
      draft_items: document.items,
      status: "Opened supported Office subset",
      saved_baseline: document.baseline,
    },
  }
}

///|
#warnings("-alert_unstable")
test "Wiki is a quiet chat and Office viewer without operator navigation" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_wiki_focus_workspace(dispatch, wiki_focus_test_model([])),
    ),
  )
  assert_true(markup.contains("aria-label=\"Document chat\""))
  assert_true(markup.contains("data-testid=\"wiki-chat-input\""))
  assert_true(markup.contains("aria-label=\"Document viewer\""))
  assert_true(markup.contains("data-testid=\"office-docx-preview\""))
  assert_false(markup.contains("data-testid=\"wiki-warning-popup\""))
  assert_false(markup.contains("activity-rail"))
  assert_false(markup.contains("Automations"))
  assert_false(markup.contains("stage"))
  assert_false(markup.contains("MoonClaw"))
  assert_false(markup.contains("MoonCode"))
}

///|
#warnings("-alert_unstable")
test "Wiki interrupts only when the document reports a warning" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let warning = "A linked chart could not be validated."
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_wiki_focus_workspace(dispatch, wiki_focus_test_model([warning])),
    ),
  )
  assert_true(markup.contains("data-testid=\"wiki-warning-popup\""))
  assert_true(markup.contains("role=\"alert\""))
  assert_true(markup.contains("Needs attention"))
  assert_true(markup.contains(warning))
}

///|
test "Wiki does not interrupt for preserved Office compatibility notes" {
  let model = wiki_focus_test_model([
    "Supported subset only. Unsupported package members are preserved.",
  ])
  assert_true(wiki_document_warnings(model) == [])
}

///|
test "Wiki Office open path stages a supported viewer request" {
  let state = update_office_editor(
    init_office_editor("book-demo"),
    OfficeOpenPath("documents/forecast.xlsx"),
  )
  assert_true(state.loading)
  assert_eq(state.path, "documents/forecast.xlsx")
  assert_eq(state.path_input, "documents/forecast.xlsx")
  assert_eq(state.request_generation, 1)
}

///|
test "Wiki chat submits document context to the general agent endpoint" {
  let model = {
    ..wiki_focus_test_model([]),
    request_prompt: "Check the totals and improve the conclusion.",
    wiki_agent_task_id: "task-general-1",
    wiki_chat_file_paths: ["documents/forecast.xlsx"],
  }
  let body = wiki_chat_submission_body(model)
  assert_eq(@desk.moonclaw_endpoint_url("chat"), "/api/moonclaw/chat")
  assert_eq(json_field_string(body, "workspace_id", default=""), "book-demo")
  assert_eq(
    json_field_string(body, "document_path", default=""),
    "documents/brief.docx",
  )
  assert_eq(json_field_string(body, "task_id", default=""), "task-general-1")
  assert_eq(json_field_string_array_items(body, "file_paths"), [
    "documents/forecast.xlsx",
  ])
  assert_false(body.stringify().contains("/v1/code"))
  assert_true(wiki_task_start_disabled({ ..model, request_status: "sending" }))
}

///|
test "Wiki chat attaches existing files and projects MoonClaw deltas" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..wiki_focus_test_model([]),
    selected_path: "documents/forecast.xlsx",
  }
  let (_, attached) = update_wiki_chat(
    dispatch,
    AttachWikiChatFile("documents/forecast.xlsx"),
    model,
  )
  assert_eq(attached.wiki_chat_file_paths, ["documents/forecast.xlsx"])
  let delta : Json = {
    "contract": "moonclaw-task-stream.v2",
    "kind": "answer_delta",
    "content": "Checking",
  }
  let (after_delta, done) = wiki_chat_apply_stream_event(attached, delta)
  assert_false(done)
  assert_eq(after_delta.wiki_chat_entries, [
    { role: "assistant-stream", content: "Checking" },
  ])
  let final_response : Json = {
    "contract": "moonclaw-task-stream.v2",
    "kind": "answer",
    "content": "Checked.",
  }
  let (after_final, done) = wiki_chat_apply_stream_event(
    after_delta, final_response,
  )
  assert_true(!done)
  assert_eq(after_final.wiki_chat_entries, [
    { role: "assistant", content: "Checked." },
  ])
  let (after_terminal, done) = wiki_chat_apply_stream_event(after_final, {
    "contract": "moonclaw-task-stream.v2",
    "kind": "terminal",
    "state": "complete",
  })
  assert_true(done)
  assert_eq(after_terminal.request_status, "complete")
}

///|
test "Wiki chat file mentions use a shared trigger grammar" {
  let trigger = ComposerTrigger::parse("Review the totals in @forecast")
  match trigger {
    Some(value) => {
      assert_eq(value.query, "forecast")
      assert_eq(value.draft_without_token, "Review the totals in ")
    }
    None => assert_true(false)
  }
  assert_true(ComposerTrigger::parse("embedded@word") is None)
  assert_false(wiki_chat_path_is_attachable("file:///tmp/report.xlsx"))
  assert_false(wiki_chat_path_is_attachable("../outside/report.xlsx"))
}

///|
test "Wiki chat file search rejects stale replies and scopes results to the book" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    wiki_chat_file_picker_open: true,
    wiki_chat_file_query: "forecast",
    wiki_chat_file_search_generation: 4,
  }
  let good : SearchHit = {
    workspace_id: "book-demo",
    workspace_name: "Demo",
    path: "documents/forecast.xlsx",
    title: "forecast.xlsx",
    kind: Artifact,
    source_layer: Wiki,
    snippet: "forecast totals",
  }
  let other : SearchHit = {
    ..good,
    workspace_id: "other-book",
    path: "documents/other.xlsx",
  }
  let response = pages_search_test_response(
    [good, other],
    query="forecast",
    workspace_id="",
  )
  let (_, loaded) = update_wiki_chat(
    dispatch,
    LoadedWikiChatFileSearch(4, Ok(response)),
    model,
  )
  assert_eq(loaded.wiki_chat_file_results.map(hit => hit.path), [
    "documents/forecast.xlsx",
  ])
  let (_, stale) = update_wiki_chat(
    dispatch,
    LoadedWikiChatFileSearch(3, Ok({ ..response, hits: [other] })),
    loaded,
  )
  assert_eq(stale.wiki_chat_file_results.map(hit => hit.path), [
    "documents/forecast.xlsx",
  ])
}

///|
#warnings("-alert_unstable")
test "Wiki chat renders file search and a non-importing drop target" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_wiki_focus_workspace(dispatch, {
        ..init_model(),
        selected_workspace_id: "book-demo",
        wiki_chat_file_picker_open: true,
        wiki_chat_file_query: "forecast",
        wiki_chat_file_search_status: "1 matching file",
        wiki_chat_file_results: [
          {
            workspace_id: "book-demo",
            workspace_name: "Demo",
            path: "documents/forecast.xlsx",
            title: "forecast.xlsx",
            kind: Artifact,
            source_layer: Wiki,
            snippet: "forecast totals",
          },
        ],
      }),
    ),
  )
  assert_true(markup.contains("data-testid=\"wiki-chat-file-picker\""))
  assert_true(markup.contains("data-testid=\"wiki-chat-file-search\""))
  assert_true(markup.contains("data-testid=\"wiki-chat-dropzone\""))
  assert_true(markup.contains("Nothing is imported"))
}

///|
#warnings("-alert_unstable")
test "Wiki chat keeps a general task conversation without exposing its id" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..wiki_focus_test_model([]),
    request_prompt: "Validate this presentation.",
  }
  let (_, next) = update_wiki_chat(
    dispatch,
    SubmittedWikiChat(
      "Validate this presentation.",
      Ok({
        task_id: "general-task-2",
        status: "generating",
        message: "working",
        queued: false,
        owner: "moonclaw-general-agent",
      }),
    ),
    model,
  )
  assert_eq(next.wiki_agent_task_id, "general-task-2")
  assert_eq(next.request_prompt, "")
  assert_true(
    next.wiki_chat_entries ==
    [{ role: "user", content: "Validate this presentation." }],
  )
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_wiki_focus_workspace(dispatch, next)),
  )
  assert_true(markup.contains("Validate this presentation."))
  assert_false(markup.contains("general-task-2"))
}

///|
#warnings("-alert_unstable")
test "Inbox note composer has stable accessible keyboard targets" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_inbox_pane(dispatch, init_model())),
  )
  assert_true(markup.contains("data-testid=\"wiki-inbox-title\""))
  assert_true(markup.contains("aria-label=\"Inbox note title\""))
  assert_true(markup.contains("data-testid=\"wiki-inbox-body\""))
  assert_true(markup.contains("aria-label=\"Inbox note body\""))
  assert_true(markup.contains("data-testid=\"wiki-save-note\""))
}

///|
test "wiki activity request collects current and imported materials once" {
  let current = @desk.preview(
    @desk.file_entry(workspace_id="book-demo", path="wiki/index.md"),
    body="# Index\n",
  )
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "wiki/index.md",
    preview: Some(current),
    request_material_paths: [
      "inbox/imports/source.md", "wiki/index.md", "inbox/imports/source.md",
    ],
  }
  assert_true(
    request_context_entries(model) ==
    ["wiki/index.md", "inbox/imports/source.md"],
  )
  assert_eq(request_material_count_label(model), "2 materials")
}

///|
test "wiki activity request body carries explicit book material context" {
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    request_prompt: "Build a concise field guide.\nUse source dates.",
    request_material_paths: ["inbox/imports/brief.md", "inbox/imports/table.md"],
  }
  let body = request_submission_body(model)
  assert_eq(
    json_field_string(body, "title", default=""),
    "Build a concise field guide.",
  )
  assert_eq(json_field_string(body, "target_book_id", default=""), "book-demo")
  assert_true(
    json_field_string_array_items(body, "context_entries") ==
    ["inbox/imports/brief.md", "inbox/imports/table.md"],
  )
}

///|
test "wiki activity blocks an empty request without losing materials" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    workspace_mode: MoonWiki,
    activity: Town,
    selected_workspace_id: "book-demo",
    request_material_paths: ["inbox/imports/source.md"],
  }
  let (_, next) = update_town_actions(dispatch, SubmitRequest, model)
  assert_true(next.request_material_paths == ["inbox/imports/source.md"])
  assert_eq(
    wiki_request_status_label(next.request_status),
    "Describe what you want this book to build.",
  )
  assert_true(wiki_task_start_disabled(next))
}

///|
test "wiki activity imports stay in activity and join the pending task" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    workspace_mode: MoonWiki,
    activity: Town,
    selected_workspace_id: "book-demo",
    selected_path: "wiki/index.md",
    request_material_paths: ["inbox/imports/earlier.md"],
    import_url: "https://example.com/report",
    import_note: "Use the tables.",
  }
  let (_, next) = update_inbox_results(
    dispatch,
    ImportedInbox(
      Ok({
        ok: true,
        workspace_id: "book-demo",
        path: "inbox/imports/report.md",
        kind: "url",
        data_path: "inbox/imports/report.data-url.txt",
      }),
    ),
    model,
  )
  assert_true(next.activity is Town)
  assert_eq(next.selected_path, "wiki/index.md")
  assert_true(
    next.request_material_paths ==
    ["inbox/imports/earlier.md", "inbox/imports/report.md"],
  )
  assert_eq(next.import_url, "")
  assert_eq(next.import_note, "")
  assert_eq(
    wiki_task_material_status(next.request_material_status),
    "Material added.",
  )
}

///|
test "wiki activity file picker opens without navigating to Inbox" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    workspace_mode: MoonWiki,
    activity: Town,
    selected_workspace_id: "book-demo",
    request_prompt: "Build a guide",
  }
  let (_, next) = update_inbox_actions(dispatch, ImportLocalFiles, model)
  assert_true(next.activity is Town)
  assert_eq(next.request_prompt, "Build a guide")
  assert_eq(
    wiki_task_material_status(next.request_material_status),
    "Choose files to add.",
  )
}

///|
test "wiki activity removes material and clears task state after submission" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    workspace_mode: MoonWiki,
    activity: Town,
    selected_workspace_id: "book-demo",
    request_prompt: "Build the guide",
    request_material_paths: ["inbox/a.md", "inbox/b.md"],
  }
  let (_, removed) = update_town_actions(
    dispatch,
    RemoveRequestMaterial("inbox/a.md"),
    model,
  )
  assert_true(removed.request_material_paths == ["inbox/b.md"])
  let record : RequestRecord = {
    id: "request-1",
    status: "staged",
    path: "requests/request-1.json",
    request: request_submission_body(removed),
  }
  let (_, submitted) = update_town_results(
    dispatch,
    SubmittedRequest(Ok(record)),
    removed,
  )
  assert_eq(submitted.request_prompt, "")
  assert_true(submitted.request_material_paths == [])
  assert_eq(submitted.request_material_status, "")
}

///|
test "wiki activity preserves description and materials when submission fails" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    workspace_mode: MoonWiki,
    activity: Town,
    selected_workspace_id: "book-demo",
    request_prompt: "Build the guide",
    request_material_paths: ["inbox/source.md"],
  }
  let (_, next) = update_town_results(
    dispatch,
    SubmittedRequest(Err("background service unavailable")),
    model,
  )
  assert_eq(next.request_prompt, "Build the guide")
  assert_true(next.request_material_paths == ["inbox/source.md"])
  assert_eq(
    wiki_request_status_label(next.request_status),
    "Could not start this task. Your request is still here.",
  )
}

///|
test "wiki preview populates Inbox only for an explicit Inbox edit" {
  let preview = @desk.preview(
    @desk.file_entry(workspace_id="book-demo", path="inbox/note.md"),
    body="# Note\n",
  )
  assert_false(should_load_preview_into_inbox(init_model(), preview))
  assert_true(
    should_load_preview_into_inbox(
      {
        ..init_model(),
        selected_path: "inbox/note.md",
        editing_inbox_path: "inbox/note.md",
      },
      preview,
    ),
  )
}

///|
test "wiki task projection translates runtime states" {
  assert_eq(wiki_task_state("queued"), "Waiting")
  assert_eq(wiki_task_state("runtime-running"), "Working")
  assert_eq(wiki_task_state("needs_review"), "Ready for review")
  assert_eq(wiki_task_state("accepted"), "Completed")
  assert_eq(wiki_task_state("failed"), "Needs attention")
  assert_eq(wiki_task_tone("failed"), "attention")
  assert_eq(wiki_task_tone("ready_for_review"), "review")
}

///|
test "wiki write feedback hides paths and transport language" {
  assert_eq(wiki_inbox_status_label("draft"), "Ready to save.")
  assert_eq(
    wiki_inbox_status_label("saved inbox/forward-seed.md"),
    "Saved to Inbox.",
  )
  assert_eq(
    wiki_inbox_status_label("Markdown edits must target inbox"),
    "Could not save. Your draft is still here.",
  )
  assert_eq(wiki_request_status_label("staging request"), "Waiting to start.")
  assert_eq(
    wiki_request_status_label("daemon unavailable"),
    "Could not start this task. Your request is still here.",
  )
}

///|
test "wiki editor feedback reports user save state" {
  let editing = {
    ..init_model(),
    markdown_editor_path: "wiki/index.md",
    markdown_editor_content: "# changed draft\n",
    markdown_editor_original: "",
    markdown_editor_status: "editing wiki/index.md",
  }
  assert_eq(wiki_editor_status_label(editing), "Unsaved changes")
  assert_eq(
    wiki_editor_status_label({
      ..editing,
      markdown_editor_content: "",
      markdown_editor_original: "",
    }),
    "Editing",
  )
  assert_eq(
    wiki_editor_status_label({
      ..editing,
      markdown_editor_status: "saving markdown",
    }),
    "Saving...",
  )
  assert_eq(
    wiki_editor_status_label({
      ..editing,
      markdown_editor_status: "saved wiki/index.md",
    }),
    "Saved",
  )
  assert_eq(
    wiki_editor_status_label({
      ..editing,
      markdown_editor_status: "write failed",
    }),
    "Could not save. Your draft is still here.",
  )
}

///|
test "wiki unsaved navigation names the edited page" {
  let model = { ..init_model(), markdown_editor_path: "wiki/notes/decision.md" }
  assert_eq(
    wiki_unsaved_navigation_message(model),
    "Your changes to decision.md have not been saved.",
  )
}

///|
test "wiki search presents useful types without source-layer labels" {
  let base : SearchHit = {
    workspace_id: "book-demo",
    workspace_name: "Demo",
    path: "wiki/index.md",
    title: "Index",
    kind: Markdown,
    source_layer: Wiki,
    snippet: "Overview",
  }
  assert_eq(wiki_search_type_label(base), "Page")
  assert_eq(
    wiki_search_type_label({
      ..base,
      path: "raw/source.pdf",
      source_layer: RawEvidence,
    }),
    "Original source",
  )
  assert_eq(
    wiki_search_type_label({
      ..base,
      path: "wiki/reviews/pending.md",
      source_layer: Review,
    }),
    "Review",
  )
}

///|
test "wiki search result opens in Wiki without switching to Desk" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    workspace_mode: MoonWiki,
    activity: Search,
    selected_workspace_id: "book-demo",
  }
  let (_, next) = update_navigation_actions(
    dispatch,
    SelectSearchHit("book-demo", "wiki/findings/result.md"),
    model,
  )
  assert_true(next.workspace_mode is MoonWiki)
  assert_true(next.activity is Files)
  assert_eq(next.selected_path, "wiki/findings/result.md")
  assert_eq(next.current_directory, "wiki/findings")
}

///|
test "wiki review feedback uses decision language" {
  assert_eq(
    wiki_review_feedback("review decisions idle"),
    "Add an optional note before making a decision.",
  )
  assert_eq(
    wiki_review_feedback("accepted wiki/reviews/pending.md"),
    "Change accepted and recorded.",
  )
  assert_eq(wiki_review_status_label("pending"), "Needs review")
  assert_false(wiki_review_feedback_visible("review decisions idle"))
  assert_true(wiki_review_feedback_visible("accepted wiki/reviews/pending.md"))
  assert_true(wiki_review_feedback_visible("rejected wiki/reviews/pending.md"))
  let item : ReviewItem = {
    id: "review-1",
    workspace_id: "book-demo",
    path: "wiki/reviews/pending.md",
    title: "Pending",
    kind: "review",
    status: "pending",
    detail: "wiki/reviews/pending.md",
  }
  assert_eq(
    wiki_review_detail(item),
    "Review this proposed change before it becomes accepted knowledge.",
  )
}
