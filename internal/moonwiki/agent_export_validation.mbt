///|
priv struct AgentExportRequest {
  operation_id : String
  version : String
  paths : Array[String]
  expected_library : String
  accepted_human_result : AgentAcceptedHumanResult?
}

///|
// Reject even in-Book symlink aliases for export inputs/proofs. General Desk
// browsing may follow confined aliases; exact package preparation must not.
async fn agent_export_existing_path(
  root : String,
  relative : String,
) -> String? {
  guard resolve_workspace_existing_path(root, relative) is Some((absolute, _)) &&
    absolute == root + "/" + relative else {
    return None
  }
  Some(absolute)
}

///|
fn agent_export_id_valid(value : String) -> Bool {
  value.length() == 32 && value.iter().all(c => c is ('0'..='9' | 'a'..='f'))
}

///|
fn agent_export_request(payload : Json) -> Result[AgentExportRequest, String] {
  guard payload is Object(fields) &&
    (fields.length() == 4 || fields.length() == 5) &&
    fields.get("operation_id") is Some(String(operation_id)) &&
    fields.get("version") is Some(String(version)) &&
    fields.get("expected_library") is Some(String(expected_library)) &&
    fields.get("paths") is Some(Array(values)) else {
    return Err(
      "Preparation requires operation_id, version, paths, expected_library, and optionally accepted_human_result_base64",
    )
  }
  let accepted_human_result = match fields.get("accepted_human_result_base64") {
    None if fields.length() == 4 => None
    Some(String(encoded)) if fields.length() == 5 =>
      match agent_human_result_decode(encoded) {
        Ok(source) => Some(source)
        Err(message) => return Err(message)
      }
    _ => return Err("Preparation has an invalid accepted human result field")
  }
  if !agent_export_id_valid(operation_id) {
    return Err("Invalid preparation ID")
  }
  if expected_library.is_empty() ||
    expected_library.length() > 4096 ||
    !expected_library.has_prefix("/") ||
    expected_library.iter().any(c => c < ' ') {
    return Err("The selected library identity is missing or invalid")
  }
  if version.is_empty() ||
    version.length() > 64 ||
    version.has_prefix("-") ||
    !version
    .iter()
    .all(c => c is ('0'..='9' | 'a'..='z' | 'A'..='Z' | '.' | '-' | '_')) {
    return Err(
      "Version must contain 1–64 letters, numbers, dots, dashes, or underscores",
    )
  }
  if values.length() > 128 {
    return Err("Select at most 128 additional output files")
  }
  let paths : Array[String] = []
  for value in values {
    guard value is String(path) &&
      path.length() <= 4096 &&
      !path.contains("\\") &&
      !path.iter().any(c => c < ' ' || c == '\u007f') &&
      clean_relative_path(path) == Some(path) &&
      path != "" &&
      !path.has_prefix("book/agents/") &&
      !@desk.moonsuite_internal_relative_path(path) else {
      return Err(
        "Additional outputs must be regular files inside the selected Book",
      )
    }
    if paths.contains(path) {
      return Err("An output file was selected more than once")
    }
    paths.push(path)
  }
  paths.sort()
  Ok({ operation_id, version, paths, expected_library, accepted_human_result, })
}

///|
fn agent_export_selection(request : AgentExportRequest) -> Json {
  let selections = request.paths.mapi((index, path) => {
    let filename = path.split("/").last().unwrap_or(path).to_owned()
    (
      {
        "artifact_id": "output-" + index.to_string(),
        "label": filename,
        "mime_type": @preview.content_type(path)
        .split(";")
        .next()
        .unwrap_or("application/octet-stream")
        .to_owned(),
        "included": true,
        "files": [{ "source_path": path, "path": filename }],
      } : Json)
  })
  if request.accepted_human_result is Some(source) {
    selections.push(agent_human_result_selection(request.operation_id, source))
  }
  Json::array(selections)
}

///|
fn agent_export_sha_valid(value : String) -> Bool {
  value.length() == 71 &&
  value.has_prefix("sha256:") &&
  value[7:].iter().all(c => c is ('0'..='9' | 'a'..='f'))
}

///|
fn agent_export_relative(id : String) -> String {
  "book/agents/desk-" + id
}

///|
fn agent_export_metadata_valid(
  inspection : Json,
  verification : Json,
  source : Json,
) -> Bool {
  let digest = json_string(source, "bundle_digest", default="")
  let count = json_int(source, "file_count", default=-1)
  let files = @mooncore.json_array_items(inspection, "files")
  json_string(source, "contract", default="") == "moonbook.portable_source.v1" &&
  json_string(source, "package_filename", default="") ==
  "package.moonbook-agent" &&
  json_string(source, "package_sha256", default="").has_prefix("sha256:") &&
  digest != "" &&
  count >= 0 &&
  files.length() == count &&
  json_bool(verification, "ok", default=false) &&
  json_int(verification, "checked_file_count", default=-1) == count &&
  json_string(verification, "bundle_digest", default="") == digest &&
  json_string(inspection, "bundle_digest", default="") == digest &&
  json_string(inspection, "contract", default="") ==
  json_string(source, "bundle_contract", default="") &&
  json_string(inspection, "agent_id", default="") ==
  json_string(source, "agent_id", default="") &&
  json_string(verification, "agent_id", default="") ==
  json_string(source, "agent_id", default="") &&
  json_string(inspection, "version", default="") ==
  json_string(source, "agent_version", default="") &&
  json_string(verification, "version", default="") ==
  json_string(source, "agent_version", default="") &&
  json_string(inspection, "book_revision", default="") ==
  json_string(source, "book_revision", default="") &&
  json_int(inspection, "file_count", default=-1) == count &&
  files.all(file => {
    let path = json_string(file, "path", default="")
    path != "" &&
    clean_relative_path(path) == Some(path) &&
    json_string(file, "digest", default="").has_prefix("sha256:") &&
    json_string(file, "role", default="") != "" &&
    json_string(file, "sensitivity", default="") != "" &&
    json_string(file, "review_status", default="") != "" &&
    json_int(file, "size_bytes", default=-1) >= 0
  }) &&
  inspection is { "exclusions": Array(_), .. }
}

///|
async fn agent_export_bounded_text(path : String, limit : Int) -> String {
  guard @fs.kind(path, follow_symlink=false) == Regular else {
    fail("Export metadata is not a regular file")
  }
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  let size = file.size()
  guard size >= 0L && size <= limit.to_int64() else {
    fail("Export metadata exceeds its size limit")
  }
  @encoding/utf8.decode(file.read_exactly(size.to_int()))
}

///|
async fn agent_export_file_identity(path : String) -> (String, Int64) {
  guard @fs.kind(path, follow_symlink=false) == Regular else {
    fail("Package is not a regular file")
  }
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  let size = file.size()
  let hash = @crypto.SHA256::new()
  let mut count = 0L
  while file.read_some(max_len=65536) is Some(bytes) {
    hash.update(bytes)
    count += bytes.length().to_int64()
  }
  guard count == size && file.size() == size else {
    fail("Package changed during inspection")
  }
  ("sha256:" + @crypto.bytes_to_hex_string(hash.finalize()), size)
}
