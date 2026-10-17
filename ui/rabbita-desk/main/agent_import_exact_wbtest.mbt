///|
fn exact_import_test_binding() -> Json {
  {
    "contract": "moontown.portable-listing-binding.v1",
    "binding_digest": "sha256:" + "e".repeat(64),
    "listing_id": "listing-original",
    "publisher_principal_id": "publisher-original",
    "tenant_id": "tenant-original",
    "source": {
      "package_sha256": portable_book_test_package().source.package_sha256,
    },
  }
}

///|
fn exact_import_test_file() -> LocalImportFile {
  {
    ..agent_import_test_file(),
    name: "download.moonbook-agent.binding.json",
    content: exact_import_test_binding().stringify(),
  }
}

///|
fn exact_import_awaiting_binding() -> AgentImportState raise {
  let (bound, _) = reduce_agent_import(
    init_agent_import(),
    BindAgentImport(true, "/library-a", "context"),
  )
  let (picking, _) = reduce_agent_import(
    bound,
    ChooseExactPackage(portable_book_test_id()),
  )
  let (waiting, effect) = reduce_agent_import(
    picking,
    PackagePicked(
      picking.generation,
      picking.request,
      Ok([agent_import_test_file()]),
    ),
  )
  assert_true(effect is NoAgentImportEffect)
  assert_eq(waiting.session.status, "awaiting-binding")
  assert_true(waiting.package_file is Some(_))
  waiting
}

///|
fn exact_import_test_staging() -> AgentImportState raise {
  let (picking, effect) = reduce_agent_import(
    exact_import_awaiting_binding(),
    ChooseBinding,
  )
  assert_true(effect is PickAgentBinding(_, _))
  let (staging, effect) = reduce_agent_import(
    picking,
    BindingPicked(
      picking.generation,
      picking.request,
      Ok([exact_import_test_file()]),
    ),
  )
  assert_true(effect is StageExactAgentPackage(_, _, _, _))
  assert_true(staging.package_file is None)
  staging
}

///|
fn exact_import_test_reply(
  status : String,
  destination~ : String = "",
) -> Json raise {
  guard agent_import_test_reply(status, destination~) is Object(fields) else {
    fail("fixture")
  }
  fields["town_binding"] = exact_import_test_binding()
  fields["exact_import_receipt"] = if status == "imported" {
    {
      "contract": "moonbook.portable_import_receipt.v1",
      "status": "complete",
      "binding_digest": "sha256:" + "e".repeat(64),
      "member_bytes_verified": true,
      "source": handoff_field(exact_import_test_binding(), "source"),
      "listing_id": "listing-original",
      "publisher_principal_id": "publisher-original",
      "tenant_id": "tenant-original",
      "local_book_id": destination,
      "local_target_root": "/library-a/" + destination,
    }
  } else {
    Json::null()
  }
  Json::object(fields)
}

///|
fn exact_import_test_inspected() -> AgentImportState raise {
  let staging = exact_import_test_staging()
  let (inspected, _) = reduce_agent_import(
    staging,
    ImportResponse(
      staging.generation,
      staging.request,
      Ok(exact_import_test_reply("inspected")),
    ),
  )
  assert_eq(inspected.session.status, "inspected")
  inspected
}

///|
test "Town exact import chooses two files explicitly and never silently falls back" {
  let waiting = exact_import_awaiting_binding()
  assert_false(agent_import_can_write(waiting))
  assert_eq(
    agent_import_recovery_json({ ..waiting, suspended: [], }),
    Json::array([]),
  )
  let (_, effect) = reduce_agent_import(waiting, ImportInspectedPackage)
  assert_true(effect is NoAgentImportEffect)
  for
    result in [
      Ok([]),
      Err("unreadable"),
      Ok([{ ..exact_import_test_file(), content: "{}", }]),
    ] {
    let (picking, _) = reduce_agent_import(waiting, ChooseBinding)
    let (cancelled, effect) = reduce_agent_import(
      picking,
      BindingPicked(picking.generation, picking.request, result),
    )
    assert_true(effect is NoAgentImportEffect)
    assert_true(cancelled.session.exact_required)
    assert_eq(cancelled.session.status, "awaiting-binding")
    assert_false(agent_import_can_write(cancelled))
    assert_true(cancelled.package_file is Some(_))
  }
  let staging = exact_import_test_staging()
  let (mismatch, _) = reduce_agent_import(
    staging,
    ImportResponse(
      staging.generation,
      staging.request,
      Ok(agent_import_test_reply("inspected")),
    ),
  )
  assert_eq(mismatch.session.status, "uncertain")
  assert_false(agent_import_can_write(mismatch))
  let ordinary = agent_import_test_pending_stage()
  assert_true(
    agent_import_decode_reply(
      exact_import_test_reply("inspected"),
      ordinary.session,
    )
    is None,
  )
}

///|
test "Town exact import repeated clicks cancellation navigation and late replies remain fenced" {
  let waiting = exact_import_awaiting_binding()
  let (picking, _) = reduce_agent_import(waiting, ChooseBinding)
  let (_, effect) = reduce_agent_import(picking, ChooseBinding)
  assert_true(effect is NoAgentImportEffect)
  let (cancelled, _) = reduce_agent_import(picking, CancelPackage)
  assert_true(cancelled.package_file is None)
  let (late, effect) = reduce_agent_import(
    cancelled,
    BindingPicked(
      picking.generation,
      picking.request,
      Ok([exact_import_test_file()]),
    ),
  )
  assert_true(effect is NoAgentImportEffect)
  assert_eq(late.session.operation_id, "")
  let (changed, _) = reduce_agent_import(
    picking,
    BindAgentImport(true, "/library-b", "other"),
  )
  let (late, effect) = reduce_agent_import(
    changed,
    BindingPicked(
      picking.generation,
      picking.request,
      Ok([exact_import_test_file()]),
    ),
  )
  assert_true(effect is NoAgentImportEffect)
  assert_eq(late.session.library, "/library-b")
  assert_true(late.package_file is None)
  let (away, _) = reduce_agent_import(
    waiting,
    BindAgentImport(false, "/library-a", "away"),
  )
  assert_eq(away.session.operation_id, "")
  assert_true(away.package_file is None)
}

///|
test "Town exact import recovery retains binding and requires an exact completion receipt before Open" {
  let (ready, _) = reduce_agent_import(
    exact_import_test_inspected(),
    SetImportDestination("new-folder"),
  )
  let (importing, effect) = reduce_agent_import(ready, ImportInspectedPackage)
  assert_true(effect is WriteAgentImport(_, _))
  let (_, effect) = reduce_agent_import(importing, ImportInspectedPackage)
  assert_true(effect is NoAgentImportEffect)
  let restored = agent_import_restore_sessions(
    agent_import_recovery_json({ ..importing, suspended: [], }).stringify(),
  )
  assert_eq(restored.length(), 1)
  assert_true(restored[0].exact_required)
  assert_eq(restored[0].binding_digest, importing.session.binding_digest)
  assert_eq(restored[0].status, "uncertain")
  guard exact_import_test_reply("imported", destination="new-folder")
    is Object(fields) else {
    fail("fixture")
  }
  let missing = fields.copy()
  missing["exact_import_receipt"] = Json::null()
  assert_true(
    agent_import_decode_reply(Json::object(missing), importing.session) is None,
  )
  let (complete, _) = reduce_agent_import(
    importing,
    ImportResponse(
      importing.generation,
      importing.request,
      Ok(Json::object(fields)),
    ),
  )
  assert_eq(complete.session.status, "imported")
  let (checking, effect) = reduce_agent_import(complete, OpenImportedPackage)
  assert_true(effect is ReadAgentImport(_, _))
  let (_, effect) = reduce_agent_import(
    checking,
    ImportResponse(
      checking.generation,
      checking.request,
      Ok(Json::object(fields)),
    ),
  )
  assert_true(effect is OpenAgentImport(_))
  let changed = fields.copy()
  guard exact_import_test_binding() is Object(binding) else { fail("fixture") }
  binding["listing_id"] = "different-listing".to_json()
  changed["town_binding"] = Json::object(binding)
  assert_true(
    agent_import_decode_reply(Json::object(changed), complete.session) is None,
  )
}

///|
test "Town exact import view explains original binding privacy ordinary route and no execution" {
  let dispatch : Dispatch[Msg] = _ => @rabbita.none
  let inspected = exact_import_test_inspected()
  let model = {
    ..init_model(),
    workspace_library_path: "/library-a",
    agent_import: inspected,
  }
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_agent_import(dispatch, model)),
  )
  assert_true(markup.contains("publisher-original"))
  assert_true(markup.contains("listing-original"))
  assert_true(markup.contains("not a signature"))
  assert_true(markup.contains("does not launch packaged apps"))
  let waiting = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_agent_import(dispatch, {
        ..model,
        agent_import: exact_import_awaiting_binding(),
      }),
    ),
  )
  assert_true(waiting.contains(".receipt.json"))
  assert_true(waiting.contains("cancel and use Choose package"))
  assert_true(waiting.contains("only to this Desk host"))
}
