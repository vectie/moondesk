///|
// Only the explicit POST preparation path invokes "pack". All reads use the
// retained artifact and existing MoonBook verify/inspect/source operations.
let agent_export_prepare_mutex : @async.Mutex = Mutex()

///|
type AgentExportRun = async (String, Array[String]) -> Result[String, String]

///|
async fn agent_export_json(
  run : AgentExportRun,
  command : String,
  args : Array[String],
) -> Json {
  let text = match run(command, args) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  @json.parse(text) catch {
    _ => fail("MoonBook returned invalid export metadata")
  }
}

///|
async fn agent_export_inspection_with(
  workspace : @desk.DeskWorkspace,
  id : String,
  relative : String,
  run : AgentExportRun,
  retained~ : Bool,
) -> Json {
  guard agent_export_id_valid(id) else { fail("Invalid preparation ID") }
  let path = relative + "/package.moonbook-agent"
  guard agent_export_existing_path(workspace.root_path, path)
    is Some(package_path) else {
    fail("No complete retained package exists for this preparation")
  }
  let verification = agent_export_json(run, "verify", [package_path])
  let inspection = agent_export_json(run, "inspect", [package_path])
  let source = agent_export_json(run, "source", [package_path])
  guard agent_export_metadata_valid(inspection, verification, source) else {
    fail("MoonBook export metadata or verification did not agree")
  }
  let (digest, size) = agent_export_file_identity(package_path)
  guard digest == json_string(source, "package_sha256", default="") &&
    size == json_int(source, "package_size_bytes", default=-1).to_int64() else {
    fail("Retained package bytes changed during inspection")
  }
  if retained {
    guard agent_export_existing_path(
        workspace.root_path,
        relative + "/source.json",
      )
      is Some(source_path) else {
      fail("Retained package source proof is missing")
    }
    guard @json.parse(agent_export_bounded_text(source_path, 131072)) == source else {
      fail("Retained package no longer matches its prepared source")
    }
  }
  {
    "workspace_id": workspace.id,
    "expected_library": @pathx.dirname(workspace.root_path).to_owned(),
    "export_id": id,
    "path": agent_export_relative(id) + "/package.moonbook-agent",
    "inspection": inspection,
    "verification": verification,
    "source": source,
  }
}

///|
async fn agent_export_existing_request_matches(
  workspace : @desk.DeskWorkspace,
  relative : String,
  request : AgentExportRequest,
) -> Bool {
  guard agent_export_existing_path(
      workspace.root_path,
      relative + "/outputs.json",
    )
    is Some(selection) &&
    agent_export_existing_path(workspace.root_path, relative + "/version.txt")
    is Some(version) else {
    return false
  }
  @json.parse(agent_export_bounded_text(selection, 131072)) ==
  agent_export_selection(request) &&
  agent_export_bounded_text(version, 64) == request.version &&
  agent_human_result_retained_matches(
    workspace,
    relative,
    request.accepted_human_result,
  )
}

///|
async fn agent_export_prepare_with(
  workspace : @desk.DeskWorkspace,
  request : AgentExportRequest,
  run : AgentExportRun,
) -> Json {
  agent_export_prepare_mutex.acquire()
  defer agent_export_prepare_mutex.release()
  guard request.expected_library ==
    @pathx.dirname(workspace.root_path).to_owned() &&
    @fs.realpath(workspace.root_path) == workspace.root_path else {
    fail("The selected library changed; refresh the Book before preparing")
  }
  let relative = agent_export_relative(request.operation_id)
  let target = workspace.root_path + "/" + relative
  if @fs.exists(target) {
    guard agent_export_existing_request_matches(workspace, relative, request) else {
      fail(
        "This preparation ID belongs to different inputs; start a new preparation",
      )
    }
    return agent_export_inspection_with(
      workspace,
      request.operation_id,
      relative,
      run,
      retained=true,
    )
  }
  let staging_relative = "book/agents/.preparing-" + request.operation_id
  let staging = workspace.root_path + "/" + staging_relative
  if @fs.exists(staging) {
    fail(
      "An earlier preparation is incomplete; check saved packages or explicitly start a new preparation",
    )
  }
  // This remains Book-local; virtual suite-product paths are never accepted.
  for path in request.paths {
    guard agent_export_existing_path(workspace.root_path, path)
      is Some(absolute) &&
      @fs.kind(absolute, follow_symlink=false) == Regular else {
      fail("A selected output is missing, unsafe, or not a regular Book file")
    }
    let file = @fs.open(absolute, mode=ReadOnly)
    let size = file.size()
    file.close()
    guard size <= 16L * 1024L * 1024L else {
      fail("A selected output exceeds MoonBook’s 16 MiB member limit")
    }
  }
  for directory in ["book", "book/agents"] {
    guard resolve_workspace_write_path(workspace.root_path, directory)
      is Some((absolute, _)) else {
      fail("The Book export directory is not confined to this Book")
    }
    if !@fs.exists(absolute) {
      @fs.mkdir(absolute, permission=0o700)
    }
    guard @fs.kind(absolute, follow_symlink=false) == Directory else {
      fail("The Book export directory is not a directory")
    }
    guard resolve_workspace_existing_path(workspace.root_path, directory)
      is Some((_, _)) else {
      fail("The Book export directory is unavailable")
    }
  }
  guard resolve_workspace_write_path(workspace.root_path, staging_relative)
    is Some((safe_staging, _)) &&
    safe_staging == staging else {
    fail("The preparation path is not confined to this Book")
  }
  @fs.mkdir(staging, permission=0o700)
  if request.accepted_human_result is Some(source) {
    agent_human_result_stage(workspace.root_path, request.operation_id, source)
  }
  @fs.write_file(
    staging + "/outputs.json",
    agent_export_selection(request).stringify(),
    create_mode=CreateNew,
    permission=0o600,
  )
  @fs.write_file(
    staging + "/version.txt",
    request.version,
    create_mode=CreateNew,
    permission=0o600,
  )
  let package_path = staging + "/package.moonbook-agent"
  match
    run("pack", [request.version, package_path, staging + "/outputs.json"]) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let result = agent_export_inspection_with(
    workspace,
    request.operation_id,
    staging_relative,
    run,
    retained=false,
  )
  if request.accepted_human_result is Some(imported) &&
    !agent_human_result_inspection_matches(result, imported) {
    fail(
      "Prepared package does not contain the exact imported source and full content",
    )
  }
  guard result is { "source": source, .. } else {
    fail("Missing export source")
  }
  @fs.write_file(
    staging + "/source.json",
    source.stringify(indent=2),
    create_mode=CreateNew,
    permission=0o600,
  )
  // One new directory is the commit point. Never replace another preparation.
  @fs.rename(staging, target, replace=false)
  result
}

///|
async fn agent_export_retained(workspace : @desk.DeskWorkspace) -> Array[Json] {
  guard resolve_workspace_existing_path(workspace.root_path, "book/agents")
    is Some((directory, _)) else {
    return []
  }
  let exports : Array[Json] = []
  for name in @fs.readdir(directory, sort=true) {
    guard name.has_prefix("desk-") else { continue }
    let id = name[5:].to_owned()
    if !agent_export_id_valid(id) {
      continue
    }
    let relative = agent_export_relative(id)
    let entry = try {
      guard agent_export_existing_path(
          workspace.root_path,
          relative + "/source.json",
        )
        is Some(source_path) else {
        continue
      }
      let source = @json.parse(agent_export_bounded_text(source_path, 131072))
      let version = json_string(source, "agent_version", default="")
      let hash = json_string(source, "package_sha256", default="")
      let size = json_int(source, "package_size_bytes", default=0)
      guard json_string(source, "contract", default="") ==
        "moonbook.portable_source.v1" &&
        json_string(source, "package_filename", default="") ==
        "package.moonbook-agent" &&
        version != "" &&
        version.length() <= 64 &&
        agent_export_sha_valid(hash) &&
        size > 0 &&
        agent_export_existing_path(
          workspace.root_path,
          relative + "/package.moonbook-agent",
        )
        is Some(_) else {
        continue
      }
      (
        {
          "export_id": id,
          "path": relative + "/package.moonbook-agent",
          "version": version,
          "package_sha256": hash,
          "package_size_bytes": size,
        } : Json)
    } catch {
      _ => continue
    }
    exports.push(entry)
  }
  exports
}
