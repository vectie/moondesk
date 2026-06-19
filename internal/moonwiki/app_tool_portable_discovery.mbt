///|
fn app_tool_books_root(root : String) -> String {
  @pathx.join(root, ".moontown/books")
}

///|
fn app_tool_book_root_for_id(root : String, book_id : String) -> String {
  @pathx.join(app_tool_books_root(root), book_id)
}

///|
fn app_tool_clean_book_id(book_id : String) -> String? {
  let trimmed = book_id.trim().to_owned()
  if trimmed == "" {
    return None
  }
  match clean_relative_path(trimmed) {
    Some(path) =>
      if path != "" && !path.contains("/") {
        Some(path)
      } else {
        None
      }
    None => None
  }
}

///|
async fn app_tool_book_ids_for_workspace(root : String) -> Array[String] {
  let book_ids : Array[String] = []
  let books_root = app_tool_books_root(root)
  if !is_directory(books_root) {
    return book_ids
  }
  for name in read_directory_names(books_root, include_hidden=false) {
    let book_id = match app_tool_clean_book_id(name) {
      Some(book_id) => book_id
      None => continue
    }
    let book_root = app_tool_book_root_for_id(root, book_id)
    if !is_directory(book_root) ||
      !@fs.exists(@pathx.join(book_root, "book.json")) {
      continue
    }
    let book_json = read_json_file_or_object(
      @pathx.join(book_root, "book.json"),
    )
    let manifest = read_json_file_or_object(
      @pathx.join(book_root, app_tool_manifest_relative_path(book_json)),
    )
    if app_tool_book_is_portable_candidate(book_root, book_json, manifest) {
      book_ids.push(book_id)
    }
  }
  book_ids
}
