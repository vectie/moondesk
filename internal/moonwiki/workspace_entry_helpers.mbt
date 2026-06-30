///|
fn should_hide_file_entry(name : String) -> Bool {
  name == ".git" ||
  name == ".DS_Store" ||
  name == "DS_Store" ||
  name == "node_modules" ||
  name == "_build" ||
  name == ".moonclaw-worktrees"
}

///|
fn is_writable_entry(path : String) -> Bool {
  path == "inbox" || path.has_prefix("inbox/")
}

///|
fn is_binary_preview(kind : @desk.EntryKind) -> Bool {
  kind is Image
}

///|
async fn workspace_file_entry(
  workspace : @desk.DeskWorkspace,
  relative : String,
  absolute : String,
) -> @desk.DeskFileEntry {
  let is_directory = is_directory(absolute)
  @desk.file_entry(
    workspace_id=workspace.id,
    path=relative,
    is_directory~,
    writable=is_writable_entry(relative),
    size_bytes=if is_directory { None } else { file_size_bytes(absolute) },
    modified_at=file_modified_at(absolute),
  )
}

///|
async fn list_workspace_entries(
  workspace : @desk.DeskWorkspace,
  relative : String,
  absolute : String,
) -> Array[@desk.DeskFileEntry] {
  if relative == "" && workspace.kind is MoonBook {
    return list_moonbook_root_entries(workspace, absolute)
  }
  let entries : Array[@desk.DeskFileEntry] = []
  for name in read_directory_names(absolute, include_hidden=true) {
    if should_hide_file_entry(name) {
      continue
    }
    let child_relative = if relative == "" {
      name
    } else {
      relative + "/" + name
    }
    let child_absolute = @pathx.join(workspace.root_path, child_relative)
    entries.push(
      workspace_file_entry(workspace, child_relative, child_absolute),
    )
  }
  sort_workspace_entries(entries)
  entries
}

///|
async fn list_moonbook_root_entries(
  workspace : @desk.DeskWorkspace,
  absolute : String,
) -> Array[@desk.DeskFileEntry] {
  let entries : Array[@desk.DeskFileEntry] = []
  let child_entries : Array[@desk.DeskFileEntry] = []
  let covered_roots : Array[String] = []
  for section in @moonbook.canonical_sections() {
    let section_absolute = @pathx.join(workspace.root_path, section.path)
    entries.push(moonbook_section_entry(workspace, section, section_absolute))
    let root = root_path_segment(section.path)
    if !covered_roots.contains(root) {
      covered_roots.push(root)
    }
  }
  for name in read_directory_names(absolute, include_hidden=true) {
    if should_hide_file_entry(name) || covered_roots.contains(name) {
      continue
    }
    let child_absolute = @pathx.join(workspace.root_path, name)
    child_entries.push(workspace_file_entry(workspace, name, child_absolute))
  }
  sort_workspace_entries(child_entries)
  for entry in child_entries {
    entries.push(entry)
  }
  entries
}

///|
fn sort_workspace_entries(entries : Array[@desk.DeskFileEntry]) -> Unit {
  entries.sort_by(fn(left, right) { compare_workspace_entries(left, right) })
}

///|
fn compare_workspace_entries(
  left : @desk.DeskFileEntry,
  right : @desk.DeskFileEntry,
) -> Int {
  let left_directory = left.kind is Directory
  let right_directory = right.kind is Directory
  if left_directory && !right_directory {
    return -1
  }
  if !left_directory && right_directory {
    return 1
  }
  let by_name = left.display_name
    .to_lower()
    .compare(right.display_name.to_lower())
  if by_name != 0 {
    return by_name
  }
  left.path.compare(right.path)
}

///|
fn moonbook_section_for_path(path : String) -> @moonbook.MoonBookSection? {
  for section in @moonbook.canonical_sections() {
    if section.path == path {
      return Some(section)
    }
  }
  None
}

///|
fn is_virtual_moonbook_section(
  workspace : @desk.DeskWorkspace,
  path : String,
) -> Bool {
  workspace.kind is MoonBook && moonbook_section_for_path(path) is Some(_)
}

///|
async fn moonbook_section_entry(
  workspace : @desk.DeskWorkspace,
  section : @moonbook.MoonBookSection,
  absolute : String,
) -> @desk.DeskFileEntry {
  let is_directory = is_directory(absolute)
  @desk.file_entry_detail(
    workspace_id=workspace.id,
    path=section.path,
    display_name=section.label,
    kind=Directory,
    source_layer=section.layer,
    readable=true,
    writable=section.writable,
    size_bytes=if is_directory { None } else { file_size_bytes(absolute) },
    modified_at=file_modified_at(absolute),
  )
}

///|
fn root_path_segment(path : String) -> String {
  match path.split_once("/") {
    Some((root, _)) => root.to_owned()
    None => path
  }
}

///|
async fn file_size_bytes(path : String) -> Int? {
  let file = @fs.open(path, mode=ReadOnly) catch { _ => return None }
  defer file.close()
  let size = file.size() catch { _ => return None }
  Some(size.to_int())
}

///|
fn file_modified_at(path : String) -> String? {
  let stat = @moonlib/fsx.stat(path) catch { _ => return None }
  Some(format_unix_mtime(stat.mtime()))
}

///|
fn format_unix_mtime(second : Int64) -> String {
  let datetime = @time.PlainDateTime::from_unix_second(
    second, 0, @time.utc_offset,
  ) catch {
    _ => return second.to_string()
  }
  datetime.to_string() + "Z"
}

///|
async fn read_directory_names(
  path : String,
  include_hidden~ : Bool,
) -> Array[String] {
  let dir = @fs.opendir(path) catch { _ => return [] }
  defer dir.close()
  let names = dir.read_all(include_hidden~) catch { _ => return [] }
  names.sort()
  names
}

///|
async fn is_directory(path : String) -> Bool {
  let kind = @fs.kind(path) catch { _ => return false }
  match kind {
    Directory => true
    _ => false
  }
}
