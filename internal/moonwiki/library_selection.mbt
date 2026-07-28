///|
fn library_selection_path(bootstrap_root : String) -> String {
  @pathx.join(
    moonsuite_product_artifact_for_workspace_root(
      bootstrap_root, "moondesk", "preferences",
    ),
    "library.json",
  )
}

///|
fn library_selection_basename(path : String) -> String {
  path.split("/").last().unwrap_or("").to_owned()
}

///|
async fn validated_library_root(input : String) -> Result[String, String] {
  let trimmed = input.trim().to_owned()
  if trimmed == "" {
    return Err("Choose a library folder")
  }
  if !@pathx.is_absolute(trimmed) {
    return Err("The library folder must use an absolute path")
  }
  let mut root = @pathx.normalize(trimmed)
  if library_selection_basename(root) == "books" {
    root = @pathx.dirname(root).to_owned()
  }
  root = @fs.realpath(root) catch {
    _ => return Err("The selected library folder could not be resolved")
  }
  if @pathx.dirname(root).to_owned() == root {
    return Err("The filesystem root cannot be used as a library")
  }
  let kind = @fs.kind(root) catch {
    _ => return Err("The selected library folder could not be inspected")
  }
  if !(kind is Directory) {
    return Err("The selected library path must be a folder")
  }
  if @fsx.exists(@pathx.join(root, "book.json")) {
    return Err("Choose a library folder, not one MoonBook")
  }
  if @fsx.exists(@pathx.join(root, "moon.mod")) ||
    @fsx.exists(@pathx.join(root, "moon.mod.json")) ||
    @fsx.exists(@pathx.join(root, ".git")) {
    return Err("A source checkout cannot be used as a library")
  }
  Ok(root)
}

///|
async fn restore_library_root(bootstrap_root : String) -> String {
  let fallback = @pathx.normalize(bootstrap_root)
  let path = library_selection_path(fallback)
  if !@fsx.exists(path) {
    return fallback
  }
  let record = @json.parse(@fsx.read_file(path)) catch { _ => return fallback }
  let saved = json_string(record, "root_path", default="")
  match validated_library_root(saved) {
    Ok(root) => root
    Err(_) => fallback
  }
}

///|
async fn persist_library_root(bootstrap_root : String, root : String) -> Bool {
  let path = library_selection_path(bootstrap_root)
  @fsx.make_directory(
    @pathx.dirname(path).to_owned(),
    recursive=true,
    exists_ok=true,
  ) catch {
    _ => return false
  }
  @fsx.write_to_file(
    path,
    ({ "root_path": root } : Json).stringify(indent=2) + "\n",
    create=0o644,
  ) catch {
    _ => return false
  }
  true
}

///|
async fn select_library_root(
  bootstrap_root : String,
  input : String,
) -> Result[String, String] {
  let root = match validated_library_root(input) {
    Ok(root) => root
    Err(message) => return Err(message)
  }
  if !prepare_moonsuite_workspace_root(root) {
    return Err("MoonDesk could not prepare the selected library folder")
  }
  if !persist_library_root(bootstrap_root, root) {
    return Err("MoonDesk could not remember the selected library folder")
  }
  Ok(root)
}

///|
async fn handle_desktop_library_request(
  bootstrap_root : String,
  active_root : Ref[String],
  method_ : @http.RequestMethod,
  body : &@io.Reader,
  conn : @http.ServerConnection,
) -> Unit {
  if method_ is Get || method_ is Head {
    send_json(conn, method_, workspace_library_metadata(active_root.val))
    return
  }
  if !(method_ is Post) {
    send_method_not_allowed_with_methods(conn, method_, ["GET", "HEAD", "POST"])
    return
  }
  let payload = match read_json_body(body) {
    Some(payload) => payload
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  let selected = json_string(payload, "root_path", default="")
  match select_library_root(bootstrap_root, selected) {
    Ok(root) => {
      active_root.val = root
      send_json(conn, method_, workspace_library_metadata(root))
    }
    Err(message) => send_api_error(conn, method_, 400, "Bad Request", message)
  }
}
