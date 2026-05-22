///|
pub async fn make_directory(
  path : StringView,
  recursive? : Bool = false,
  exists_ok? : Bool = false,
) -> Unit {
  let dirs : Array[String] = []
  collect_missing_dirs(path.to_string(), dirs, recursive)
  for i = 0; i < dirs.length(); i = i + 1 {
    let dir = dirs[dirs.length() - 1 - i]
    if exists_ok && @fs.exists(dir) {
      continue
    }
    @fs.mkdir(dir, permission=0o755) catch {
      error => if exists_ok { () } else { raise error }
    }
  }
}

///|
async fn collect_missing_dirs(
  current : String,
  dirs : Array[String],
  recursive : Bool,
) -> Unit {
  if current == "." || current == "" || @fs.exists(current) {
    return
  }
  dirs.push(current)
  if !recursive {
    return
  }
  let parent = @pathx.dirname(current).to_string()
  if parent == current {
    return
  }
  collect_missing_dirs(parent, dirs, recursive)
}
