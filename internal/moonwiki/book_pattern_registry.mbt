///|
fn book_pattern_records() -> Array[Json] {
  [
    {
      "id": "pdf-evidence-watch",
      "title": "PDF Evidence Watch Book",
      "base_type": "research-book",
      "description": "A reusable research-book pattern that watches websites, discovers PDFs, extracts text, analyzes against a method page, and notifies only when accepted knowledge changes.",
      "output": "wiki findings and generated book site",
      "default_topic": "my domain",
      "default_cadence_minutes": 30,
      "default_source_policy": "web-first",
      "standing_watch": true,
      "creation_backend": "builtin-pdf-evidence-watch",
      "default_websites": json_from_string_array([
        "https://example.org/reports", "https://example.com/publications",
      ]),
      "skills": json_from_string_array(["pdf-watch", "pdf-analysis"]),
      "template_registry_refs": json_from_string_array([
        "moontown://templates/books/templates.json", "moontown://templates/books/pdf-evidence-watch/book.json",
        "moontown://protocols/standing-goal.v1", "moontown://protocols/book-template-request.v1",
      ]),
      "output_files": json_from_string_array([
        "raw/pdfs/",
        "raw/extracted/",
        pdf_watch_operator_config_relative_path(),
        pdf_watch_base_type_selection_relative_path(),
        "wiki/sources/",
        "wiki/evidence-matrix.md",
        "wiki/findings/",
        "book/site/generated/index.html",
        pdf_watch_moontown_standing_goal_receipt_relative_path(),
        pdf_watch_moontown_publish_receipt_relative_path(),
      ]),
    },
  ]
}

///|
fn book_pattern_record(pattern_id : String) -> Json? {
  let id = pattern_id.trim().to_owned()
  for record in book_pattern_records() {
    if json_string(record, "id", default="") == id {
      return Some(record)
    }
  }
  None
}

///|
fn supported_book_pattern_id(pattern_id : String) -> String? {
  match book_pattern_record(pattern_id) {
    Some(record) => Some(json_string(record, "id", default=""))
    None => None
  }
}

///|
fn book_pattern_supported(pattern_id : String) -> Bool {
  book_pattern_record(pattern_id) is Some(_)
}

///|
fn book_pattern_base_type(pattern_id : String) -> String {
  match book_pattern_record(pattern_id) {
    Some(record) => json_string(record, "base_type", default="")
    None => ""
  }
}

///|
fn book_pattern_template_registry_refs(pattern_id : String) -> Array[String] {
  match book_pattern_record(pattern_id) {
    Some(record) => json_string_array_items(record, "template_registry_refs")
    None => []
  }
}

///|
fn book_pattern_default_skills(pattern_id : String) -> Array[String] {
  match book_pattern_record(pattern_id) {
    Some(record) => json_string_array_items(record, "skills")
    None => []
  }
}

///|
fn book_pattern_output_files(pattern_id : String) -> Array[String] {
  match book_pattern_record(pattern_id) {
    Some(record) => json_string_array_items(record, "output_files")
    None => []
  }
}

///|
fn book_pattern_supports_standing_watch(pattern_id : String) -> Bool {
  match book_pattern_record(pattern_id) {
    Some(record) => json_bool(record, "standing_watch", default=false)
    None => false
  }
}

///|
fn book_pattern_creation_backend(pattern_id : String) -> String {
  match book_pattern_record(pattern_id) {
    Some(record) => json_string(record, "creation_backend", default="")
    None => ""
  }
}
