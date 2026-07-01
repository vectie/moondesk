///|
async fn handle_workspace_create_entry(
  workspace_root : String,
  workspace_id : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(workspace) => workspace
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
      return
    }
  }
  let payload = match read_json_body(body) {
    Some(json) => json
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  match create_workspace_entry(workspace, payload) {
    Ok(response) => send_json(conn, method_, response)
    Err(error) =>
      send_api_json_error(
        conn,
        method_,
        json_int(error, "code", default=400),
        json_string(error, "reason", default="Bad Request"),
        {
          "error": json_string(
            error,
            "message",
            default="Could not create entry",
          ),
        },
      )
  }
}

///|
async fn handle_workspace_import_files(
  workspace_root : String,
  workspace_id : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(workspace) => workspace
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
      return
    }
  }
  let payload = match read_json_body(body) {
    Some(json) => json
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  match import_workspace_files(workspace, payload) {
    Ok(response) => send_json(conn, method_, response)
    Err(error) =>
      send_api_json_error(
        conn,
        method_,
        json_int(error, "code", default=400),
        json_string(error, "reason", default="Bad Request"),
        {
          "error": json_string(
            error,
            "message",
            default="Could not import files",
          ),
        },
      )
  }
}

///|
async fn handle_workspace_rename_entry(
  workspace_root : String,
  workspace_id : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(workspace) => workspace
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
      return
    }
  }
  let payload = match read_json_body(body) {
    Some(json) => json
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  match rename_workspace_entry(workspace, payload) {
    Ok(response) => send_json(conn, method_, response)
    Err(error) =>
      send_api_json_error(
        conn,
        method_,
        json_int(error, "code", default=400),
        json_string(error, "reason", default="Bad Request"),
        {
          "error": json_string(
            error,
            "message",
            default="Could not rename entry",
          ),
        },
      )
  }
}

///|
async fn handle_workspace_move_entry(
  workspace_root : String,
  workspace_id : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(workspace) => workspace
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
      return
    }
  }
  let payload = match read_json_body(body) {
    Some(json) => json
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  match move_workspace_entry(workspace, payload) {
    Ok(response) => send_json(conn, method_, response)
    Err(error) =>
      send_api_json_error(
        conn,
        method_,
        json_int(error, "code", default=400),
        json_string(error, "reason", default="Bad Request"),
        {
          "error": json_string(error, "message", default="Could not move entry"),
        },
      )
  }
}

///|
async fn handle_workspace_copy_entry(
  workspace_root : String,
  workspace_id : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(workspace) => workspace
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
      return
    }
  }
  let payload = match read_json_body(body) {
    Some(json) => json
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  match copy_workspace_entry(workspace, payload) {
    Ok(response) => send_json(conn, method_, response)
    Err(error) =>
      send_api_json_error(
        conn,
        method_,
        json_int(error, "code", default=400),
        json_string(error, "reason", default="Bad Request"),
        {
          "error": json_string(error, "message", default="Could not copy entry"),
        },
      )
  }
}

///|
async fn create_workspace_entry(
  workspace : @desk.DeskWorkspace,
  payload : Json,
) -> Result[Json, Json] {
  let kind = json_string(payload, "kind", default="folder")
    .trim()
    .to_lower()
    .to_owned()
  let directory = json_string(payload, "directory", default="")
  let name = json_string(payload, "name", default="").trim().to_owned()
  let safe_name = match clean_new_entry_name(name, kind) {
    Ok(name) => name
    Err(message) =>
      return Err(workspace_entry_create_error(400, "Bad Request", message))
  }
  let directory_clean = match clean_relative_path(directory) {
    Some(path) => path
    None =>
      return Err(
        workspace_entry_create_error(
          400, "Bad Request", "Invalid directory path",
        ),
      )
  }
  let relative = if directory_clean == "" {
    safe_name
  } else {
    @pathx.join(directory_clean, safe_name)
  }
  if !is_desk_create_path_allowed(relative) {
    return Err(
      workspace_entry_create_error(
        400, "Bad Request", "Desk cannot create files in generated or system paths",
      ),
    )
  }
  let absolute = match resolve_workspace_path(workspace.root_path, relative) {
    Some((absolute, _)) => absolute
    None =>
      return Err(
        workspace_entry_create_error(400, "Bad Request", "Invalid target path"),
      )
  }
  if @fs.exists(absolute) {
    return Err(
      workspace_entry_create_error(409, "Conflict", "Entry already exists"),
    )
  }
  match kind {
    "folder" | "directory" =>
      @fsx.make_directory(absolute, recursive=true, exists_ok=false) catch {
        _ =>
          return Err(
            workspace_entry_create_error(
              500, "Internal Server Error", "Could not create folder",
            ),
          )
      }
    "markdown" | "note" | "file" => {
      @fsx.make_directory(
        @pathx.dirname(absolute).to_owned(),
        recursive=true,
        exists_ok=true,
      ) catch {
        _ =>
          return Err(
            workspace_entry_create_error(
              500, "Internal Server Error", "Could not create parent folder",
            ),
          )
      }
      let title = markdown_title_from_path(relative)
      @fsx.write_to_file(
        absolute,
        "# \{if title == "" { "Untitled" } else { title }}\n\n",
        create=0o644,
      ) catch {
        _ =>
          return Err(
            workspace_entry_create_error(
              500, "Internal Server Error", "Could not create Markdown file",
            ),
          )
      }
    }
    _ =>
      return Err(
        workspace_entry_create_error(400, "Bad Request", "Unknown entry kind"),
      )
  }
  Ok({
    "workspace_id": workspace.id,
    "path": relative,
    "directory": parent_path_for_created_entry(relative),
    "kind": if kind == "folder" || kind == "directory" {
      "folder"
    } else {
      "markdown"
    },
  })
}

///|
async fn import_workspace_files(
  workspace : @desk.DeskWorkspace,
  payload : Json,
) -> Result[Json, Json] {
  let target_directory = match import_target_directory(workspace, payload) {
    Ok(directory) => directory
    Err(error) => return Err(error)
  }
  let files = import_payload_files(payload)
  if files.length() == 0 {
    return Err(
      workspace_entry_create_error(
        400, "Bad Request", "Import files are required",
      ),
    )
  }
  let planned : Array[(String, String, Bytes)] = []
  let seen_targets : Array[String] = []
  for file in files {
    let import_path = match clean_import_file_path(file) {
      Ok(path) => path
      Err(message) =>
        return Err(workspace_entry_create_error(400, "Bad Request", message))
    }
    let target_relative = unique_import_target_path(
      workspace.root_path,
      target_directory,
      import_path,
      seen_targets,
    )
    if !is_desk_create_path_allowed(target_relative) ||
      moonbook_section_for_path(target_relative) is Some(_) {
      return Err(
        workspace_entry_create_error(
          400, "Bad Request", "Desk cannot import into generated or system paths",
        ),
      )
    }
    let target_absolute = match
      resolve_workspace_path(workspace.root_path, target_relative) {
      Some((absolute, _)) => absolute
      None =>
        return Err(
          workspace_entry_create_error(
            400, "Bad Request", "Invalid import target path",
          ),
        )
    }
    let bytes = match import_file_bytes(file) {
      Ok(bytes) => bytes
      Err(message) =>
        return Err(workspace_entry_create_error(400, "Bad Request", message))
    }
    seen_targets.push(target_relative)
    planned.push((target_absolute, target_relative, bytes))
  }
  let items : Array[Json] = []
  for item in planned {
    let (target_absolute, target_relative, bytes) = item
    @fsx.make_directory(
      @pathx.dirname(target_absolute).to_owned(),
      recursive=true,
      exists_ok=true,
    ) catch {
      _ =>
        return Err(
          workspace_entry_create_error(
            500, "Internal Server Error", "Could not create import directory",
          ),
        )
    }
    write_bytes_file(target_absolute, bytes, create=0o644) catch {
      _ =>
        return Err(
          workspace_entry_create_error(
            500, "Internal Server Error", "Could not write imported file",
          ),
        )
    }
    items.push(rename_workspace_entry_response(workspace.id, target_relative))
  }
  Ok(import_workspace_files_response(workspace.id, target_directory, items))
}

///|
async fn rename_workspace_entry(
  workspace : @desk.DeskWorkspace,
  payload : Json,
) -> Result[Json, Json] {
  let source_path = decode_query_value(json_string(payload, "path", default=""))
  let source = match resolve_workspace_path(workspace.root_path, source_path) {
    Some((absolute, clean_relative)) => (absolute, clean_relative)
    None =>
      return Err(
        workspace_entry_create_error(400, "Bad Request", "Invalid source path"),
      )
  }
  let (source_absolute, source_relative) = source
  if source_relative == "" ||
    moonbook_section_for_path(source_relative) is Some(_) {
    return Err(
      workspace_entry_create_error(
        400, "Bad Request", "Desk cannot rename MoonBook sections",
      ),
    )
  }
  if !@fs.exists(source_absolute) {
    return Err(
      workspace_entry_create_error(404, "Not Found", "Entry path not found"),
    )
  }
  if !is_desk_create_path_allowed(source_relative) {
    return Err(
      workspace_entry_create_error(
        400, "Bad Request", "Desk cannot rename generated or system paths",
      ),
    )
  }
  let is_source_directory = is_directory(source_absolute)
  let requested_name = json_string(payload, "name", default="")
    .trim()
    .to_owned()
  let target_name = match
    clean_rename_entry_name(
      requested_name, source_relative, is_source_directory,
    ) {
    Ok(name) => name
    Err(message) =>
      return Err(workspace_entry_create_error(400, "Bad Request", message))
  }
  let parent = parent_path_for_created_entry(source_relative)
  let target_relative = if parent == "" {
    target_name
  } else {
    @pathx.join(parent, target_name)
  }
  if target_relative == source_relative {
    return Ok(rename_workspace_entry_response(workspace.id, source_relative))
  }
  if !is_desk_create_path_allowed(target_relative) ||
    moonbook_section_for_path(target_relative) is Some(_) {
    return Err(
      workspace_entry_create_error(
        400, "Bad Request", "Desk cannot rename into generated or system paths",
      ),
    )
  }
  let target_absolute = match
    resolve_workspace_path(workspace.root_path, target_relative) {
    Some((absolute, _)) => absolute
    None =>
      return Err(
        workspace_entry_create_error(400, "Bad Request", "Invalid target path"),
      )
  }
  if @fs.exists(target_absolute) {
    return Err(
      workspace_entry_create_error(409, "Conflict", "Entry already exists"),
    )
  }
  @fs.rename(source_absolute, target_absolute) catch {
    _ =>
      return Err(
        workspace_entry_create_error(
          500, "Internal Server Error", "Could not rename entry",
        ),
      )
  }
  Ok(rename_workspace_entry_response(workspace.id, target_relative))
}

///|
async fn copy_workspace_entry(
  workspace : @desk.DeskWorkspace,
  payload : Json,
) -> Result[Json, Json] {
  let requested_paths = move_payload_paths(payload)
  if requested_paths.length() == 0 {
    return Err(
      workspace_entry_create_error(400, "Bad Request", "Entry path is required"),
    )
  }
  let target_directory_input = json_string(payload, "directory", default="")
    .trim()
    .to_owned()
  let target_directory = if target_directory_input == "" {
    ""
  } else {
    match move_target_directory(workspace, payload) {
      Ok(directory) => directory
      Err(error) => return Err(error)
    }
  }
  let planned : Array[(String, String, String, String)] = []
  let seen_sources : Array[String] = []
  let seen_targets : Array[String] = []
  for requested_path in requested_paths {
    let source_path = decode_query_value(requested_path)
    let source = match
      resolve_workspace_path(workspace.root_path, source_path) {
      Some((absolute, clean_relative)) => (absolute, clean_relative)
      None =>
        return Err(
          workspace_entry_create_error(
            400, "Bad Request", "Invalid source path",
          ),
        )
    }
    let (source_absolute, source_relative) = source
    if seen_sources.contains(source_relative) {
      return Err(
        workspace_entry_create_error(
          400, "Bad Request", "Duplicate source path",
        ),
      )
    }
    for seen_source in seen_sources {
      if move_sources_overlap(seen_source, source_relative) {
        return Err(
          workspace_entry_create_error(
            400, "Bad Request", "Overlapping source paths",
          ),
        )
      }
    }
    seen_sources.push(source_relative)
    match validate_move_source(source_absolute, source_relative) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
    let target_relative = unique_copy_target_path(
      workspace.root_path,
      source_relative,
      target_directory,
      seen_targets,
    )
    let target_absolute = match
      validate_move_target(
        workspace, source_absolute, source_relative, target_relative, target_directory,
      ) {
      Ok(absolute) => absolute
      Err(error) => return Err(error)
    }
    seen_targets.push(target_relative)
    planned.push(
      (source_absolute, source_relative, target_absolute, target_relative),
    )
  }
  let items : Array[Json] = []
  for item in planned {
    let (source_absolute, _, target_absolute, target_relative) = item
    let copied = if is_directory(source_absolute) {
      copy_workspace_directory(source_absolute, target_absolute)
    } else {
      copy_workspace_file(source_absolute, target_absolute)
    }
    if !copied {
      return Err(
        workspace_entry_create_error(
          500, "Internal Server Error", "Could not copy entry",
        ),
      )
    }
    items.push(rename_workspace_entry_response(workspace.id, target_relative))
  }
  Ok(copy_workspace_entry_response(workspace.id, items))
}

///|
async fn unique_copy_target_path(
  workspace_root : String,
  source_relative : String,
  target_directory : String,
  planned_targets : Array[String],
) -> String {
  let name = @desk.display_name(source_relative)
  let is_source_directory = is_directory(
    @pathx.join(workspace_root, source_relative),
  )
  let ext = if is_source_directory { "" } else { @pathx.ext(name).to_owned() }
  let stem = if ext != "" && name.has_suffix(ext) {
    name[:name.length() - ext.length()].to_owned()
  } else {
    name
  }
  for index = 0; ; index = index + 1 {
    let candidate_name = if index == 0 {
      name
    } else {
      let suffix = if index == 1 { " copy" } else { " copy \{index}" }
      stem + suffix + ext
    }
    let parent = if target_directory == "" {
      parent_path_for_created_entry(source_relative)
    } else {
      target_directory
    }
    let candidate = if parent == "" {
      candidate_name
    } else {
      @pathx.join(parent, candidate_name)
    }
    if !@fs.exists(@pathx.join(workspace_root, candidate)) &&
      !planned_targets.contains(candidate) {
      return candidate
    }
  }
}

///|
async fn copy_workspace_directory(source : String, target : String) -> Bool {
  @fsx.make_directory(target, recursive=true, exists_ok=false) catch {
    _ => return false
  }
  for name in read_directory_names(source, include_hidden=true) {
    if import_should_skip_copy_name(name) {
      continue
    }
    let child_source = @pathx.join(source, name)
    let child_target = @pathx.join(target, name)
    if is_directory(child_source) {
      if !copy_workspace_directory(child_source, child_target) {
        return false
      }
    } else if !copy_workspace_file(child_source, child_target) {
      return false
    }
  }
  true
}

///|
async fn copy_workspace_file(source : String, target : String) -> Bool {
  let bytes = @fs.read_file(source).binary() catch { _ => return false }
  @fsx.make_directory(
    @pathx.dirname(target).to_owned(),
    recursive=true,
    exists_ok=true,
  ) catch {
    _ => return false
  }
  write_bytes_file(target, bytes, create=0o644) catch {
    _ => return false
  }
  true
}

///|
fn copy_workspace_entry_response(
  workspace_id : String,
  items : Array[Json],
) -> Json {
  let first = if items.length() == 0 { Json::object({}) } else { items[0] }
  {
    "workspace_id": workspace_id,
    "path": json_string(first, "path", default=""),
    "directory": json_string(first, "directory", default=""),
    "copied_count": items.length(),
    "items": Json::array(items),
  }
}

///|
async fn import_target_directory(
  workspace : @desk.DeskWorkspace,
  payload : Json,
) -> Result[String, Json] {
  let target_directory = match move_target_directory(workspace, payload) {
    Ok(directory) => directory
    Err(error) => return Err(error)
  }
  if target_directory != "" && !is_desk_create_path_allowed(target_directory) {
    return Err(
      workspace_entry_create_error(
        400, "Bad Request", "Desk cannot import into generated or system paths",
      ),
    )
  }
  Ok(target_directory)
}

///|
fn import_payload_files(payload : Json) -> Array[Json] {
  match payload {
    { "files": Array(files), .. } => files
    _ => {
      let filename = json_string(payload, "filename", default="")
      let name = json_string(payload, "name", default="")
      let content = json_string(payload, "content", default="")
      let data_url = json_string(payload, "data_url", default="")
      if filename == "" && name == "" && content == "" && data_url == "" {
        []
      } else {
        [payload]
      }
    }
  }
}

///|
fn clean_import_file_name(name : String) -> Result[String, String] {
  let name = name.trim().to_owned()
  if name == "" {
    return Err("Import filename is required")
  }
  if name == "." || name == ".." || name.has_prefix(".") {
    return Err("Import filename is not allowed")
  }
  if name.contains("/") || name.contains("\\") || @pathx.is_absolute(name) {
    return Err("Import filename must not contain path separators")
  }
  if should_hide_file_entry(name) {
    return Err("Import filename is reserved")
  }
  if @pathx.normalize(name) != name {
    return Err("Import filename is not allowed")
  }
  Ok(name)
}

///|
fn clean_import_file_path(file : Json) -> Result[String, String] {
  let fallback_name = json_string(
    file,
    "filename",
    default=json_string(file, "name", default=""),
  )
  let relative_path = json_string(file, "relative_path", default="")
    .trim()
    .to_owned()
  if relative_path == "" {
    return clean_import_file_name(fallback_name)
  }
  if relative_path.has_prefix("/") || @pathx.is_absolute(relative_path) {
    return Err("Import path must be relative")
  }
  let trimmed = relative_path.trim(chars=['/']).to_owned()
  if trimmed == "" {
    return clean_import_file_name(fallback_name)
  }
  let normalized = @pathx.normalize(trimmed)
  if normalized == "." || normalized == ".." || normalized.has_prefix("../") {
    return Err("Import path is not allowed")
  }
  let mut clean_path = ""
  for raw_segment in normalized.split("/") {
    let segment = raw_segment.to_owned()
    if segment == "" {
      continue
    }
    let clean_segment = match clean_import_file_name(segment) {
      Ok(name) => name
      Err(_) => return Err("Import path contains an invalid segment")
    }
    clean_path = if clean_path == "" {
      clean_segment
    } else {
      @pathx.join(clean_path, clean_segment)
    }
  }
  if clean_path == "" {
    clean_import_file_name(fallback_name)
  } else {
    Ok(clean_path)
  }
}

///|
async fn unique_import_target_path(
  workspace_root : String,
  target_directory : String,
  import_path : String,
  planned_targets : Array[String],
) -> String {
  let import_parent = parent_path_for_created_entry(import_path)
  let filename = @desk.display_name(import_path)
  let target_parent = if target_directory == "" {
    import_parent
  } else if import_parent == "" {
    target_directory
  } else {
    @pathx.join(target_directory, import_parent)
  }
  let ext = @pathx.ext(filename).to_owned()
  let stem = if ext != "" && filename.has_suffix(ext) {
    filename[:filename.length() - ext.length()].to_owned()
  } else {
    filename
  }
  for index = 0; ; index = index + 1 {
    let candidate_name = if index == 0 {
      filename
    } else {
      let suffix = if index == 1 { " copy" } else { " copy \{index}" }
      stem + suffix + ext
    }
    let candidate = if target_parent == "" {
      candidate_name
    } else {
      @pathx.join(target_parent, candidate_name)
    }
    if !@fs.exists(@pathx.join(workspace_root, candidate)) &&
      !planned_targets.contains(candidate) {
      return candidate
    }
  }
}

///|
fn import_file_bytes(file : Json) -> Result[Bytes, String] {
  let data_url = json_string(file, "data_url", default="")
  if data_url != "" {
    return decode_data_url_bytes(data_url)
  }
  Ok(@encoding/utf8.encode(json_string(file, "content", default="")))
}

///|
fn decode_data_url_bytes(data_url : String) -> Result[Bytes, String] {
  let parts = match data_url.split_once(",") {
    Some(parts) => parts
    None => return Err("Invalid data URL")
  }
  let (metadata, payload) = parts
  if !metadata.has_prefix("data:") {
    return Err("Invalid data URL")
  }
  if metadata.contains(";base64") {
    decode_base64_bytes(payload.to_owned())
  } else {
    Ok(@encoding/utf8.encode(payload.to_owned()))
  }
}

///|
fn decode_base64_bytes(payload : String) -> Result[Bytes, String] {
  let bytes : Array[Byte] = []
  let mut buffer = 0
  let mut bits = 0
  for index in 0..<payload.length() {
    let code = payload[index]
    if code == '=' {
      break
    }
    if code == ' ' || code == '\n' || code == '\r' || code == '\t' {
      continue
    }
    let value = match base64_value(code) {
      Some(value) => value
      None => return Err("Invalid base64 data")
    }
    buffer = (buffer << 6) | value
    bits = bits + 6
    if bits >= 8 {
      bits = bits - 8
      bytes.push(((buffer >> bits) & 0xff).to_byte())
    }
  }
  Ok(Bytes::from_array(bytes))
}

///|
fn base64_value(code : UInt16) -> Int? {
  if code >= 'A' && code <= 'Z' {
    Some(code.to_int() - ('A' : UInt16).to_int())
  } else if code >= 'a' && code <= 'z' {
    Some(26 + code.to_int() - ('a' : UInt16).to_int())
  } else if code >= '0' && code <= '9' {
    Some(52 + code.to_int() - ('0' : UInt16).to_int())
  } else if code == '+' {
    Some(62)
  } else if code == '/' {
    Some(63)
  } else {
    None
  }
}

///|
fn import_workspace_files_response(
  workspace_id : String,
  target_directory : String,
  items : Array[Json],
) -> Json {
  let first = if items.length() == 0 { Json::object({}) } else { items[0] }
  let first_path = json_string(first, "path", default="")
  {
    "workspace_id": workspace_id,
    "path": visible_import_path(target_directory, first_path),
    "directory": target_directory,
    "imported_count": items.length(),
    "items": Json::array(items),
  }
}

///|
fn visible_import_path(target_directory : String, path : String) -> String {
  if path == "" {
    return ""
  }
  let remainder = if target_directory == "" {
    path
  } else {
    let prefix = target_directory + "/"
    if path.has_prefix(prefix) {
      path[prefix.length():].to_owned()
    } else {
      path
    }
  }
  let segments = path_segments(remainder)
  if segments.length() == 0 {
    target_directory
  } else if target_directory == "" {
    segments[0]
  } else {
    @pathx.join(target_directory, segments[0])
  }
}

///|
async fn move_workspace_entry(
  workspace : @desk.DeskWorkspace,
  payload : Json,
) -> Result[Json, Json] {
  let requested_paths = move_payload_paths(payload)
  if requested_paths.length() == 0 {
    return Err(
      workspace_entry_create_error(400, "Bad Request", "Entry path is required"),
    )
  }
  let target_directory = match move_target_directory(workspace, payload) {
    Ok(directory) => directory
    Err(error) => return Err(error)
  }
  let planned : Array[(String, String, String, String)] = []
  let seen_sources : Array[String] = []
  let seen_targets : Array[String] = []
  for requested_path in requested_paths {
    let source_path = decode_query_value(requested_path)
    let source = match
      resolve_workspace_path(workspace.root_path, source_path) {
      Some((absolute, clean_relative)) => (absolute, clean_relative)
      None =>
        return Err(
          workspace_entry_create_error(
            400, "Bad Request", "Invalid source path",
          ),
        )
    }
    let (source_absolute, source_relative) = source
    if seen_sources.contains(source_relative) {
      return Err(
        workspace_entry_create_error(
          400, "Bad Request", "Duplicate source path",
        ),
      )
    }
    for seen_source in seen_sources {
      if move_sources_overlap(seen_source, source_relative) {
        return Err(
          workspace_entry_create_error(
            400, "Bad Request", "Overlapping source paths",
          ),
        )
      }
    }
    seen_sources.push(source_relative)
    match validate_move_source(source_absolute, source_relative) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
    let target_relative = if target_directory == "" {
      @desk.display_name(source_relative)
    } else {
      @pathx.join(target_directory, @desk.display_name(source_relative))
    }
    if seen_targets.contains(target_relative) {
      return Err(
        workspace_entry_create_error(409, "Conflict", "Duplicate target path"),
      )
    }
    seen_targets.push(target_relative)
    let target_absolute = match
      validate_move_target(
        workspace, source_absolute, source_relative, target_relative, target_directory,
      ) {
      Ok(absolute) => absolute
      Err(error) => return Err(error)
    }
    planned.push(
      (source_absolute, source_relative, target_absolute, target_relative),
    )
  }
  let items : Array[Json] = []
  for item in planned {
    let (source_absolute, source_relative, target_absolute, target_relative) = item
    if target_relative == source_relative {
      items.push(rename_workspace_entry_response(workspace.id, source_relative))
      continue
    }
    @fs.rename(source_absolute, target_absolute) catch {
      _ =>
        return Err(
          workspace_entry_create_error(
            500, "Internal Server Error", "Could not move entry",
          ),
        )
    }
    items.push(rename_workspace_entry_response(workspace.id, target_relative))
  }
  Ok(move_workspace_entry_response(workspace.id, items))
}

///|
fn move_payload_paths(payload : Json) -> Array[String] {
  let paths = json_string_array_items(payload, "paths")
  if paths.length() > 0 {
    paths
  } else {
    let path = json_string(payload, "path", default="").trim().to_owned()
    if path == "" {
      []
    } else {
      [path]
    }
  }
}

///|
fn move_sources_overlap(left : String, right : String) -> Bool {
  left.has_prefix(right + "/") || right.has_prefix(left + "/")
}

///|
async fn move_target_directory(
  workspace : @desk.DeskWorkspace,
  payload : Json,
) -> Result[String, Json] {
  let target_directory_input = decode_query_value(
    json_string(payload, "directory", default=""),
  )
  let target_directory = match clean_relative_path(target_directory_input) {
    Some(path) => path
    None =>
      return Err(
        workspace_entry_create_error(
          400, "Bad Request", "Invalid target directory",
        ),
      )
  }
  let target_directory_absolute = match
    resolve_workspace_path(workspace.root_path, target_directory) {
    Some((absolute, _)) => absolute
    None =>
      return Err(
        workspace_entry_create_error(
          400, "Bad Request", "Invalid target directory",
        ),
      )
  }
  if !@fs.exists(target_directory_absolute) {
    if is_virtual_moonbook_section(workspace, target_directory) {
      @fsx.make_directory(
        target_directory_absolute,
        recursive=true,
        exists_ok=true,
      ) catch {
        _ =>
          return Err(
            workspace_entry_create_error(
              500, "Internal Server Error", "Could not create target directory",
            ),
          )
      }
    } else {
      return Err(
        workspace_entry_create_error(
          404, "Not Found", "Target directory not found",
        ),
      )
    }
  } else if !is_directory(target_directory_absolute) {
    return Err(
      workspace_entry_create_error(
        400, "Bad Request", "Target path is not a directory",
      ),
    )
  }
  Ok(target_directory)
}

///|
async fn validate_move_source(
  source_absolute : String,
  source_relative : String,
) -> Result[Unit, Json] {
  if source_relative == "" ||
    moonbook_section_for_path(source_relative) is Some(_) {
    return Err(
      workspace_entry_create_error(
        400, "Bad Request", "Desk cannot move MoonBook sections",
      ),
    )
  }
  if !@fs.exists(source_absolute) {
    return Err(
      workspace_entry_create_error(404, "Not Found", "Entry path not found"),
    )
  }
  if !is_desk_create_path_allowed(source_relative) {
    return Err(
      workspace_entry_create_error(
        400, "Bad Request", "Desk cannot move generated or system paths",
      ),
    )
  }
  Ok(())
}

///|
async fn validate_move_target(
  workspace : @desk.DeskWorkspace,
  source_absolute : String,
  source_relative : String,
  target_relative : String,
  target_directory : String,
) -> Result[String, Json] {
  if target_relative == source_relative {
    return Ok(source_absolute)
  }
  if !is_desk_create_path_allowed(target_relative) ||
    moonbook_section_for_path(target_relative) is Some(_) {
    return Err(
      workspace_entry_create_error(
        400, "Bad Request", "Desk cannot move into generated or system paths",
      ),
    )
  }
  if is_directory(source_absolute) &&
    (
      target_directory == source_relative ||
      target_directory.has_prefix(source_relative + "/")
    ) {
    return Err(
      workspace_entry_create_error(
        400, "Bad Request", "Desk cannot move a folder into itself",
      ),
    )
  }
  let target_absolute = match
    resolve_workspace_path(workspace.root_path, target_relative) {
    Some((absolute, _)) => absolute
    None =>
      return Err(
        workspace_entry_create_error(400, "Bad Request", "Invalid target path"),
      )
  }
  if @fs.exists(target_absolute) {
    return Err(
      workspace_entry_create_error(409, "Conflict", "Entry already exists"),
    )
  }
  Ok(target_absolute)
}

///|
fn move_workspace_entry_response(
  workspace_id : String,
  items : Array[Json],
) -> Json {
  let first = if items.length() == 0 { Json::object({}) } else { items[0] }
  {
    "workspace_id": workspace_id,
    "path": json_string(first, "path", default=""),
    "directory": json_string(first, "directory", default=""),
    "moved_count": items.length(),
    "items": Json::array(items),
  }
}

///|
fn clean_rename_entry_name(
  requested_name : String,
  source_relative : String,
  is_source_directory : Bool,
) -> Result[String, String] {
  let base = match clean_new_entry_name(requested_name, "folder") {
    Ok(name) => name
    Err(message) => return Err(message)
  }
  if is_source_directory || base.contains(".") {
    Ok(base)
  } else {
    let ext = @pathx.ext(source_relative).to_owned()
    if ext == "" {
      Ok(base)
    } else {
      Ok(base + ext)
    }
  }
}

///|
fn rename_workspace_entry_response(
  workspace_id : String,
  path : String,
) -> Json {
  {
    "workspace_id": workspace_id,
    "path": path,
    "directory": parent_path_for_created_entry(path),
  }
}

///|
fn clean_new_entry_name(name : String, kind : String) -> Result[String, String] {
  if name == "" {
    return Err("Entry name is required")
  }
  if name == "." || name == ".." || name.has_prefix(".") {
    return Err("Entry name is not allowed")
  }
  if name.contains("/") || name.contains("\\") || @pathx.is_absolute(name) {
    return Err("Entry name must not contain path separators")
  }
  if should_hide_file_entry(name) {
    return Err("Entry name is reserved")
  }
  let normalized = @pathx.normalize(name)
  if normalized != name {
    return Err("Entry name is not allowed")
  }
  if kind == "markdown" || kind == "note" || kind == "file" {
    if is_markdown_file_path(name) {
      Ok(name)
    } else {
      Ok(name + ".md")
    }
  } else {
    Ok(name)
  }
}

///|
fn is_desk_create_path_allowed(path : String) -> Bool {
  path != "" &&
  !path.has_prefix(".moonsuite") &&
  !path.has_prefix(".tmp") &&
  !path.has_prefix(".moontown") &&
  !path.has_prefix("book/") &&
  path != "book" &&
  !path.has_prefix("site/generated") &&
  !path.has_prefix("portable") &&
  !path.has_prefix("moonclaw-jobs") &&
  !path.contains("/../")
}

///|
fn parent_path_for_created_entry(path : String) -> String {
  match path.rev_split_once("/") {
    Some((parent, _)) => parent.to_owned()
    None => ""
  }
}

///|
fn markdown_title_from_path(path : String) -> String {
  let name = @desk.display_name(path)
  if name.has_suffix(".markdown") {
    name[:name.length() - ".markdown".length()].to_owned()
  } else if name.has_suffix(".mbt.md") {
    name[:name.length() - ".mbt.md".length()].to_owned()
  } else if name.has_suffix(".md") {
    name[:name.length() - ".md".length()].to_owned()
  } else {
    name
  }
}

///|
fn workspace_entry_create_error(
  code : Int,
  reason : String,
  message : String,
) -> Json {
  { "code": code, "reason": reason, "message": message }
}
