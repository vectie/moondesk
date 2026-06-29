///|
fn should_hide_file_entry(name : String) -> Bool {
  name == ".git" ||
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
  entries
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
