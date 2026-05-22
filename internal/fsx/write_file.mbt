///|
pub async fn write_to_file(
  path : StringView,
  content : StringView,
  create? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path.to_string(),
    @encoding/utf8.encode(content),
    create~,
    truncate=true,
  )
}
