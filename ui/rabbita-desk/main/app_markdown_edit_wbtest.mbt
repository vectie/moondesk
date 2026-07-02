///|
fn markdown_edit_preview(path : String, body : String) -> @desk.DeskPreview {
  @desk.preview(@desk.file_entry(workspace_id="book-demo", path~), body~)
}

///|
test "moonwiki markdown editor starts from selected preview" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "wiki/index.md",
    preview: Some(markdown_edit_preview("wiki/index.md", "# Hello\n")),
  }
  let (_, next) = update_workspace_surface_actions(
    dispatch,
    StartMarkdownEdit,
    model,
  )
  assert_eq(next.markdown_editor_path, "wiki/index.md")
  assert_eq(next.markdown_editor_content, "# Hello\n")
  assert_eq(next.markdown_editor_status, "editing wiki/index.md")
  assert_true(markdown_editor_active(next))
}

///|
test "moonwiki markdown editor rejects non wiki markdown selection" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "raw/source.md",
    preview: Some(markdown_edit_preview("raw/source.md", "# Raw\n")),
  }
  let (_, next) = update_workspace_surface_actions(
    dispatch,
    StartMarkdownEdit,
    model,
  )
  assert_eq(next.markdown_editor_path, "")
  assert_true(next.markdown_editor_status.contains("wiki or inbox markdown"))
}

///|
test "saved markdown edit refreshes preview and exits editor" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "wiki/index.md",
    current_directory: "wiki",
    markdown_editor_path: "wiki/index.md",
    markdown_editor_content: "# Updated\n",
  }
  let (_, next) = update_workspace_results(
    dispatch,
    SavedMarkdownEdit(Ok({ workspace_id: "book-demo", path: "wiki/index.md" })),
    model,
  )
  assert_eq(next.selected_workspace_id, "book-demo")
  assert_eq(next.selected_path, "wiki/index.md")
  assert_eq(next.current_directory, "wiki")
  assert_eq(next.markdown_editor_path, "")
  assert_eq(next.markdown_editor_content, "")
  assert_eq(next.markdown_editor_status, "saved wiki/index.md")
  assert_eq(next.preview_status, "loading saved markdown")
}

///|
test "markdown editor preview follows draft content" {
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "wiki/index.md",
    markdown_editor_path: "wiki/index.md",
    markdown_editor_content: "# Draft\n\n- one\n",
  }
  let preview = markdown_editor_preview(model)
  assert_true(preview.renderer is Markdown)
  assert_eq(preview.title, "index.md")
  assert_eq(preview.body, "# Draft\n\n- one\n")
}

///|
test "navigating away clears markdown editor state" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "wiki/index.md",
    markdown_editor_path: "wiki/index.md",
    markdown_editor_content: "# Draft\n",
    markdown_editor_status: "editing wiki/index.md",
  }
  let (_, next) = update_navigation_actions(
    dispatch,
    SelectPath("wiki/other.md"),
    model,
  )
  assert_eq(next.selected_path, "wiki/other.md")
  assert_eq(next.markdown_editor_path, "")
  assert_eq(next.markdown_editor_content, "")
  assert_eq(next.markdown_editor_status, "editor idle")
}

///|
test "reloading same markdown path keeps editor state" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "wiki/index.md",
    markdown_editor_path: "wiki/index.md",
    markdown_editor_content: "# Draft\n",
    markdown_editor_status: "editing wiki/index.md",
  }
  let (_, next) = update_navigation_actions(
    dispatch,
    OpenQuickPath("wiki/index.md"),
    model,
  )
  assert_eq(next.selected_path, "wiki/index.md")
  assert_eq(next.markdown_editor_path, "wiki/index.md")
  assert_eq(next.markdown_editor_content, "# Draft\n")
}

///|
test "failed markdown save keeps draft visible" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "wiki/index.md",
    markdown_editor_path: "wiki/index.md",
    markdown_editor_content: "# Draft\n",
    markdown_editor_status: "editing wiki/index.md",
    preview_status: "preview ready",
  }
  let (_, next) = update_workspace_results(
    dispatch,
    SavedMarkdownEdit(Err("Markdown edits must target wiki/*.md")),
    model,
  )
  assert_eq(next.selected_path, "wiki/index.md")
  assert_eq(next.markdown_editor_path, "wiki/index.md")
  assert_eq(next.markdown_editor_content, "# Draft\n")
  assert_eq(next.markdown_editor_status, "Markdown edits must target wiki/*.md")
  assert_eq(next.preview_status, "Markdown edits must target wiki/*.md")
}

///|
test "search results keep wiki hit metadata" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let hit : SearchHit = {
    workspace_id: "book-demo",
    workspace_name: "Demo",
    path: "wiki/findings/forward-seed.md",
    title: "forward-seed.md",
    kind: Markdown,
    source_layer: Wiki,
    snippet: "Promote this into Wiki knowledge.",
  }
  let (_, next) = update_workspace_results(
    dispatch,
    LoadedSearch(Ok([hit])),
    init_model(),
  )
  assert_eq(next.search_status, "1 results")
  assert_eq(next.search_hits.length(), 1)
  assert_eq(next.search_hits[0].path, "wiki/findings/forward-seed.md")
  assert_true(next.search_hits[0].source_layer is Wiki)
}

///|
test "failed search reports status without clearing context" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "wiki/index.md",
    search_status: "loading",
  }
  let (_, next) = update_workspace_results(
    dispatch,
    LoadedSearch(Err("search unavailable")),
    model,
  )
  assert_eq(next.selected_workspace_id, "book-demo")
  assert_eq(next.selected_path, "wiki/index.md")
  assert_eq(next.search_status, "search unavailable")
}

///|
test "standing goal decoder accepts native api records" {
  let payload = Json::array([
    {
      "id": "watch-research-demo-pdfs",
      "title": "Watch Demo PDFs",
      "target_book_id": "research-demo",
      "cadence_ticks": 30,
      "next_due_tick": 0,
      "last_run_tick": Json::null(),
      "enabled": true,
      "source_policy": "web-first",
      "review_policy": "accepted_new_knowledge",
      "prompt": "Watch configured websites and queue Bookkeeper review.",
    },
  ])
  let goals : Array[StandingGoalRecord] = @json.from_json(payload)
  assert_eq(goals.length(), 1)
  assert_eq(goals[0].id, "watch-research-demo-pdfs")
  assert_eq(last_run_label(goals[0]), "never")
  assert_true(goals[0].prompt.contains("Bookkeeper"))
}

///|
test "review decision note edits settings state" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, next) = update_workspace_surface_actions(
    dispatch,
    SetReviewDecisionNote("Looks sourced."),
    init_model(),
  )
  assert_eq(next.review_decision_note, "Looks sourced.")
}

///|
test "review decision result clears note and reports accepted path" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = { ..init_model(), review_decision_note: "Looks sourced." }
  let (_, next) = update_town_results(
    dispatch,
    DecidedReviewItem(
      Ok({
        id: "review-decision-1",
        workspace_id: "book-demo",
        source_path: "wiki/reviews/pending.md",
        decision: "accepted",
        status: "accepted",
        note: "Looks sourced.",
        receipt_path: "wiki/reviews/decisions/review-decision-1.json",
      }),
    ),
    model,
  )
  assert_eq(next.review_decision_note, "")
  assert_eq(
    next.review_decision_status,
    "accepted wiki/reviews/pending.md -> wiki/reviews/decisions/review-decision-1.json",
  )
  assert_eq(next.host_status, "accepted review decision recorded for book-demo")
  assert_eq(next.inbox_status, "review note recorded")
}

///|
test "review decision rejects non book-scoped item before http" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let item : ReviewItem = {
    id: "town-review",
    workspace_id: "",
    path: ".moonsuite/products/moontown/events/review.json",
    title: "Town review",
    kind: "event",
    status: "review",
    detail: "town event",
  }
  let (_, next) = update_workspace_surface_actions(
    dispatch,
    DecideReviewItem(item, "accepted"),
    init_model(),
  )
  assert_eq(next.review_decision_status, "review item is not book-scoped")
}

///|
test "review decision decoder accepts receipt payload" {
  let payload : Json = {
    "id": "review-decision-1",
    "workspace_id": "book-demo",
    "source_path": "wiki/reviews/pending.md",
    "decision": "rejected",
    "status": "rejected",
    "note": "Needs stronger evidence.",
    "receipt_path": "wiki/reviews/decisions/review-decision-1.json",
  }
  let receipt : ReviewDecisionResult = @json.from_json(payload)
  assert_eq(receipt.decision, "rejected")
  assert_eq(
    receipt.receipt_path,
    "wiki/reviews/decisions/review-decision-1.json",
  )
}

///|
test "inbox save result selects saved note for wiki forward run" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, next) = update_inbox_results(
    dispatch,
    SavedInbox(
      Ok({ ok: true, workspace_id: "book-demo", path: "inbox/forward-seed.md" }),
    ),
    init_model(),
  )
  assert_true(next.activity is Inbox)
  assert_eq(next.current_directory, "inbox")
  assert_eq(next.selected_workspace_id, "book-demo")
  assert_eq(next.selected_path, "inbox/forward-seed.md")
  assert_eq(next.editing_inbox_path, "inbox/forward-seed.md")
  assert_eq(next.inbox_status, "saved inbox/forward-seed.md")
  assert_eq(next.preview_status, "loading saved note")
}

///|
test "import result preserves attachment sidecar status" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, next) = update_inbox_results(
    dispatch,
    ImportedInbox(
      Ok({
        ok: true,
        workspace_id: "book-demo",
        path: "inbox/imports/source.md",
        kind: "url",
        data_path: "inbox/imports/source.data-url.txt",
      }),
    ),
    init_model(),
  )
  assert_true(next.activity is Inbox)
  assert_eq(next.current_directory, "inbox/imports")
  assert_eq(next.selected_path, "inbox/imports/source.md")
  assert_eq(
    next.inbox_status,
    "imported url to inbox/imports/source.md and inbox/imports/source.data-url.txt",
  )
  assert_eq(next.preview_status, "loading import")
}

///|
test "browser local import parser accepts empty successful batch" {
  match parse_browser_import_batch("{\"ok\":true,\"files\":[]}") {
    Ok(files) => assert_eq(files.length(), 0)
    Err(error) => fail(error)
  }
  match parse_browser_import_batch("") {
    Ok(files) => assert_eq(files.length(), 0)
    Err(error) => fail(error)
  }
}

///|
test "browser local import parser preserves files and errors" {
  match
    parse_browser_import_batch(
      "{\"ok\":true,\"files\":[{\"id\":\"drop:a.md:1:2\",\"name\":\"a.md\",\"media_type\":\"text/markdown\",\"content\":\"# A\\n\",\"source\":\"drop\"}]}",
    ) {
    Ok(files) => {
      assert_eq(files.length(), 1)
      assert_eq(files[0].name, "a.md")
      assert_eq(files[0].source, "drop")
      assert_eq(files[0].content, "# A\n")
    }
    Err(error) => fail(error)
  }
  match
    parse_browser_import_batch(
      "{\"ok\":false,\"files\":[],\"error\":\"picker unavailable\"}",
    ) {
    Ok(_) => fail("expected browser import error")
    Err(error) => assert_eq(error, "picker unavailable")
  }
}
