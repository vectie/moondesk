///|
fn agent_import_test_file() -> LocalImportFile {
  {
    id: "local-file",
    name: "experience.moonbook-agent",
    relative_path: None,
    media_type: "application/octet-stream",
    content: "data:application/octet-stream;base64,e30=",
    source: "agent-package-picker",
  }
}

///|
fn agent_import_test_reply(
  status : String,
  destination? : String = "",
  library? : String = "/library-a",
  prepared? : PortableBookPrepared = portable_book_test_package(),
  changed? : Array[String] = [],
) -> Json {
  {
    "operation_id": portable_book_test_id(),
    "expected_library": library,
    "status": status,
    "filename": "experience.moonbook-agent",
    "destination_folder": destination,
    "inspection": ToJson::to_json(prepared.inspection),
    "verification": ToJson::to_json(prepared.verification),
    "source": ToJson::to_json(prepared.source),
    "import_verification": if status == "imported" {
      {
        "ok": changed.is_empty(),
        "changed_members": json_string_array(changed),
      }
    } else {
      Json::null()
    },
    "created": if status == "imported" {
      {
        "workspace_id": @desk.stable_id("book", destination),
        "book_id": "original-book-id",
        "name": "Original Book Name",
        "path": "wiki/index.md",
      }
    } else {
      Json::null()
    },
    "message": "Verified operation",
  }
}

///|
fn agent_import_test_pending_stage() -> AgentImportState {
  let (bound, _) = reduce_agent_import(
    init_agent_import(),
    BindAgentImport(true, "/library-a", "context"),
  )
  let (picking, _) = reduce_agent_import(
    bound,
    ChoosePackage(portable_book_test_id()),
  )
  let (staging, _) = reduce_agent_import(
    picking,
    PackagePicked(
      picking.generation,
      picking.request,
      Ok([agent_import_test_file()]),
    ),
  )
  staging
}

///|
fn agent_import_test_inspected() -> AgentImportState {
  let staging = agent_import_test_pending_stage()
  let (inspected, _) = reduce_agent_import(
    staging,
    ImportResponse(
      staging.generation,
      staging.request,
      Ok(agent_import_test_reply("inspected")),
    ),
  )
  inspected
}

///|
fn agent_import_test_importing() -> AgentImportState {
  let (destination, _) = reduce_agent_import(
    agent_import_test_inspected(),
    SetImportDestination("new-folder"),
  )
  let (importing, _) = reduce_agent_import(destination, ImportInspectedPackage)
  importing
}

///|
test "package receive reply schema decodes null completion before import" {
  let wire = agent_import_test_reply("inspected")
  guard agent_import_parse_reply(wire) is Some(reply) else {
    fail("Nullable reply did not decode")
  }
  assert_eq(reply.status, "inspected")
  assert_true(reply.created is None)
  assert_true(reply.import_verification is None)
  let pending = agent_import_test_pending_stage()
  assert_eq(pending.session.filename, reply.filename)
  assert_eq(pending.session.library, reply.expected_library)
  assert_eq(pending.session.operation_id, reply.operation_id)
  assert_true(agent_import_decode_reply(wire, pending.session) is Some(_))
}

///|
test "package receive requires ordered explicit inspection destination import and open" {
  let (bound, effect) = reduce_agent_import(
    init_agent_import(),
    BindAgentImport(true, "/library-a", "context"),
  )
  assert_true(effect is NoAgentImportEffect)
  let (_, effect) = reduce_agent_import(bound, ImportInspectedPackage)
  assert_true(effect is NoAgentImportEffect)
  let (picking, effect) = reduce_agent_import(
    bound,
    ChoosePackage(portable_book_test_id()),
  )
  assert_true(effect is PickAgentPackage(_, _))
  let (_, effect) = reduce_agent_import(
    picking,
    ChoosePackage(portable_book_test_id()),
  )
  assert_true(effect is NoAgentImportEffect)
  let (staging, effect) = reduce_agent_import(
    picking,
    PackagePicked(
      picking.generation,
      picking.request,
      Ok([agent_import_test_file()]),
    ),
  )
  assert_true(effect is StageAgentPackage(_, _, _))
  let (_, effect) = reduce_agent_import(staging, ImportInspectedPackage)
  assert_true(effect is NoAgentImportEffect)
  let (inspected, effect) = reduce_agent_import(
    staging,
    ImportResponse(
      staging.generation,
      staging.request,
      Ok(agent_import_test_reply("inspected")),
    ),
  )
  assert_true(effect is NoAgentImportEffect)
  assert_eq(inspected.session.status, "inspected")
  assert_false(agent_import_can_write(inspected))
  for
    value in [
      "", "../escape", "/absolute", "a/b", "a\\b", ".", "..", "space name",
    ] {
    let (invalid, _) = reduce_agent_import(
      inspected,
      SetImportDestination(value),
    )
    assert_false(agent_import_can_write(invalid))
  }
  let (ready, _) = reduce_agent_import(
    inspected,
    SetImportDestination("new-folder"),
  )
  assert_true(agent_import_can_write(ready))
  let (importing, effect) = reduce_agent_import(ready, ImportInspectedPackage)
  assert_true(effect is WriteAgentImport(_, _))
  assert_true(importing.session.import_started)
  let (_, effect) = reduce_agent_import(importing, ImportInspectedPackage)
  assert_true(effect is NoAgentImportEffect)
  let (imported, effect) = reduce_agent_import(
    importing,
    ImportResponse(
      importing.generation,
      importing.request,
      Ok(agent_import_test_reply("imported", destination="new-folder")),
    ),
  )
  assert_true(effect is NoAgentImportEffect)
  assert_eq(imported.session.status, "imported")
  let (opening, effect) = reduce_agent_import(imported, OpenImportedPackage)
  assert_true(effect is ReadAgentImport(_, _))
  let (_, effect) = reduce_agent_import(
    opening,
    ImportResponse(
      opening.generation,
      opening.request,
      Ok(agent_import_test_reply("imported", destination="new-folder")),
    ),
  )
  assert_true(
    effect
    is OpenAgentImport(
      { workspace_id: "book-new-folder", book_id: "original-book-id", .. }
    ),
  )
}

///|
test "package receive cancel reselect and navigation invalidate picker and late responses" {
  let (bound, _) = reduce_agent_import(
    init_agent_import(),
    BindAgentImport(true, "/library-a", "context"),
  )
  let (picking, _) = reduce_agent_import(
    bound,
    ChoosePackage(portable_book_test_id()),
  )
  let (cancelled, _) = reduce_agent_import(picking, CancelPackage)
  let (late, effect) = reduce_agent_import(
    cancelled,
    PackagePicked(
      picking.generation,
      picking.request,
      Ok([agent_import_test_file()]),
    ),
  )
  assert_true(effect is NoAgentImportEffect)
  assert_eq(late.session.operation_id, "")
  let (none, _) = reduce_agent_import(
    picking,
    PackagePicked(picking.generation, picking.request, Ok([])),
  )
  assert_eq(none.session.status, "empty")
  let (reselected, _) = reduce_agent_import(
    cancelled,
    ChoosePackage("abcdef0123456789abcdef0123456789"),
  )
  let (late, effect) = reduce_agent_import(
    reselected,
    PackagePicked(
      picking.generation,
      picking.request,
      Ok([agent_import_test_file()]),
    ),
  )
  assert_true(effect is NoAgentImportEffect)
  assert_eq(late.session.operation_id, "abcdef0123456789abcdef0123456789")
  let stage = agent_import_test_pending_stage()
  let (away, _) = reduce_agent_import(
    stage,
    BindAgentImport(true, "/library-a", "new-navigation"),
  )
  let (late, effect) = reduce_agent_import(
    away,
    ImportResponse(
      stage.generation,
      stage.request,
      Ok(agent_import_test_reply("inspected")),
    ),
  )
  assert_true(effect is NoAgentImportEffect)
  assert_eq(late.session.status, "uncertain")
  let (_, effect) = reduce_agent_import(late, CheckImport)
  assert_true(effect is ReadAgentImport(_, _))
}

///|
test "package receive timeout partial and library switch retain read only recovery" {
  let importing = agent_import_test_importing()
  let (timed_out, _) = reduce_agent_import(
    importing,
    ImportTimedOut(importing.generation, importing.request),
  )
  assert_eq(timed_out.session.status, "uncertain")
  let (cancelled, _) = reduce_agent_import(timed_out, CancelPackage)
  assert_eq(cancelled.session.operation_id, importing.session.operation_id)
  let (_, effect) = reduce_agent_import(cancelled, ImportInspectedPackage)
  assert_true(effect is NoAgentImportEffect)
  let (other_library, _) = reduce_agent_import(
    timed_out,
    BindAgentImport(true, "/library-b", "context"),
  )
  assert_eq(other_library.session.operation_id, "")
  assert_eq(other_library.suspended.length(), 1)
  let (_, effect) = reduce_agent_import(
    other_library,
    ImportResponse(
      importing.generation,
      importing.request,
      Ok(agent_import_test_reply("imported", destination="new-folder")),
    ),
  )
  assert_true(effect is NoAgentImportEffect)
  let (returned, _) = reduce_agent_import(
    other_library,
    BindAgentImport(true, "/library-a", "context"),
  )
  assert_eq(returned.session.status, "uncertain")
  assert_eq(returned.session.destination, "new-folder")
  let (checking, effect) = reduce_agent_import(returned, CheckImport)
  assert_true(effect is ReadAgentImport(_, _))
  let (partial, effect) = reduce_agent_import(
    checking,
    ImportResponse(
      checking.generation,
      checking.request,
      Ok(agent_import_test_reply("partial", destination="new-folder")),
    ),
  )
  assert_true(effect is NoAgentImportEffect)
  assert_eq(partial.session.status, "partial")
  let (_, effect) = reduce_agent_import(partial, OpenImportedPackage)
  assert_true(effect is NoAgentImportEffect)
  let (_, effect) = reduce_agent_import(partial, ImportInspectedPackage)
  assert_true(effect is NoAgentImportEffect)
}

///|
test "package receive recovery distinguishes unstarted conflict from completed verified import" {
  let importing = agent_import_test_importing()
  let (failed, _) = reduce_agent_import(
    importing,
    ImportResponse(
      importing.generation,
      importing.request,
      Err("destination exists"),
    ),
  )
  let (checking, _) = reduce_agent_import(failed, CheckImport)
  let (unstarted, _) = reduce_agent_import(
    checking,
    ImportResponse(
      checking.generation,
      checking.request,
      Ok(agent_import_test_reply("inspected")),
    ),
  )
  assert_false(unstarted.session.import_started)
  assert_eq(unstarted.session.status, "inspected")
  let (renamed, _) = reduce_agent_import(
    unstarted,
    SetImportDestination("another-folder"),
  )
  assert_true(agent_import_can_write(renamed))
  let (checking, _) = reduce_agent_import(failed, CheckImport)
  let (complete, effect) = reduce_agent_import(
    checking,
    ImportResponse(
      checking.generation,
      checking.request,
      Ok(agent_import_test_reply("imported", destination="new-folder")),
    ),
  )
  assert_true(effect is NoAgentImportEffect)
  assert_eq(complete.session.status, "imported")
}

///|
test "package receive refuses changed proof wrong library destination and member drift" {
  let importing = agent_import_test_importing()
  let prepared = portable_book_test_package()
  let changed = {
    ..prepared,
    source: { ..prepared.source, package_size_bytes: 1201, },
  }
  for
    wire in [
      agent_import_test_reply(
        "imported",
        destination="new-folder",
        library="/library-b",
      ),
      agent_import_test_reply("imported", destination="other-folder"),
      agent_import_test_reply(
        "imported",
        destination="new-folder",
        prepared=changed,
      ),
      agent_import_test_reply("imported", destination="new-folder", changed=[
        "memory/preferences.json",
      ]),
    ] {
    let (rejected, effect) = reduce_agent_import(
      importing,
      ImportResponse(importing.generation, importing.request, Ok(wire)),
    )
    assert_true(effect is NoAgentImportEffect)
    assert_eq(rejected.session.status, "uncertain")
    let (_, effect) = reduce_agent_import(rejected, OpenImportedPackage)
    assert_true(effect is NoAgentImportEffect)
  }
}

///|
test "package receive reload restores only recovery handles and never auto imports" {
  let importing = agent_import_test_importing()
  let saved = agent_import_recovery_json(importing).stringify()
  assert_false(saved.contains("accepted-knowledge"))
  assert_false(saved.contains("memory/preferences.json"))
  assert_false(saved.contains("data:application"))
  let sessions = agent_import_restore_sessions(saved)
  assert_eq(sessions.length(), 1)
  assert_eq(sessions[0].status, "uncertain")
  assert_true(sessions[0].reply is None)
  let restored = { ..init_agent_import(), suspended: sessions, }
  let (bound, effect) = reduce_agent_import(
    restored,
    BindAgentImport(true, "/library-a", "context"),
  )
  assert_true(effect is NoAgentImportEffect)
  assert_eq(bound.session.reviewed_sha, portable_book_test_sha())
  let (_, effect) = reduce_agent_import(bound, ImportInspectedPackage)
  assert_true(effect is NoAgentImportEffect)
  let (checking, effect) = reduce_agent_import(bound, CheckImport)
  assert_true(effect is ReadAgentImport(_, _))
  let (complete, _) = reduce_agent_import(
    checking,
    ImportResponse(
      checking.generation,
      checking.request,
      Ok(agent_import_test_reply("imported", destination="new-folder")),
    ),
  )
  assert_eq(complete.session.status, "imported")
  let prepared = portable_book_test_package()
  let changed = {
    ..prepared,
    source: {
      ..prepared.source,
      package_sha256: "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    },
  }
  let (rejected, _) = reduce_agent_import(
    checking,
    ImportResponse(
      checking.generation,
      checking.request,
      Ok(
        agent_import_test_reply(
          "imported",
          destination="new-folder",
          prepared=changed,
        ),
      ),
    ),
  )
  assert_eq(rejected.session.status, "uncertain")
  let (partial, _) = reduce_agent_import(
    checking,
    ImportResponse(
      checking.generation,
      checking.request,
      Ok(agent_import_test_reply("partial", destination="new-folder")),
    ),
  )
  assert_eq(partial.session.status, "partial")
  let (new_flow, effect) = reduce_agent_import(partial, KeepAttemptAndStartNew)
  assert_true(effect is NoAgentImportEffect)
  assert_eq(new_flow.session.operation_id, "")
  assert_eq(new_flow.suspended.length(), 1)
  assert_eq(new_flow.suspended[0].destination, "new-folder")
  let (selected, effect) = reduce_agent_import(
    new_flow,
    SelectSavedImport(portable_book_test_id()),
  )
  assert_true(effect is NoAgentImportEffect)
  assert_eq(selected.session.status, "uncertain")
  let (_, effect) = reduce_agent_import(selected, CheckImport)
  assert_true(effect is ReadAgentImport(_, _))
  assert_eq(agent_import_restore_sessions("not json").length(), 0)
  assert_eq(agent_import_restore_sessions("{}").length(), 0)
}

///|
test "package receive root open is fenced to current library and library picker" {
  let dispatch : Dispatch[Msg] = _ => @rabbita.none
  let importing = agent_import_test_importing()
  let (complete, _) = reduce_agent_import(
    importing,
    ImportResponse(
      importing.generation,
      importing.request,
      Ok(agent_import_test_reply("imported", destination="new-folder")),
    ),
  )
  let model = {
    ..init_model(),
    workspace_mode: Desk,
    workspace_library_path: "/library-a",
    agent_import: complete,
  }
  let (_, opening) = update_agent_import(dispatch, OpenImportedPackage, model)
  assert_eq(opening.selected_workspace_id, model.selected_workspace_id)
  let (_, opened) = update_agent_import(
    dispatch,
    ImportResponse(
      opening.agent_import.generation,
      opening.agent_import.request,
      Ok(agent_import_test_reply("imported", destination="new-folder")),
    ),
    opening,
  )
  assert_eq(opened.selected_workspace_id, "book-new-folder")
  assert_eq(opened.requested_workspace_id, "book-new-folder")
  assert_eq(opened.selected_path, "wiki/index.md")
  assert_eq(opened.import_book_status, "imported original-book-id")
  let (_, blocked) = update_agent_import(dispatch, OpenImportedPackage, {
    ..model,
    workspace_library_path: "/library-b",
  })
  assert_eq(blocked.selected_workspace_id, model.selected_workspace_id)
  let (_, blocked) = update_agent_import(
    dispatch,
    ImportResponse(
      opening.agent_import.generation,
      opening.agent_import.request,
      Ok(agent_import_test_reply("imported", destination="new-folder")),
    ),
    { ..opening, workspace_library_path: "/library-b", },
  )
  assert_eq(blocked.selected_workspace_id, model.selected_workspace_id)
  let (away, _) = reduce_agent_import(
    opening.agent_import,
    BindAgentImport(true, "/library-a", "new-navigation"),
  )
  let (_, effect) = reduce_agent_import(
    away,
    ImportResponse(
      opening.agent_import.generation,
      opening.agent_import.request,
      Ok(agent_import_test_reply("imported", destination="new-folder")),
    ),
  )
  assert_true(effect is NoAgentImportEffect)
  let changed = agent_import_library_transition(PickLibraryFolder, model)
  let (_, blocked) = update_agent_import(dispatch, OpenImportedPackage, changed)
  assert_eq(blocked.selected_workspace_id, model.selected_workspace_id)
}

///|
#warnings("-alert_unstable")
test "package receive renders all actual retained export proof contents with collapsed technical details" {
  let wire = portable_book_actual_wire_fixture()
  guard portable_book_decode_prepared(
      wire,
      handoff_text(wire, "expected_library"),
      handoff_text(wire, "workspace_id"),
      handoff_text(wire, "export_id"),
    )
    is Some(prepared) else {
    fail("actual retained export proof did not decode")
  }
  let staging = agent_import_test_pending_stage()
  let (inspected, _) = reduce_agent_import(
    staging,
    ImportResponse(
      staging.generation,
      staging.request,
      Ok(agent_import_test_reply("inspected", prepared~)),
    ),
  )
  guard inspected.session.reply is Some(reply) else {
    fail("actual package proof rejected")
  }
  assert_eq(reply.source.package_size_bytes, 707957)
  let dispatch : Dispatch[Msg] = _ => @rabbita.none
  let model = {
    ..init_model(),
    workspace_mode: Desk,
    workspace_library_path: "/library-a",
    agent_import: inspected,
  }
  let html = @rabbita.render_to_string(
    @rabbita.static_cell(render_agent_import(dispatch, model)),
  )
  assert_eq(
    html.split("data-testid=\"agent-import-member\"").length(),
    reply.inspection.file_count + 1,
  )
  for file in reply.inspection.files {
    assert_true(html.contains(file.path))
    assert_true(html.contains(file.role))
    assert_true(html.contains(file.sensitivity))
    assert_true(html.contains(file.digest))
  }
  assert_true(html.contains("Contains user-private content: 2 file(s)"))
  assert_true(html.contains("Technical details</summary>"))
  assert_false(html.contains("<details open"))
  assert_true(html.contains("3. Choose a new folder"))
  assert_true(html.contains("4. Import into this library"))
  assert_false(html.contains("data-testid=\"agent-import-open\""))
}
