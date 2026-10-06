///|
priv struct AgentImportStage {
  operation_id : String
  expected_library : String
  filename : String
  bytes : Bytes
}

///|
priv struct AgentImportRequest {
  operation_id : String
  expected_library : String
  destination_folder : String
  package_sha256 : String
} derive(Eq, ToJson)

///|
let agent_import_package_limit : Int = 64 * 1024 * 1024

///|
let agent_import_body_limit : Int = 90 * 1024 * 1024

///|
fn agent_import_library_valid(path : String) -> Bool {
  path.length() > 1 &&
  path.length() <= 4096 &&
  path.has_prefix("/") &&
  !path.has_suffix("/") &&
  !path.contains("\\") &&
  !path.contains("//") &&
  !path.contains("/./") &&
  !path.contains("/../") &&
  !path.has_suffix("/.") &&
  !path.has_suffix("/..") &&
  !path.iter().any(c => c < ' ' || c == '\u007f')
}

///|
fn agent_import_folder_valid(value : String) -> Bool {
  value.length() > 0 &&
  value.length() <= 80 &&
  value[0] is ('a'..='z' | 'A'..='Z' | '0'..='9') &&
  value.iter().all(c => c is ('a'..='z' | 'A'..='Z' | '0'..='9' | '-' | '_'))
}

///|
fn agent_import_stage_request(
  payload : Json,
) -> Result[AgentImportStage, String] {
  guard payload is Object(fields) &&
    fields.length() == 4 &&
    fields.get("operation_id") is Some(String(operation_id)) &&
    fields.get("expected_library") is Some(String(expected_library)) &&
    fields.get("filename") is Some(String(filename)) &&
    fields.get("data_url") is Some(String(data_url)) else {
    return Err(
      "Receive requires only operation_id, expected_library, filename, and data_url",
    )
  }
  guard agent_export_id_valid(operation_id) &&
    agent_import_library_valid(expected_library) else {
    return Err("Invalid operation or selected library")
  }
  guard filename.length() <= 255 &&
    filename.has_suffix(".moonbook-agent") &&
    clean_import_file_name(filename) == Ok(filename) &&
    !filename.iter().any(c => c < ' ' || c == '\u007f') else {
    return Err("Choose one .moonbook-agent file")
  }
  guard data_url.length() <= agent_import_body_limit &&
    data_url.split_once(",") is Some((metadata, encoded)) &&
    metadata.has_prefix("data:") &&
    metadata.has_suffix(";base64") else {
    return Err("Package upload must contain base64 file bytes")
  }
  let bytes = @base64.decode(encoded.to_owned(), ignore_whitespace=false) catch {
    _ => return Err("Package upload contains invalid base64")
  }
  guard bytes.length() > 0 && bytes.length() <= agent_import_package_limit else {
    return Err("Package must contain at most 64 MiB")
  }
  // Canonical base64 prevents truncated padding or ignored suffixes.
  guard @base64.encode(bytes, padding=true) == encoded.to_owned() else {
    return Err("Package upload contains noncanonical base64")
  }
  Ok({ operation_id, expected_library, filename, bytes, })
}

///|
fn agent_import_request(payload : Json) -> Result[AgentImportRequest, String] {
  guard payload is Object(fields) &&
    fields.length() == 4 &&
    fields.get("operation_id") is Some(String(operation_id)) &&
    fields.get("expected_library") is Some(String(expected_library)) &&
    fields.get("destination_folder") is Some(String(destination_folder)) &&
    fields.get("package_sha256") is Some(String(package_sha256)) &&
    agent_export_id_valid(operation_id) &&
    agent_import_library_valid(expected_library) &&
    agent_import_folder_valid(destination_folder) &&
    agent_export_sha_valid(package_sha256) else {
    return Err(
      "Import requires the reviewed operation, library, package digest, and a new folder name",
    )
  }
  Ok({ operation_id, expected_library, destination_folder, package_sha256, })
}

///|
fn agent_import_hash(bytes : Bytes) -> String {
  "sha256:" + @crypto.bytes_to_hex_string(@crypto.sha256(bytes))
}

///|
fn agent_import_manifest(request : AgentImportStage) -> Json {
  {
    "operation_id": request.operation_id,
    "expected_library": request.expected_library,
    "filename": request.filename,
    "package_sha256": agent_import_hash(request.bytes),
    "package_size_bytes": request.bytes.length(),
  }
}

///|
fn agent_import_root(context : WorkspaceContext) -> String {
  moonsuite_product_artifact_for_workspace_root(
    context.suite_root,
    "moondesk",
    "agent-imports",
  )
}

///|
async fn agent_import_canonical_directory(path : String) -> Unit {
  guard agent_import_library_valid(path) &&
    @fs.kind(path, follow_symlink=false) == Directory &&
    @fs.realpath(path) == path else {
    fail("Import directory is missing or is a path alias")
  }
}

///|
async fn agent_import_regular_file(path : String, maximum : Int) -> Unit {
  guard agent_import_library_valid(path) &&
    @fs.kind(path, follow_symlink=false) == Regular &&
    @fs.realpath(path) == path else {
    fail("Import file is missing or is a path alias")
  }
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  guard file.kind() == Regular &&
    file.size() >= 0L &&
    file.size() <= maximum.to_int64() else {
    fail("Import file exceeds its size limit")
  }
}

///|
async fn agent_import_package_identity(path : String) -> (String, Int64) {
  agent_import_regular_file(path, agent_import_package_limit)
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  let size = file.size()
  guard file.kind() == Regular &&
    size > 0L &&
    size <= agent_import_package_limit.to_int64() else {
    fail("Package size changed before reading")
  }
  let digest = @crypto.SHA256::new()
  let mut count = 0
  while file.read_some(
          max_len=(agent_import_package_limit - count + 1).min(65536),
        )
        is Some(chunk) {
    count += chunk.length()
    guard count <= agent_import_package_limit else {
      fail("Package grew beyond its size limit")
    }
    digest.update(chunk)
  }
  guard count.to_int64() == size && file.size() == size else {
    fail("Package changed while reading")
  }
  ("sha256:" + @crypto.bytes_to_hex_string(digest.finalize()), size)
}

///|
async fn agent_import_path_present(path : String) -> Bool {
  try {
    ignore(@fs.kind(path, follow_symlink=false))
    true
  } catch {
    @os_error.OSError(_) as error if error.is_ENOENT() => false
    error => raise error
  }
}

///|
async fn agent_import_context(
  context : WorkspaceContext,
  expected : String,
) -> Unit {
  guard expected == context.books_root else { fail("Selected library changed") }
  agent_import_canonical_directory(context.suite_root)
  agent_import_canonical_directory(context.books_root)
  guard context.books_root == context.suite_root + "/books" &&
    agent_import_root(context).has_prefix(context.suite_root + "/") &&
    !agent_import_root(context).has_prefix(context.books_root + "/") else {
    fail("Import staging is not outside the Book library")
  }
}

///|
async fn agent_import_prepare_directory(context : WorkspaceContext) -> Unit {
  let staging = agent_import_root(context)
  let relative = staging[context.suite_root.length() + 1:].to_owned()
  let mut current = context.suite_root
  for part in relative.split("/") {
    current += "/" + part.to_owned()
    if !agent_import_path_present(current) {
      @fs.mkdir(current, permission=0o700)
    }
    agent_import_canonical_directory(current)
  }
}
