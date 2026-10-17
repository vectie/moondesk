///|
fn specialist_test_model() -> Model {
  let agent : AgentPassportRecord = @json.from_json({
    "contract_id": "moonsuite.agent-passport.v1",
    "agent_id": "book-research",
    "workspace_id": "book-research",
    "book_id": "research-briefs",
    "name": "Research Book",
    "summary": "Research knowledge",
    "version": "1.0.0",
    "status": "ready",
    "source_kind": "moonbook",
    "capabilities": ["Evidence-backed answers"],
    "example_tasks": [],
    "knowledge_count": 1,
    "skill_count": 0,
    "schema_count": 0,
    "tool_count": 0,
    "app_count": 0,
    "recurring_work_count": 0,
  }) catch {
    _ => abort("invalid test passport")
  }
  { ..init_model(), agent_passports: [agent], }
}

///|
fn specialist_test_binding(paths : Array[String]) -> String {
  let binding : Json = {
    "request_id": "trial-1",
    "library_scope": specialist_library_scope(specialist_test_model()),
    "book_id": "research-briefs",
    "version": "1.0.0",
    "capabilities": ["Evidence-backed answers"],
    "knowledge_paths": Json::array(paths.map(path => Json::string(path))),
  }
  binding.stringify()
}

///|
test "specialist prepares exact Book and file context without submitting or retaining ambient materials" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let base = {
    ..specialist_test_model(),
    selected_workspace_id: "previous-book",
    request_material_paths: ["wiki/unrelated.md"],
    wiki_chat_file_paths: ["raw/unrelated.md"],
    wiki_agent_task_id: "completed-old-task",
    request_status: "completed",
  }
  let (_, prepared) = update_workspace_features(
    dispatch,
    workspace_feature_msg(
      "prepare-specialist",
      first="book-research",
      second="Exact representative example",
      third=specialist_test_binding(["wiki/method.md", "raw/report.md"]),
    ),
    base,
  )
  assert_eq(prepared.selected_workspace_id, "book-research")
  assert_eq(prepared.request_prompt, "Exact representative example")
  assert_eq(prepared.wiki_agent_task_id, "")
  assert_eq(prepared.request_material_paths, [])
  assert_eq(prepared.wiki_chat_file_paths, ["wiki/method.md", "raw/report.md"])
  assert_eq(prepared.wiki_chat_context_items.length(), 0)
  assert_true(prepared.workspace_mode is MoonWiki)
  assert_true(prepared.request_status.contains("click Send"))
  assert_false(prepared.request_status == "sending")
  let payload = wiki_chat_submission_body(prepared).stringify()
  assert_true(payload.contains("book-research"))
  assert_true(payload.contains("raw/report.md"))
  assert_false(payload.contains("unrelated"))
}

///|
test "specialist rejects active chat current draft and unrecognized Book without altering context" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let base = {
    ..specialist_test_model(),
    selected_workspace_id: "previous-book",
  }
  for
    guarded in [
      { ..base, request_status: "working", },
      { ..base, request_prompt: "Unsaved current prompt", },
      { ..base, wiki_chat_stream_task_id: "active-stream", },
      { ..base, git_review_note: "Review in progress", },
    ] {
    let (_, result) = prepare_specialist_example(
      dispatch,
      guarded,
      "book-research",
      "Example",
      specialist_test_binding(["wiki/method.md"]),
    )
    assert_eq(result.selected_workspace_id, "previous-book")
    assert_eq(result.request_prompt, guarded.request_prompt)
    assert_eq(result.request_status, guarded.request_status)
  }
  let (_, mismatch) = prepare_specialist_example(
    dispatch,
    base,
    "unknown-book",
    "Example",
    specialist_test_binding(["wiki/method.md"]),
  )
  assert_eq(mismatch.selected_workspace_id, "previous-book")
  let (_, unsafe) = prepare_specialist_example(
    dispatch,
    base,
    "book-research",
    "Example",
    specialist_test_binding(["wiki/../outside.md"]),
  )
  assert_eq(unsafe.selected_workspace_id, "previous-book")
}

///|
test "specialist knowledge paths stay in the declared Book knowledge layers" {
  for path in ["wiki/method.md", "raw/report.pdf"] {
    assert_true(specialist_knowledge_path_safe(path))
  }
  for
    path in [
      "/absolute", "wiki/../outside", "wiki/a\\b", "wiki/a\nb", "wiki//a", "tools/command.json",
      "wiki/",
    ] {
    assert_false(specialist_knowledge_path_safe(path))
  }
}

///|
#warnings("-alert_unstable")
test "Packs exposes the specialist creator without a second MoonBooks library" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_pack_home(dispatch, specialist_test_model())),
  )
  assert_true(markup.contains("data-testid=\"build-specialist\""))
  assert_true(markup.contains("Build your specialist"))
}

///|
test "specialist catalog is loaded on demand and stale library replies cannot authorize a draft" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let base = { ..specialist_test_model(), request_prompt: "Keep this draft", }
  let (_, waiting) = update_workspace_features(
    dispatch,
    workspace_feature_msg("open-specialist"),
    base,
  )
  assert_true(waiting.agent_passports.is_empty())
  assert_eq(waiting.request_prompt, "Keep this draft")
  let catalog : SpecialistAgentCatalog = {
    agent_count: 1,
    agents: base.agent_passports,
  }
  let (_, stale) = update_workspace_results(
    dispatch,
    LoadedSpecialistCatalog("another library", Ok(catalog)),
    waiting,
  )
  assert_true(stale.agent_passports.is_empty())
  assert_eq(stale.request_prompt, "Keep this draft")
  let (_, loaded) = update_workspace_results(
    dispatch,
    LoadedSpecialistCatalog(specialist_library_scope(base), Ok(catalog)),
    waiting,
  )
  assert_eq(loaded.agent_passports.length(), 1)
  assert_eq(loaded.request_prompt, "Keep this draft")
  let (_, failed) = update_workspace_results(
    dispatch,
    LoadedSpecialistCatalog(specialist_library_scope(base), Err("unavailable")),
    loaded,
  )
  assert_true(failed.agent_passports.is_empty())
  assert_eq(failed.request_prompt, "Keep this draft")
}

///|
test "specialist preparation preserves a Code draft after visiting Pack Home" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let base = {
    ..specialist_test_model(),
    workspace_mode: MoonCode,
    selected_workspace_id: "previous-book",
    selected_mooncode_session_id: "code-session",
    mooncode_prompt: "Unsent Code investigation with exact user detail",
  }
  let (_, home) = select_workspace_mode_action(dispatch, PackHome, base)
  assert_eq(home.mooncode_prompt, base.mooncode_prompt)
  let (_, blocked) = prepare_specialist_example(
    dispatch,
    home,
    "book-research",
    "Example",
    specialist_test_binding(["wiki/method.md"]),
  )
  assert_eq(blocked.mooncode_prompt, base.mooncode_prompt)
  assert_eq(blocked.selected_workspace_id, home.selected_workspace_id)
  assert_eq(
    blocked.selected_mooncode_session_id,
    home.selected_mooncode_session_id,
  )
  assert_eq(blocked.request_prompt, home.request_prompt)
  assert_true(blocked.workspace_mode is PackHome)
}

///|
test "specialist preparation preserves image-only and pending Code composer work" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let base = {
    ..specialist_test_model(),
    workspace_mode: PackHome,
    selected_workspace_id: "previous-book",
    selected_mooncode_session_id: "code-session",
  }
  for
    guarded in [
      { ..base, mooncode_images: [{ "id": "unsent-image" }], },
      { ..base, mooncode_image_submit_pending: true, },
      { ..base, mooncode_task_intent_submit_pending: true, },
      { ..base, mooncode_guidance_pending_session_id: "code-session", },
    ] {
    let (_, blocked) = prepare_specialist_example(
      dispatch,
      guarded,
      "book-research",
      "Example",
      specialist_test_binding(["wiki/method.md"]),
    )
    assert_eq(blocked.selected_workspace_id, guarded.selected_workspace_id)
    assert_eq(
      blocked.selected_mooncode_session_id,
      guarded.selected_mooncode_session_id,
    )
    assert_eq(blocked.mooncode_images, guarded.mooncode_images)
    assert_eq(
      blocked.mooncode_image_submit_pending,
      guarded.mooncode_image_submit_pending,
    )
    assert_eq(
      blocked.mooncode_task_intent_submit_pending,
      guarded.mooncode_task_intent_submit_pending,
    )
    assert_eq(
      blocked.mooncode_guidance_pending_session_id,
      guarded.mooncode_guidance_pending_session_id,
    )
  }
}

///|
test "queued automatic history restore cannot erase a newly prepared specialist" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, prepared) = prepare_specialist_example(
    dispatch,
    specialist_test_model(),
    "book-research",
    "Exact representative example",
    specialist_test_binding(["wiki/method.md"]),
  )
  let (_, retained) = update_workspace_features(
    dispatch,
    workspace_feature_msg(
      "restore-thread",
      first="old-task",
      second="",
      third="[{\"role\":\"user\",\"content\":\"Old unrelated task\"}]",
      fourth="automatic",
    ),
    prepared,
  )
  assert_eq(retained.request_prompt, "Exact representative example")
  assert_eq(retained.wiki_chat_file_paths, ["wiki/method.md"])
  assert_eq(retained.wiki_agent_task_id, "")
  let cleared = { ..prepared, request_prompt: "", }
  let (_, context_retained) = update_workspace_features(
    dispatch,
    workspace_feature_msg(
      "restore-thread",
      first="old-task",
      third="[]",
      fourth="automatic",
    ),
    cleared,
  )
  assert_eq(context_retained.wiki_chat_file_paths, ["wiki/method.md"])
  assert_eq(context_retained.wiki_agent_task_id, "")
}
