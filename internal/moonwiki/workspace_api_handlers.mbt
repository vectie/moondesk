///|
fn resolve_request_path(root : String, request_path : StringView) -> String? {
  let request_path = strip_query(request_path.to_owned())
  let relative = match request_path {
    "/" => "index.html"
    ['/', .. path] => path.to_owned()
    _ => return None
  }
  let normalized = @pathx.normalize(relative)
  if normalized == "." {
    return Some(@pathx.join(root, "index.html"))
  }
  if normalized == ".." || normalized.has_prefix("../") {
    return None
  }
  let resolved = @pathx.join(root, normalized)
  let expected_prefix = root + "/"
  if resolved == root || resolved.has_prefix(expected_prefix) {
    Some(resolved)
  } else {
    None
  }
}

///|
async fn discover_workspaces(
  workspace_root : String,
) -> Array[@desk.DeskWorkspace] {
  let root = @pathx.normalize(workspace_root)
  let books_root = moonsuite_books_root(root)
  let workspaces : Array[@desk.DeskWorkspace] = []
  if is_directory(books_root) {
    for name in read_directory_names(books_root, include_hidden=false) {
      let book_root = @pathx.join(books_root, name)
      if is_directory(book_root) {
        let workspace_name = moonbook_workspace_display_name(book_root, name)
        let workspace_status = moonbook_workspace_status(book_root)
        workspaces.push(
          @desk.workspace(
            id=@desk.stable_id("book", name),
            name=workspace_name,
            root_path=book_root,
            kind=MoonBook,
            status=workspace_status,
          ),
        )
      }
    }
    return sorted_discovered_workspaces(workspaces)
  }
  if !is_directory(moonsuite_state_dir(root)) {
    return []
  }
  [
    @desk.workspace(
      id=@desk.stable_id("root", root),
      name=@desk.display_name(root),
      root_path=root,
      kind=TownRoot,
    ),
  ]
}

///|
async fn moonbook_workspace_status(book_root : String) -> @desk.WorkspaceStatus {
  if @fs.exists(@pathx.join(book_root, "book.json")) {
    Ready
  } else {
    NeedsAttention
  }
}

///|
async fn moonbook_workspace_display_name(
  book_root : String,
  fallback : String,
) -> String {
  let book_json_path = @pathx.join(book_root, "book.json")
  if !@fs.exists(book_json_path) {
    return fallback
  }
  let book_json = read_json_file_or_object(book_json_path)
  let title = json_string(book_json, "title", default="").trim().to_owned()
  if title != "" {
    return title
  }
  let name = json_string(book_json, "name", default="").trim().to_owned()
  if name != "" {
    return name
  }
  fallback
}

///|
fn workspace_library_metadata(workspace_root : String) -> Json {
  let root = @pathx.normalize(workspace_root)
  {
    "root_path": root,
    "library_path": moonsuite_books_root(root),
    "suite_path": moonsuite_state_dir(root),
    "product_registry_path": moonsuite_product_registry_path(root),
  }
}

///|
fn sorted_discovered_workspaces(
  workspaces : Array[@desk.DeskWorkspace],
) -> Array[@desk.DeskWorkspace] {
  let sorted : Array[@desk.DeskWorkspace] = []
  let added : Array[String] = []
  while sorted.length() < workspaces.length() {
    let mut best : @desk.DeskWorkspace? = None
    for workspace in workspaces {
      if added.contains(workspace.id) {
        continue
      }
      match best {
        Some(current) =>
          if discovered_workspace_before(workspace, current) {
            best = Some(workspace)
          }
        None => best = Some(workspace)
      }
    }
    match best {
      Some(workspace) => {
        sorted.push(workspace)
        added.push(workspace.id)
      }
      None => break
    }
  }
  sorted
}

///|
fn discovered_workspace_before(
  left : @desk.DeskWorkspace,
  right : @desk.DeskWorkspace,
) -> Bool {
  if left.name != right.name {
    lexical_string_before(left.name, right.name)
  } else {
    lexical_string_before(left.root_path, right.root_path)
  }
}

///|
fn lexical_string_before(left : String, right : String) -> Bool {
  let left_chars = string_chars(left.to_lower())
  let right_chars = string_chars(right.to_lower())
  let limit = if left_chars.length() < right_chars.length() {
    left_chars.length()
  } else {
    right_chars.length()
  }
  for index in 0..<limit {
    let left_code = left_chars[index].to_int()
    let right_code = right_chars[index].to_int()
    if left_code < right_code {
      return true
    }
    if left_code > right_code {
      return false
    }
  }
  left_chars.length() < right_chars.length()
}

///|
fn string_chars(value : String) -> Array[Char] {
  let chars : Array[Char] = []
  for ch in value {
    chars.push(ch)
  }
  chars
}

///|
async fn find_workspace(
  workspace_root : String,
  workspace_id : String,
) -> @desk.DeskWorkspace? {
  for workspace in discover_workspaces(workspace_root) {
    if workspace.id == workspace_id {
      return Some(workspace)
    }
  }
  None
}
