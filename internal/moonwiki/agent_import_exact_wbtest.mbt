///|
fn receive_exact_binding(source : Json) -> Json {
  let unsigned : Json = {
    "contract": "moontown.portable-listing-binding.v1",
    "listing_id": "synthetic-listing-v1",
    "publisher_principal_id": "synthetic-publisher",
    "tenant_id": "synthetic-tenant",
    "binding_revision": 1,
    "source": source,
    "reuse_mode": "local_file_import",
    "verification_scope": "publisher_declared_expected_source",
  }
  guard unsigned is Object(fields) else { abort("fixture") }
  let digest = agent_import_hash(@encoding/utf8.encode(unsigned.stringify()))
  fields["binding_digest"] = digest.to_json()
  Json::object(fields)
}

///|
fn receive_exact_runner(
  calls : Array[String],
  outcome~ : String = "complete",
) -> AgentExportRun {
  let ordinary = receive_test_runner(calls, outcome~)
  (command, args) => {
    if command != "import-exact" {
      return ordinary(command, args)
    }
    calls.push(command)
    let result = ordinary("import", args)
    let path = args[0] + "/.moonbook/agent/receipts/local.json"
    if !@fs.exists(path) {
      return result
    }
    guard @json.parse(@fs.read_file(path).text()) is Object(fields) else {
      fail("fixture")
    }
    fields["action"] = "import-exact".to_json()
    fields["receipt_id"] = "synthetic-installation".to_json()
    @fs.write_file(
      path,
      Json::object(fields).stringify(),
      create_mode=TruncateExisting,
    )
    if outcome == "no-exact-receipt" {
      return Err("interrupted before exact receipt")
    }
    let binding = @json.parse(@fs.read_file(args[2]).text())
    guard binding is Object(binding_fields) else { fail("fixture") }
    let receipt : Json = {
      "contract": "moonbook.portable_import_receipt.v1",
      "source": binding_fields["source"],
      "listing_id": binding_fields["listing_id"],
      "publisher_principal_id": binding_fields["publisher_principal_id"],
      "tenant_id": binding_fields["tenant_id"],
      "binding_digest": binding_fields["binding_digest"],
      "installation_receipt_id": "synthetic-installation",
      "local_target_root": args[0],
      "local_book_id": args[0].split("/").last().unwrap_or("").to_owned(),
      "imported_at": 1791230000000L.to_json(),
      "member_bytes_verified": true,
      "status": "complete",
    }
    @fs.write_file(
      args[0] + "/state/portable-source-binding.json",
      receipt.stringify(),
      create_mode=CreateNew,
    )
    result
  }
}

///|
async test "Town binding exact import preserves original binding and recovers a lost result without reimport" {
  let context = receive_test_context()
  defer @fs.rmdir(context.suite_root, recursive=true)
  let calls : Array[String] = []
  let run = receive_exact_runner(calls, outcome="lost-response")
  let source = agent_export_json(run, "source", ["not-read-by-fixture"])
  let binding = receive_exact_binding(source)
  let stage = { ..receive_test_stage(context), town_binding: Some(binding), }
  let inspected = agent_import_stage_with(context, stage, run)
  assert_true(
    inspected is { "town_binding": original, .. } && original == binding,
  )
  assert_eq(@fs.readdir(context.books_root).length(), 0)
  let request = {
    ..receive_test_request(context),
    binding_digest: Some(json_string(binding, "binding_digest", default="")),
  }
  let imported = agent_import_apply_with(context, request, run)
  assert_eq(json_string(imported, "status", default=""), "imported")
  assert_true(
    imported is { "exact_import_receipt": { "status": "complete", .. }, .. },
  )
  assert_eq(agent_import_apply_with(context, request, run), imported)
  assert_eq(
    agent_import_inspect_with(
      context,
      stage.operation_id,
      context.books_root,
      run,
    ),
    imported,
  )
  assert_eq(calls.filter(c => c == "import-exact").length(), 1)
  assert_true(
    try {
      ignore(
        agent_import_apply_with(context, receive_test_request(context), run),
      )
      false
    } catch {
      _ => true
    },
  )
  @fs.write_file(
    context.books_root + "/received/state/portable-source-binding.json",
    "{}",
    create_mode=TruncateExisting,
  )
  let partial = agent_import_inspect_with(
    context,
    stage.operation_id,
    context.books_root,
    run,
  )
  assert_eq(json_string(partial, "status", default=""), "partial")
  assert_true(partial is { "created": Null, .. })
  assert_eq(calls.filter(c => c == "import-exact").length(), 1)
}

///|
async test "Town binding mismatch invalid digest and replaced binding cannot import or invent provenance" {
  let context = receive_test_context()
  defer @fs.rmdir(context.suite_root, recursive=true)
  let calls : Array[String] = []
  let run = receive_exact_runner(calls)
  let source = agent_export_json(run, "source", ["fixture"])
  guard receive_exact_binding(source) is Object(binding_fields) else {
    fail("fixture")
  }
  let wrong = binding_fields.copy()
  wrong["binding_digest"] = ("sha256:" + "0".repeat(64)).to_json()
  assert_true(
    try {
      ignore(agent_import_checked_binding(Json::object(wrong), source))
      false
    } catch {
      _ => true
    },
  )
  let wrong_source = binding_fields.copy()
  wrong_source["source"] = Json::null()
  assert_true(
    try {
      ignore(agent_import_checked_binding(Json::object(wrong_source), source))
      false
    } catch {
      _ => true
    },
  )
  let binding = Json::object(binding_fields)
  let stage = { ..receive_test_stage(context), town_binding: Some(binding), }
  ignore(agent_import_stage_with(context, stage, run))
  @fs.mkdir(context.books_root + "/existing")
  let collision = agent_import_apply_with(
    context,
    {
      ..receive_test_request(context, folder="existing"),
      binding_digest: Some(json_string(binding, "binding_digest", default="")),
    },
    run,
  )
  assert_eq(json_string(collision, "status", default=""), "inspected")
  assert_eq(json_string(collision, "destination_folder", default=""), "")
  assert_true(
    try {
      ignore(
        agent_import_apply_with(context, receive_test_request(context), run),
      )
      false
    } catch {
      _ => true
    },
  )
  assert_eq(@fs.readdir(context.books_root), ["existing"])
  let replacement = binding_fields.copy()
  replacement["listing_id"] = "different-listing".to_json()
  assert_true(
    try {
      ignore(
        agent_import_stage_with(
          context,
          { ..stage, town_binding: Some(Json::object(replacement)), },
          run,
        ),
      )
      false
    } catch {
      _ => true
    },
  )
  @fs.write_file(
    agent_import_root(context) + "/" + stage.operation_id + "/town-binding.json",
    "{}",
    create_mode=TruncateExisting,
  )
  assert_true(
    try {
      ignore(
        agent_import_inspect_with(
          context,
          stage.operation_id,
          context.books_root,
          run,
        ),
      )
      false
    } catch {
      _ => true
    },
  )
  assert_eq(calls.filter(c => c == "import-exact").length(), 0)
}

///|
async test "exact import interrupted before provenance receipt stays partial and cannot replay" {
  let context = receive_test_context()
  defer @fs.rmdir(context.suite_root, recursive=true)
  let calls : Array[String] = []
  let run = receive_exact_runner(calls, outcome="no-exact-receipt")
  let binding = receive_exact_binding(
    agent_export_json(run, "source", ["fixture"]),
  )
  ignore(
    agent_import_stage_with(
      context,
      { ..receive_test_stage(context), town_binding: Some(binding), },
      run,
    ),
  )
  let request = {
    ..receive_test_request(context),
    binding_digest: Some(json_string(binding, "binding_digest", default="")),
  }
  let partial = agent_import_apply_with(context, request, run)
  assert_eq(json_string(partial, "status", default=""), "partial")
  assert_true(partial is { "created": Null, "exact_import_receipt": Null, .. })
  assert_eq(agent_import_apply_with(context, request, run), partial)
  assert_eq(
    agent_import_inspect_with(
      context,
      request.operation_id,
      context.books_root,
      run,
    ),
    partial,
  )
  assert_eq(calls.filter(command => command == "import-exact").length(), 1)
  assert_true(@fs.exists(context.books_root + "/received/USER.md"))
}

///|
async test "actual Town downloaded package exact import retains discoverable provenance without execution" {
  guard @env.get_env_var("MOONDESK_AGENT_EXACT_PACKAGE") is Some(package_path) &&
    @env.get_env_var("MOONDESK_AGENT_EXACT_BINDING") is Some(binding_path) &&
    @env.get_env_var("MOONDESK_AGENT_EXACT_EVIDENCE") is Some(evidence) else {
    return
  }
  let root = @fs.realpath(@fs.tmpdir(prefix="desk-exact-acceptance-"))
  @fs.mkdir(root + "/books")
  let context = workspace_context(root)
  let bytes = @fs.read_file(package_path).binary()
  let binding = @json.parse(@fs.read_file(binding_path).text())
  let runtime = @trusted_host.moonbook_import_runtime(exact=true).unwrap()
  let run = agent_import_runtime_runner(runtime, root)
  let request : AgentImportStage = {
    operation_id: receive_test_id(),
    expected_library: context.books_root,
    filename: "received-original.moonbook-agent",
    bytes,
    town_binding: Some(binding),
  }
  let staged = agent_import_stage_with(context, request, run)
  assert_eq(json_string(staged, "status", default=""), "inspected")
  assert_eq(@fs.readdir(context.books_root).length(), 0)
  let apply : AgentImportRequest = {
    operation_id: request.operation_id,
    expected_library: context.books_root,
    destination_folder: "town-received",
    package_sha256: agent_import_hash(bytes),
    binding_digest: Some(json_string(binding, "binding_digest", default="")),
  }
  let imported = agent_import_apply_with(context, apply, run)
  assert_eq(json_string(imported, "status", default=""), "imported")
  assert_eq(agent_import_apply_with(context, apply, run), imported)
  assert_eq(
    agent_import_inspect_with(
      context,
      request.operation_id,
      context.books_root,
      run,
    ),
    imported,
  )
  let destination = context.books_root + "/town-received"
  let exact_receipt = agent_import_read_json(
    destination + "/state/portable-source-binding.json",
    131072,
  )
  assert_true(
    exact_receipt is { "source": expected, .. } &&
    binding is { "source": original, .. } &&
    expected == original,
  )
  let workspace = find_workspace(root, @desk.stable_id("book", "town-received")).unwrap()
  assert_eq(workspace.root_path, destination)
  @fsx.make_directory(evidence, recursive=true, exists_ok=true)
  @fs.write_file(
    evidence + "/actual-exact-import-proof.json",
    (
      {
        "staged": staged,
        "imported": imported,
        "workspace_root": root,
        "books_root": context.books_root,
        "book_root": destination,
        "binding": binding,
        "package_sha256": agent_import_hash(bytes),
        "no_provider": true,
        "no_socket": true,
        "no_agent_or_app_execution": true,
      } : Json).stringify(indent=2),
    create_mode=CreateNew,
  )
}
