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
