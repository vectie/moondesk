///|
async fn handle_workspace_create(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = match read_json_body(body) {
    Some(payload) => payload
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  let result = create_blank_moonbook_workspace(workspace_root, payload)
  match result {
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
            default="Could not create MoonBook",
          ),
        },
      )
  }
}

///|
async fn handle_moonbook_import(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = match read_json_body(body) {
    Some(payload) => payload
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  let result = import_existing_moonbook_workspace(workspace_root, payload)
  match result {
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
            default="Could not import MoonBook",
          ),
        },
      )
  }
}

///|
async fn create_blank_moonbook_workspace(
  workspace_root : String,
  payload : Json,
) -> Result[Json, Json] {
  let name = json_first_string(payload, ["name", "title"], default="")
    .trim()
    .to_owned()
  let requested_id = json_first_string(payload, ["book_id", "id"], default="")
  let from_name = if name == "" {
    ""
  } else {
    "research-" + sanitize_external_id(name)
  }
  let book_id = if requested_id.trim().to_owned() == "" {
    from_name
  } else {
    sanitize_external_id(requested_id)
  }
  if book_id == "" {
    return Err(
      workspace_create_error(
        400, "Bad Request", "MoonBook name or id is required",
      ),
    )
  }
  if book_id == "." || book_id == ".." || book_id.has_prefix(".") {
    return Err(
      workspace_create_error(400, "Bad Request", "MoonBook id is not allowed"),
    )
  }
  let title = if name == "" { book_id } else { name }
  let context = workspace_context(workspace_root)
  let book_root = context.book_root(book_id)
  if !context.book_root_allowed(book_root) {
    return Err(
      workspace_create_error(400, "Bad Request", "MoonBook path is not allowed"),
    )
  }
  if @fs.exists(book_root) {
    return Err(
      workspace_create_error(409, "Conflict", "MoonBook already exists"),
    )
  }
  @fsx.make_directory(context.books_root, recursive=true, exists_ok=true) catch {
    _ =>
      return Err(
        workspace_create_error(
          500, "Internal Server Error", "Could not prepare MoonBook library",
        ),
      )
  }
  for path in ["", "wiki", "raw", "inbox", "book/site/generated", "reviews"] {
    @fsx.make_directory(
      @pathx.join(book_root, path),
      recursive=true,
      exists_ok=true,
    ) catch {
      _ =>
        return Err(
          workspace_create_error(
            500, "Internal Server Error", "Could not create MoonBook layout",
          ),
        )
    }
  }
  @fsx.make_directory(
    moonclaw_jobs_root(book_root),
    recursive=true,
    exists_ok=true,
  ) catch {
    _ =>
      return Err(
        workspace_create_error(
          500, "Internal Server Error", "Could not prepare MoonClaw product ledger",
        ),
      )
  }
  let book_json : Json = {
    "id": book_id,
    "name": title,
    "created_by": "moondesk-desk",
  }
  @fsx.write_to_file(
    @pathx.join(book_root, "book.json"),
    book_json.stringify(indent=2) + "\n",
  ) catch {
    _ =>
      return Err(
        workspace_create_error(
          500, "Internal Server Error", "Could not write MoonBook manifest",
        ),
      )
  }
  @fsx.write_to_file(
    @pathx.join(book_root, "wiki/index.md"),
    "# \{title}\n\nThis MoonBook was created from Desk.\n",
  ) catch {
    _ =>
      return Err(
        workspace_create_error(
          500, "Internal Server Error", "Could not write MoonBook home page",
        ),
      )
  }
  let workspace_id = @desk.stable_id("book", book_id)
  Ok({
    "workspace_id": workspace_id,
    "book_id": book_id,
    "name": title,
    "root_path": book_root,
    "path": "wiki/index.md",
  })
}

///|
async fn import_existing_moonbook_workspace(
  workspace_root : String,
  payload : Json,
) -> Result[Json, Json] {
  let uploaded_files = @mooncore.json_array_items(payload, "files")
  if uploaded_files.length() > 0 {
    return import_moonbook_from_uploaded_files(
      workspace_root, payload, uploaded_files,
    )
  }
  let data_url = json_string(payload, "data_url", default="")
  if data_url != "" {
    return import_moonbook_from_data_url(workspace_root, payload, data_url)
  }
  let source_input = json_first_string(
    payload,
    ["source_path", "source", "root_path"],
    default="",
  )
  let source_path = @pathx.normalize(source_input.trim().to_owned())
  if source_path == "" || source_path == "." {
    return Err(
      workspace_create_error(
        400, "Bad Request", "MoonBook source path is required",
      ),
    )
  }
  if is_directory(source_path) {
    return import_moonbook_from_source_dir(
      workspace_root,
      payload,
      source_path,
      @desk.display_name(source_path),
    )
  }
  if !@fs.exists(source_path) {
    return Err(
      workspace_create_error(
        404, "Not Found", "MoonBook source folder or archive was not found",
      ),
    )
  }
  if import_is_zip_archive(source_path) {
    return import_moonbook_from_archive(workspace_root, payload, source_path)
  }
  Err(
    workspace_create_error(
      400, "Bad Request", "MoonBook source must be a folder or .zip archive",
    ),
  )
}

///|
async fn import_moonbook_from_uploaded_files(
  workspace_root : String,
  payload : Json,
  files : Array[Json],
) -> Result[Json, Json] {
  @moonlib/fsx.with_temporary_directory(
    "moondesk-moonbook-folder-upload-XXXXXX",
    temp_root => {
      let source_root = @pathx.join(temp_root, "source")
      @fsx.make_directory(source_root, recursive=true, exists_ok=true) catch {
        error =>
          return Err(
            workspace_create_error(
              500,
              "Internal Server Error",
              "Could not create folder-upload staging directory: \{error}",
            ),
          )
      }
      let staged_paths : Array[String] = []
      for file in files {
        let relative = match import_uploaded_moonbook_file_path(file) {
          Ok(path) => path
          Err(message) =>
            return Err(workspace_create_error(400, "Bad Request", message))
        }
        if staged_paths.contains(relative) {
          return Err(
            workspace_create_error(
              400, "Bad Request", "MoonBook folder upload contains duplicate paths",
            ),
          )
        }
        let bytes = match import_file_bytes(file) {
          Ok(bytes) => bytes
          Err(message) =>
            return Err(workspace_create_error(400, "Bad Request", message))
        }
        let target = @pathx.join(source_root, relative)
        @fsx.make_directory(
          @pathx.dirname(target).to_owned(),
          recursive=true,
          exists_ok=true,
        ) catch {
          error =>
            return Err(
              workspace_create_error(
                500,
                "Internal Server Error",
                "Could not create uploaded-file parent directory: \{error}",
              ),
            )
        }
        write_bytes_file(target, bytes, create=0o644) catch {
          error =>
            return Err(
              workspace_create_error(
                500,
                "Internal Server Error",
                "Could not stage folder upload: \{error}",
              ),
            )
        }
        staged_paths.push(relative)
      }
      let source_dir = match import_archive_source_dir(source_root) {
        Some(path) => path
        None =>
          return Err(
            workspace_create_error(
              400,
              "Bad Request",
              "MoonBook folder upload must contain " +
              moonbook_metadata_requirement(),
            ),
          )
      }
      import_moonbook_from_source_dir(
        workspace_root,
        payload,
        source_dir,
        @desk.display_name(source_dir),
      )
    },
  ) catch {
    error =>
      Err(
        workspace_create_error(
          500,
          "Internal Server Error",
          "Could not create temporary folder-upload workspace: \{error}",
        ),
      )
  }
}

///|
async fn import_moonbook_from_data_url(
  workspace_root : String,
  payload : Json,
  data_url : String,
) -> Result[Json, Json] {
  let bytes = match decode_data_url_bytes(data_url) {
    Ok(bytes) => bytes
    Err(message) =>
      return Err(workspace_create_error(400, "Bad Request", message))
  }
  let filename = import_archive_upload_filename(
    json_first_string(payload, ["filename", "name", "title"], default=""),
  )
  @moonlib/fsx.with_temporary_directory("moondesk-moonbook-upload-", temp_root => {
    let archive_path = @pathx.join(temp_root, filename)
    write_bytes_file(archive_path, bytes, create=0o644) catch {
      _ =>
        return Err(
          workspace_create_error(
            500, "Internal Server Error", "Could not stage archive upload",
          ),
        )
    }
    import_moonbook_from_archive(workspace_root, payload, archive_path)
  }) catch {
    _ =>
      Err(
        workspace_create_error(
          500, "Internal Server Error", "Could not stage archive upload",
        ),
      )
  }
}

///|
async fn import_moonbook_from_source_dir(
  workspace_root : String,
  payload : Json,
  source_path : String,
  source_name : String,
) -> Result[Json, Json] {
  let manifest = match moonbook_metadata(source_path) {
    Some(value) => value
    None =>
      return Err(
        workspace_create_error(
          400,
          "Bad Request",
          "MoonBook source must contain " + moonbook_metadata_requirement(),
        ),
      )
  }
  let requested_id = json_first_string(payload, ["book_id", "id"], default="")
  let manifest_id = json_first_string(manifest, ["id", "book_id"], default="")
  let book_id = import_moonbook_id(requested_id, manifest_id, source_name)
  if book_id == "" ||
    book_id == "." ||
    book_id == ".." ||
    book_id.has_prefix(".") {
    return Err(
      workspace_create_error(400, "Bad Request", "MoonBook id is not allowed"),
    )
  }
  let title = import_moonbook_title(payload, manifest, book_id)
  let context = workspace_context(workspace_root)
  let book_root = context.book_root(book_id)
  if !context.book_root_allowed(book_root) {
    return Err(
      workspace_create_error(400, "Bad Request", "MoonBook path is not allowed"),
    )
  }
  if @pathx.normalize(source_path) == book_root {
    return Ok(import_moonbook_response(book_id, title, book_root))
  }
  if @fs.exists(book_root) {
    return Err(
      workspace_create_error(409, "Conflict", "MoonBook already exists"),
    )
  }
  @fsx.make_directory(context.books_root, recursive=true, exists_ok=true) catch {
    _ =>
      return Err(
        workspace_create_error(
          500, "Internal Server Error", "Could not prepare MoonBook library",
        ),
      )
  }
  let copied = import_copy_dir_recursive(source_path, book_root, "") catch {
    _ => false
  }
  if !copied {
    return Err(
      workspace_create_error(
        500, "Internal Server Error", "Could not copy MoonBook into library",
      ),
    )
  }
  Ok(import_moonbook_response(book_id, title, book_root))
}

///|
async fn import_moonbook_from_archive(
  workspace_root : String,
  payload : Json,
  archive_path : String,
) -> Result[Json, Json] {
  @moonlib/fsx.with_temporary_directory("moondesk-moonbook-import-", temp_root => {
    let extract_root = @pathx.join(temp_root, "archive")
    @fsx.make_directory(extract_root, recursive=true, exists_ok=true) catch {
      _ =>
        return Err(
          workspace_create_error(
            500, "Internal Server Error", "Could not prepare archive import",
          ),
        )
    }
    match import_extract_zip_archive(archive_path, extract_root) {
      ArchiveExtracted => ()
      ArchiveRejected(reason) =>
        return Err(
          workspace_create_error(
            400,
            "Bad Request",
            "Could not extract MoonBook .zip archive: " + reason,
          ),
        )
    }
    let source_dir = match import_archive_source_dir(extract_root) {
      Some(path) => path
      None =>
        return Err(
          workspace_create_error(
            400,
            "Bad Request",
            "MoonBook archive must contain " + moonbook_metadata_requirement(),
          ),
        )
    }
    import_moonbook_from_source_dir(
      workspace_root,
      payload,
      source_dir,
      import_archive_default_name(archive_path),
    )
  }) catch {
    _ =>
      Err(
        workspace_create_error(
          500, "Internal Server Error", "Could not prepare archive import",
        ),
      )
  }
}

///|
fn import_is_zip_archive(path : String) -> Bool {
  path.to_lower().has_suffix(".zip")
}

///|
priv enum ImportArchiveExtractionResult {
  ArchiveExtracted
  ArchiveRejected(String)
}

///|
/// Extracts only bounded, stored ZIP entries. Deflate is deliberately refused:
/// the current in-process ZIP API accepts the entry size as a hint and may grow
/// beyond it, so it cannot enforce a hard expansion limit for hostile input.
async fn import_extract_zip_archive(
  archive_path : String,
  extract_root : String,
) -> ImportArchiveExtractionResult {
  let limits = archive_import_limits()
  let archive_file = @fs.open(archive_path, mode=ReadOnly) catch {
    _ => return ArchiveRejected("archive is unavailable")
  }
  defer archive_file.close()
  let archive_size = archive_file.size() catch {
    _ => return ArchiveRejected("archive size is unavailable")
  }
  if archive_size <= 0L || archive_size > limits.max_archive_bytes.to_int64() {
    return ArchiveRejected("archive exceeds the compressed-size limit")
  }
  let archive = archive_file.read_exactly(archive_size.to_int()).to_fixedarray() catch {
      _ => return ArchiveRejected("archive could not be read")
    }
  let entries = @moonzip.unzip_list(archive) catch {
    _ => return ArchiveRejected("archive directory is invalid")
  }
  if entries.length() == 0 || entries.length() > limits.max_entries {
    return ArchiveRejected("archive entry limit exceeded")
  }
  let clean_paths : Array[String] = []
  let directories : Array[Bool] = []
  let collision_keys : Array[String] = []
  let mut expanded_bytes = 0
  for entry in entries {
    let clean = match archive_entry_path(entry.name) {
      Ok(path) => path
      Err(_) => return ArchiveRejected("archive entry path is not confined")
    }
    let collision_key = clean.to_lower()
    if collision_keys.contains(collision_key) {
      return ArchiveRejected("archive contains a duplicate path")
    }
    collision_keys.push(collision_key)
    let unix_kind = (entry.attrs >> 16) & 0xF000
    if unix_kind != 0 && unix_kind != 0x4000 && unix_kind != 0x8000 {
      return ArchiveRejected("archive contains an unsupported entry type")
    }
    let is_directory = entry.name.has_suffix("/") ||
      unix_kind == 0x4000 ||
      (entry.attrs & 0x10) != 0
    if is_directory {
      if entry.original_size != 0 {
        return ArchiveRejected("archive directory contains payload bytes")
      }
    } else {
      if entry.compression != 0 || entry.size != entry.original_size {
        return ArchiveRejected(
          "compressed archive entries require an execution sandbox",
        )
      }
      if entry.original_size < 0 || entry.original_size > limits.max_file_bytes {
        return ArchiveRejected("archive entry exceeds the expanded-size limit")
      }
      expanded_bytes += entry.original_size
      if expanded_bytes > limits.max_total_bytes {
        return ArchiveRejected("archive exceeds the expanded-size limit")
      }
    }
    clean_paths.push(clean)
    directories.push(is_directory)
  }
  let extracted = @moonzip.unzip_sync(archive) catch {
    _ => return ArchiveRejected("archive payload is invalid")
  }
  if extracted.length() != entries.length() {
    return ArchiveRejected("archive directory changed during extraction")
  }
  for index, item in extracted {
    let (name, bytes) = item
    if name != entries[index].name ||
      bytes.length() != entries[index].original_size {
      return ArchiveRejected("archive payload does not match its directory")
    }
    let target = @pathx.join(extract_root, clean_paths[index])
    if directories[index] {
      @fsx.make_directory(target, recursive=true, exists_ok=true) catch {
        _ => return ArchiveRejected("archive directory could not be staged")
      }
      continue
    }
    @fsx.make_directory(@pathx.dirname(target), recursive=true, exists_ok=true) catch {
      _ => return ArchiveRejected("archive entry directory could not be staged")
    }
    @fs.write_file(
      target,
      Bytes::makei(bytes.length(), index => bytes[index]),
      create_mode=CreateNew,
      permission=0o600,
    ) catch {
      _ => return ArchiveRejected("archive entry could not be staged")
    }
  }
  ArchiveExtracted
}

///|
async fn import_archive_source_dir(extract_root : String) -> String? {
  if moonbook_metadata_exists(extract_root) {
    return Some(extract_root)
  }
  let candidates : Array[String] = []
  for name in read_directory_names(extract_root, include_hidden=true) {
    if import_should_skip_copy_name(name) {
      continue
    }
    let child = @pathx.join(extract_root, name)
    if is_directory(child) && moonbook_metadata_exists(child) {
      candidates.push(child)
    }
  }
  if candidates.length() == 1 {
    Some(candidates[0])
  } else {
    None
  }
}

///|
fn import_uploaded_moonbook_file_path(file : Json) -> Result[String, String] {
  let fallback_name = json_string(
    file,
    "filename",
    default=json_string(file, "name", default=""),
  )
  let raw_path = json_string(file, "relative_path", default="")
    .trim()
    .to_owned()
  let candidate = if raw_path == "" {
    fallback_name.trim().to_owned()
  } else {
    raw_path
  }
  if candidate == "" {
    return Err("MoonBook folder upload includes a file without a path")
  }
  if candidate.contains("\\") ||
    candidate.has_prefix("/") ||
    @pathx.is_absolute(candidate) {
    return Err("MoonBook folder upload path must be relative")
  }
  match clean_relative_path(candidate) {
    Some(clean) =>
      if clean == "" {
        Err("MoonBook folder upload path is not allowed")
      } else {
        Ok(clean)
      }
    None => Err("MoonBook folder upload path is not allowed")
  }
}

///|
fn import_archive_default_name(archive_path : String) -> String {
  let name = @desk.display_name(archive_path)
  if import_is_zip_archive(name) {
    name[:name.length() - 4].to_owned()
  } else {
    name
  }
}

///|
fn import_archive_upload_filename(filename : String) -> String {
  let leaf = @desk.display_name(filename.trim().to_owned())
  let base = if leaf == "" { "moonbook-upload.zip" } else { leaf }
  if import_is_zip_archive(base) {
    base
  } else {
    base + ".zip"
  }
}

///|
fn import_moonbook_id(
  requested_id : String,
  manifest_id : String,
  source_name : String,
) -> String {
  let requested = sanitize_external_id(requested_id)
  if requested != "" {
    requested
  } else {
    let from_manifest = sanitize_external_id(manifest_id)
    if from_manifest != "" {
      from_manifest
    } else {
      sanitize_external_id(source_name)
    }
  }
}

///|
fn import_moonbook_title(
  payload : Json,
  manifest : Json,
  book_id : String,
) -> String {
  let requested = json_first_string(payload, ["name", "title"], default="")
    .trim()
    .to_owned()
  if requested != "" {
    requested
  } else {
    let from_manifest = json_first_string(
        manifest,
        ["name", "title"],
        default="",
      )
      .trim()
      .to_owned()
    if from_manifest == "" {
      book_id
    } else {
      from_manifest
    }
  }
}

///|
async fn import_moonbook_response(
  book_id : String,
  title : String,
  book_root : String,
) -> Json {
  {
    "workspace_id": @desk.stable_id("book", book_id),
    "book_id": book_id,
    "name": title,
    "root_path": book_root,
    "path": import_initial_path(book_root),
  }
}

///|
async fn import_initial_path(book_root : String) -> String {
  if @fs.exists(@pathx.join(book_root, "wiki/index.md")) {
    "wiki/index.md"
  } else {
    ""
  }
}

///|
async fn import_copy_dir_recursive(
  source_root : String,
  target_root : String,
  relative_dir : String,
) -> Bool {
  let target_dir = if relative_dir == "" {
    target_root
  } else {
    @pathx.join(target_root, relative_dir)
  }
  @fsx.make_directory(target_dir, recursive=true, exists_ok=true) catch {
    _ => return false
  }
  let source_dir = if relative_dir == "" {
    source_root
  } else {
    @pathx.join(source_root, relative_dir)
  }
  for name in read_directory_names(source_dir, include_hidden=true) {
    if import_should_skip_copy_name(name) {
      continue
    }
    let child_relative = if relative_dir == "" {
      name
    } else {
      @pathx.join(relative_dir, name)
    }
    let child_source = @pathx.join(source_root, child_relative)
    if is_directory(child_source) {
      if !import_copy_dir_recursive(source_root, target_root, child_relative) {
        return false
      }
    } else if !import_copy_file(source_root, target_root, child_relative) {
      return false
    }
  }
  true
}

///|
fn import_should_skip_copy_name(name : String) -> Bool {
  name == ".DS_Store" ||
  name == "__MACOSX" ||
  name == ".git" ||
  name == "node_modules" ||
  name == "_build" ||
  name == ".moonbit" ||
  name == ".mooncakes"
}

///|
async fn import_copy_file(
  source_root : String,
  target_root : String,
  relative : String,
) -> Bool {
  let source = @pathx.join(source_root, relative)
  let target = @pathx.join(target_root, relative)
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
fn workspace_create_error(
  code : Int,
  reason : String,
  message : String,
) -> Json {
  { "code": code, "reason": reason, "message": message }
}
