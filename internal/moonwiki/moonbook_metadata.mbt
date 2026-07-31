///|
fn moonbook_metadata_requirement() -> String {
  "book.json or canonical book.toml/wiki.toml metadata"
}

///|
fn moonbook_toml_string(value : StringView) -> String? {
  let text = value.trim().to_owned()
  if text.has_prefix("\"") {
    guard text.rev_split_once("\"") is Some((body, suffix)) else { return None }
    guard body.length() >= 1 &&
      (suffix.trim().is_empty() || suffix.trim().to_owned().has_prefix("#")) else {
      return None
    }
    return Some(
      body[1:]
      .to_owned()
      .replace(old="\\\"", new="\"")
      .replace(old="\\\\", new="\\"),
    )
  }
  if text.has_prefix("'") {
    guard text.rev_split_once("'") is Some((body, suffix)) else { return None }
    guard body.length() >= 1 &&
      (suffix.trim().is_empty() || suffix.trim().to_owned().has_prefix("#")) else {
      return None
    }
    return Some(body[1:].to_owned())
  }
  None
}

///|
fn moonbook_toml_book_metadata(text : String) -> Json {
  let fields : Map[String, String] = Map([])
  let mut in_book = false
  for source_line in text.split("\n") {
    let line = source_line.trim().to_owned()
    if line == "" || line.has_prefix("#") {
      continue
    }
    if line.has_prefix("[") {
      in_book = line == "[book]"
      continue
    }
    if !in_book {
      continue
    }
    guard line.split_once("=") is Some((key_view, value_view)) else { continue }
    let key = key_view.trim().to_owned()
    if !["id", "book_id", "title", "name"].contains(key) {
      continue
    }
    match moonbook_toml_string(value_view) {
      Some(value) => fields[key] = value.trim().to_owned()
      None => ()
    }
  }
  let id = match fields.get("id") {
    Some(value) => value
    None => fields.get("book_id").unwrap_or("")
  }
  let title = match fields.get("title") {
    Some(value) => value
    None => fields.get("name").unwrap_or("")
  }
  { "id": id, "book_id": id, "title": title, "name": title }
}

///|
async fn moonbook_metadata(root : String) -> Json? {
  let json_path = @pathx.join(root, "book.json")
  if @fs.exists(json_path) && !is_directory(json_path) {
    return Some(
      @json.parse(@fs.read_file(json_path).text()) catch {
        _ => Json::object({})
      },
    )
  }
  let book_toml_path = @pathx.join(root, "book.toml")
  if @fs.exists(book_toml_path) && !is_directory(book_toml_path) {
    return Some(
      moonbook_toml_book_metadata(@fs.read_file(book_toml_path).text()),
    )
  }
  let wiki_toml_path = @pathx.join(root, "wiki.toml")
  if @fs.exists(wiki_toml_path) && !is_directory(wiki_toml_path) {
    return Some(Json::object({}))
  }
  None
}

///|
async fn moonbook_metadata_exists(root : String) -> Bool {
  moonbook_metadata(root) is Some(_)
}
