///|
fn normalize_book_pattern_id_strict(pattern_id : String) -> String {
  match supported_book_pattern_id(pattern_id) {
    Some(id) => id
    None => ""
  }
}

///|
fn pdf_watch_pattern_id_from_book_json(book_json : Json) -> String {
  let pattern = normalize_book_pattern_id_strict(
    json_string(book_json, "pattern", default=""),
  )
  if pattern != "" {
    return pattern
  }
  let specialization = normalize_book_pattern_id_strict(
    json_string(book_json, "specialization", default=""),
  )
  if specialization != "" {
    return specialization
  }
  ""
}

///|
fn pdf_watch_book_id(topic : String, pattern_id~ : String) -> String {
  ignore(pattern_id)
  let suffix = "-pdf-watch"
  let base = @desk.stable_id("research", topic)
  if base.has_suffix(suffix) {
    base
  } else {
    base + suffix
  }
}

///|
fn normalize_pdf_watch_book_id(
  requested : String,
  topic~ : String,
  pattern_id~ : String,
) -> String {
  let cleaned = sanitize_external_id(requested)
  if cleaned != "" {
    cleaned
  } else {
    pdf_watch_book_id(topic, pattern_id~)
  }
}

///|
fn sanitize_external_id(value : String) -> String {
  let mut out = ""
  for ch in value.trim() {
    if (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') {
      out = out + ch.to_string()
    } else if ch >= 'A' && ch <= 'Z' {
      out = out + ch.to_string().to_lower()
    } else if out != "" && !out.has_suffix("-") {
      out = out + "-"
    }
  }
  out.trim(chars=['-']).to_owned()
}
