///|
// Serialize operation reservations and reads with the single import mutation.
// A persisted request is consumed even if the process result is uncertain.
let agent_import_mutex : @async.Mutex = Mutex()

///|
async fn agent_import_read_json(path : String, maximum : Int) -> Json {
  agent_import_regular_file(path, maximum)
  @json.parse(agent_export_bounded_text(path, maximum))
}

///|
async fn agent_import_workspace_identity_count(
  context : WorkspaceContext,
  workspace_id : String,
) -> Int {
  let mut count = 0
  for folder in read_directory_names(context.books_root, include_hidden=false) {
    if @desk.stable_id("book", folder) == workspace_id &&
      is_directory(context.books_root + "/" + folder) {
      count += 1
    }
  }
  count
}

///|
async fn agent_import_inspect_with(
  context : WorkspaceContext,
  id : String,
  expected_library : String,
  run : AgentExportRun,
) -> Json {
  guard agent_export_id_valid(id) else { fail("Invalid receive operation") }
  agent_import_context(context, expected_library)
  let directory = agent_import_root(context) + "/" + id
  agent_import_canonical_directory(directory)
  let manifest = agent_import_read_json(directory + "/received.json", 8192)
  guard json_string(manifest, "operation_id", default="") == id &&
    json_string(manifest, "expected_library", default="") == expected_library else {
    fail("Received package belongs to another operation or library")
  }
  let package_path = directory + "/package.moonbook-agent"
  agent_import_regular_file(package_path, agent_import_package_limit)
  let source = agent_import_read_json(directory + "/source.json", 131072)
  let (before_hash, before_size) = agent_import_package_identity(package_path)
  guard before_hash == json_string(manifest, "package_sha256", default="") &&
    before_size ==
    json_int(manifest, "package_size_bytes", default=-1).to_int64() &&
    before_hash == json_string(source, "package_sha256", default="") else {
    fail("Received package changed after review")
  }
  let verification = agent_export_json(run, "verify", [package_path])
  let inspection = agent_export_json(run, "inspect", [package_path])
  let current_source = agent_export_json(run, "source", [package_path])
  guard source == current_source &&
    agent_export_metadata_valid(inspection, verification, source) &&
    agent_import_package_identity(package_path) == (before_hash, before_size) else {
    fail("Received package verification or source proof changed")
  }
  let town_binding = agent_import_retained_binding(directory, manifest, source)
  let response : Map[String, Json] = {
    "operation_id": id.to_json(),
    "expected_library": expected_library.to_json(),
    "status": "inspected".to_json(),
    "filename": json_string(manifest, "filename", default="").to_json(),
    "destination_folder": "".to_json(),
    "inspection": inspection,
    "verification": verification,
    "source": source,
    "import_verification": Json::null(),
    "created": Json::null(),
    "message": "Package verified. Review its contents before importing.".to_json(),
    "town_binding": town_binding.unwrap_or(Json::null()),
    "exact_import_receipt": Json::null(),
  }
  let request_path = directory + "/import-request.json"
  if !agent_import_path_present(request_path) {
    return Json::object(response)
  }
  let request = match
    agent_import_request(agent_import_read_json(request_path, 8192)) {
    Ok(value) => value
    Err(_) => fail("Saved import reservation is invalid")
  }
  guard request.operation_id == id &&
    request.expected_library == expected_library &&
    request.package_sha256 == before_hash else {
    fail("Import reservation does not match the received package")
  }
  guard request.binding_digest ==
    town_binding.map(binding => {
      json_string(binding, "binding_digest", default="")
    }) else {
    fail("Import reservation does not match the retained Town binding")
  }
  response["destination_folder"] = request.destination_folder.to_json()
  let destination = context.books_root + "/" + request.destination_folder
  response["status"] = "uncertain".to_json()
  response["message"] = "The import was started. Check its result; this operation will not import again.".to_json()
  if !agent_import_path_present(destination) {
    return Json::object(response)
  }
  response["status"] = "partial".to_json()
  response["message"] = "A destination exists, but its imported files could not all be verified. It has been left in place.".to_json()
  let verified = try {
    agent_import_canonical_directory(destination)
    for entry in @mooncore.json_array_items(inspection, "files") {
      let path = json_string(entry, "path", default="")
      agent_import_regular_file(destination + "/" + path, 16 * 1024 * 1024)
    }
    let member_verification = agent_export_json(run, "verify-import", [
      destination, package_path,
    ])
    guard member_verification
      is { "ok": True, "changed_members": Array([]), .. } else {
      fail("Imported members do not match")
    }
    // Require the ordinary Book importer’s completed installation record.
    // A matching directory or a half-written receipt alone is not completion.
    let state = agent_import_read_json(
      destination + "/state/agent-installation.json",
      131072,
    )
    let receipt_relative = json_string(state, "receipt_path", default="")
    guard receipt_relative.has_prefix(".moonbook/agent/receipts/") &&
      clean_relative_path(receipt_relative) == Some(receipt_relative) &&
      json_string(state, "contract", default="") ==
      "moonbook.agent_installation.v1" &&
      json_string(state, "agent_id", default="") ==
      json_string(source, "agent_id", default="") &&
      json_string(state, "version", default="") ==
      json_string(source, "agent_version", default="") &&
      json_string(state, "bundle_digest", default="") ==
      json_string(source, "bundle_digest", default="") else {
      fail("Imported installation state does not match")
    }
    let receipt = agent_import_read_json(
      destination + "/" + receipt_relative,
      8 * 1024 * 1024,
    )
    guard json_string(receipt, "contract", default="") ==
      "moonbook.agent_installation_receipt.v1" &&
      json_string(receipt, "action", default="") ==
      (if town_binding is Some(_) { "import-exact" } else { "import" }) &&
      json_string(receipt, "target_root", default="") == destination &&
      json_string(receipt, "bundle_digest", default="") ==
      json_string(source, "bundle_digest", default="") &&
      json_string(receipt, "agent_id", default="") ==
      json_string(source, "agent_id", default="") &&
      json_string(receipt, "version", default="") ==
      json_string(source, "agent_version", default="") &&
      @mooncore.json_array_items(receipt, "applied_files") ==
      @mooncore.json_array_items(inspection, "files").map(file => {
        json_string(file, "path", default="").to_json()
      }) &&
      agent_import_package_identity(package_path) == (before_hash, before_size) else {
      fail("Imported receipt or package source does not match")
    }
    let metadata = agent_import_book_metadata(destination)
    let exact_receipt = match town_binding {
      Some(binding) => agent_import_exact_receipt(destination, binding, receipt)
      None => Json::null()
    }
    let declared_id = json_string(metadata, "id", default="")
    let book_id = if declared_id == "" {
      json_string(source, "agent_id", default="")
    } else {
      declared_id
    }
    let title = json_string(
      metadata,
      "title",
      default=request.destination_folder,
    )
    let workspace_id = @desk.stable_id("book", request.destination_folder)
    // The discovery sorter coalesces duplicate IDs, so inspect raw directory
    // identities as well as the actual discovery result before allowing Open.
    let identity_count = agent_import_workspace_identity_count(
      context, workspace_id,
    )
    let matching = discover_workspaces(context.suite_root).filter(workspace => {
      workspace.id == workspace_id
    })
    guard identity_count == 1 &&
      matching.length() == 1 &&
      matching[0].root_path == destination else {
      fail("The imported workspace identifier is ambiguous")
    }
    let created : Json = {
      "workspace_id": workspace_id,
      "book_id": book_id,
      "name": if title == "" {
        request.destination_folder
      } else {
        title
      },
      "root_path": destination,
      "path": import_initial_path(destination),
    }
    Some((member_verification, created, exact_receipt))
  } catch {
    _ => None
  }
  if verified is Some((member_verification, created, exact_receipt)) {
    response["status"] = "imported".to_json()
    response["import_verification"] = member_verification
    response["created"] = created
    response["exact_import_receipt"] = exact_receipt
    response["message"] = "Imported Book verified and ready to open.".to_json()
  }
  Json::object(response)
}

///|
async fn agent_import_book_metadata(destination : String) -> Json {
  // Read canonical imported identity without writing or synthesizing book.json.
  let toml_path = destination + "/book.toml"
  if agent_import_path_present(toml_path) {
    agent_import_regular_file(toml_path, 16 * 1024 * 1024)
    return moonbook_toml_book_metadata(
      agent_export_bounded_text(toml_path, 16 * 1024 * 1024),
    )
  }
  let metadata = agent_import_read_json(
    destination + "/book.json",
    16 * 1024 * 1024,
  )
  {
    "id": json_first_string(metadata, ["id", "book_id"], default=""),
    "title": json_first_string(metadata, ["title", "name"], default=""),
  }
}

///|
async fn agent_import_stage_with(
  context : WorkspaceContext,
  request : AgentImportStage,
  run : AgentExportRun,
  is_current? : () -> Bool = () => true,
) -> Json {
  agent_import_mutex.acquire()
  defer agent_import_mutex.release()
  guard is_current() else { fail("The active library changed") }
  agent_import_context(context, request.expected_library)
  agent_import_prepare_directory(context)
  guard is_current() else { fail("The active library changed") }
  let directory = agent_import_root(context) + "/" + request.operation_id
  let manifest = agent_import_manifest(request)
  if agent_import_path_present(directory) {
    guard agent_import_read_json(directory + "/received.json", 8192) == manifest else {
      fail("Receive operation already belongs to different file bytes")
    }
    return agent_import_inspect_with(
      context,
      request.operation_id,
      request.expected_library,
      run,
    )
  }
  @fs.mkdir(directory, permission=0o700)
  @fs.write_file(
    directory + "/received.json",
    manifest.stringify(),
    create_mode=CreateNew,
    permission=0o600,
  )
  let package_path = directory + "/package.moonbook-agent"
  @fs.write_file(
    package_path,
    request.bytes,
    create_mode=CreateNew,
    permission=0o600,
  )
  let source = agent_export_json(run, "source", [package_path])
  guard json_string(source, "package_sha256", default="") ==
    agent_import_hash(request.bytes) &&
    json_int(source, "package_size_bytes", default=-1) == request.bytes.length() else {
    fail("Received package source proof did not match the uploaded bytes")
  }
  if request.town_binding is Some(binding) {
    let checked = agent_import_checked_binding(binding, source)
    @fs.write_file(
      directory + "/town-binding.json",
      checked.stringify(),
      create_mode=CreateNew,
      permission=0o600,
    )
  }
  @fs.write_file(
    directory + "/source.json",
    source.stringify(indent=2),
    create_mode=CreateNew,
    permission=0o600,
  )
  agent_import_inspect_with(
    context,
    request.operation_id,
    request.expected_library,
    run,
  )
}

///|
async fn agent_import_apply_with(
  context : WorkspaceContext,
  request : AgentImportRequest,
  run : AgentExportRun,
  is_current? : () -> Bool = () => true,
) -> Json {
  agent_import_mutex.acquire()
  defer agent_import_mutex.release()
  guard is_current() else { fail("The active library changed") }
  let before = agent_import_inspect_with(
    context,
    request.operation_id,
    request.expected_library,
    run,
  )
  guard before is { "source": source, .. } &&
    request.package_sha256 == json_string(source, "package_sha256", default="") else {
    fail("Explicit import does not match the reviewed package")
  }
  let town_binding = match before {
    { "town_binding": Object(_) as binding, .. } => Some(binding)
    _ => None
  }
  guard request.binding_digest ==
    town_binding.map(binding => {
      json_string(binding, "binding_digest", default="")
    }) else {
    fail("Explicit import must match the inspected Town binding")
  }
  let directory = agent_import_root(context) + "/" + request.operation_id
  let request_path = directory + "/import-request.json"
  if agent_import_path_present(request_path) {
    guard agent_import_request(agent_import_read_json(request_path, 8192)) ==
      Ok(request) else {
      fail("This import operation is already bound to another destination")
    }
    return before
  }
  let destination = context.books_root + "/" + request.destination_folder
  agent_import_context(context, request.expected_library)
  let workspace_id = @desk.stable_id("book", request.destination_folder)
  let identity_conflict = agent_import_workspace_identity_count(
      context, workspace_id,
    ) >
    0
  if agent_import_path_present(destination) || identity_conflict {
    guard before is Object(fields) else {
      fail("Missing received package inspection")
    }
    let response = fields.copy()
    response["message"] = "That destination already exists or shares a Book identifier with another folder. Choose a different Book folder to import this verified package.".to_json()
    return Json::object(response)
  }
  guard is_current() else { fail("The active library changed before import") }
  // Durable, exclusive reservation is the only mutation entry. Write it before
  // launch so cancellation, lost responses, and restart never replay import.
  @fs.write_file(
    request_path,
    ToJson::to_json(request).stringify(),
    create_mode=CreateNew,
    permission=0o600,
  )
  ignore(
    run(if town_binding is Some(_) { "import-exact" } else { "import" }, [
      destination,
      directory + "/package.moonbook-agent",
      directory +
      (if town_binding is Some(_) {
        "/town-binding.json"
      } else {
        "/source.json"
      }),
    ]) catch {
      _ => Err("Import outcome is uncertain")
    },
  )
  agent_import_inspect_with(
    context,
    request.operation_id,
    request.expected_library,
    run,
  )
}
