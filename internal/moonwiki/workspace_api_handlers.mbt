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
  let books_root = @pathx.join(root, ".moontown/books")
  let workspaces : Array[@desk.DeskWorkspace] = []
  if is_directory(books_root) {
    for name in read_directory_names(books_root, include_hidden=false) {
      let book_root = @pathx.join(books_root, name)
      if is_directory(book_root) {
        workspaces.push(
          @desk.workspace(
            id=@desk.stable_id("book", name),
            name~,
            root_path=book_root,
            kind=MoonBook,
          ),
        )
      }
    }
  }
  if workspaces.length() > 0 {
    return workspaces
  }
  if !is_directory(@pathx.join(root, ".moontown")) {
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
