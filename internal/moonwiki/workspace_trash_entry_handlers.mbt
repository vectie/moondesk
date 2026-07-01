///|
async fn handle_workspace_trash_entry(
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
  match trash_workspace_entry(workspace, payload) {
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
            default="Could not move entry to trash",
          ),
        },
      )
  }
}

///|
async fn handle_workspace_trash_listing(
  workspace_root : String,
  workspace_id : String,
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
  send_json(conn, method_, Json::array(list_workspace_trash_entries(workspace)))
}

///|
async fn handle_workspace_restore_entry(
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
  match restore_workspace_entry(workspace, payload) {
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
            default="Could not restore entry",
          ),
        },
      )
  }
}

///|
async fn list_workspace_trash_entries(
  workspace : @desk.DeskWorkspace,
) -> Array[Json] {
  let entries : Array[Json] = []
  let receipts_dir = desk_trash_receipts_root(workspace.root_path)
  for name in read_directory_names(receipts_dir, include_hidden=false) {
    if !name.has_suffix(".json") {
      continue
    }
    let receipt_absolute = @pathx.join(receipts_dir, name)
    let receipt = @json.parse(@fs.read_file(receipt_absolute).text()) catch {
      _ => continue
    }
    if json_string(receipt, "workspace_id", default="") != workspace.id {
      continue
    }
    let trash_path = json_string(receipt, "trash_path", default="")
    let trash = match resolve_desk_trash_path(workspace.root_path, trash_path) {
      Some(absolute) => (absolute, @pathx.normalize(trash_path))
      None => continue
    }
    let (trash_absolute, trash_relative) = trash
    if !is_desk_trash_path(trash_relative) || !@fs.exists(trash_absolute) {
      continue
    }
    entries.push({
      "workspace_id": workspace.id,
      "original_path": json_string(receipt, "original_path", default=""),
      "trash_path": trash_relative,
      "receipt_path": json_string(receipt, "receipt_path", default=""),
      "trashed_at": json_string(receipt, "trashed_at", default=""),
    })
  }
  entries.sort_by(fn(left, right) {
    json_string(right, "trashed_at", default="").compare(
      json_string(left, "trashed_at", default=""),
    )
  })
  entries
}

///|
async fn trash_workspace_entry(
  workspace : @desk.DeskWorkspace,
  payload : Json,
) -> Result[Json, Json] {
  let requested_paths = trash_payload_paths(payload)
  if requested_paths.length() == 0 {
    return Err(
      workspace_entry_create_error(400, "Bad Request", "Entry path is required"),
    )
  }
  let planned : Array[(String, String, String, String)] = []
  let seen : Array[String] = []
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
    if seen.contains(source_relative) {
      return Err(
        workspace_entry_create_error(
          400, "Bad Request", "Duplicate source path",
        ),
      )
    }
    seen.push(source_relative)
    match validate_trash_source(source_absolute, source_relative) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
    let trash_id = unique_trash_id(source_relative)
    let trash_relative = desk_trash_file_relative_path(
      trash_id,
      @desk.display_name(source_relative),
    )
    let receipt_relative = desk_trash_receipt_relative_path(trash_id)
    let trash_absolute = match
      resolve_desk_trash_path(workspace.root_path, trash_relative) {
      Some(path) => path
      None =>
        return Err(
          workspace_entry_create_error(
            500, "Internal Server Error", "Invalid trash target",
          ),
        )
    }
    if @fs.exists(trash_absolute) {
      return Err(
        workspace_entry_create_error(
          409, "Conflict", "Trash entry already exists",
        ),
      )
    }
    planned.push(
      (source_absolute, source_relative, trash_relative, receipt_relative),
    )
  }
  let items : Array[Json] = []
  for item in planned {
    let (source_absolute, source_relative, trash_relative, receipt_relative) = item
    let response = match
      trash_planned_workspace_entry(
        workspace, source_absolute, source_relative, trash_relative, receipt_relative,
      ) {
      Ok(response) => response
      Err(error) => return Err(error)
    }
    items.push(response)
  }
  Ok(trash_workspace_batch_response(workspace.id, items))
}

///|
fn trash_payload_paths(payload : Json) -> Array[String] {
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
async fn validate_trash_source(
  source_absolute : String,
  source_relative : String,
) -> Result[Unit, Json] {
  if source_relative == "" ||
    moonbook_section_for_path(source_relative) is Some(_) {
    return Err(
      workspace_entry_create_error(
        400, "Bad Request", "Desk cannot trash MoonBook sections",
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
        400, "Bad Request", "Desk cannot trash generated or system paths",
      ),
    )
  }
  Ok(())
}

///|
async fn trash_planned_workspace_entry(
  workspace : @desk.DeskWorkspace,
  source_absolute : String,
  source_relative : String,
  trash_relative : String,
  receipt_relative : String,
) -> Result[Json, Json] {
  let trash_absolute = match
    resolve_desk_trash_path(workspace.root_path, trash_relative) {
    Some(path) => path
    None =>
      return Err(
        workspace_entry_create_error(400, "Bad Request", "Invalid trash path"),
      )
  }
  let receipt_absolute = match
    resolve_desk_trash_receipt_path(workspace.root_path, receipt_relative) {
    Some(path) => path
    None =>
      return Err(
        workspace_entry_create_error(
          400, "Bad Request", "Invalid trash receipt path",
        ),
      )
  }
  @fsx.make_directory(
    @pathx.dirname(trash_absolute).to_owned(),
    recursive=true,
    exists_ok=true,
  ) catch {
    _ =>
      return Err(
        workspace_entry_create_error(
          500, "Internal Server Error", "Could not create trash directory",
        ),
      )
  }
  @fsx.make_directory(
    @pathx.dirname(receipt_absolute).to_owned(),
    recursive=true,
    exists_ok=true,
  ) catch {
    _ =>
      return Err(
        workspace_entry_create_error(
          500, "Internal Server Error", "Could not create trash receipts",
        ),
      )
  }
  @fs.rename(source_absolute, trash_absolute) catch {
    _ =>
      return Err(
        workspace_entry_create_error(
          500, "Internal Server Error", "Could not move entry to trash",
        ),
      )
  }
  let receipt : Json = {
    "kind": "desk-trash-receipt",
    "workspace_id": workspace.id,
    "original_path": source_relative,
    "trash_path": trash_relative,
    "receipt_path": receipt_relative,
    "trashed_at": @async.now().to_string(),
  }
  @fsx.write_to_file(
    receipt_absolute,
    receipt.stringify(indent=2) + "\n",
    create=0o644,
  ) catch {
    _ =>
      return Err(
        workspace_entry_create_error(
          500, "Internal Server Error", "Could not record trash receipt",
        ),
      )
  }
  Ok(
    trash_workspace_entry_response(
      workspace.id,
      source_relative,
      trash_relative,
    ),
  )
}

///|
fn trash_workspace_batch_response(
  workspace_id : String,
  items : Array[Json],
) -> Json {
  let first = if items.length() == 0 { Json::object({}) } else { items[0] }
  let last = if items.length() == 0 {
    Json::object({})
  } else {
    items[items.length() - 1]
  }
  {
    "workspace_id": workspace_id,
    "path": json_string(first, "path", default=""),
    "directory": json_string(first, "directory", default=""),
    "trash_path": json_string(last, "trash_path", default=""),
    "trashed_count": items.length(),
    "items": Json::array(items),
  }
}

///|
async fn restore_workspace_entry(
  workspace : @desk.DeskWorkspace,
  payload : Json,
) -> Result[Json, Json] {
  let trash_path = decode_query_value(
    json_string(payload, "trash_path", default=""),
  )
  let trash = match resolve_desk_trash_path(workspace.root_path, trash_path) {
    Some(absolute) => (absolute, @pathx.normalize(trash_path))
    None =>
      return Err(
        workspace_entry_create_error(400, "Bad Request", "Invalid trash path"),
      )
  }
  let (trash_absolute, trash_relative) = trash
  if !is_desk_trash_path(trash_relative) {
    return Err(
      workspace_entry_create_error(400, "Bad Request", "Invalid trash path"),
    )
  }
  if !@fs.exists(trash_absolute) {
    return Err(
      workspace_entry_create_error(404, "Not Found", "Trash entry not found"),
    )
  }
  let receipt = match read_trash_receipt(workspace.root_path, trash_relative) {
    Some(receipt) => receipt
    None =>
      return Err(
        workspace_entry_create_error(
          404, "Not Found", "Trash receipt not found",
        ),
      )
  }
  if json_string(receipt, "workspace_id", default="") != workspace.id {
    return Err(
      workspace_entry_create_error(
        400, "Bad Request", "Trash receipt belongs to another workspace",
      ),
    )
  }
  let original_path = json_string(receipt, "original_path", default="")
  let target = match
    resolve_workspace_path(workspace.root_path, original_path) {
    Some((absolute, clean_relative)) => (absolute, clean_relative)
    None =>
      return Err(
        workspace_entry_create_error(
          400, "Bad Request", "Invalid restore target",
        ),
      )
  }
  let (target_absolute, target_relative) = target
  if !is_desk_create_path_allowed(target_relative) ||
    moonbook_section_for_path(target_relative) is Some(_) {
    return Err(
      workspace_entry_create_error(
        400, "Bad Request", "Desk cannot restore into generated or system paths",
      ),
    )
  }
  if @fs.exists(target_absolute) {
    return Err(
      workspace_entry_create_error(409, "Conflict", "Restore target exists"),
    )
  }
  @fsx.make_directory(
    @pathx.dirname(target_absolute).to_owned(),
    recursive=true,
    exists_ok=true,
  ) catch {
    _ =>
      return Err(
        workspace_entry_create_error(
          500, "Internal Server Error", "Could not create restore directory",
        ),
      )
  }
  @fs.rename(trash_absolute, target_absolute) catch {
    _ =>
      return Err(
        workspace_entry_create_error(
          500, "Internal Server Error", "Could not restore entry",
        ),
      )
  }
  Ok(rename_workspace_entry_response(workspace.id, target_relative))
}

///|
fn unique_trash_id(path : String) -> String {
  @desk.stable_id("trash", path + "-" + @async.now().to_string())
}

///|
fn is_desk_trash_path(path : String) -> Bool {
  path.has_prefix(desk_trash_files_relative_prefix()) && !path.contains("/../")
}

///|
async fn read_trash_receipt(root : String, trash_relative : String) -> Json? {
  let prefix = desk_trash_files_relative_prefix()
  if !trash_relative.has_prefix(prefix) {
    return None
  }
  let rest = trash_relative[prefix.length():].to_owned()
  let id = match rest.split_once("/") {
    Some((id, _)) => id.to_owned()
    None => return None
  }
  let receipt_absolute = @pathx.join(
    desk_trash_receipts_root(root),
    id + ".json",
  )
  if !@fs.exists(receipt_absolute) {
    return None
  }
  Some(@json.parse(@fs.read_file(receipt_absolute).text())) catch {
    _ => None
  }
}

///|
fn trash_workspace_entry_response(
  workspace_id : String,
  path : String,
  trash_path : String,
) -> Json {
  {
    "workspace_id": workspace_id,
    "path": path,
    "directory": parent_path_for_created_entry(path),
    "trash_path": trash_path,
  }
}

///|
fn desk_trash_files_relative_root() -> String {
  ".moonsuite/products/moondesk/trash/files"
}

///|
fn desk_trash_files_relative_prefix() -> String {
  desk_trash_files_relative_root() + "/"
}

///|
fn desk_trash_receipts_relative_root() -> String {
  ".moonsuite/products/moondesk/trash/receipts"
}

///|
fn desk_trash_files_root(workspace_root : String) -> String {
  moonsuite_product_artifact_for_workspace_root(
    workspace_root, "moondesk", "trash/files",
  )
}

///|
fn desk_trash_receipts_root(workspace_root : String) -> String {
  moonsuite_product_artifact_for_workspace_root(
    workspace_root, "moondesk", "trash/receipts",
  )
}

///|
fn desk_trash_file_relative_path(trash_id : String, name : String) -> String {
  @pathx.join(@pathx.join(desk_trash_files_relative_root(), trash_id), name)
}

///|
fn desk_trash_receipt_relative_path(trash_id : String) -> String {
  @pathx.join(desk_trash_receipts_relative_root(), trash_id + ".json")
}

///|
fn resolve_desk_trash_path(
  workspace_root : String,
  trash_relative : String,
) -> String? {
  let clean = @pathx.normalize(trash_relative)
  let prefix = desk_trash_files_relative_prefix()
  if !clean.has_prefix(prefix) || clean.contains("/../") {
    return None
  }
  let rest = clean[prefix.length():].to_owned()
  if rest == "" {
    None
  } else {
    Some(@pathx.join(desk_trash_files_root(workspace_root), rest))
  }
}

///|
fn resolve_desk_trash_receipt_path(
  workspace_root : String,
  receipt_relative : String,
) -> String? {
  let clean = @pathx.normalize(receipt_relative)
  let prefix = desk_trash_receipts_relative_root() + "/"
  if !clean.has_prefix(prefix) || clean.contains("/../") {
    return None
  }
  let rest = clean[prefix.length():].to_owned()
  if rest == "" {
    None
  } else {
    Some(@pathx.join(desk_trash_receipts_root(workspace_root), rest))
  }
}
