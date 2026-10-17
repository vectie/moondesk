///|
priv struct AgentExportGroupFile {
  source_path : String
  path : String
} derive(FromJson, ToJson)

///|
priv struct AgentExportGroup {
  artifact_id : String
  label : String
  mime_type : String
  files : Array[AgentExportGroupFile]
  preview_path : String?
  app_entrypoint : String?
} derive(FromJson, ToJson)

///|
fn agent_export_group_path(path : String) -> Bool {
  path != "" &&
  path.length() <= 4096 &&
  !path.contains("\\") &&
  !path.iter().any(c => c < ' ' || c == '\u007f') &&
  clean_relative_path(path) == Some(path)
}

///|
fn agent_export_groups(
  value : Json?,
  flat_count : Int32,
) -> Result[Array[AgentExportGroup], String] {
  guard value is Some(value) else { return Ok([]) }
  guard value is Array(values) && values.length() <= 16 else {
    return Err("Select at most 16 named deliverables")
  }
  let groups : Array[AgentExportGroup] = []
  let mut count = flat_count
  for value in values {
    guard value is Object(fields) &&
      fields.length() >= 4 &&
      fields.length() <= 6 &&
      fields
      .keys()
      .all(key => {
        [
          "artifact_id", "label", "mime_type", "files", "preview_path", "app_entrypoint",
        ].contains(key)
      }) &&
      fields.get("files") is Some(Array(files)) &&
      files.all(file => {
        file is Object(fields) &&
        fields.length() == 2 &&
        fields.contains("source_path") &&
        fields.contains("path")
      }) else {
      return Err("A named deliverable has unsupported fields")
    }
    let group : AgentExportGroup = @json.from_json(value) catch {
      _ => return Err("A named deliverable could not be read")
    }
    if !group.artifact_id.has_prefix("group-") ||
      group.artifact_id.length() <= 6 ||
      group.artifact_id.length() > 64 ||
      !group.artifact_id.iter().all(c => c is ('a'..<='z' | '0'..<='9' | '-')) ||
      groups.any(other => other.artifact_id == group.artifact_id) {
      return Err("Deliverable IDs must be unique group-prefixed identifiers")
    }
    if group.label.trim().is_empty() ||
      group.label.length() > 120 ||
      group.label.iter().any(c => c < ' ' || c == '\u007f') ||
      !["application/octet-stream", "text/html"].contains(group.mime_type) {
      return Err("Name each deliverable and choose a supported output type")
    }
    if group.files.is_empty() {
      return Err("Select at least one file in each named deliverable")
    }
    count += group.files.length()
    if count > 128 {
      return Err(
        "Select at most 128 additional output files across all deliverables",
      )
    }
    let seen : Array[AgentExportGroupFile] = []
    for file in group.files {
      if !agent_export_group_path(file.source_path) ||
        file.source_path.has_prefix("book/agents/") ||
        @desk.moonsuite_internal_relative_path(file.source_path) ||
        !agent_export_group_path(file.path) {
        return Err(
          "Deliverable members must be safe relative files inside the selected Book",
        )
      }
      if seen.any(other => {
          other.source_path == file.source_path ||
          other.path.to_lower() == file.path.to_lower() ||
          other.path.to_lower().has_prefix(file.path.to_lower() + "/") ||
          file.path.to_lower().has_prefix(other.path.to_lower() + "/")
        }) {
        return Err("Deliverable members have duplicate or conflicting paths")
      }
      seen.push(file)
    }
    for link in [group.preview_path, group.app_entrypoint] {
      if link is Some(path) && !group.files.any(file => file.path == path) {
        return Err(
          "A preview or app entrypoint must be one of this deliverable’s selected files",
        )
      }
    }
    groups.push(group)
  }
  Ok(groups)
}

///|
fn agent_export_group_selection(group : AgentExportGroup) -> Json {
  // Share the typed wire codec with request serialization, retaining this
  // selection object's original field order and optional-field behavior.
  let encoded = ToJson::to_json(group)
  let files = match encoded {
    { "files": files, .. } => files
    _ => ToJson::to_json(group.files)
  }
  let value : Json = {
    "artifact_id": group.artifact_id,
    "label": group.label,
    "mime_type": group.mime_type,
    "included": true,
    "files": files,
  }
  guard value is Object(fields) else { return value }
  if group.preview_path is Some(path) {
    fields["preview_path"] = ToJson::to_json(path)
  }
  if group.app_entrypoint is Some(path) {
    fields["app_entrypoint"] = ToJson::to_json(path)
  }
  Json::object(fields)
}

///|
fn agent_export_all_paths(request : AgentExportRequest) -> Array[String] {
  let paths = request.paths.copy()
  for group in request.output_groups {
    for file in group.files {
      if !paths.contains(file.source_path) {
        paths.push(file.source_path)
      }
    }
  }
  paths
}
