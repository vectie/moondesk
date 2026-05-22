///|
pub async fn list_directory(path : StringView) -> Array[String] {
  let dir : @fs.Directory = @fs.opendir(path.to_string())
  defer dir.close()
  let entries : Array[String] = []
  for name in dir.read_all() {
    entries.push(@pathx.join(path, name))
  }
  entries.sort()
  entries
}
