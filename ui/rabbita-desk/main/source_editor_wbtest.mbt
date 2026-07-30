///|
test "source path typing does not open until explicit request" {
  let initial = init_source_pane("workspace", "session")
  let typed = update_source_pane(initial, SetPathInput("src/main.mbt"))
  assert_eq(typed.path_input, "src/main.mbt")
  assert_eq(typed.requested_path, "")
  assert_eq(typed.request_generation, 0)
  assert_true(typed.content is Empty)
  let opened = update_source_pane(typed, OpenPathInput)
  assert_eq(opened.requested_path, "src/main.mbt")
  assert_true(opened.content is Loading)
}

///|
test "same-workspace session changes preserve source state and response authority" {
  let loading = update_source_pane(
    update_source_pane(
      init_source_pane("workspace", "session-a"),
      SetPathInput("src/main.mbt"),
    ),
    OpenPathInput,
  )
  let identity = source_pane_identity(loading)
  let rebound = update_source_pane(loading, Rebind("workspace", "session-b"))
  assert_eq(rebound.requested_path, "src/main.mbt")
  assert_eq(rebound.session_id, "session-b")
  assert_true(source_pane_is_current(rebound, identity))
  let ready = update_source_pane(
    rebound,
    PreviewResult(identity, Ok(source_pane_test_preview())),
  )
  assert_true(ready.content is Ready(_))
}

///|
test "different workspace rebind invalidates clean source response" {
  let loading = update_source_pane(
    init_source_pane("workspace-a", "session-a"),
    RequestSource("src/main.mbt"),
  )
  let identity = source_pane_identity(loading)
  let rebound = update_source_pane(loading, Rebind("workspace-b", "session-b"))
  assert_false(source_pane_is_current(rebound, identity))
  assert_true(rebound.content is Empty)
}

///|
test "source draft blocks navigation and remains dirty after save failure" {
  let loading = update_source_pane(
    init_source_pane("workspace", "session"),
    RequestSource("src/main.mbt"),
  )
  let ready = update_source_pane(
    loading,
    PreviewResult(source_pane_identity(loading), Ok(source_pane_test_preview())),
  )
  let dirty = update_source_pane(ready, EditDraft("fn direct_edit {}"))
  assert_true(source_pane_dirty(dirty))
  let blocked = update_source_pane(dirty, RequestSource("src/other.mbt"))
  assert_eq(blocked.requested_path, "src/main.mbt")
  let failed = update_source_pane(
    dirty,
    SaveResult(SourceConflict("fn external {}")),
  )
  assert_eq(failed.draft, "fn direct_edit {}")
  assert_true(failed.server_content is Some("fn external {}"))
  assert_true(source_pane_dirty(failed))
}

///|
test "source conflict reload and replace preserve deliberate choices" {
  let initial = init_source_pane("workspace", "session")
  let state = {
    ..initial,
    requested_path: "src/main.mbt",
    baseline: "agent",
    draft: "user",
    server_content: Some("external"),
  }
  let replace = update_source_pane(state, ReplaceServer)
  assert_eq(replace.baseline, "external")
  assert_eq(replace.draft, "user")
  assert_true(replace.saving)
  let reload = update_source_pane(state, ReloadServer)
  assert_eq(reload.baseline, "external")
  assert_eq(reload.draft, "external")
  assert_false(source_pane_dirty(reload))
}
