///|
/// Resolve an existing path only when its canonical target remains under the
/// canonical root. Callers perform IO on the returned canonical path.
pub async fn resolve_confined_existing(
  root : StringView,
  relative : StringView,
) -> String? {
  let relative = relative.to_owned()
  if invalid_relative_path(relative) {
    return None
  }
  let canonical_root = @fs.realpath(root) catch { _ => return None }
  let candidate = @pathx.join(canonical_root, relative)
  let canonical_target = @fs.realpath(candidate) catch { _ => return None }
  if path_is_within(canonical_root, canonical_target) {
    Some(canonical_target)
  } else {
    None
  }
}

///|
/// Resolve a write destination under a canonical root. The nearest existing
/// parent is canonicalized before missing descendants are created. Existing
/// final-component symlinks are refused.
pub async fn resolve_confined_write(
  root : StringView,
  relative : StringView,
) -> String? {
  let relative = relative.to_owned()
  if invalid_relative_path(relative) || relative == "" {
    return None
  }
  let canonical_root = @fs.realpath(root) catch { _ => return None }
  let candidate = @pathx.join(canonical_root, relative)
  if @fs.exists(candidate) {
    let followed = @fs.realpath(candidate) catch { _ => return None }
    let kind = @fs.kind(candidate, follow_symlink=false) catch {
      _ => return None
    }
    if kind is SymLink || !path_is_within(canonical_root, followed) {
      return None
    }
    return Some(followed)
  }
  let missing : Array[String] = []
  let mut parent = @pathx.dirname(candidate).to_owned()
  while !@fs.exists(parent) {
    missing.push(parent)
    let next = @pathx.dirname(parent).to_owned()
    if next == parent {
      return None
    }
    parent = next
  }
  let mut canonical_parent = @fs.realpath(parent) catch { _ => return None }
  if !path_is_within(canonical_root, canonical_parent) {
    return None
  }
  let mut index = missing.length()
  while index > 0 {
    index -= 1
    let leaf = path_leaf(missing[index])
    let next = @pathx.join(canonical_parent, leaf)
    @fs.mkdir(next, permission=0o755) catch {
      _ => return None
    }
    canonical_parent = @fs.realpath(next) catch { _ => return None }
    if !path_is_within(canonical_root, canonical_parent) {
      return None
    }
  }
  let destination = @pathx.join(canonical_parent, path_leaf(candidate))
  if path_is_within(canonical_root, destination) {
    Some(destination)
  } else {
    None
  }
}

///|
pub async fn read_confined_text(
  root : StringView,
  relative : StringView,
) -> String? {
  match resolve_confined_existing(root, relative) {
    Some(path) => Some(@fs.read_file(path).text())
    None => None
  }
}

///|
pub async fn write_confined_text(
  root : StringView,
  relative : StringView,
  content : StringView,
  create? : Int = 0o644,
) -> Bool {
  match resolve_confined_write(root, relative) {
    Some(path) => {
      @fs.write_file(
        path,
        @encoding/utf8.encode(content),
        create_mode=CreateOrTruncate,
        permission=create,
      ) catch {
        _ => return false
      }
      true
    }
    None => false
  }
}

///|
pub(all) enum ConfinedWriteResult {
  Saved
  Conflict(String)
  InvalidTarget
  UnsupportedText
  WriteFailed
} derive(Eq, Debug)

///|
/// Compare and replace one existing UTF-8 file under the confined root. The
/// current content is always returned so callers can offer reload or compare.
pub async fn compare_and_write_confined_text(
  root : StringView,
  relative : StringView,
  expected : StringView,
  content : StringView,
) -> ConfinedWriteResult {
  let path = match resolve_confined_existing(root, relative) {
    Some(path) => path
    None => return InvalidTarget
  }
  let current = @fs.read_file(path).text() catch { _ => return UnsupportedText }
  if current != expected.to_owned() {
    return Conflict(current)
  }
  @fs.write_file(
    path,
    @encoding/utf8.encode(content),
    create_mode=CreateOrTruncate,
    permission=0o644,
  ) catch {
    _ => return WriteFailed
  }
  Saved
}

///|
pub(all) enum ConfinedBytesWriteResult {
  SavedBytes
  ConflictBytes(Bytes)
  InvalidBytesTarget
  BytesWriteFailed
} derive(Eq, Debug)

///|
pub async fn compare_and_write_confined_bytes(
  root : StringView,
  relative : StringView,
  expected : BytesView,
  content : BytesView,
) -> ConfinedBytesWriteResult {
  let path = match resolve_confined_existing(root, relative) {
    Some(path) => path
    None => return InvalidBytesTarget
  }
  let current = @fs.read_file(path).binary() catch {
    _ => return BytesWriteFailed
  }
  if current != expected.to_owned() {
    return ConflictBytes(current)
  }
  @fs.write_file(path, content, create_mode=CreateOrTruncate, permission=0o644) catch {
    _ => return BytesWriteFailed
  }
  SavedBytes
}

///|
fn invalid_relative_path(relative : String) -> Bool {
  relative.has_prefix("/") ||
  @pathx.is_absolute(relative) ||
  relative.split("/").any(part => part == "..")
}

///|
fn path_is_within(root : String, candidate : String) -> Bool {
  candidate == root || candidate.has_prefix(root + "/")
}

///|
fn path_leaf(path : String) -> String {
  let normalized = @pathx.normalize(path)
  let parent = @pathx.dirname(normalized).to_owned()
  if parent == "." {
    normalized
  } else {
    normalized[parent.length() + 1:].to_owned()
  }
}
