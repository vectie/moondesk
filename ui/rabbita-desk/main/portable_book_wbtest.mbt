///|
fn portable_book_test_id() -> String {
  "0123456789abcdef0123456789abcdef"
}

///|
fn portable_book_test_sha() -> String {
  "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
}

///|
fn portable_book_test_ready() -> PortableBookState {
  {
    ..init_portable_book(),
    active: true,
    library: "/library-a",
    workspace: "book-a",
    available: true,
    loaded: true,
    version: "1.2.3",
  }
}

///|
fn portable_book_test_package() -> PortableBookPrepared {
  {
    workspace_id: "book-a",
    expected_library: "/library-a",
    export_id: portable_book_test_id(),
    path: "agents/exports/" + portable_book_test_id() + "/agent.json",
    inspection: {
      contract: "moonbook.agent.v1",
      agent_id: "agent-a",
      version: "1.2.3",
      book_revision: "revision-a",
      bundle_digest: "bundle-a",
      file_count: 2,
      total_bytes: 9,
      files: [
        {
          path: "wiki/accepted.md",
          role: "accepted-knowledge",
          digest: "member-one",
          size_bytes: 4,
          review_status: "accepted",
          sensitivity: "public",
        },
        {
          path: "memory/preferences.json",
          role: "learned-preferences",
          digest: "member-two",
          size_bytes: 5,
          review_status: "accepted",
          sensitivity: "user-private",
        },
      ],
      exclusions: [
        { path: "runtime/session.json", reason: "runtime state excluded", },
      ],
      compatibility: { "moonclaw_contract": "moonclaw.v1" },
      export_policy: { "include_credentials": false },
      memory_policy: { "contract": "memory.v1" },
      memory_metrics: { "exported": 1 },
    },
    verification: {
      ok: true,
      agent_id: "agent-a",
      version: "1.2.3",
      bundle_digest: "bundle-a",
      checked_file_count: 2,
      issues: [],
    },
    source: {
      agent_id: "agent-a",
      agent_version: "1.2.3",
      book_revision: "revision-a",
      bundle_digest: "bundle-a",
      package_filename: "agent.json",
      package_size_bytes: 1200,
      package_sha256: portable_book_test_sha(),
      file_count: 2,
      total_decoded_bytes: 9,
    },
  }
}

///|
fn portable_book_test_entry(
  path : String,
  kind : @desk.EntryKind,
) -> @desk.DeskFileEntry {
  @desk.file_entry_detail(
    workspace_id="book-a",
    path~,
    display_name=path,
    kind~,
    source_layer=BookOutput,
    size_bytes=Some(4),
  )
}

///|
test "portable Book view binding and refresh can only read" {
  let (state, effect) = reduce_portable_book(
    init_portable_book(),
    BindPortable(true, "/library-a", "book-a"),
  )
  assert_true(effect is ReadPortableCatalog(1, 1))
  assert_eq(state.paths, [])
  assert_eq(state.operation_id, "")
  let (same, effect) = reduce_portable_book(
    state,
    BindPortable(true, "/library-a", "book-a"),
  )
  assert_true(effect is NoPortableEffect)
  assert_eq(same.generation, state.generation)
  let (ready, effect) = reduce_portable_book(
    state,
    Received(
      1,
      1,
      Ok({
        "workspace_id": "book-a",
        "expected_library": "/library-a",
        "available": true,
        "message": "Available",
        "exports": [],
      }),
    ),
  )
  assert_true(effect is NoPortableEffect)
  assert_true(ready.available)
  let (_, effect) = reduce_portable_book(ready, RefreshCatalog)
  assert_true(effect is ReadPortableCatalog(1, 2))
}

///|
test "portable Book additional files require explicit individual selection" {
  let state = {
    ..portable_book_test_ready(),
    entries: [
      portable_book_test_entry("output/report.txt", Text),
      portable_book_test_entry("output", Directory),
    ],
  }
  assert_eq(state.paths.length(), 0)
  let (folder, effect) = reduce_portable_book(state, ToggleFile("output"))
  assert_eq(folder.paths.length(), 0)
  assert_true(effect is NoPortableEffect)
  let (selected, effect) = reduce_portable_book(
    state,
    ToggleFile("output/report.txt"),
  )
  assert_eq(selected.paths, ["output/report.txt"])
  assert_true(effect is NoPortableEffect)
  let (removed, _) = reduce_portable_book(
    selected,
    RemoveFile("output/report.txt"),
  )
  assert_eq(removed.paths.length(), 0)
  let (unknown, _) = reduce_portable_book(state, ToggleFile("secret.txt"))
  assert_eq(unknown.paths.length(), 0)
}

///|
test "portable Book Prepare is explicit and duplicate clicks cannot pack twice" {
  let id = portable_book_test_id()
  let (pending, effect) = reduce_portable_book(
    portable_book_test_ready(),
    Prepare(id),
  )
  assert_true(
    effect is PreparePortablePackage(0, 1, actual, "1.2.3", []) && actual == id,
  )
  assert_eq(pending.operation_id, id)
  let (duplicate, effect) = reduce_portable_book(
    pending,
    Prepare("ffffffffffffffffffffffffffffffff"),
  )
  assert_true(effect is NoPortableEffect)
  assert_eq(duplicate.operation_id, id)
  let (unchanged, effect) = reduce_portable_book(pending, SetVersion("2.0.0"))
  assert_eq(unchanged.version, "1.2.3")
  assert_true(effect is NoPortableEffect)
}

///|
test "portable Book preparation needs capability version and valid identity" {
  let ready = portable_book_test_ready()
  for
    state in [
      { ..ready, available: false, },
      { ..ready, version: " ", },
      { ..ready, loaded: false, },
      { ..ready, active: false, },
    ] {
    assert_false(portable_book_can_prepare(state))
    let (_, effect) = reduce_portable_book(
      state,
      Prepare(portable_book_test_id()),
    )
    assert_true(effect is NoPortableEffect)
  }
  let (_, effect) = reduce_portable_book(ready, Prepare("not-an-operation"))
  assert_true(effect is NoPortableEffect)
}

///|
test "portable Book timeout recovery reads exact operation without repacking" {
  let (pending, _) = reduce_portable_book(
    portable_book_test_ready(),
    Prepare(portable_book_test_id()),
  )
  let (uncertain, effect) = reduce_portable_book(pending, TimedOut(0, 1))
  assert_true(effect is NoPortableEffect)
  assert_eq(uncertain.operation_id, portable_book_test_id())
  assert_false(portable_book_can_prepare(uncertain))
  let (_, effect) = reduce_portable_book(uncertain, StartNewPreparation)
  assert_true(effect is NoPortableEffect)
  let (checking, effect) = reduce_portable_book(uncertain, CheckPreparation)
  assert_true(
    effect is InspectPortablePackage(0, 2, id) && id == portable_book_test_id(),
  )
  let (missing, effect) = reduce_portable_book(
    checking,
    Received(0, 2, Ok({ "error": "not_found" })),
  )
  assert_true(effect is NoPortableEffect)
  assert_true(missing.recovery_checked)
  assert_eq(missing.operation_id, portable_book_test_id())
  let (new_draft, effect) = reduce_portable_book(missing, StartNewPreparation)
  assert_true(effect is NoPortableEffect)
  assert_eq(new_draft.operation_id, "")
  assert_true(new_draft.notice.contains("earlier package"))
  assert_true(portable_book_can_prepare(new_draft))
}

///|
test "portable Book stale responses cannot cross Book library or request boundaries" {
  let (pending, _) = reduce_portable_book(
    portable_book_test_ready(),
    Prepare(portable_book_test_id()),
  )
  let response = Received(
    0,
    1,
    Ok(ToJson::to_json(portable_book_test_package())),
  )
  for
    binding in [
      BindPortable(true, "/library-a", "book-b"),
      BindPortable(true, "/library-b", "book-a"),
      BindPortable(false, "/library-a", "book-a"),
    ] {
    let (rebound, _) = reduce_portable_book(pending, binding)
    let (ignored, effect) = reduce_portable_book(rebound, response)
    assert_true(ignored.prepared is None)
    assert_true(effect is NoPortableEffect)
    assert_eq(ignored.generation, 1)
  }
  let (timed_out, _) = reduce_portable_book(pending, TimedOut(0, 1))
  let (ignored, effect) = reduce_portable_book(timed_out, response)
  assert_true(ignored.prepared is None)
  assert_true(effect is NoPortableEffect)
}

///|
test "portable Book source inspection and verification must agree completely" {
  let bundle = portable_book_test_package()
  assert_true(
    portable_book_decode_prepared(
      ToJson::to_json(bundle),
      "/library-a",
      "book-a",
      portable_book_test_id(),
    )
    is Some(_),
  )
  assert_true(
    portable_book_decode_prepared(
      ToJson::to_json(bundle),
      "/library-a",
      "book-b",
      portable_book_test_id(),
    )
    is None,
  )
  for
    invalid in [
      { ..bundle, path: "../escape.json", },
      { ..bundle, source: { ..bundle.source, package_sha256: "wrong", }, },
      { ..bundle, source: { ..bundle.source, agent_id: "other-agent", }, },
      { ..bundle, source: { ..bundle.source, file_count: 1, }, },
      { ..bundle, verification: { ..bundle.verification, ok: false, }, },
      {
        ..bundle,
        verification: { ..bundle.verification, checked_file_count: 1, },
      },
      {
        ..bundle,
        inspection: {
          ..bundle.inspection,
          files: [bundle.inspection.files[0]],
        },
      },
      {
        ..bundle,
        inspection: {
          ..bundle.inspection,
          files: [bundle.inspection.files[0], bundle.inspection.files[0]],
        },
      },
    ] {
    assert_true(
      portable_book_decode_prepared(
        ToJson::to_json(invalid),
        "/library-a",
        "book-a",
        portable_book_test_id(),
      )
      is None,
    )
  }
}

///|
test "portable Book changed inputs invalidate the exact prepared download" {
  let (pending, _) = reduce_portable_book(
    portable_book_test_ready(),
    Prepare(portable_book_test_id()),
  )
  let (prepared, _) = reduce_portable_book(
    pending,
    Received(0, 1, Ok(ToJson::to_json(portable_book_test_package()))),
  )
  assert_true(prepared.prepared is Some(_))
  let (same, _) = reduce_portable_book(prepared, SetVersion("1.2.3"))
  assert_true(same.prepared is Some(_))
  let (changed, effect) = reduce_portable_book(prepared, SetVersion("2.0.0"))
  assert_true(changed.prepared is None)
  assert_eq(changed.operation_id, "")
  assert_true(effect is NoPortableEffect)
}

///|
test "portable Book complete inspection shows every member exclusion and private flag" {
  let bundle = portable_book_test_package()
  let html = render_test_dom(
    @rabbita.static_cell(render_portable_book_inspection(bundle, true)),
  )
  assert_eq(html.split("data-testid=\"portable-book-member\"").count(), 3)
  assert_eq(html.split("data-testid=\"portable-book-exclusion\"").count(), 2)
  for
    text in [
      "wiki/accepted.md", "memory/preferences.json", "accepted-knowledge", "learned-preferences",
      "user-private", "Review status: accepted", "member-one", "member-two", "runtime/session.json",
      "runtime state excluded", "USER-PRIVATE", "portable-book-private-warning",
      "1200 bytes", "9", "bundle-a",
    ] {
    assert_true(html.contains(text))
  }
  assert_true(html.contains("download=\"\""))
  assert_true(html.contains(portable_book_test_sha()))
  assert_true(html.contains("/artifact?"))
  assert_true(
    html.contains("digest=" + @desk.url_component(portable_book_test_sha())),
  )
}

///|
test "portable Book SHA identities preserve the actual MoonBook contract prefix" {
  assert_true(portable_book_sha_valid(portable_book_test_sha()))
  assert_false(portable_book_sha_valid(portable_book_test_sha()[7:].to_owned()))
  assert_false(portable_book_sha_valid("sha256:wrong"))
  let bundle = portable_book_test_package()
  let url = portable_book_download_url(bundle)
  assert_true(url.contains("digest=sha256%3A"))
  let catalog : Json = {
    "workspace_id": "book-a",
    "expected_library": "/library-a",
    "available": true,
    "message": "Available",
    "exports": [
      {
        "export_id": portable_book_test_id(),
        "path": bundle.path,
        "version": "1.2.3",
        "package_sha256": portable_book_test_sha(),
        "package_size_bytes": 1200,
      },
    ],
  }
  let (loading, _) = reduce_portable_book(
    init_portable_book(),
    BindPortable(true, "/library-a", "book-a"),
  )
  let (loaded, _) = reduce_portable_book(loading, Received(1, 1, Ok(catalog)))
  assert_true(loaded.available)
  assert_eq(loaded.exports.length(), 1)
}

///|
test "portable Book hides download until inspected and refuses stale Book render" {
  let dispatch : Dispatch[Msg] = _ => @rabbita.none
  let bundle = portable_book_test_package()
  let state = { ..portable_book_test_ready(), prepared: Some(bundle), }
  let model = {
    ..init_model(),
    portable_book: state,
    selected_workspace_id: "book-b",
    workspace_library_path: "/library-a",
  }
  let html = render_test_dom(
    @rabbita.static_cell(render_portable_book(dispatch, model)),
  )
  assert_false(html.contains("portable-book-download"))
  assert_false(html.contains("memory/preferences.json"))
  let draft = render_test_dom(
    @rabbita.static_cell(
      render_portable_book(dispatch, {
        ..model,
        selected_workspace_id: "book-a",
        portable_book: portable_book_test_ready(),
      }),
    ),
  )
  assert_false(draft.contains("portable-book-download"))
  assert_true(draft.contains("No additional files are preselected"))
  assert_true(draft.contains("missing keeper files"))
  assert_true(draft.contains("normalize wiki metadata"))
  assert_true(draft.contains("add missing provenance links"))
  assert_true(draft.contains("refresh generated pages and projections"))
  assert_true(draft.contains("Prepare local package"))
  assert_false(draft.contains("Send to Town"))
  let blocked = render_test_dom(
    @rabbita.static_cell(render_portable_book_inspection(bundle, false)),
  )
  assert_false(blocked.contains("portable-book-download"))
}

///|
test "portable Book folder response must match its exact Book and request" {
  let (loading, effect) = reduce_portable_book(
    portable_book_test_ready(),
    BrowseFiles("output"),
  )
  assert_true(effect is ReadPortableEntries(0, 1, "output"))
  let (stale, _) = reduce_portable_book(
    loading,
    FilesReceived(
      1,
      1,
      Ok([portable_book_test_entry("output/report.txt", Text)]),
    ),
  )
  assert_false(stale.entries_loaded)
  let (loaded, effect) = reduce_portable_book(
    loading,
    FilesReceived(
      0,
      1,
      Ok([portable_book_test_entry("output/report.txt", Text)]),
    ),
  )
  assert_true(loaded.entries_loaded)
  assert_true(effect is NoPortableEffect)
  assert_eq(loaded.paths, [])
}

///|
test "portable Book expected library is sent and echoed for colliding Book IDs" {
  let bundle = portable_book_test_package()
  assert_true(
    portable_book_decode_prepared(
      ToJson::to_json(bundle),
      "/library-b",
      "book-a",
      portable_book_test_id(),
    )
    is None,
  )
  assert_eq(
    portable_book_read_url("book-a", "/library-a", ""),
    "/api/workspaces/book-a/agent-export?expected_library=%2Flibrary-a",
  )
  assert_eq(
    portable_book_entries_url("book-a", "/library-a", "output/reports"),
    "/api/workspaces/book-a/entries?path=output%2Freports&expected_library=%2Flibrary-a",
  )
  assert_eq(
    portable_book_read_url("book-a", "/library-b", portable_book_test_id()),
    "/api/workspaces/book-a/agent-export/" +
    portable_book_test_id() +
    "?expected_library=%2Flibrary-b",
  )
  let body = portable_book_prepare_body(
    "/library-a",
    portable_book_test_id(),
    "1.2.3",
    [],
  )
  assert_true(body is { "expected_library": String("/library-a"), .. })
  let (loading, _) = reduce_portable_book(
    init_portable_book(),
    BindPortable(true, "/library-a", "book-a"),
  )
  let (wrong, _) = reduce_portable_book(
    loading,
    Received(
      1,
      1,
      Ok({
        "workspace_id": "book-a",
        "expected_library": "/library-b",
        "available": true,
        "message": "Available",
        "exports": [],
      }),
    ),
  )
  assert_false(wrong.available)
  assert_false(wrong.loaded)
  let (pending, _) = reduce_portable_book(
    portable_book_test_ready(),
    Prepare(portable_book_test_id()),
  )
  let (wrong, _) = reduce_portable_book(
    pending,
    Received(
      0,
      1,
      Ok(ToJson::to_json({ ..bundle, expected_library: "/library-b", })),
    ),
  )
  assert_true(wrong.prepared is None)
  assert_false(portable_book_can_prepare(wrong))
}

///|
test "portable Book library picker invalidates preparation before metadata changes" {
  let ready = portable_book_test_ready()
  let model = {
    ..init_model(),
    portable_book: ready,
    workspace_mode: PublishWorkspace,
    workspace_library_path: "/library-a",
    selected_workspace_id: "book-a",
  }
  let picking = portable_book_library_transition(PickLibraryFolder, model)
  assert_true(picking.portable_book.library_changing)
  assert_false(portable_book_can_prepare(picking.portable_book))
  assert_true(picking.portable_book.prepared is None)
  let dispatch : Dispatch[Msg] = _ => @rabbita.none
  let (_, bound) = sync_portable_book_context(dispatch, picking)
  assert_false(bound.portable_book.active)
  assert_true(bound.portable_book.library_changing)
  let cancelled = portable_book_library_transition(
    LibraryFolderPicked(Ok("")),
    bound,
  )
  assert_false(cancelled.portable_book.library_changing)
  let (_, rebound) = sync_portable_book_context(dispatch, cancelled)
  assert_true(rebound.portable_book.pending is Some({ operation: Catalog, .. }))
  assert_false(portable_book_can_prepare(rebound.portable_book))
}

///|
test "portable Book timeout cannot be bypassed by edits or another saved package" {
  let ready = {
    ..portable_book_test_ready(),
    entries: [portable_book_test_entry("output/report.txt", Text)],
    paths: ["output/report.txt"],
    exports: [
      {
        export_id: "ffffffffffffffffffffffffffffffff",
        path: "exports/other.json",
        version: "other",
        package_sha256: portable_book_test_sha(),
        package_size_bytes: 20,
      },
    ],
  }
  let (pending, _) = reduce_portable_book(
    ready,
    Prepare(portable_book_test_id()),
  )
  let (uncertain, _) = reduce_portable_book(pending, TimedOut(0, 1))
  for
    action in [
      SetVersion("2.0.0"),
      ToggleFile("output/report.txt"),
      RemoveFile("output/report.txt"),
      InspectSaved("ffffffffffffffffffffffffffffffff"),
    ] {
    let (unchanged, effect) = reduce_portable_book(uncertain, action)
    assert_true(effect is NoPortableEffect)
    assert_eq(unchanged.version, "1.2.3")
    assert_eq(unchanged.paths, ["output/report.txt"])
    assert_eq(unchanged.operation_id, portable_book_test_id())
    let (_, effect) = reduce_portable_book(
      unchanged,
      Prepare("ffffffffffffffffffffffffffffffff"),
    )
    assert_true(effect is NoPortableEffect)
  }
  let (checking, effect) = reduce_portable_book(uncertain, CheckPreparation)
  assert_true(effect is InspectPortablePackage(0, 2, _))
  let (checked, _) = reduce_portable_book(
    checking,
    Received(0, 2, Ok({ "error": "not_found" })),
  )
  assert_true(portable_book_inputs_locked(checked))
  let (fresh, effect) = reduce_portable_book(checked, StartNewPreparation)
  assert_true(effect is NoPortableEffect)
  assert_false(portable_book_inputs_locked(fresh))
  assert_true(portable_book_can_prepare(fresh))
}
