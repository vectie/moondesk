///|
test "wiki navigation uses normal user language and compatible slugs" {
  let items = activities()
  assert_eq(items.length(), 6)
  assert_eq(items[0].label, "Library")
  assert_eq(items[1].label, "Search")
  assert_eq(items[2].label, "Inbox")
  assert_eq(items[3].label, "Activity")
  assert_eq(items[4].label, "Review")
  assert_eq(items[5].label, "More")
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
test "wiki empty-book detection waits for an indexed root" {
  let empty_book = {
    ..init_model(),
    selected_workspace_id: "book-empty",
    host_status: "workspace indexed",
    current_directory: "",
    selected_path: "",
    entries: [],
    preview: None,
    preview_status: "Preview is not available",
  }
  assert_true(wiki_book_is_empty(empty_book))
  assert_false(
    wiki_book_is_empty({ ..empty_book, host_status: "loading workspace" }),
  )
  assert_false(
    wiki_book_is_empty({ ..empty_book, preview_status: "loading preview" }),
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
