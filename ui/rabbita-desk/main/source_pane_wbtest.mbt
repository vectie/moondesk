///|
fn source_pane_test_preview() -> @desk.DeskPreview {
  @desk.preview(
    @desk.file_entry(workspace_id="book-demo", path="src/main.mbt"),
    body="fn main {}",
  )
}

///|
test "source pane accepts only the current result" {
  let loading = update_source_pane(
    init_source_pane("workspace", "session"),
    RequestSource("src/main.mbt"),
  )
  let identity = source_pane_identity(loading)
  let accepted = update_source_pane(
    loading,
    PreviewResult(identity, Ok(source_pane_test_preview())),
  )
  match accepted.content {
    Ready(preview) => assert_eq(preview.body, "fn main {}")
    _ => assert_true(false)
  }
}

///|
test "source pane rejects stale generation workspace and path" {
  let loading = update_source_pane(
    init_source_pane("workspace", "session"),
    RequestSource("src/main.mbt"),
  )
  let current = source_pane_identity(loading)
  let stale = [
    { ..current, generation: current.generation - 1 },
    { ..current, workspace_id: "other" },
    { ..current, path: "other.mbt" },
  ]
  for identity in stale {
    let next = update_source_pane(
      loading,
      PreviewResult(identity, Ok(source_pane_test_preview())),
    )
    assert_true(next == loading)
  }
}

///|
test "source pane rebind resets and invalidates pending result" {
  let loading = update_source_pane(
    init_source_pane("old-workspace", "old-session"),
    RequestSource("src/main.mbt"),
  )
  let pending = source_pane_identity(loading)
  let rebound = update_source_pane(
    loading,
    Rebind("new-workspace", "new-session"),
  )
  assert_eq(rebound.workspace_id, "new-workspace")
  assert_eq(rebound.session_id, "new-session")
  assert_eq(rebound.requested_path, "")
  assert_true(rebound.content is Empty)
  let stale_result_state = update_source_pane(
    rebound,
    PreviewResult(pending, Ok(source_pane_test_preview())),
  )
  assert_true(stale_result_state == rebound)
}

///|
test "source pane records failed and unsupported current results" {
  let loading = update_source_pane(
    init_source_pane("workspace", "session"),
    RequestSource("src/main.mbt"),
  )
  let identity = source_pane_identity(loading)
  let failed = update_source_pane(
    loading,
    PreviewResult(identity, Err("failed")),
  )
  assert_true(failed.content is Failed("failed"))
  let unsupported = update_source_pane(
    loading,
    PreviewUnsupported(identity, "binary"),
  )
  assert_true(unsupported.content is Unsupported("binary"))
}

///|
test "source pane empty path clears loading and invalidates prior work" {
  let loading = update_source_pane(
    init_source_pane("workspace", "session"),
    RequestSource("src/main.mbt"),
  )
  let cleared = update_source_pane(loading, RequestSource("   "))
  assert_eq(cleared.requested_path, "")
  assert_eq(cleared.request_generation, loading.request_generation + 1)
  assert_true(cleared.content is Empty)
}

///|
test "source pane rejects unsafe absolute and parent paths" {
  for path in ["/etc/passwd", "../secret", "src/../../secret", "C:\\secret"] {
    let state = update_source_pane(
      init_source_pane("workspace", "session"),
      RequestSource(path),
    )
    assert_true(state.content is Failed(_))
    assert_true(state.status.contains("parent-traversal"))
  }
}

///|
test "source pane valid request has normalized full identity" {
  let state = update_source_pane(
    init_source_pane("workspace", "session"),
    RequestSource("  src/main.mbt  "),
  )
  let identity = source_pane_identity(state)
  assert_eq(identity.generation, 1)
  assert_eq(identity.workspace_id, "workspace")
  assert_eq(identity.session_id, "session")
  assert_eq(identity.path, "src/main.mbt")
  assert_true(state.content is Loading)
}

///|
test "routing source pane leaves selected path and prompt context unchanged" {
  let dispatch : Dispatch[Msg] = fn(_) { @rabbita.none }
  let model = init_model()
  let model = {
    ..model,
    selected_path: "keep/selected.mbt",
    mooncode_prompt: "keep prompt",
    request_prompt: "keep request context",
  }
  let (_, next) = update(
    dispatch,
    SourcePane(RequestSource("src/main.mbt")),
    model,
  )
  assert_eq(next.selected_path, "keep/selected.mbt")
  assert_eq(next.mooncode_prompt, "keep prompt")
  assert_eq(next.request_prompt, "keep request context")
}

///|
test "source pane same-context rebind is a complete no-op" {
  let ready = update_source_pane(
    update_source_pane(
      update_source_pane(
        init_source_pane("workspace", "session"),
        SetOpen(true),
      ),
      SetCollapsed(true),
    ),
    RequestSource("src/main.mbt"),
  )
  let ready = update_source_pane(
    ready,
    PreviewResult(source_pane_identity(ready), Ok(source_pane_test_preview())),
  )
  assert_true(
    update_source_pane(ready, Rebind("workspace", "session")) == ready,
  )
}

///|
test "source pane changed-context preserves presentation and clears content" {
  let loading = update_source_pane(
    update_source_pane(
      update_source_pane(init_source_pane("old", ""), SetOpen(true)),
      SetCollapsed(true),
    ),
    RequestSource("src/main.mbt"),
  )
  let old_identity = source_pane_identity(loading)
  let rebound = update_source_pane(loading, Rebind("new", ""))
  assert_true(rebound.open)
  assert_true(rebound.collapsed)
  assert_eq(rebound.request_generation, loading.request_generation + 1)
  assert_eq(rebound.requested_path, "")
  assert_true(rebound.content is Empty)
  assert_true(
    update_source_pane(
      rebound,
      PreviewResult(old_identity, Ok(source_pane_test_preview())),
    ) ==
    rebound,
  )
}

///|
test "source pane rejects blank workspace but permits empty session" {
  let unauthorized = update_source_pane(
    init_source_pane("   ", "session"),
    RequestSource("src/main.mbt"),
  )
  assert_true(unauthorized.content is Failed(_))
  let authorized = update_source_pane(
    init_source_pane("workspace", ""),
    RequestSource("src/main.mbt"),
  )
  assert_true(authorized.content is Loading)
}

///|
test "source pane preserves a dirty buffer across tabs and discards deliberately" {
  let loading = update_source_pane(
    init_source_pane("workspace", "session"),
    RequestSource("src/main.mbt"),
  )
  assert_true(update_source_pane(loading, EditDraft("too early")) == loading)
  let ready = update_source_pane(
    loading,
    PreviewResult(source_pane_identity(loading), Ok(source_pane_test_preview())),
  )
  let dirty = update_source_pane(ready, EditDraft("changed"))
  assert_true(source_pane_dirty(dirty))
  let opening_other = update_source_pane(dirty, RequestSource("src/other.mbt"))
  assert_true(opening_other.content is Loading)
  assert_eq(opening_other.draft, "")
  let restored = update_source_pane(opening_other, SwitchBuffer("src/main.mbt"))
  assert_eq(restored.draft, "changed")
  assert_true(source_pane_dirty(restored))
  let discarded = update_source_pane(restored, DiscardDraft)
  assert_false(source_pane_dirty(discarded))
  assert_eq(discarded.draft, "fn main {}")
}

///|
test "source pane clears the previous buffer while another path loads" {
  let loading = update_source_pane(
    init_source_pane("workspace", "session"),
    RequestSource("src/main.mbt"),
  )
  let ready = update_source_pane(
    loading,
    PreviewResult(source_pane_identity(loading), Ok(source_pane_test_preview())),
  )
  let next = update_source_pane(ready, RequestSource("src/other.mbt"))
  assert_true(next.content is Loading)
  assert_eq(next.baseline, "")
  assert_eq(next.draft, "")
  assert_false(source_pane_editable(next))
  assert_eq(next.buffers.length(), 1)
  assert_eq(next.buffers[0].path, "src/main.mbt")
}

///|
test "source pane closes only clean tabs and restores another buffer" {
  let loading = update_source_pane(
    init_source_pane("workspace", "session"),
    RequestSource("src/main.mbt"),
  )
  let ready = update_source_pane(
    loading,
    PreviewResult(source_pane_identity(loading), Ok(source_pane_test_preview())),
  )
  let dirty = update_source_pane(ready, EditDraft("changed"))
  let blocked = update_source_pane(dirty, CloseBuffer("src/main.mbt"))
  assert_true(blocked.status.contains("modified tab"))
  let clean = update_source_pane(blocked, DiscardDraft)
  let closed = update_source_pane(clean, CloseBuffer("src/main.mbt"))
  assert_true(closed.content is Empty)
  assert_true(closed.buffers.is_empty())
}

///|
test "source pane keeps tab identity stable while a save is pending" {
  let loading = update_source_pane(
    init_source_pane("workspace", "session"),
    RequestSource("src/main.mbt"),
  )
  let ready = update_source_pane(
    loading,
    PreviewResult(source_pane_identity(loading), Ok(source_pane_test_preview())),
  )
  let saving = update_source_pane(
    update_source_pane(ready, EditDraft("changed")),
    Save,
  )
  let switched = update_source_pane(saving, SwitchBuffer("src/other.mbt"))
  assert_eq(switched.requested_path, "src/main.mbt")
  assert_true(switched.status.contains("current save"))
  let closed = update_source_pane(saving, CloseBuffer("src/main.mbt"))
  assert_eq(closed.requested_path, "src/main.mbt")
  assert_true(closed.status.contains("current save"))
}

///|
test "source pane derives editor language and line-number chrome" {
  let moonbit = {
    ..init_source_pane("workspace", "session"),
    requested_path: "src/main.mbt",
    draft: "fn main {\n  println(\"moon\")\n}\n",
  }
  assert_eq(source_pane_language_label(moonbit), "MoonBit")
  assert_eq(source_pane_line_count(moonbit), 4)
  assert_eq(source_pane_line_numbers(moonbit), "1\n2\n3\n4")
  assert_eq(
    source_pane_language_label({ ..moonbit, requested_path: "notes/readme.md" }),
    "Markdown",
  )
  assert_eq(
    source_pane_language_label({ ..moonbit, requested_path: "unknown.data" }),
    "Plain text",
  )
}
